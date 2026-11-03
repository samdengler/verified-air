import Rules.Core.Attributes
import Rules.OneOrder.Order
import Rules.OneOrder.Delivery.Services

/-!
# Changing an order item

An order item is never changed in place.  A change replaces the item with a
new one: the services the change keeps move to the new item under the same
references, and their copies in the original item are marked transferred.
The other services of the original item are cancelled.  This is the change
once it is paid, as the worked examples show it after payment.
-/

namespace Rules.OneOrder.Change

open Rules.Core
open Rules.OneOrder.Delivery (MoveReading endWith)

/-- A change to one order item that the seller has accepted and paid. -/
structure ItemChange where
  /-- The reference of the order item being changed. -/
  item : String
  /-- The reference of the new order item. -/
  newItem : String
  /-- The offer item the new order item comes from. -/
  fromOfferItem : String
  /-- The price of the new order item. -/
  newPrice : Money
  /-- The references of the services the change keeps. -/
  kept : List String
  /-- The services the change adds. -/
  added : List Service
  deriving DecidableEq, Repr, Inhabited

/-- Why a change was refused. -/
inductive ChangeRejection
  /-- The order has no item with the reference given. -/
  | unknownItem
  /-- The new item's reference is already used in the order. -/
  | duplicateItemReference
  deriving DecidableEq, Repr, Inhabited

/-- A service of the changed item after the change: marked transferred if the
change keeps it, with its delivery status as it was; otherwise cancelled and
removed, where the delivery status table lets it be removed. -/
def originalAfterChange (m : MoveReading) (kept : List String) (s : Service) : Service :=
  if s.id ∈ kept then { s with status := .transferred }
  else endWith m .remove .cancelled s

/-- An order item after a change: the changed item has its services marked,
and every other item is unchanged. -/
def afterChange (m : MoveReading) (c : ItemChange) (i : OrderItem) : OrderItem :=
  if i.id = c.item then { i with services := i.services.map (originalAfterChange m c.kept) } else i

/-- The new order item of a change: the kept services of the original item,
confirmed and with the same references, then the added services. -/
def newItemOf (c : ItemChange) (old : OrderItem) : OrderItem :=
  { id := c.newItem, fromOfferItem := c.fromOfferItem, price := c.newPrice,
    services := (old.services.filter (fun s => s.id ∈ c.kept)).map (fun s => { s with status := .confirmed })
      ++ c.added }

/-- EARS: When a seller has accepted and paid a change to an order item, the
system shall add a new item with the services the change keeps and cancel
the services it does not keep.

Story: As an airline, I want a changed item's kept services to move to the new
item under the same references, so that each service is delivered and
accounted for once.

Acceptance criteria:

* ONE-204.1: When a change keeps a service of the changed item, the system
  shall give the new item a service with the same reference, passenger,
  segment and delivery status.
* ONE-204.2: When a change keeps a service of the changed item, the system
  shall mark the original copy transferred and leave its delivery status as it
  was.
* ONE-204.3: When a change does not keep a service of the changed item and the
  delivery status table lets it be removed, the system shall mark it cancelled
  and removed.
* ONE-204.4: When a change is made, the system shall keep the order's item
  references distinct.
* ONE-204.5: When a change is made, the system shall mark the changed item
  cancelled.

The original copy keeps its delivery status because the worked examples show
it so: after the change, the transferred copies are still READY TO PROCEED.  A
service the change does not keep is removed through the delivery status table
({name}`Delivery.endWith`), so a service already DELIVERED, such as an
outbound flight already flown, stays as it was. -/
@[ears "ONE-204", source "easd-modification-of-an-order"]
def changeItem (m : MoveReading) (o : Order) (c : ItemChange) : Except ChangeRejection Order :=
  match o.items.find? (·.id = c.item) with
  | none => .error .unknownItem
  | some old =>
    if o.items.any (·.id = c.newItem) then .error .duplicateItemReference
    else .ok { o with items := o.items.map (afterChange m c) ++ [newItemOf c old] }

end Rules.OneOrder.Change
