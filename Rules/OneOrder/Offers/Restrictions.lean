import Rules.Core.Attributes
import Rules.OneOrder.Change.Differential
import Rules.OneOrder.Offers.Price

/-!
# Change and cancel restrictions

An offer item carries rules for voluntary changes and cancellations.  Each rule
belongs to one stage of the journey (before payment, before departure, after
departure, no show) and starts at its effective date.  At an instant, the rule
in force is the latest one of the current stage that has started.  It decides
whether a change is allowed and for what fee, and what a cancellation returns.
The guide leaves two points open, so the model takes them as parameters:
whether a rule's expiration date ends it, and which amount a refund marked full
and also given a fixed amount returns.
-/

namespace Rules.OneOrder.Offers

open Rules.Core

/-- The stage of a journey that a change or cancel rule belongs to. -/
inductive Stage
  /-- The order is not paid yet. -/
  | beforePayment
  /-- The order is paid and the flight has not departed. -/
  | beforeDeparture
  /-- The flight has departed with the passenger on board. -/
  | afterDeparture
  /-- The flight has departed without the passenger. -/
  | noShow
  deriving DecidableEq, Repr, Inhabited

/-- What the rules need to know about a journey to tell its stage. -/
structure Journey where
  /-- When the order was paid, if it was. -/
  paidAt : Option Instant
  /-- When the flight departs. -/
  departsAt : Instant
  /-- Whether the passenger did not show up for the flight. -/
  noShow : Bool
  deriving DecidableEq, Repr, Inhabited

/-- The stage a journey is in at an instant.  A stage starts at the instant of
the event that opens it: payment, then departure. -/
def Journey.stageAt (j : Journey) (now : Instant) : Stage :=
  match j.paidAt with
  | none => .beforePayment
  | some t =>
    if now < t then .beforePayment
    else if now < j.departsAt then .beforeDeparture
    else if j.noShow then .noShow
    else .afterDeparture

/-- The kinds of voluntary change the model distinguishes. -/
inductive ChangeKind
  /-- A change of flight. -/
  | flight
  /-- A change of passenger name. -/
  | name
  deriving DecidableEq, Repr, Inhabited

/-- What a rule governs: a kind of voluntary change, or a voluntary
cancellation. -/
inductive Action
  /-- A voluntary change of the given kind. -/
  | change (kind : ChangeKind)
  /-- A voluntary cancellation. -/
  | cancel
  deriving DecidableEq, Repr, Inhabited

/-- What a cancel rule returns when it allows cancellation. -/
inductive RefundTerms
  /-- Nothing. -/
  | nothing
  /-- The item's whole price. -/
  | full
  /-- A fixed amount. -/
  | fixed (amount : Money)
  /-- Marked as a full refund and also given a fixed amount.  One example in
  the guide has both. -/
  | fullWithAmount (amount : Money)
  deriving DecidableEq, Repr, Inhabited

/-- One change or cancel rule of an offer item.  It corresponds to a ONE Order
offer restriction. -/
structure Restriction where
  /-- The rule's reference. -/
  id : String
  /-- What the rule governs. -/
  action : Action
  /-- The stage of the journey the rule belongs to. -/
  stage : Stage
  /-- The instant the rule starts. -/
  effective : Instant
  /-- The rule's expiration date, if it has one. -/
  expires : Option Instant
  /-- Whether the rule allows the change or cancellation. -/
  allowed : Bool
  /-- The fee for a change, if the rule states one. -/
  fee : Option Money
  /-- Whether the fee is marked as approximate. -/
  feeApproximate : Bool
  /-- What a cancellation returns. -/
  refund : RefundTerms
  /-- Whether a refund goes to the original form of payment. -/
  toOriginalForm : Bool
  deriving DecidableEq, Repr, Inhabited

/-- Whether a rule's expiration date ends it.  The guide's description of the
rules uses the stage and the effective date only, while its message examples
also give rules an expiration date, so the model takes the answer as a
parameter: a reading of the guide. -/
inductive ExpiryReading
  /-- A rule runs until its stage ends or a later rule takes over; its
  expiration date changes nothing. -/
  | ignored
  /-- A rule also stops at its expiration date. -/
  | ends
  deriving DecidableEq, Repr, Inhabited

/-- Whether a rule has started at an instant and, under the reading that
expiration dates end rules, has not yet expired. -/
def Restriction.live (e : ExpiryReading) (now : Instant) (r : Restriction) : Bool :=
  decide (r.effective ≤ now) &&
    match e with
    | .ignored => true
    | .ends => r.expires.all (now < ·)

/-- The rule with the latest effective date in a list.  When two rules start at
the same instant, the first listed is taken; no guarantee depends on which. -/
def latestOf : List Restriction → Option Restriction
  | [] => none
  | r :: rs =>
    match latestOf rs with
    | none => some r
    | some r' => if r.effective < r'.effective then some r' else some r

/-- The rules for an action in the stage a journey is in at an instant that are
live at that instant. -/
def candidates (e : ExpiryReading) (rules : List Restriction) (j : Journey) (a : Action)
    (now : Instant) : List Restriction :=
  rules.filter fun r => decide (r.action = a) && decide (r.stage = j.stageAt now) && r.live e now

/-- EARS: When a change or cancellation is asked for at an instant, the system
shall take as the rule in force the rule for that action and the journey's
current stage with the latest effective date not after that instant.

Story: As a seller, I want to know which change or cancel rule applies at any
moment of the journey, so that I can tell the customer what a change costs and
what a cancellation returns.

Acceptance criteria:

* ONE-503.1: When a rule is in force for an action at an instant, the system
  shall take it from the rules for that action and for the stage the journey is
  in at that instant.
* ONE-503.2: When a rule is in force at an instant, the system shall take one
  whose effective date is not after that instant.
* ONE-503.3: When rules for an action and the current stage have started, and
  have not expired where expiration dates end rules, the system shall take as
  the rule in force one with the latest effective date among them.
* ONE-503.4: Where expiration dates end rules, the system shall not take a rule
  as in force at or after its expiration date.
* ONE-503.5: While a journey is in a stage for which an action has rules, the
  system shall have a rule in force for that action.

Whether a rule's expiration date ends it is a reading of the guide
({name}`ExpiryReading`). -/
@[ears "ONE-503", source "easd-offer-restrictions easd-offer-conditions-and-restrictions"]
def ruleInForce (e : ExpiryReading) (rules : List Restriction) (j : Journey) (a : Action)
    (now : Instant) : Option Restriction :=
  latestOf (candidates e rules j a now)

/-- A voluntary change a customer asks for. -/
structure ChangeRequest where
  /-- The kind of change. -/
  kind : ChangeKind
  /-- When the change is asked for. -/
  requestedAt : Instant
  /-- The price of the order items to be changed. -/
  oldPrice : Money
  /-- The price of the new order items. -/
  newPrice : Money
  /-- Whether the fee is netted or charged separately. -/
  handling : Change.PenaltyHandling
  /-- How the airline settles money it owes. -/
  settlement : Change.Settlement
  deriving DecidableEq, Repr, Inhabited

/-- What the rules decide about a voluntary change. -/
inductive ChangeDecision
  /-- No rule is in force for the change at that instant. -/
  | noRule
  /-- The rule in force forbids the change. -/
  | refused
  /-- The rule in force allows the change.  This is the change to price, as
  ONE-201 prices it, and whether the fee is marked approximate. -/
  | allowed (quote : Change.ChangeQuote) (approximate : Bool)
  deriving DecidableEq, Repr, Inhabited

/-- The fee a rule charges, in the given currency when the rule states none. -/
def Restriction.feeOr (r : Restriction) (c : Currency) : Money := r.fee.getD ⟨0, c⟩

/-- EARS: When a customer asks for a voluntary change, the system shall refuse
it if the rule in force forbids it, and otherwise quote it with the rule's fee
as the penalty.

Story: As a customer, I want a change to cost what the rule in force says, so
that I pay the fee and the fare difference and nothing else.

Acceptance criteria:

* ONE-504.1: If the rule in force forbids a change of the kind asked for, then
  the system shall refuse the change.
* ONE-504.2: When the rule in force allows a change and states a fee, the
  system shall quote the change with that fee as its penalty.
* ONE-504.3: When the rule in force allows a change and states no fee, the
  system shall quote the change with no penalty.
* ONE-504.4: When the rule in force allows a change with a fee no larger than
  the price of the items changed, and the seller does not ask to keep the value
  for later use, the system shall price the change so that the customer owes
  the fee plus the fare difference, net of what the airline returns.

The quote is a change for ONE-201 to price ({name}`Change.priceDifferential`):
the old and new prices, the fee as the penalty, and nothing forfeited.  When no rule is in force the decision says
so; the guide does not say what applies then. -/
@[ears "ONE-504", source "easd-offer-restrictions"]
def voluntaryChange (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (req : ChangeRequest) : ChangeDecision :=
  match ruleInForce e rules j (.change req.kind) req.requestedAt with
  | none => .noRule
  | some r =>
    if r.allowed then
      .allowed { oldPrice := req.oldPrice, newPrice := req.newPrice,
                 penalty := r.feeOr req.oldPrice.currency, forfeited := ⟨0, req.oldPrice.currency⟩,
                 handling := req.handling, settlement := req.settlement } r.feeApproximate
    else .refused

/-- An unused order item being cancelled: its price and the taxes, fees and
charges in it. -/
structure CancelledItem where
  /-- The item's whole price. -/
  price : Money
  /-- The taxes, fees and charges in the price, each with its refund flag. -/
  charges : List Charge
  deriving DecidableEq, Repr, Inhabited

/-- The taxes, fees and charges of an item flagged refundable, in minor
units. -/
def CancelledItem.refundableCharges (i : CancelledItem) : Nat :=
  sumOf ((i.charges.filter (·.refundable)).map (·.amount))

/-- Which amount a refund marked full and also given a fixed amount returns.
One example in the guide has both and the guide does not say which governs, so
the model takes the answer as a parameter: a reading of the guide. -/
inductive FullOrFixed
  /-- The item's whole price. -/
  | full
  /-- The fixed amount. -/
  | fixed
  deriving DecidableEq, Repr, Inhabited

/-- What a cancel rule's refund terms return for an item's price. -/
def RefundTerms.amount (ff : FullOrFixed) (price : Money) : RefundTerms → Money
  | .nothing => ⟨0, price.currency⟩
  | .full => price
  | .fixed m => m
  | .fullWithAmount m =>
    match ff with
    | .full => price
    | .fixed => m

/-- What the rules decide about a voluntary cancellation. -/
inductive RefundDecision
  /-- No cancel rule is in force at that instant. -/
  | noRule
  /-- The amount returned, and whether it goes to the original form of
  payment. -/
  | refund (amount : Money) (toOriginalForm : Bool)
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When a customer cancels an unused order item voluntarily, the system
shall return what the cancel rule in force gives: nothing if it forbids
cancellation, and otherwise a full or a fixed refund.

Story: As a customer, I want a cancellation to return what the rule in force
promised, so that I know what I get back before I cancel.

Acceptance criteria:

* ONE-505.1: If the cancel rule in force forbids cancellation, then the system
  shall return nothing.
* ONE-505.2: When the cancel rule in force allows cancellation with a full
  refund and no fixed amount, the system shall return the item's whole price.
* ONE-505.3: When the cancel rule in force allows cancellation with a fixed
  refund not marked full, the system shall return that amount.
* ONE-505.4: When the cancel rule in force allows cancellation and sends the
  refund to the original form of payment, the system shall pay the refund to
  the original form of payment.
* ONE-505.5: When an unused item is cancelled voluntarily, the system shall
  return at least the taxes, fees and charges in its price that are flagged
  refundable.

Which amount a refund marked full and also given a fixed amount returns is a
reading of the guide ({name}`FullOrFixed`).  When no cancel rule is in force
the decision says so; the guide does not say what applies then. -/
@[ears "ONE-505", source "easd-offer-restrictions"]
def cancellationRefund (e : ExpiryReading) (ff : FullOrFixed) (rules : List Restriction)
    (j : Journey) (now : Instant) (item : CancelledItem) : RefundDecision :=
  match ruleInForce e rules j .cancel now with
  | none => .noRule
  | some r =>
    if r.allowed then .refund (r.refund.amount ff item.price) r.toOriginalForm
    else .refund ⟨0, item.price.currency⟩ false

end Rules.OneOrder.Offers
