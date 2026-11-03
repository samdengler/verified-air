import Rules.Core.Attributes
import Rules.OneOrder.Change.Differential
import Rules.OneOrder.AirlineChange.FollowUp

/-!
# Declining an airline change

A customer who does not want a change the airline made can answer it with the
Cancel or Reshop follow-up action.  The airline prices the answer as it prices
any cancellation or change, with a price differential.  The sources never say
whether the airline's cancellation and change fees apply when the customer
declines a change the airline imposed, and no source defines which changes
the airline imposes.  The model takes both answers as parameters, readings of
the sources.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core
open Rules.OneOrder.Change

/-- Which kinds of change count as involuntary: imposed by the airline, as
opposed to requested by the customer.  No source defines the two kinds, so the
model takes the answer as a parameter: a reading of the sources.  The settled
three follow from the meaning of the words: a flight the airline cancels and
flights the airline moves the customer to are involuntary, and a change the
customer made with the airline is voluntary.  The sources set no threshold for
the rest, such as a 10-minute schedule change or another operating carrier. -/
structure InvoluntaryReading where
  /-- Whether a kind of change counts as involuntary. -/
  involuntary : ChangeReason → Bool
  /-- A flight the airline cancels is an involuntary change. -/
  flightCancelled : involuntary .flightCancelled = true
  /-- Flights the airline moves the customer to are an involuntary change. -/
  itineraryChange : involuntary .itineraryChange = true
  /-- A change the customer made with the airline is voluntary. -/
  customerRequest : involuntary .customerRequest = false

/-- Whether the airline's fees apply when a customer declines an involuntary
change.  The sources offer Cancel and Reshop as answers to a change and never
say, and the cancellation page leaves penalties to the airline.  The model
takes the answer as a parameter: a reading of the sources. -/
inductive DeclineFees
  /-- The item's fees apply as on any cancellation or change. -/
  | airlineTerms
  /-- An involuntary change is declined free of the item's fees. -/
  | waived
  deriving DecidableEq, Repr, Inhabited

/-- The fees the airline's terms set on an order item.  In the itinerary change
worked example the new order item carries a cancellation fee of 50 EUR and a
change fee of 40 EUR. -/
structure ItemFees where
  /-- The fee for cancelling the item. -/
  cancellation : Money
  /-- The fee for changing the item. -/
  change : Money
  deriving DecidableEq, Repr, Inhabited

/-- The airline's terms for pricing a customer's answer to a change. -/
structure DeclineTerms where
  /-- The fees on the affected order items. -/
  fees : ItemFees
  /-- The part of the affected items' price the airline keeps. -/
  forfeited : Money
  /-- Whether a penalty is netted or charged separately. -/
  handling : PenaltyHandling
  /-- How the airline settles money it owes. -/
  settlement : Settlement
  deriving DecidableEq, Repr, Inhabited

/-- How a customer leaves a change the airline made. -/
inductive Decline
  /-- Cancel the affected order items, through the Cancel follow-up action or
  by Auto-cancellation at a time limit. -/
  | cancel
  /-- Reshop to new order items at this price, through the Reshop follow-up
  action. -/
  | reshop (newPrice : Money)
  deriving DecidableEq, Repr, Inhabited

/-- The penalty charged for declining a change under the two readings: the
fee, or nothing when the change is involuntary and the fees are waived. -/
def DeclineFees.penalty (w : DeclineFees) (inv : InvoluntaryReading) (reason : ChangeReason)
    (fee : Money) : Money :=
  match w with
  | .airlineTerms => fee
  | .waived => if inv.involuntary reason then ⟨0, fee.currency⟩ else fee

/-- The change or cancellation the airline prices when a customer declines a
change: from the affected items to nothing for Cancel, or to the new items for
Reshop, with the cancellation or change fee as the penalty. -/
def declineQuote (w : DeclineFees) (inv : InvoluntaryReading) (n : ChangeNotice) (affected : Money)
    (t : DeclineTerms) : Decline → ChangeQuote
  | .cancel =>
    { oldPrice := affected, newPrice := ⟨0, affected.currency⟩,
      penalty := w.penalty inv n.reason t.fees.cancellation, forfeited := t.forfeited,
      handling := t.handling, settlement := t.settlement }
  | .reshop p =>
    { oldPrice := affected, newPrice := p, penalty := w.penalty inv n.reason t.fees.change,
      forfeited := t.forfeited, handling := t.handling, settlement := t.settlement }

/-- EARS: When a customer declines an airline change through Cancel or
Reshop, the system shall price it as a cancellation or change of the affected
order items, with the airline's cancellation or change fee as the penalty.

Story: As a customer, I want to know what declining a change the airline made
will cost me, so that I can choose between the changed trip, another trip
and my money back.

Acceptance criteria:

* ONE-703.1: When a customer declines an airline change through Cancel or
  Auto-cancellation, the system shall price a cancellation of the affected
  order items with a new price of zero.
* ONE-703.2: When a customer declines an airline change through Reshop, the
  system shall price a change from the affected order items to the new items at
  their price.
* ONE-703.4: If a customer declines an involuntary change through Cancel or
  Auto-cancellation, then the system shall charge no cancellation penalty.
* ONE-703.5: If a customer declines an involuntary change through Reshop, then
  the system shall charge no change fee.

The differential comes from {name}`priceDifferential`, with the reading of a
penalty above the refundable value given.  The sources do not say what
Auto-cancellation cancels and refunds; the model prices it as a Cancel of the
affected items.  Whether the fees apply is the reading's
({name}`DeclineFees`), and which changes are involuntary is another reading's
({name}`InvoluntaryReading`). -/
@[ears "ONE-703", source "easd-seller-follow-up-actions"]
def declineOffer (e : ExcessPenalty) (w : DeclineFees) (inv : InvoluntaryReading) (n : ChangeNotice)
    (affected : Money) (t : DeclineTerms) (d : Decline) : Except QuoteRejection PriceDifferential :=
  priceDifferential e (declineQuote w inv n affected t d)

end Rules.OneOrder.AirlineChange
