import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Basic
import Rules.OneOrder.Change.Transfer

/-!
# Adding ancillaries to an order

A flight-related ancillary enters an order only with a flight for the same
passenger and segment, in the same request or already in the order.  The
sources never define flight related.  The taxonomy gives one answer: services
under Flight are flight related and services under Journey, such as insurance,
are not.  The model takes the answer as a parameter, a reading of the sources.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive)

/-- Why a request to add services to an order was refused. -/
inductive AddRejection
  /-- A flight-related ancillary in the request has no live flight service for
  its passenger and segment, in the order or in the request. -/
  | noFlight (service : String)
  deriving DecidableEq, Repr, Inhabited

/-- Whether a list of services holds a live flight service for the passenger
and segment of a service. -/
def hasFlightFor (d : ServiceDetails) (svcs : List Service) (s : Service) : Bool :=
  svcs.any fun f => d.isFlight f && isLive f && f.passenger == s.passenger && f.segment == s.segment

/-- Whether a service is a flight-related ancillary under a reading of which
kinds are flight related. -/
def isFlightRelated (related : ServiceKind → Bool) (d : ServiceDetails) (s : Service) : Bool :=
  !d.isFlight s && related (d.kind s.id)

/-- The live flight-related ancillaries of an order with no live flight
service for their passenger and segment. -/
def uncovered (related : ServiceKind → Bool) (d : ServiceDetails) (o : Order) : List Service :=
  (services o).filter fun s => isLive s && isFlightRelated related d s && !hasFlightFor d (services o) s

/-- The first flight-related ancillary of a request with no live flight
service for its passenger and segment, in the order or in the request. -/
def missingFlight (related : ServiceKind → Bool) (d : ServiceDetails) (o : Order)
    (items : List OrderItem) : Option Service :=
  (items.flatMap (·.services)).find? fun s =>
    isFlightRelated related d s && !hasFlightFor d (services o ++ items.flatMap (·.services)) s

/-- EARS: When a seller adds services to an order, the system shall accept the
request only if every flight-related ancillary in it has a live flight service
for its passenger and segment, in the order or in the request.

Story: As an airline, I want a bag or a seat sold only with the flight it is
for, so that no customer pays for an ancillary on a flight they do not hold.

Acceptance criteria:

* ONE-602.1: If a seller adds a flight-related ancillary for a passenger on a
  segment, and neither the order nor the request holds a live flight service
  for that passenger on that segment, then the system shall refuse the
  request.
* ONE-602.2: When a request to add services is accepted, the system shall add
  its order items after the existing ones and leave the existing ones as they
  were.
* ONE-602.3: Where no service in a request is a flight-related ancillary, the
  system shall accept the request.
* ONE-602.4: When a seller changes an order item of an order in which every
  live flight-related ancillary has a live flight service for its passenger
  and segment, the system shall keep a live flight service for the passenger
  and segment of every live flight-related ancillary.

Which kinds are flight related is the reading's.  The last criterion asks
whether the rule holds for the life of the order or only when the ancillary
is bought; it is checked against the change rule for a paid change
({name}`Rules.OneOrder.Change.changeItem`). -/
@[ears "ONE-602", source "easd-shop-for-ancillaries easd-add-ancillary"]
def addServices (related : ServiceKind → Bool) (d : ServiceDetails) (o : Order)
    (items : List OrderItem) : Except AddRejection Order :=
  match missingFlight related d o items with
  | some s => .error (.noFlight s.id)
  | none => .ok { o with items := o.items ++ items }

end Rules.OneOrder.Ancillaries
