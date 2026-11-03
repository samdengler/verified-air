import Rules.Core.Attributes
import Rules.Core.Money
import Rules.Core.Time

/-!
# Orders

An order is what the customer bought: the items of an accepted offer, each
with its own delivery state.  It corresponds to the IATA ONE Order {lit}`Order`,
{lit}`OrderItem`, and the delivery status of a service.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- Where a purchased service is in its life: ready to be delivered,
delivered (the passenger flew, the bag was carried), cancelled before
delivery, or refunded after cancellation. -/
inductive DeliveryState
  /-- Paid for and not yet delivered. -/
  | ready
  /-- Delivered to the passenger. -/
  | delivered
  /-- Cancelled before delivery. -/
  | cancelled
  /-- Cancelled and refunded. -/
  | refunded
  deriving DecidableEq, Repr, Inhabited

/-- Something that happens to a purchased service: it is delivered, it is
cancelled, or its cancellation is refunded. -/
inductive DeliveryEvent
  /-- The service was delivered. -/
  | deliver
  /-- The service was cancelled. -/
  | cancel
  /-- The cancelled service was refunded. -/
  | refund
  deriving DecidableEq, Repr, Inhabited

/-- One purchased service inside an order, created from one offer item.  It
corresponds to a ONE Order {lit}`OrderItem`. -/
structure OrderItem where
  /-- The order item reference. -/
  id : String
  /-- The offer item this order item was created from. -/
  fromOfferItem : String
  /-- The price paid for this item. -/
  price : Money
  /-- Where the service is in its life. -/
  delivery : DeliveryState
  deriving DecidableEq, Repr, Inhabited

/-- A customer's purchase: the items of one accepted offer, the total price,
and when it was created.  It corresponds to a ONE Order {lit}`Order`. -/
structure Order where
  /-- The order reference. -/
  id : String
  /-- The offer this order was created from. -/
  fromOffer : String
  /-- The purchased items. -/
  items : List OrderItem
  /-- The total price of the order. -/
  price : Money
  /-- When the order was created. -/
  createdAt : Instant
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When a delivery event is applied to a service, the system shall allow
only the transitions ready to delivered, ready to cancelled, cancelled to
refunded.

Story: As an operations agent, I want a service's delivery state to change only
along the allowed transitions, so that a delivered service is never cancelled
and a service is never refunded before it is cancelled.

Acceptance criteria:

* OO-002.1: When a ready service is delivered, the system shall mark it
  delivered.
* OO-002.2: When a ready service is cancelled, the system shall mark it
  cancelled.
* OO-002.3: When a cancelled service is refunded, the system shall mark it
  refunded.
* OO-002.4: If a delivered service is cancelled, then the system shall refuse
  the event.
* OO-002.5: If any other event is applied to a service, then the system shall
  refuse the event.

The result is the new state, or {lean}`none` when the event is not allowed in the
current state. -/
@[ears "OO-002", source "pilot-slice"]
def step : DeliveryState → DeliveryEvent → Option DeliveryState
  | .ready, .deliver => some .delivered
  | .ready, .cancel => some .cancelled
  | .cancelled, .refund => some .refunded
  | _, _ => none

end Rules.OfferOrder
