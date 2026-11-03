import Rules.Core.Attributes
import Rules.Core.Time
import Rules.OneOrder.Order

/-!
# Seller follow-up actions on an airline change

When the airline changes an order, it sends the seller a change notice.  The
notice may ask the seller to act: accept the change, reshop, cancel, contact
the airline, or reprice and accept.  Each follow-up action may carry a time
limit and a consequence that applies if the seller has not acted by then.  A
notice with no follow-up action needs only acknowledgement.  The sources leave
two things open, so the model takes them as a parameter, a reading of the
sources: what applies when a time limit passes and no consequence is stated,
and whether contacting the airline, which happens outside the order, is
recorded as the seller's answer.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core

/-- What a change notice can ask the seller to do.  The names are the ONE
Order follow-up action codes. -/
inductive FollowUpAction
  /-- Accept the change.  ONE Order code Accept. -/
  | accept
  /-- Look for other flights or services.  ONE Order code Reshop. -/
  | reshop
  /-- Cancel the affected order items.  ONE Order code Cancel. -/
  | cancel
  /-- Contact the airline outside the order.  ONE Order code ContactAirline. -/
  | contactAirline
  /-- Reprice the order item and accept it, for example when a waitlisted
  service is confirmed.  ONE Order code RepriceAndAccept. -/
  | repriceAndAccept
  deriving DecidableEq, Repr, Inhabited

/-- What the airline does if the seller has not acted by a follow-up action's
time limit. -/
inductive Inaction
  /-- The airline treats the change as accepted. -/
  | autoAccept
  /-- The airline cancels the affected order items. -/
  | autoCancel
  deriving DecidableEq, Repr, Inhabited

/-- One follow-up action on a change notice, with its optional time limit and
its optional consequence of inaction.  The airline contact link a follow-up
action may carry is not modelled. -/
structure FollowUp where
  /-- The action the seller is asked to take. -/
  action : FollowUpAction
  /-- The instant by which the seller should act, if the airline gave one. -/
  timeLimit : Option Instant
  /-- What the airline does if the seller has not acted by the time limit, if
  the airline stated it. -/
  consequence : Option Inaction
  deriving DecidableEq, Repr, Inhabited

/-- Why the airline changed the order.  The sources list these kinds of
change in the notices and worked examples. -/
inductive ChangeReason
  /-- The airline cancels a flight. -/
  | flightCancelled
  /-- The airline moves the customer to other flights. -/
  | itineraryChange
  /-- The airline changes a departure or arrival time. -/
  | scheduleChange
  /-- The airline changes a flight number. -/
  | flightNumberChange
  /-- The airline changes the aircraft. -/
  | aircraftChange
  /-- Another carrier now operates the flight. -/
  | operatingCarrierChange
  /-- The airline confirms a waitlisted service. -/
  | waitlistConfirmed
  /-- The customer made the change directly with the airline, such as a name
  or contact update. -/
  | customerRequest
  deriving DecidableEq, Repr, Inhabited

/-- A notice from the airline to the seller that the airline has changed an
order. -/
structure ChangeNotice where
  /-- The notice reference. -/
  id : String
  /-- Why the airline changed the order. -/
  reason : ChangeReason
  /-- When the first affected flight departs. -/
  departure : Instant
  /-- The follow-up actions the notice offers; none when it needs only
  acknowledgement. -/
  followUps : List FollowUp
  deriving DecidableEq, Repr, Inhabited

/-- Something the seller did about a change notice, and when. -/
structure SellerAct where
  /-- The follow-up action the seller took. -/
  action : FollowUpAction
  /-- When the seller took it. -/
  time : Instant
  deriving DecidableEq, Repr, Inhabited

/-- What the sources leave open about follow-up actions, as a parameter: a
reading of the sources.  A guarantee about follow-up actions counts as proven
only when it holds for every reading. -/
structure FollowUpReading where
  /-- What applies when a time limit passes and the follow-up action states no
  consequence: nothing, Auto-acceptance or Auto-cancellation. -/
  defaultConsequence : Option Inaction
  /-- Whether contacting the airline, which happens outside the order, is
  recorded in the order as the seller's answer. -/
  contactRecorded : Bool
  deriving DecidableEq, Repr, Inhabited

/-- When a follow-up action lapses and what then applies: its time limit and
its consequence, stated or taken from the reading.  A follow-up action with no
time limit, or with no consequence under the reading, never lapses. -/
def FollowUp.lapse (r : FollowUpReading) (f : FollowUp) : Option (Instant × Inaction) :=
  match f.timeLimit, f.consequence.or r.defaultConsequence with
  | some t, some c => some (t, c)
  | _, _ => none

/-- The entry with the earliest instant; the first listed on a tie. -/
def earliest : List (Instant × Inaction) → Option (Instant × Inaction)
  | [] => none
  | x :: xs =>
    match earliest xs with
    | none => some x
    | some y => if y.1 < x.1 then some y else some x

/-- When a notice lapses and what then applies: the earliest lapse among its
follow-up actions. -/
def ChangeNotice.lapse (r : FollowUpReading) (n : ChangeNotice) : Option (Instant × Inaction) :=
  earliest (n.followUps.filterMap (·.lapse r))

/-- EARS: When a time limit of a change notice passes and the seller has not
answered, the system shall apply the consequence of inaction of the follow-up
action whose time limit passed first.

Story: As a seller, I want to know what happens if I do not answer a change
notice in time, so that the customer is not surprised by an outcome nobody
chose.

Acceptance criteria:

* ONE-702.1: When a time limit that carries a consequence of inaction passes,
  the system shall apply the consequence of a follow-up action whose time limit
  is the earliest.
* ONE-702.2: If no follow-up action of a notice has a time limit, then the
  system shall apply no consequence of inaction.
* ONE-702.3: While no time limit of a notice has passed, the system shall
  apply no consequence of inaction.
* ONE-702.4: If the seller does not answer a change notice that carries
  follow-up actions, then the system shall resolve it before the affected
  flight departs.

A time limit passes at its instant, as an offer expires at its expiry instant.
A follow-up action with no stated consequence takes the reading's default
({name}`FollowUpReading`).  The result is the consequence that applies at the
instant given, or {lean}`none` when none applies yet. -/
@[ears "ONE-702", source "easd-seller-follow-up-actions"]
def consequenceAt (r : FollowUpReading) (n : ChangeNotice) (now : Instant) : Option Inaction :=
  match n.lapse r with
  | some (t, c) => if t ≤ now then some c else none
  | none => none

/-- How a change notice stands at an instant. -/
inductive Resolution
  /-- The notice offers no follow-up action; the seller only acknowledges it. -/
  | acknowledgeOnly
  /-- The seller has not answered and no consequence of inaction applies yet. -/
  | pending
  /-- The seller answered with this follow-up action. -/
  | answered (a : FollowUpAction)
  /-- A time limit passed before the seller answered, and this consequence
  applies. -/
  | lapsed (c : Inaction)
  deriving DecidableEq, Repr, Inhabited

/-- Whether the notice offers a follow-up action. -/
def ChangeNotice.offers (n : ChangeNotice) (a : FollowUpAction) : Bool :=
  n.followUps.any (·.action == a)

/-- Whether the order records a seller's action: every action but contacting
the airline, and that one too under a reading that records it. -/
def FollowUpReading.records (r : FollowUpReading) (a : FollowUpAction) : Bool :=
  a != .contactAirline || r.contactRecorded

/-- Whether a seller's act answers the notice by an instant: the notice offers
the action, the order records it, and the seller took it by then and before
any consequence of inaction applied. -/
def ChangeNotice.answeredBy (r : FollowUpReading) (n : ChangeNotice) (now : Instant)
    (a : SellerAct) : Bool :=
  n.offers a.action && r.records a.action && decide (a.time ≤ now) &&
    (consequenceAt r n a.time).isNone

/-- EARS: When an airline change notice offers follow-up actions, the system
shall keep them pending until the seller answers with one of them or a
consequence of inaction applies.

Story: As a seller, I want each change notice to show whether it waits for me,
what I answered, or what the airline did when I did not answer, so that I can
tell the customer where their trip stands.

Acceptance criteria:

* ONE-701.1: When an airline change notice carries no follow-up action, the
  system shall ask the seller only to acknowledge it.
* ONE-701.2: When the seller performs an offered Accept, Reshop, Cancel or
  RepriceAndAccept action before any consequence of inaction applies, the
  system shall resolve the notice with the seller's answer.
* ONE-701.3: The system shall resolve a notice with an answer only when the
  seller took that action, the notice offers it, and the seller took it before
  any consequence of inaction applied.
* ONE-701.4: While the seller has not answered a notice that offers follow-up
  actions, the system shall keep it pending until a consequence of inaction
  applies, and then resolve it with that consequence.
* ONE-701.5: When the seller contacts the airline about a notice that offers
  ContactAirline before any consequence of inaction applies, the system shall
  apply no consequence of inaction.

The seller's acts are listed in the order they happened; the first act that
answers the notice resolves it, and answering one follow-up action resolves
them all.  Whether contacting the airline counts as an answer is the reading's
({name}`FollowUpReading`). -/
@[ears "ONE-701", source "easd-seller-follow-up-actions"]
def resolve (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct) (now : Instant) :
    Resolution :=
  if n.followUps.isEmpty then .acknowledgeOnly
  else
    match acts.find? (n.answeredBy r now) with
    | some a => .answered a.action
    | none =>
      match consequenceAt r n now with
      | some c => .lapsed c
      | none => .pending

end Rules.OneOrder.AirlineChange
