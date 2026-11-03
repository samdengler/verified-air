import Mathlib.Data.List.ProdSigma
import Rules.Core.Attributes
import Rules.OfferOrder.Accept
import Rules.OneOrder.Order

/-!
# Creating an order from an offer

The ONE Order way: each offer item becomes one order item, and each order item
gets one service per passenger and flight segment, since an ordered service is
for one passenger on one segment.
-/

namespace Rules.OneOrder

open Rules.Core

/-- One priced product in an offer, for one or more passengers on one or more
flight segments.  It corresponds to a ONE Order offer item. -/
structure OfferItem where
  /-- The offer item reference, unique within its offer. -/
  id : String
  /-- The price of the item. -/
  price : Money
  /-- The passengers the item is for. -/
  passengers : List Passenger
  /-- The flight segments the item covers. -/
  segments : List String
  deriving DecidableEq, Repr, Inhabited

/-- An offer: priced items, valid until it expires, in one currency.  It
corresponds to a ONE Order offer. -/
structure Offer where
  /-- The offer reference. -/
  id : String
  /-- The items on offer. -/
  items : List OfferItem
  /-- The instant the offer stops being valid. -/
  expiresAt : Instant
  /-- The currency the offer is priced in. -/
  currency : Currency
  deriving DecidableEq, Repr, Inhabited

/-- The services an offer item becomes: one per passenger and flight segment,
confirmed and waiting for payment. -/
def servicesFor (itemId : String) (oi : OfferItem) : List Service :=
  (oi.passengers ×ˢ oi.segments).map fun (p, seg) =>
    { id := itemId ++ "-" ++ p.id ++ "-" ++ seg, passenger := p, segment := seg,
      status := .confirmed, delivery := .confirmed }

/-- The order item an offer item becomes. -/
def toOrderItem (orderId : String) (oi : OfferItem) : OrderItem :=
  let itemId := orderId ++ "-" ++ oi.id
  { id := itemId, fromOfferItem := oi.id, price := oi.price, services := servicesFor itemId oi }

/-- EARS: When a customer accepts an offer, the system shall create an order with
one order item for each offer item and one service for each passenger and
flight segment of that item.

Story: As an airline, I want each accepted offer item to become one order item
with a service for every passenger and segment, so that each service can be
delivered and accounted for on its own.

Acceptance criteria:

* ONE-001.1: When an offer is accepted, the system shall create exactly one
  order item for each offer item.
* ONE-001.2: When an order item is created, the system shall give it one
  service for each passenger and flight segment of its offer item.
* ONE-001.3: When an order is created, the system shall give its order items
  distinct references.
* ONE-001.4: When an order is created, the system shall mark it opened.
* ONE-001.5: If a customer accepts an offer at or after its expiry instant, then
  the system shall reject it as expired.

The checks before creating the order are the same as in the airline's rules:
expiry first, then an empty offer, then items priced in another currency. -/
@[ears "ONE-001", source "easd-order"]
def accept (o : Offer) (now : Instant) (orderId : String) : Except Rules.OfferOrder.Rejection Order :=
  if now ≥ o.expiresAt then .error .expired
  else if o.items.isEmpty then .error .emptyOffer
  else if o.items.any (·.price.currency != o.currency) then .error .mixedCurrency
  else .ok { id := orderId, items := o.items.map (toOrderItem orderId), createdAt := now }

end Rules.OneOrder
