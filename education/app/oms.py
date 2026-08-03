"""Shared model for the toy order management system.

The event shape is deliberately minimal, but every field exists to make one
specific failure visible in Chapter 6:

  event_id   unique per event. The consumer dedupes on this, which is what
             makes at-least-once delivery survivable (Ch5 7).
  order_id   the PARTITION KEY. Same order -> same partition -> ordered
             (Ch3 2). This is the only reason per-order sequencing works.
  seq        per-order sequence number, so the consumer can PROVE ordering
             rather than assume it, and detect gaps caused by loss.
  qty        filled quantity. Duplicates inflate the total, which turns
             "we processed a message twice" into a visibly wrong number.

Arithmetic is deliberately fixed so the correct answer is knowable without
any coordination between producer and consumer:

    FILLS_PER_ORDER (4) x FILL_QTY (100) = 400 shares per order
"""

import json
import uuid

FILLS_PER_ORDER = 4
FILL_QTY = 100
QTY_PER_ORDER = FILLS_PER_ORDER * FILL_QTY


def order_events(order_id):
    """The full lifecycle of one order: NEW, then FILLS_PER_ORDER fills."""
    yield {
        "event_id": str(uuid.uuid4()),
        "order_id": order_id,
        "seq": 0,
        "type": "NEW",
        "qty": 0,
    }
    for n in range(1, FILLS_PER_ORDER + 1):
        yield {
            "event_id": str(uuid.uuid4()),
            "order_id": order_id,
            "seq": n,
            "type": "FILL",
            "qty": FILL_QTY,
        }


def encode(event):
    return json.dumps(event, separators=(",", ":")).encode()


def decode(raw):
    return json.loads(raw)


def expected_total(n_orders):
    return n_orders * QTY_PER_ORDER
