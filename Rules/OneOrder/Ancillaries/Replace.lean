import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Seats

/-!
# Dependents when a flight is replaced

When a flight is replaced, by the customer's change or by the airline, the
guide asks for the effect on each dependent service to be stated, and does not
say which effect applies.  The model takes the effect for each kind of service
as a parameter, a reading of the sources: a dependent moves to the new flight,
is cancelled with its value refunded or stored, or must be reshopped.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive)

/-- What happens to a dependent service when its flight is replaced. -/
inductive DependentEffect
  /-- It moves to the new flight, keeping its reference and details. -/
  | move
  /-- It is cancelled and its value refunded. -/
  | refund
  /-- It is cancelled and its value stored for the customer to reuse. -/
  | store
  /-- The customer must reshop it. -/
  | reshop
  deriving DecidableEq, Repr, Inhabited

/-- The effect stated for one dependent service, and the service on the new
flight when it moves. -/
structure Impact where
  /-- The reference of the dependent service. -/
  service : String
  /-- The effect stated for it. -/
  effect : DependentEffect
  /-- The service on the new flight, when it moves. -/
  moved : Option Service
  deriving DecidableEq, Repr, Inhabited

/-- The effect on one dependent service under a reading of the effect for each
kind of service.  A service that moves goes to the new segment, confirmed,
under the same reference. -/
def impactOf (e : ServiceKind → DependentEffect) (d : ServiceDetails) (newSeg : String)
    (s : Service) : Impact :=
  match e (d.kind s.id) with
  | .move => { service := s.id, effect := .move, moved := some { s with segment := newSeg, status := .confirmed } }
  | eff => { service := s.id, effect := eff, moved := none }

/-- EARS: When a flight service is replaced by a flight on another segment, the
system shall state for each live service that depends on it the effect the
reading gives for its kind.

Story: As a customer whose flight changed, I want to be told what happens to my
bag and my seat, so that I know what I still hold on the new flight.

Acceptance criteria:

* ONE-604.1: When a flight service is replaced, the system shall state an
  effect for each live service that depends on it and for no other service.
* ONE-604.2: When a flight service is replaced, the system shall give each
  dependent service the effect the reading gives for its kind.
* ONE-604.3: Where a kind of service moves with its flight, the system shall
  put the moved service on the new segment, for the same passenger and under
  the same reference.
* ONE-604.4: When a flight service is replaced, the system shall not move a
  seat to a seat that another passenger holds on the new flight.

The effect for each kind is the reading's; which services depend on the
flight is the link's ({name}`LinkReading`).  A moved seat keeps its seat
number, since the service details are kept by reference. -/
@[ears "ONE-604", source "easd-inform-of-impacted-dependent-services"]
def replaceFlight (e : ServiceKind → DependentEffect) (r : LinkReading) (d : ServiceDetails)
    (o : Order) (f : Service) (newSeg : String) : List Impact :=
  ((dependents r d o f).filter isLive).map (impactOf e d newSeg)

/-- The seats that moved services hold on the new flight. -/
def movedSeats (d : ServiceDetails) (impacts : List Impact) : List SeatAssignment :=
  impacts.filterMap fun x => x.moved.bind fun s => (seatOf d s).map fun n => ⟨s.passenger, s.segment, n⟩

end Rules.OneOrder.Ancillaries
