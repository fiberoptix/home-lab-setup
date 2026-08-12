"""Shared model for the toy order management system.

The event shape is deliberately minimal, but every field exists to make one
specific failure visible in Chapter 6:

  event_id   unique per event. Available as a dedupe key, but note that the
             consumer does NOT use it: it upserts on (order_id, seq), the
             natural business key. A surrogate id only dedupes retries of the
             same emission; the business key also dedupes a re-run of the
             producer, which is the failure that actually happens (Ch6 7).
  order_id   the PARTITION KEY. Same order -> same partition -> ordered
             (Ch3 2). This is the only reason per-order sequencing works.
  seq        per-order sequence number, so the consumer can PROVE ordering
             rather than assume it, and detect gaps caused by loss.
  qty        filled quantity. Duplicates inflate the total, which turns
             "we processed a message twice" into a visibly wrong number.
  ts         emission time, epoch seconds. Consumer lag is a count of records,
             which nobody can act on; ts turns it into "our view of the book is
             N seconds stale", which is what an SLO can be written against.

Arithmetic is deliberately fixed so the correct answer is knowable without
any coordination between producer and consumer:

    FILLS_PER_ORDER (4) x FILL_QTY (100) = 400 shares per order
"""

import json
import time
import uuid

FILLS_PER_ORDER = 4
FILL_QTY = 100
QTY_PER_ORDER = FILLS_PER_ORDER * FILL_QTY

REQUIRED = ("order_id", "seq", "type", "qty")


def order_events(order_id):
    """The full lifecycle of one order: NEW, then FILLS_PER_ORDER fills."""
    yield {
        "event_id": str(uuid.uuid4()),
        "order_id": order_id,
        "seq": 0,
        "type": "NEW",
        "qty": 0,
        "ts": time.time(),
    }
    for n in range(1, FILLS_PER_ORDER + 1):
        yield {
            "event_id": str(uuid.uuid4()),
            "order_id": order_id,
            "seq": n,
            "type": "FILL",
            "qty": FILL_QTY,
            "ts": time.time(),
        }


def encode(event):
    return json.dumps(event, separators=(",", ":")).encode()


def decode(raw):
    """Parse and validate. Raises on anything the consumer cannot act on.

    Validating here rather than letting a KeyError surface three frames deeper
    is what makes the consumer's poison-message path able to report WHICH field
    was wrong. A schema registry (Ch7) moves this check to the broker boundary
    and to compile time; this is the hand-rolled version of the same idea.
    """
    event = json.loads(raw)
    if not isinstance(event, dict):
        raise ValueError(f"expected a JSON object, got {type(event).__name__}")
    missing = [f for f in REQUIRED if f not in event]
    if missing:
        raise ValueError(f"missing required field(s): {', '.join(missing)}")
    if not isinstance(event["seq"], int) or not isinstance(event["qty"], int):
        raise ValueError("seq and qty must be integers")
    return event


def expected_total(n_orders):
    return n_orders * QTY_PER_ORDER
