import Rules.Core.Attributes
import Rules.Core.Money
import Rules.Core.Time
import Rules.OneOrder.Service

/-!
# Order items and orders

Order items hold services and carry the price; an order holds order items.
The statuses of items and orders follow from their services, as the ONE Order
implementation guide defines them.
-/

namespace Rules.OneOrder

open Rules.Core

/-- One purchased product inside an order, created from one offer item.  The
price is defined here, and the item is not split.  It corresponds to a ONE
Order order item. -/
structure OrderItem where
  /-- The order item reference, unique within the order. -/
  id : String
  /-- The offer item this order item was created from. -/
  fromOfferItem : String
  /-- The price of the item. -/
  price : Money
  /-- The services in the item, one per passenger and flight segment. -/
  services : List Service
  deriving DecidableEq, Repr, Inhabited

/-- A customer's order: its order items and when it was created.  It
corresponds to a ONE Order order. -/
structure Order where
  /-- The order reference. -/
  id : String
  /-- The order items. -/
  items : List OrderItem
  /-- When the order was created. -/
  createdAt : Instant
  deriving DecidableEq, Repr, Inhabited

/-- The status of an order item. -/
inductive ItemStatus
  /-- At least one service still holds value. -/
  | active
  /-- Every service is cancelled or transferred and none holds value. -/
  | cancelled
  /-- At least one service is delivered and every other is delivered or removed. -/
  | closed
  deriving DecidableEq, Repr, Inhabited

/-- The status of an order. -/
inductive OrderStatus
  /-- At least one service still holds value. -/
  | opened
  /-- Every item is closed or cancelled and every service is delivered or removed. -/
  | closed
  deriving DecidableEq, Repr, Inhabited

/-- At least one of the item's services holds value. -/
def OrderItem.isActive (v : ValueReading) (i : OrderItem) : Bool :=
  i.services.any (·.holdsValue v)

/-- Every service of the item is cancelled or transferred, and none holds value. -/
def OrderItem.isCancelled (v : ValueReading) (i : OrderItem) : Bool :=
  i.services.all (fun s => s.status == .cancelled || s.status == .transferred) && !i.isActive v

/-- At least one service of the item is delivered, and every other is delivered
or removed. -/
def OrderItem.isClosed (i : OrderItem) : Bool :=
  i.services.any (·.delivery == .delivered) &&
    i.services.all (fun s => s.delivery == .delivered || s.delivery == .removed)

/-- EARS: The system shall give each order item the status active, cancelled or
closed from the service and delivery statuses of its services.

Story: As a revenue accountant, I want each order item's status worked out from
its services, so that I know which items still hold value.

Acceptance criteria:

* ONE-002.1: While at least one service of an order item holds value, the system
  shall mark the item active.
* ONE-002.2: When every service of an order item is cancelled or transferred and
  none holds value, the system shall mark the item cancelled.
* ONE-002.3: When at least one service of an order item is delivered and every
  other service is delivered or removed, the system shall mark the item closed.
* ONE-002.4: The system shall give each order item exactly one status.

The result lists every status whose condition holds, so an item that meets two
conditions, or none, shows it. -/
@[ears "ONE-002", source "easd-order"]
def itemStatuses (v : ValueReading) (i : OrderItem) : List ItemStatus :=
  (if i.isActive v then [.active] else []) ++
    (if i.isCancelled v then [.cancelled] else []) ++
    (if i.isClosed then [.closed] else [])

/-- At least one service of the order holds value. -/
def Order.isOpened (v : ValueReading) (o : Order) : Bool :=
  o.items.any (·.isActive v)

/-- Every item of the order is closed or cancelled, and every service is
delivered or removed. -/
def Order.isClosed (v : ValueReading) (o : Order) : Bool :=
  o.items.all (fun i => i.isClosed || i.isCancelled v) &&
    o.items.all (fun i => i.services.all (fun s => s.delivery == .delivered || s.delivery == .removed))

/-- EARS: The system shall mark an order opened while any of its services holds
value, and closed once all its items are closed or cancelled and all its
services are delivered or removed.

Story: As an airline, I want an order's status worked out from its items and
services, so that an order is closed only when nothing in it holds value.

Acceptance criteria:

* ONE-003.1: While at least one service of an order holds value, the system
  shall mark the order opened.
* ONE-003.2: When every item of an order is closed or cancelled and every
  service is delivered or removed, the system shall mark the order closed.
* ONE-003.3: The system shall never mark an order both opened and closed.
* ONE-003.4: The system shall give every order that has a service either the
  status opened or the status closed.

The result lists every status whose condition holds. -/
@[ears "ONE-003", source "easd-order"]
def orderStatuses (v : ValueReading) (o : Order) : List OrderStatus :=
  (if o.isOpened v then [.opened] else []) ++ (if o.isClosed v then [.closed] else [])

end Rules.OneOrder
