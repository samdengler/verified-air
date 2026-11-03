import Rules.Core.Attributes
import Rules.OneOrder.Order
import Rules.OneOrder.Delivery.Services

/-!
# Ancillaries and the flights they depend on

A bag, a seat or a meal is a service of its own in the order, for one
passenger on one flight segment, and it depends on the flight service for that
passenger and segment.  The guide records the link in two ways.  The page on
impacted dependent services shows a dependent service naming its parent
flight service by reference; the worked examples for adding an ancillary link
bags and seats to the flight only through the shared passenger and segment.
The model takes the link as a parameter, a reading of the sources.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive)

/-- What a service is: a flight, or an ancillary sold with one. -/
inductive ServiceKind
  /-- A flight. -/
  | flight
  /-- A seat on a flight, by seat number. -/
  | seat (number : String)
  /-- A checked bag. -/
  | bag
  /-- A meal. -/
  | meal
  /-- Access to a lounge. -/
  | lounge
  /-- Travel insurance. -/
  | insurance
  deriving DecidableEq, Repr, Inhabited

/-- What the order records about each service beyond its statuses, by service
reference: what the service is, and the service it names as its parent, if
any.  A reference stays the same when a service is transferred, so a change
keeps these details. -/
structure ServiceDetails where
  /-- What the service with a reference is. -/
  kind : String → ServiceKind
  /-- The reference of the service it names as its parent, if it names one. -/
  parent : String → Option String

/-- Whether a service is a flight. -/
def ServiceDetails.isFlight (d : ServiceDetails) (s : Service) : Bool := d.kind s.id == .flight

/-- The details with one more service recorded. -/
def ServiceDetails.record (d : ServiceDetails) (id : String) (k : ServiceKind) (p : Option String) :
    ServiceDetails where
  kind x := if x = id then k else d.kind x
  parent x := if x = id then p else d.parent x

/-- Every service of an order, item by item. -/
def services (o : Order) : List Service := o.items.flatMap (·.services)

/-- How the order links a dependent service to its parent flight service.
The sources show both, so the model takes the answer as a parameter: a
reading of the sources. -/
inductive LinkReading
  /-- The dependent service names its parent flight service by reference, as
  the page on impacted dependent services shows. -/
  | reference
  /-- The dependent service depends on every flight service for the same
  passenger on the same segment, as the worked examples for adding an
  ancillary show. -/
  | passengerSegment
  deriving DecidableEq, Repr, Inhabited

/-- Whether a service is linked to a flight service under a reading: it names
the flight service as its parent, or it is for the same passenger on the same
segment. -/
def linked : LinkReading → ServiceDetails → Service → Service → Bool
  | .reference, d, f, s => d.parent s.id == some f.id
  | .passengerSegment, _, f, s => s.passenger == f.passenger && s.segment == f.segment

/-- Whether a service depends on a flight service under a reading: the first is
a flight, the second is an ancillary, and the two are linked. -/
def dependsOn (r : LinkReading) (d : ServiceDetails) (f s : Service) : Bool :=
  d.isFlight f && !d.isFlight s && linked r d f s

/-- EARS: The system shall count as dependent on a flight service the
ancillary services of the order that the link between dependent and parent
ties to it.

Story: As an airline, I want to know which bags, seats and meals depend on a
flight, so that a change to the flight reaches every service it affects.

Acceptance criteria:

* ONE-601.1: Where the order links a dependent service to its parent by
  reference, the system shall count an ancillary service of the order as
  dependent on a flight service exactly when it names that flight service as
  its parent.
* ONE-601.2: Where the order links a dependent service to its parent through
  passenger and segment, the system shall count an ancillary service of the
  order as dependent on a flight service exactly when it is for the same
  passenger on the same segment.
* ONE-601.3: The system shall count no flight service as a dependent.
* ONE-601.4: When an order holds an ancillary service and a flight service for
  the same passenger and segment, the system shall count the ancillary service
  as dependent on that flight service.

Which link holds is the reading's ({name}`LinkReading`).  Under the reference
reading an ancillary may name another ancillary as its parent, such as a
lounge pass naming a premium seat.  The rule counts dependents of flights
only, so such a pass depends on no flight. -/
@[ears "ONE-601", source "easd-inform-of-impacted-dependent-services easd-add-ancillary-services"]
def dependents (r : LinkReading) (d : ServiceDetails) (o : Order) (f : Service) : List Service :=
  (services o).filter (dependsOn r d f)

end Rules.OneOrder.Ancillaries
