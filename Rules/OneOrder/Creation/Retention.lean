import Rules.Core.Attributes
import Rules.Core.Time
import Rules.OneOrder.Order

/-!
# Order retention

IATA Resolution 797 asks the airline that owns an order to keep it accessible
for 13 months from its creation and from its first usage while an item is
open, and for 7 days once every item has reached a final status.  It does not
say how 13 months is counted on UTC instants, so the model takes the count as
a parameter.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-- How 13 months are counted from a UTC instant.  The resolution does not
say, so the model takes the count as a parameter. -/
structure MonthCount where
  /-- The instant 13 months after the instant given. -/
  thirteenAfter : Instant → Instant

/-- Seven days, in seconds. -/
def sevenDays : Nat := 7 * 24 * 60 * 60

/-- EARS: The system shall keep an order accessible for 13 months from its
creation and for 13 months from its first usage while it has an active item,
and for 7 days after every item has reached a final status.

Story: As a seller, I want an order to stay retrievable while the customer
can still use it, so that I can service the trip and any value it holds.

Acceptance criteria:

* ONE-406.1: While an order has an active item, the system shall keep the
  order accessible until 13 months after its creation.
* ONE-406.2: While an order has an active item and has been used, the system
  shall keep the order accessible until 13 months after its first usage.
* ONE-406.3: When every item of an order has become closed or cancelled, the
  system shall keep the order accessible for 7 more days.
* ONE-406.4: While an order has an active item, the system shall keep the
  order accessible.

The resolution defines neither an open item nor first usage.  The model reads
an open item as an active one, which depends on a reading of the guide
({name}`ValueReading`).  The instant of first usage, if any, and the instant
every item reached a final status, if they all have, are inputs. -/
@[ears "ONE-406", source "iata-r797"]
def mustKeep (m : MonthCount) (v : ValueReading) (o : Order) (firstUse finalSince : Option Instant)
    (now : Instant) : Bool :=
  if o.isOpened v then
    decide (now < m.thirteenAfter o.createdAt) || firstUse.any fun t => decide (now < m.thirteenAfter t)
  else
    finalSince.any fun t => decide (now.epochSeconds < t.epochSeconds + sevenDays)

end Rules.OneOrder.Creation
