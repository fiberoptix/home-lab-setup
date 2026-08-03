"""Position keeper: consumes order events and maintains filled quantity.

This is the half of the system where delivery semantics stop being theory.
Chapter 5 proved that a SIGKILLed consumer's successor replays everything
between the last commit and the crash. This program shows what that does to a
number a business actually cares about.

Every fill is applied TWO ways at once, so a single run shows both outcomes
side by side:

  fills   TRANSACTIONAL and idempotent. UPSERT keyed by (order_id, seq),
          written inside the same transaction that the offset commit follows.
          Replaying an event overwrites the same row, so the total does not
          move.

  gateway NON-TRANSACTIONAL and accumulating: an autocommit connection, one
          durable write per event, `total = total + qty`. This models a side
          effect that leaves the process and cannot be taken back -- a POST to
          an execution venue, an email, a payment. There is no rollback.

The first version of this program made BOTH ledgers transactional, and a hard
kill produced zero duplicates. That was not a broken demo, it was the finding:
when your state store is transactional and you commit the offset AFTER the
write, a crash rolls the writes back and redelivery re-applies them cleanly --
effectively-once, with no dedupe logic at all.

Duplicates only hurt when the side effect escapes the transaction. Hence the
two paths here.

State lives in SQLite on a volume, not in memory, and that is deliberate. An
in-process dedupe set is useless here: it is destroyed by exactly the crash
that causes the duplicates. Idempotency has to live wherever the state lives.

  COMMIT_EVERY=N     records processed between offset commits. This is the
                     replay window: duplicates on crash ~= COMMIT_EVERY.
                     Auto-commit is DISABLED; we commit after the write, so a
                     crash costs a duplicate (recoverable) rather than a lost
                     record (not).
  COMMIT_SECONDS=N   commit after N seconds even if COMMIT_EVERY was not
                     reached. Without this, a count-only trigger leaves the
                     TAIL of the stream permanently uncommitted on an idle
                     topic: lag sticks at a non-zero number forever, and every
                     restart replays the same records again. Measured: lag
                     stuck at 13, +11 duplicate gateway calls per restart,
                     compounding 11 -> 22 -> 33.
  IDLE_EXIT=N        exit after N seconds with no new records. 0 = run forever.
"""

import os
import signal
import sqlite3
import sys
import time

from confluent_kafka import Consumer, KafkaError

from oms import decode

BROKERS = os.environ.get("BROKERS", "redpanda.redpanda.svc.cluster.local:9093")
TOPIC = os.environ.get("TOPIC", "orders")
GROUP = os.environ.get("GROUP", "position-keeper")
COMMIT_EVERY = int(os.environ.get("COMMIT_EVERY", "50"))
COMMIT_SECONDS = float(os.environ.get("COMMIT_SECONDS", "5"))
IDLE_EXIT = float(os.environ.get("IDLE_EXIT", "0"))
STATE = os.environ.get("STATE", "/state/positions.db")
GATEWAY = os.environ.get("GATEWAY", "/state/gateway.db")
RESET = os.environ.get("RESET", "false").lower() == "true"

running = True


def stop(signum, _frame):
    # SIGTERM is the graceful path (Ch5 6): stop the loop, commit, close the
    # group membership explicitly. SIGKILL cannot be handled -- that is the
    # entire point of the contrast.
    global running
    print(f"signal {signum} received, shutting down gracefully", flush=True)
    running = False


def open_state():
    os.makedirs(os.path.dirname(STATE), exist_ok=True)

    # Two SEPARATE files, not two connections to one. The first attempt shared
    # a file and deadlocked: the transactional connection holds SQLite's write
    # lock from its first write until commit, so the autocommit connection was
    # starved. Separate files is also the truer model -- the execution venue is
    # a different system, not another table in your database.

    # Transactional: writes are staged and only become durable at db.commit(),
    # immediately before the offset commit.
    db = sqlite3.connect(STATE)

    # Autocommit (isolation_level=None): every statement is durable the instant
    # it runs and cannot be rolled back. Stand-in for a side effect that has
    # already left the building.
    gw = sqlite3.connect(GATEWAY, isolation_level=None)

    if RESET:
        db.executescript("DROP TABLE IF EXISTS fills;")
        gw.executescript("DROP TABLE IF EXISTS gateway;")
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS fills (
            order_id TEXT NOT NULL,
            seq      INTEGER NOT NULL,
            qty      INTEGER NOT NULL,
            PRIMARY KEY (order_id, seq)
        );
        """
    )
    db.commit()
    gw.executescript(
        """
        CREATE TABLE IF NOT EXISTS gateway (
            id    INTEGER PRIMARY KEY CHECK (id = 1),
            total INTEGER NOT NULL,
            calls INTEGER NOT NULL
        );
        INSERT OR IGNORE INTO gateway (id, total, calls) VALUES (1, 0, 0);
        """
    )
    return db, gw


def totals(db, gw):
    idem = db.execute("SELECT COALESCE(SUM(qty), 0) FROM fills").fetchone()[0]
    sent, calls = gw.execute("SELECT total, calls FROM gateway WHERE id = 1").fetchone()
    return idem, sent, calls


def apply_event(db, gw, event):
    """Apply the same fill both ways, so one run shows the difference."""
    if event["type"] != "FILL":
        return

    # (1) The external, non-transactional side effect. Durable immediately,
    # no rollback, no idempotency key. Reprocessing sends it AGAIN.
    gw.execute(
        "UPDATE gateway SET total = total + ?, calls = calls + 1 WHERE id = 1",
        (event["qty"],),
    )

    # (2) Transactional idempotent state. Upsert on the natural business key,
    # so re-applying the same event is a no-op.
    db.execute(
        "INSERT INTO fills (order_id, seq, qty) VALUES (?, ?, ?) "
        "ON CONFLICT(order_id, seq) DO UPDATE SET qty = excluded.qty",
        (event["order_id"], event["seq"], event["qty"]),
    )


def main():
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    db, gw = open_state()
    print(
        f"consumer: brokers={BROKERS} topic={TOPIC} group={GROUP} "
        f"commit_every={COMMIT_EVERY} commit_seconds={COMMIT_SECONDS} state={STATE}",
        flush=True,
    )

    c = Consumer(
        {
            "bootstrap.servers": BROKERS,
            "group.id": GROUP,
            "auto.offset.reset": "earliest",
            # Explicit commits only. Auto-commit would commit records we have
            # not finished writing, converting a duplicate into a LOST record.
            "enable.auto.commit": False,
            "client.id": os.environ.get("HOSTNAME", "consumer"),
        }
    )
    c.subscribe([TOPIC])

    processed = 0
    since_commit = 0
    last_commit = time.time()
    last_msg = time.time()

    # seq of the last event seen per order. Lets the consumer PROVE ordering
    # instead of assuming it: a gap means records arrived out of order or were
    # lost; a regression means the same events were replayed.
    last_seq = {}
    gaps = 0
    replays = 0

    def flush_commit():
        # Order matters: durable state first, THEN the offset. A crash between
        # the two replays the window -- safe only because the transactional
        # write is idempotent. Committing the offset first would LOSE records.
        nonlocal since_commit, last_commit
        db.commit()
        c.commit(asynchronous=False)
        since_commit = 0
        last_commit = time.time()

    try:
        while running:
            msg = c.poll(1.0)
            if msg is None:
                # An idle topic still needs the tail committed, or lag never
                # reaches zero and every restart replays the same records.
                if since_commit and time.time() - last_commit >= COMMIT_SECONDS:
                    flush_commit()
                if IDLE_EXIT and time.time() - last_msg > IDLE_EXIT:
                    print(f"idle for {IDLE_EXIT}s, exiting", flush=True)
                    break
                continue
            if msg.error():
                if msg.error().code() != KafkaError._PARTITION_EOF:
                    print(f"consume error: {msg.error()}", flush=True)
                continue

            last_msg = time.time()
            event = decode(msg.value())

            oid, seq = event["order_id"], event["seq"]
            prev = last_seq.get(oid)
            if prev is not None:
                if seq <= prev:
                    replays += 1
                elif seq > prev + 1:
                    gaps += 1
            last_seq[oid] = max(seq, prev) if prev is not None else seq

            apply_event(db, gw, event)
            processed += 1
            since_commit += 1

            if since_commit >= COMMIT_EVERY or time.time() - last_commit >= COMMIT_SECONDS:
                flush_commit()

            if processed % 100 == 0:
                idem, sent, calls = totals(db, gw)
                print(
                    f"processed={processed} idempotent_total={idem} "
                    f"gateway_total={sent} gateway_calls={calls} "
                    f"seq_gaps={gaps} seq_replays={replays}",
                    flush=True,
                )
    finally:
        db.commit()
        try:
            c.commit(asynchronous=False)
        except Exception as exc:                     # nothing committed yet
            print(f"final commit skipped: {exc}", flush=True)
        idem, sent, calls = totals(db, gw)
        print(
            f"FINAL processed={processed} idempotent_total={idem} "
            f"gateway_total={sent} gateway_calls={calls} "
            f"seq_gaps={gaps} seq_replays={replays}",
            flush=True,
        )
        c.close()
        db.close()
        gw.close()


if __name__ == "__main__":
    main()
    sys.exit(0)
