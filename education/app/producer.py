"""Order gateway: emits keyed order-lifecycle events.

Every knob that matters is an environment variable, because the point of this
program is to demonstrate what each one costs you:

  ACKS=all|1|0        durability. `0` is fire-and-forget: the client reports
                      success without the broker ever confirming, so a broker
                      failure loses records SILENTLY.
  IDEMPOTENCE=true    the PRODUCER-side duplicate guard. Without it, an
                      internal retry after a timeout can append the same
                      record twice -- a duplicate the consumer's dedupe would
                      have to catch. Requires acks=all.
  ORDERS=50           how many orders to emit (each = 1 NEW + 4 FILLs).
  RATE=0              records/second. 0 = as fast as possible.

Exits non-zero if any delivery failed, so a Job wrapping it goes red.
"""

import os
import sys
import time

from confluent_kafka import Producer

from oms import QTY_PER_ORDER, encode, order_events

BROKERS = os.environ.get("BROKERS", "redpanda.redpanda.svc.cluster.local:9093")
TOPIC = os.environ.get("TOPIC", "orders")
ACKS = os.environ.get("ACKS", "all")
IDEMPOTENCE = os.environ.get("IDEMPOTENCE", "true").lower() == "true"
ORDERS = int(os.environ.get("ORDERS", "50"))
RATE = float(os.environ.get("RATE", "0"))
PREFIX = os.environ.get("PREFIX", "ORD")

stats = {"delivered": 0, "failed": 0}


def on_delivery(err, msg):
    if err is not None:
        stats["failed"] += 1
        print(f"DELIVERY FAILED  {err}", flush=True)
    else:
        stats["delivered"] += 1


def main():
    conf = {
        "bootstrap.servers": BROKERS,
        "acks": ACKS,
        "client.id": os.environ.get("HOSTNAME", "producer"),
    }
    # librdkafka rejects enable.idempotence together with acks!=all, so only
    # set it when it is actually coherent. That refusal is itself the lesson:
    # idempotence is BUILT ON acks=all, it is not an alternative to it.
    if IDEMPOTENCE:
        conf["enable.idempotence"] = True

    print(
        f"producer: brokers={BROKERS} topic={TOPIC} acks={ACKS} "
        f"idempotence={IDEMPOTENCE} orders={ORDERS} rate={RATE}/s",
        flush=True,
    )

    p = Producer(conf)
    sent = 0
    t0 = time.time()

    for i in range(1, ORDERS + 1):
        order_id = f"{PREFIX}-{i}"
        for event in order_events(order_id):
            # The KEY is the order id. This is the whole ordering guarantee:
            # hash(order_id) % partitions is stable, so every event for this
            # order lands on one partition and is read in the order written.
            p.produce(
                TOPIC,
                key=order_id.encode(),
                value=encode(event),
                on_delivery=on_delivery,
            )
            sent += 1
            p.poll(0)
            if RATE:
                time.sleep(1.0 / RATE)

    remaining = p.flush(30)
    elapsed = time.time() - t0

    print(
        f"produced={sent} delivered={stats['delivered']} failed={stats['failed']} "
        f"unflushed={remaining} in {elapsed:.1f}s",
        flush=True,
    )
    print(f"expected filled quantity = {ORDERS} x {QTY_PER_ORDER} = {ORDERS * QTY_PER_ORDER}", flush=True)

    if stats["failed"] or remaining:
        sys.exit(1)


if __name__ == "__main__":
    main()
