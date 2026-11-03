import Rules.Core.Attributes
import Rules.OneOrder.Service

/-!
# Delivery statuses and their moves

How a service moves between the thirteen delivery statuses of the ONE Order
implementation guide: the events that move it, the ways it ends without
delivery, the statuses no event leaves, and suspension.  The sources show some
moves and leave others undecided, so the model takes the undecided moves as a
parameter, a reading of the sources.
-/

namespace Rules.OneOrder.Delivery

open Rules.Core

/-- Something that happens to a service on its way to delivery, reported by the
airline or by the delivery provider. -/
inductive DeliveryEvent
  /-- The airline confirms a service it was still deciding on. -/
  | confirm
  /-- Payment for the service succeeds. -/
  | pay
  /-- The delivery provider is ready to start delivery. -/
  | prepare
  /-- The delivery provider starts delivery. -/
  | start
  /-- The delivery provider completes delivery. -/
  | deliver
  /-- The service is cancelled and none of its value is kept. -/
  | remove
  /-- The service is cancelled and the airline holds its value for reuse. -/
  | removeHoldValue
  /-- The value held for a cancelled service is refunded, moved to a value
  store or used in a change. -/
  | releaseValue
  /-- The consumption time limit passes before the customer claims the service. -/
  | expire
  /-- The passenger's own action or inaction, such as a no-show, prevents delivery. -/
  | notClaimed
  /-- Legal, regulatory or force majeure constraints prevent delivery. -/
  | unable
  /-- The constraint that prevented delivery lifts. -/
  | constraintLifted
  /-- The airline or its provider fails to deliver because of its own limits. -/
  | fail
  /-- The airline suspends delivery. -/
  | suspend
  /-- The airline lifts the suspension. -/
  | resume
  deriving DecidableEq, Repr, Inhabited

/-- Which of the moves the sources leave undecided are allowed.  The status
definitions, the ORDSTS guidance and the worked examples show some moves and
are silent on others, so the model takes the answer as a parameter: a reading
of the sources.  A guarantee about moves counts as proven only when it holds
for every reading. -/
structure MoveReading where
  /-- Whether delivery may start for a CONFIRMED service before it is paid for.
  The sources treat READY TO PROCEED as the payment gate but never forbid
  delivery from CONFIRMED. -/
  deliverBeforePayment : Bool
  /-- Whether an UNABLE TO DELIVER service returns to READY TO PROCEED once the
  constraint lifts, or stays where it is. -/
  unableReturns : Bool
  /-- Whether a service whose delivery is IN PROGRESS can be cancelled. -/
  cancelInProgress : Bool
  /-- Whether a service whose delivery is IN PROGRESS can end NOT CLAIMED. -/
  notClaimedInProgress : Bool
  deriving DecidableEq, Repr

/-- How a cancellation or a delivery outcome ends a service that is CONFIRMED,
READY TO PROCEED or READY TO DELIVER. -/
def endBeforeDelivery : DeliveryEvent → Option DeliveryStatus
  | .remove => some .removed
  | .removeHoldValue => some .removedHoldValue
  | .expire => some .expired
  | .notClaimed => some .notClaimed
  | .unable => some .unableToDeliver
  | .fail => some .failedToDeliver
  | _ => none

/-- EARS: When a service is cancelled, expires, is not claimed or cannot be
delivered, the system shall move it to the delivery status that records why.

Story: As a revenue accountant, I want each service that ends without delivery
to record why, so that I know whether its value is held, refunded or earned.

Acceptance criteria:

* ONE-102.1: When a service that is CONFIRMED, READY TO PROCEED or READY TO
  DELIVER is cancelled, the system shall mark it REMOVED HOLD VALUE if the
  airline holds its value for reuse and REMOVED if not.
* ONE-102.2: When the value held for a REMOVED HOLD VALUE service is refunded,
  moved to a value store or used in a change, the system shall mark it
  REMOVED, the only move out of REMOVED HOLD VALUE.
* ONE-102.3: When the consumption time limit of a service that is CONFIRMED,
  READY TO PROCEED or READY TO DELIVER passes before the customer claims it,
  the system shall mark it EXPIRED.
* ONE-102.4: When the passenger's own action or inaction, such as a no-show,
  prevents delivery of a service that is CONFIRMED, READY TO PROCEED or READY
  TO DELIVER, the system shall mark it NOT CLAIMED.
* ONE-102.5: When legal, regulatory or force majeure constraints prevent
  delivery of a service that is CONFIRMED, READY TO PROCEED or READY TO
  DELIVER, the system shall mark it UNABLE TO DELIVER.
* ONE-102.6: When the airline or its provider fails to deliver a service that
  is CONFIRMED, READY TO PROCEED, READY TO DELIVER or IN PROGRESS because of
  its own limits, the system shall mark it FAILED TO DELIVER.

Whether an IN PROGRESS service can be cancelled or end NOT CLAIMED is left to
the reading.  The result is the new status, or {lean}`none` when the event
does not end the service. -/
@[ears "ONE-102", source "easd-order"]
def endService (m : MoveReading) : DeliveryStatus → DeliveryEvent → Option DeliveryStatus
  | .confirmed, e | .readyToProceed, e | .readyToDeliver, e => endBeforeDelivery e
  | .inProgress, .remove => if m.cancelInProgress then some .removed else none
  | .inProgress, .removeHoldValue => if m.cancelInProgress then some .removedHoldValue else none
  | .inProgress, .notClaimed => if m.notClaimedInProgress then some .notClaimed else none
  | .inProgress, .fail => some .failedToDeliver
  | .removedHoldValue, .releaseValue => some .removed
  | _, _ => none

/-- EARS: When an event happens to a service, the system shall move its
delivery status only along the moves in the delivery status table.

Story: As an airline, I want a service's delivery status to change only along
the moves the standard describes, so that a service is delivered only once it
is paid for and each status means the same to every party.

Acceptance criteria:

* ONE-101.1: When the airline confirms a REQUESTED service, the system shall
  mark it CONFIRMED.
* ONE-101.2: When payment for a CONFIRMED service succeeds, the system shall
  mark it READY TO PROCEED.
* ONE-101.3: When a service that is READY TO PROCEED, READY TO DELIVER or IN
  PROGRESS is delivered, the system shall mark it DELIVERED.
* ONE-101.4: If payment for a service has not succeeded, then the system shall
  keep it out of READY TO PROCEED, READY TO DELIVER, IN PROGRESS and
  DELIVERED.
* ONE-101.6: If an event has no move from the service's delivery status in the
  table, then the system shall refuse it.

The table, read from the status definitions, the ORDSTS guidance and the worked
examples: REQUESTED goes to CONFIRMED; CONFIRMED goes to READY TO PROCEED on
payment; READY TO PROCEED goes to READY TO DELIVER, IN PROGRESS or DELIVERED;
READY TO DELIVER goes to IN PROGRESS or DELIVERED; IN PROGRESS goes to
DELIVERED.  The ways a service ends without delivery are in
{name}`endService`, and suspension is in {lit}`step`.  Delivery from CONFIRMED
and the return from UNABLE TO DELIVER to READY TO PROCEED are left to the
reading.  The result is the new status, or {lean}`none` when the event is
refused. -/
@[ears "ONE-101", source "easd-order"]
def move (m : MoveReading) : DeliveryStatus → DeliveryEvent → Option DeliveryStatus
  | .requested, .confirm => some .confirmed
  | .confirmed, .pay => some .readyToProceed
  | .confirmed, .prepare => if m.deliverBeforePayment then some .readyToDeliver else none
  | .confirmed, .start => if m.deliverBeforePayment then some .inProgress else none
  | .confirmed, .deliver => if m.deliverBeforePayment then some .delivered else none
  | .readyToProceed, .prepare => some .readyToDeliver
  | .readyToProceed, .start | .readyToDeliver, .start => some .inProgress
  | .readyToProceed, .deliver | .readyToDeliver, .deliver | .inProgress, .deliver => some .delivered
  | .unableToDeliver, .constraintLifted =>
    if m.unableReturns then some .readyToProceed else none
  | s, e => endService m s e

/-- EARS: The system shall treat DELIVERED, REMOVED, EXPIRED, NOT CLAIMED and
FAILED TO DELIVER as final delivery statuses, which no event leaves.

Story: As a revenue accountant, I want a service's final delivery status never
to change, so that what accounting was told about the service stays true.

Acceptance criteria:

* ONE-103.1: If a service is DELIVERED, REMOVED, EXPIRED, NOT CLAIMED or
  FAILED TO DELIVER, then the system shall refuse every event for its delivery
  status.
* ONE-103.2: The system shall let every service that is not in a final
  delivery status reach one through some sequence of events.
* ONE-103.3: While an order is closed, the system shall refuse every event for
  the delivery status of its services.
* ONE-103.4: When every service of an order is in a final delivery status, the
  system shall mark the order closed.

These are the five statuses the accounting message names as final.  UNABLE TO
DELIVER is not among them, and the sources do not say whether it is final. -/
@[ears "ONE-103", source "armi-ordsts easd-order"]
def isFinal : DeliveryStatus → Bool
  | .delivered | .removed | .expired | .notClaimed | .failedToDeliver => true
  | _ => false

/-- Whether the airline can suspend a service in a delivery status: any status
that is not final, except SUSPENDED itself and REMOVED HOLD VALUE, whose only
move is to REMOVED. -/
def suspendable (s : DeliveryStatus) : Bool :=
  !isFinal s && s != .suspended && s != .removedHoldValue

/-- A service's delivery status, with the status it left if it is suspended. -/
structure DeliveryRecord where
  /-- The delivery status. -/
  status : DeliveryStatus
  /-- The delivery status the service had when it was suspended, if it is. -/
  suspendedFrom : Option DeliveryStatus
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When the airline suspends a service, the system shall record the
delivery status it left and return it only to that status or remove it.

Story: As an airline, I want to suspend delivery of a service, for example on
suspected fraud, and lift the suspension later, so that delivery stops without
losing where the service was.

Acceptance criteria:

* ONE-104.1: When the airline suspends a service that is REQUESTED, CONFIRMED,
  READY TO PROCEED, READY TO DELIVER, IN PROGRESS or UNABLE TO DELIVER, the
  system shall mark it SUSPENDED and record the status it left.
* ONE-104.2: When the airline lifts the suspension of a service, the system
  shall return it to the delivery status it had before it was suspended.
* ONE-104.3: When a suspended service is cancelled with none of its value
  kept, the system shall mark it REMOVED.
* ONE-104.4: While a service is suspended, the system shall move it only to the
  delivery status it left or to REMOVED.
* ONE-104.5: When any event but a suspension happens to a service that is not
  suspended, the system shall apply the move in the delivery status table.

The sources say that any status that is not final can be suspended, and that
REMOVED HOLD VALUE moves only to REMOVED.  The model follows the second for
REMOVED HOLD VALUE.  Every other event follows {name}`move`.  The result is
the new record, or {lean}`none` when the event is refused. -/
@[ears "ONE-104", source "easd-order"]
def step (m : MoveReading) : DeliveryRecord → DeliveryEvent → Option DeliveryRecord
  | ⟨.suspended, before⟩, .resume => before.map fun s => ⟨s, none⟩
  | ⟨.suspended, _⟩, .remove => some ⟨.removed, none⟩
  | ⟨.suspended, _⟩, _ => none
  | ⟨s, _⟩, .suspend => if suspendable s then some ⟨.suspended, some s⟩ else none
  | ⟨s, _⟩, e => (move m s e).map fun s' => ⟨s', none⟩

/-- A service's record after a sequence of events, each applied in turn.  An
event the rule refuses leaves the record as it was. -/
def run (m : MoveReading) (r : DeliveryRecord) : List DeliveryEvent → DeliveryRecord
  | [] => r
  | e :: es => run m ((step m r e).getD r) es

/-- Whether a payment for the service succeeds during a sequence of events:
the rule accepts a payment event at some point. -/
def paymentSucceeds (m : MoveReading) (r : DeliveryRecord) : List DeliveryEvent → Bool
  | [] => false
  | e :: es => (e == .pay && (step m r e).isSome) || paymentSucceeds m ((step m r e).getD r) es

/-- The delivery statuses a service is in after each event of a sequence. -/
def visits (m : MoveReading) (r : DeliveryRecord) : List DeliveryEvent → List DeliveryStatus
  | [] => []
  | e :: es =>
    let r' := (step m r e).getD r
    r'.status :: visits m r' es

end Rules.OneOrder.Delivery
