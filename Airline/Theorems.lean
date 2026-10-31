import Airline.Evaluate
import Rules.OfferOrder.Payment

/-!
# Verified Airline's fares as theorems

The facts {lit}`lake exe airline-facts` prints evaluate each fare at one journey
and one instant per stage.  Each fact about a change or a cancellation has a
theorem here that states it for every input in that stage: every journey and
every instant at which the journey is in the stage once the fare terms have
started, every item or change request, and every reading of the guide.  The
theorem {lit}`probes_in_stage` shows that the journey and instant the facts
evaluate are in their stage after the terms start, so each fact is its
theorem at that point.  The JSON the executable prints is not proved.

A fact's theorem is named after its place in the facts: the fact at
{lit}`fares.main.cancel.noShow` is {lit}`main_cancel_noShow`.
{lit}`lake exe airline-facts --theorems` lists them for Verified Airline's site,
with their lines in this file, and fails if a fact has none.

The last two sections state the rules of the airline's support chat that hold
for every fare, and what the model's types say about amounts.  The chat's
Automated Reasoning policy, which {lit}`scripts/export_airline_policy.py` writes,
cites each one beside the rule it backs.

A theorem holds once the terms have started, since no rule is in force
before then.  The cancellation theorems cover every item, including one whose
price holds taxes flagged refundable; whether those come back is the model's
open criterion ONE-505.5.
-/

namespace Airline

open Rules.Core Rules.OneOrder.Offers

/-- The change a rule quotes for a request, as {name}`voluntaryChange` builds it:
the request's old and new prices, the fee as the penalty, and nothing
forfeited. -/
def quote (req : ChangeRequest) (fee : Money) : Rules.OneOrder.Change.ChangeQuote :=
  { oldPrice := req.oldPrice, newPrice := req.newPrice, penalty := fee,
    forfeited := ⟨0, req.oldPrice.currency⟩, handling := req.handling, settlement := req.settlement }

/-- The journey and instant at which the facts evaluate each stage after
payment are in that stage, after the fare terms start. -/
theorem probes_in_stage :
    ∀ p ∈ stages, (probe p.2).1.stageAt (probe p.2).2 = p.2 ∧ termsStart ≤ (probe p.2).2 := by
  decide

attribute [local simp] voluntaryChange cancellationRefund ruleInForce candidates Restriction.live
  latestOf Restriction.feeOr RefundTerms.amount quote term basicFare mainFare flexFare

variable (e : ExpiryReading) (ff : FullOrFixed) (j : Journey) (now : Instant)
  (item : CancelledItem) (req : ChangeRequest)

/-! ## Basic -/

/-- On Basic, a change of flight before departure is refused. -/
theorem basic_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a change of flight after the first flight is refused. -/
theorem basic_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a change of flight after a missed flight is refused. -/
theorem basic_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a cancellation before departure returns nothing. -/
theorem basic_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-- On Basic, a cancellation after the first flight returns nothing. -/
theorem basic_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-- On Basic, a cancellation after a missed flight returns nothing. -/
theorem basic_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-! ## Main -/

/-- On Main, a change of flight before departure is allowed with a 75 dollar
fee as its penalty, priced from the request's old and new prices. -/
theorem main_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .allowed (quote req (usd 75)) false := by
  cases e <;> simp [*]

/-- On Main, a change of flight after the first flight is allowed with a 75
dollar fee as its penalty, priced from the request's old and new prices. -/
theorem main_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .allowed (quote req (usd 75)) false := by
  cases e <;> simp [*]

/-- On Main, a change of flight after a missed flight is refused. -/
theorem main_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Main, a cancellation before departure returns 150 dollars to the
original form of payment, whatever the item's price. -/
theorem main_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund (usd 150) true := by
  cases e <;> simp [*]

/-- On Main, a cancellation after the first flight returns 150 dollars to the
original form of payment, whatever the item's price. -/
theorem main_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund (usd 150) true := by
  cases e <;> simp [*]

/-- On Main, a cancellation after a missed flight returns nothing. -/
theorem main_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-! ## Flex -/

/-- On Flex, a change of flight before departure is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a change of flight after the first flight is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a change of flight after a missed flight is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a cancellation before departure returns the item's whole price to
the original form of payment. -/
theorem flex_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund item.price true := by
  cases e <;> simp [*]

/-- On Flex, a cancellation after the first flight returns the item's whole
price to the original form of payment. -/
theorem flex_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund item.price true := by
  cases e <;> simp [*]

/-- On Flex, a cancellation after a missed flight returns 100 dollars to the
original form of payment, whatever the item's price. -/
theorem flex_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund (usd 100) true := by
  cases e <;> simp [*]

/-! ## Rules for every fare

Each theorem here holds for every rule list, so for every fare: it states one
of the support chat's general rules for every allowed change or every refund,
under every reading of the guide. -/

/-- The fare difference of an allowed change is the new flight's price minus
the price paid. -/
theorem change_fareDifference (rs : List Restriction) (q : Rules.OneOrder.Change.ChangeQuote) (a : Bool)
    (h : voluntaryChange e rs j req = .allowed q a) :
    q.difference = (req.newPrice.amount : Int) - req.oldPrice.amount := by
  simp only [voluntaryChange] at h
  split at h
  · cases h
  · split at h
    · cases h
      simp [Rules.OneOrder.Change.ChangeQuote.difference]
    · cases h

/-- When the new flight costs at least the price paid and the price paid
covers the fee, an allowed change leaves the traveler to pay the fee plus the
fare difference, and the airline owes nothing back.  This holds under both
readings of a fee larger than the refundable value and whether the fee is
netted or charged separately.  Without the second condition the readings
differ: under one, the airline waives the part of the fee above the price
paid. -/
theorem change_amountDue (rs : List Restriction) (q : Rules.OneOrder.Change.ChangeQuote) (a : Bool)
    (r : Rules.OneOrder.Change.ExcessPenalty)
    (h : voluntaryChange e rs j req = .allowed q a)
    (hd : 0 ≤ q.difference) (hf : q.penalty.amount ≤ req.oldPrice.amount) :
    ((Rules.OneOrder.Change.dueAmounts r q).toAirline : Int) = q.difference + q.penalty.amount ∧
      (Rules.OneOrder.Change.dueAmounts r q).byAirline = 0 := by
  simp only [voluntaryChange] at h
  split at h
  · cases h
  · split at h
    · cases h
      simp only [Rules.OneOrder.Change.ChangeQuote.difference] at hd hf ⊢
      cases r <;> cases req.handling <;>
        simp only [Rules.OneOrder.Change.dueAmounts, Rules.OneOrder.Change.ExcessPenalty.charged,
          Rules.OneOrder.Change.ChangeQuote.refundable, Rules.OneOrder.Change.ChangeQuote.difference] <;>
        omega
    · cases h

/-- A refund larger than the payment it is asked against is refused. -/
theorem refund_overPayment (p : Rules.OfferOrder.Payment) (rf : Rules.OfferOrder.Refund)
    (h : p.amount.amount < rf.amount.amount) :
    Rules.OfferOrder.acceptRefund p rf = false := by
  simp [Rules.OfferOrder.acceptRefund]
  omega

/-- A refund no larger than the payment it names is accepted.  The rule looks
at this one refund and this one payment; whether refunds against one payment
are capped in total is the model's open criterion OO-003.2. -/
theorem refund_withinPayment (p : Rules.OfferOrder.Payment) (rf : Rules.OfferOrder.Refund)
    (hp : rf.payment = p.id) (h : rf.amount.amount ≤ p.amount.amount) :
    Rules.OfferOrder.acceptRefund p rf = true := by
  simp [Rules.OfferOrder.acceptRefund, hp, h]

/-! ## Amounts

What the model's types and the fares say about amounts, which the support
chat's policy takes as given. -/

/-- An amount of money is never negative: the model counts it in minor units,
as a natural number. -/
theorem money_nonNegative (m : Money) : (0 : Int) ≤ m.amount := by
  omega

/-- Every Verified Airline fare has a positive price: the price of one booked
item on the fare in the worked examples. -/
theorem fares_pricePositive : ∀ f ∈ fares, 0 < f.price.amount := by
  decide

end Airline
