import Rules.Core.Attributes
import Rules.OneOrder.Change.Transfer

/-!
# Re-accommodation before the seller answers

When the airline moves a customer to other flights, it replaces the affected
order item with a new one, as a paid change does.  In the itinerary change
worked example the replacement is already in the order, at a higher order
version, while the seller's Accept is still pending, and the new services
start CONFIRMED.  The sources do not say whether a change awaiting acceptance
is provisional, so the model takes the answer as a parameter, a reading of the
sources.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core
open Rules.OneOrder.Change

/-- An order with its version, which rises each time the order changes. -/
structure VersionedOrder where
  /-- The order. -/
  order : Order
  /-- The order version. -/
  version : Nat
  deriving DecidableEq, Repr, Inhabited

/-- When an airline change takes effect in the order.  The worked example
shows it in effect at notice; the sources do not say whether that is the rule.
The model takes the answer as a parameter: a reading of the sources. -/
inductive ApplyAt
  /-- The change takes effect when the airline notifies it, as in the worked
  example. -/
  | notice
  /-- The change waits for the seller's Accept; until then the order is as it
  was. -/
  | acceptance
  deriving DecidableEq, Repr, Inhabited

/-- The airline moves the customers of one order item to other flights. -/
structure Reaccommodation where
  /-- The reference of the order item the airline changes. -/
  item : String
  /-- The reference of the new order item. -/
  newItem : String
  /-- The references of the services on flights the change keeps. -/
  kept : List String
  /-- The flight segments the airline moves the customers to. -/
  newSegments : List String
  deriving DecidableEq, Repr, Inhabited

/-- The passengers of an order item, each once. -/
def passengersOf (i : OrderItem) : List Passenger :=
  (i.services.map (·.passenger)).dedup

/-- The services the airline creates for a re-accommodation: one for each
passenger of the original item on each new flight, CONFIRMED with delivery
status CONFIRMED, as in the itinerary change worked example. -/
def Reaccommodation.newServices (c : Reaccommodation) (old : OrderItem) : List Service :=
  (passengersOf old).flatMap fun p => c.newSegments.map fun seg =>
    { id := c.newItem ++ "-" ++ p.id ++ "-" ++ seg, passenger := p, segment := seg,
      status := .confirmed, delivery := .confirmed }

/-- A re-accommodation as a change of an order item: the new item comes from
the same offer item, at the same price, and holds the kept services and the
new ones. -/
def Reaccommodation.toItemChange (c : Reaccommodation) (old : OrderItem) : ItemChange :=
  { item := c.item, newItem := c.newItem, fromOfferItem := old.fromOfferItem, newPrice := old.price,
    kept := c.kept, added := c.newServices old }

/-- EARS: When the airline moves a customer to other flights, the system shall
replace the affected order item with a new item at the same price, holding a
service for each passenger on each new flight.

Story: As a customer whose flights the airline changed, I want the new flights
in my order at no extra cost and the old ones kept until I accept, so that I
can still choose what to do.

Acceptance criteria:

* ONE-705.1: Where an airline change takes effect when it is notified, the
  system shall replace the changed order item as a paid change does and raise
  the order version by one.
* ONE-705.2: Where an airline change waits for the seller's Accept, the system
  shall leave the order and its version unchanged when the change is notified.
* ONE-705.3: When an airline change takes effect, the system shall give the
  new order item the original item's price and a service for each passenger of
  the original item on each new flight.
* ONE-705.4: While the seller's Accept of an airline change is pending, the
  system shall keep the original order item with the status it had.
* ONE-705.5: When the airline replaces paid services at no price difference,
  the system shall mark every service of the new order item READY TO PROCEED.

The replacement is the change rule for a paid change ({name}`changeItem`):
kept services move to the new item, their originals are marked transferred,
and the other services of the original item are cancelled and removed, through
the delivery status table.  When the change takes effect is the reading's
({name}`ApplyAt`); under the reading where it waits for acceptance, applying
it once the seller accepts is the same replacement, which this rule does not
model. -/
@[ears "ONE-705", source "easd-airline-notifies-seller"]
def notifyChange (m : Delivery.MoveReading) (a : ApplyAt) (vo : VersionedOrder) (c : Reaccommodation) :
    Except ChangeRejection VersionedOrder :=
  match vo.order.items.find? (·.id = c.item) with
  | none => .error .unknownItem
  | some old =>
    match a with
    | .acceptance => .ok vo
    | .notice =>
      (changeItem m vo.order (c.toItemChange old)).map fun o => { order := o, version := vo.version + 1 }

end Rules.OneOrder.AirlineChange
