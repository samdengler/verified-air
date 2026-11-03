import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Basic

/-!
# Cancelling a flight with its ancillaries

A seller cancels order items by naming them.  The cancellation worked example
names the flight item and the ancillary item together, and no source says
what happens to a bag or a seat when its flight is cancelled alone.  The model
takes the answer as a parameter, a reading of the sources.  An order item's
conditions may forbid cancelling it, as the extra bag of the add bag worked
example does.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive MoveReading endWith)

/-- What happens to the services that depend on a flight the seller cancels.
No source says, so the model takes the answer as a parameter: a reading of the
sources. -/
inductive DependentHandling
  /-- The dependents are cancelled with the flight. -/
  | cancelWithFlight
  /-- The cancellation is refused until the seller names the dependents'
  order items too. -/
  | refuseUnlessNamed
  /-- The dependents stay as they are. -/
  | leaveInPlace
  deriving DecidableEq, Repr, Inhabited

/-- Why a request to cancel order items was refused. -/
inductive CancelRejection
  /-- The order has no item with the reference named. -/
  | unknownItem (item : String)
  /-- The conditions of a named item do not allow cancellation. -/
  | notCancellable (item : String)
  /-- A live service depends on a flight the request cancels, and its order
  item is not named. -/
  | dependentNotNamed (service : String)
  deriving DecidableEq, Repr, Inhabited

/-- A service after it is cancelled: if it is live, CANCELLED with delivery
status REMOVED where the delivery status table lets it be removed; otherwise
as it was. -/
def endService (m : MoveReading) (s : Service) : Service :=
  if isLive s then endWith m .remove .cancelled s else s

/-- The live flight services of the order items a request names. -/
def namedFlights (d : ServiceDetails) (o : Order) (named : List String) : List Service :=
  ((o.items.filter (fun i => named.contains i.id)).flatMap (·.services)).filter
    fun f => d.isFlight f && isLive f

/-- Whether a service is live and depends on one of the flights given. -/
def isLiveDependent (r : LinkReading) (d : ServiceDetails) (fs : List Service) (s : Service) : Bool :=
  isLive s && fs.any fun f => dependsOn r d f s

/-- The live services outside the named items that depend on a flight of a
named item. -/
def unnamedDependents (r : LinkReading) (d : ServiceDetails) (o : Order) (named : List String) :
    List Service :=
  ((o.items.filter (fun i => !named.contains i.id)).flatMap (·.services)).filter
    (isLiveDependent r d (namedFlights d o named))

/-- An order item after a cancellation: a named item has every live service
cancelled; another item has its live dependents of the cancelled flights
cancelled when the reading cancels them with the flight, and is otherwise as
it was. -/
def itemAfterCancel (m : MoveReading) (h : DependentHandling) (r : LinkReading) (d : ServiceDetails)
    (fs : List Service) (named : List String) (i : OrderItem) : OrderItem :=
  if named.contains i.id then { i with services := i.services.map (endService m) }
  else if h = .cancelWithFlight then
    { i with services := i.services.map fun s => if isLiveDependent r d fs s then endService m s else s }
  else i

/-- EARS: When a seller cancels order items, the system shall cancel every live
service of the items named and treat the services that depend on a cancelled
flight as the reading says.

Story: As a seller, I want to know what happens to a customer's bag and seat
when I cancel their flight, so that the customer neither keeps a service they
cannot use nor loses one they were promised.

Acceptance criteria:

* ONE-603.1: When a seller cancels order items, the system shall mark every
  live service of each named item that the delivery status table lets be
  removed CANCELLED with delivery status REMOVED.
* ONE-603.2: If a seller names an order item whose conditions do not allow
  cancellation, then the system shall refuse the request.
* ONE-603.3: When a seller cancels order items, the system shall leave as it
  was every service outside the named items that does not depend on a
  cancelled flight.
* ONE-603.4: When a seller cancels a flight, the system shall leave no live
  service that depends on it.
* ONE-603.5: The system shall never cancel a live service of an order item
  whose conditions do not allow cancellation.
* ONE-603.6: When the conditions of an order item allow cancellation, the
  system shall let the seller cancel it.

What happens to the dependents is the reading's ({name}`DependentHandling`);
which services depend on a flight is the link's ({name}`LinkReading`).  The
refund is not modelled; whose conditions govern the refund of a dependent
cancelled with its flight is an open point.  The conditions of each order item
are given by item reference.  A service is removed through the delivery status
table ({name}`Delivery.endWith`), so one still REQUESTED from the airline stays
as it was. -/
@[ears "ONE-603", source "easd-cancellation-of-order-items easd-add-ancillary-services"]
def cancelItems (m : MoveReading) (h : DependentHandling) (r : LinkReading) (d : ServiceDetails)
    (allows : String → Bool) (o : Order) (named : List String) : Except CancelRejection Order :=
  match named.find? (fun id => !o.items.any (·.id == id)) with
  | some id => .error (.unknownItem id)
  | none =>
    match named.find? (fun id => !allows id) with
    | some id => .error (.notCancellable id)
    | none =>
      match h, unnamedDependents r d o named with
      | .refuseUnlessNamed, s :: _ => .error (.dependentNotNamed s.id)
      | _, _ => .ok { o with items := o.items.map (itemAfterCancel m h r d (namedFlights d o named) named) }

end Rules.OneOrder.Ancillaries
