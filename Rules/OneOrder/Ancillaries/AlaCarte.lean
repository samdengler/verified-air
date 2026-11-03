import Rules.Core.Attributes
import Rules.OneOrder.Accept
import Rules.OneOrder.Ancillaries.Basic

/-!
# A-la-carte offer items

An a-la-carte offer item is an optional ancillary with a unit price and the
passengers and segments it may be bought for.  It holds no flight.  The add bag
worked example buys one at quantity 1 for one passenger over two journeys and
gets two order items, one per journey, each at the unit price.  The model
follows the worked example: one order item for each passenger and segment
chosen, each at the unit price times the quantity.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core

/-- An a-la-carte offer item: an ancillary at a unit price, with the passengers
and segments it may be bought for. -/
structure AlaCarteItem where
  /-- The offer item reference. -/
  id : String
  /-- What the item sells. -/
  kind : ServiceKind
  /-- The unit price. -/
  unitPrice : Money
  /-- The passengers it may be bought for. -/
  passengers : List Passenger
  /-- The segments it may be bought for. -/
  segments : List String
  deriving DecidableEq, Repr, Inhabited

/-- What a seller chooses from an a-la-carte offer item: passengers, segments
and a quantity. -/
structure AlaCarteChoice where
  /-- The passengers chosen. -/
  passengers : List Passenger
  /-- The segments chosen. -/
  segments : List String
  /-- The quantity, such as a number of bags. -/
  quantity : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Why an a-la-carte choice was refused. -/
inductive AlaCarteRejection
  /-- The offer item does not list the passenger as eligible. -/
  | passengerNotEligible (passenger : String)
  /-- The offer item does not list the segment as eligible. -/
  | segmentNotEligible (segment : String)
  /-- The choice names no passenger, no segment, or a quantity of zero. -/
  | emptyChoice
  deriving DecidableEq, Repr, Inhabited

/-- The order item an a-la-carte choice gives for one passenger on one
segment: the unit price times the quantity, holding one service for that
passenger on that segment, confirmed and waiting for payment. -/
def alaCarteOrderItem (orderId : String) (oi : AlaCarteItem) (q : Nat) (p : Passenger)
    (seg : String) : OrderItem :=
  let id := orderId ++ "-" ++ oi.id ++ "-" ++ p.id ++ "-" ++ seg
  { id, fromOfferItem := oi.id, price := ⟨oi.unitPrice.amount * q, oi.unitPrice.currency⟩,
    services := [{ id := id ++ "-SVC", passenger := p, segment := seg, status := .confirmed,
                   delivery := .confirmed }] }

/-- EARS: When a seller chooses an a-la-carte offer item for passengers and
segments it lists as eligible, the system shall create one order item for each
passenger and segment chosen, at the unit price times the quantity.

Story: As a seller, I want an extra bag priced the same way every time, so that
I can quote the customer the right amount before they pay.

Acceptance criteria:

* ONE-606.1: If an a-la-carte choice names a passenger or a segment that the
  offer item does not list as eligible, then the system shall refuse it.
* ONE-606.2: When an a-la-carte choice is accepted, the system shall create
  one order item for each passenger and segment chosen, each holding one
  service for that passenger on that segment.
* ONE-606.3: When an a-la-carte choice is accepted, the system shall price
  each order item at the unit price times the quantity.
* ONE-606.4: When an a-la-carte choice is accepted, the system shall make the
  total price of its order items the unit price times the quantity times the
  number of passengers and segments chosen.
* ONE-606.5: When an a-la-carte offer item is ordered, the system shall create
  exactly one order item from it.

The unit of the unit price is not named in the guide; the model prices per
passenger and segment, as the add bag worked example does.  The last criterion
is the rule that each offer item becomes one order item, as {name}`accept`
makes it (ONE-001.1). -/
@[ears "ONE-606", source "easd-offers easd-add-ancillary-services"]
def chooseAlaCarte (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice) :
    Except AlaCarteRejection (List OrderItem) :=
  if c.passengers = [] ∨ c.segments = [] ∨ c.quantity = 0 then .error .emptyChoice
  else
    match c.passengers.find? (fun p => !oi.passengers.contains p) with
    | some p => .error (.passengerNotEligible p.id)
    | none =>
      match c.segments.find? (fun seg => !oi.segments.contains seg) with
      | some seg => .error (.segmentNotEligible seg)
      | none => .ok ((c.passengers ×ˢ c.segments).map fun (p, seg) => alaCarteOrderItem orderId oi c.quantity p seg)

end Rules.OneOrder.Ancillaries
