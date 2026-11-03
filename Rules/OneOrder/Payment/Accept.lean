import Rules.Core.Attributes
import Rules.OneOrder.Payment.Basic

/-!
# Accepting a payment

The checks the airline makes before it takes a payment for order items: the
items' payment time limits, the currencies, the commitment method, and whether
the requested amounts add up to the items' price.  Each payment method is then
charged its requested amount plus its surcharge.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- Why the airline refuses a payment. -/
inductive PaymentRejection
  /-- An order item the payment covers is at or past its payment time limit. -/
  | timeLimitPassed
  /-- The payment names no payment method. -/
  | noMethod
  /-- A price or an amount is in a currency other than the payment's. -/
  | mixedCurrency
  /-- A commitment method carries an amount other than zero. -/
  | commitmentNotZero
  /-- A payment with a commitment method covers an item with an amount to pay. -/
  | commitmentWithAmountDue
  /-- The requested amounts do not add up to the price of the items covered. -/
  | amountMismatch
  deriving DecidableEq, Repr, Inhabited

/-- What a payment method is charged: its requested amount plus its surcharge,
in the payment's currency. -/
def MethodPart.charged (c : Currency) (m : MethodPart) : Money :=
  ⟨m.requested.amount + m.surcharge.amount, c⟩

/-- EARS: When a seller pays for order items, the system shall accept the
payment only if it is made before the items' payment time limits and its
requested amounts add up to their price, and shall charge each payment method
its requested amount plus its surcharge.

Story: As an airline, I want each payment checked against the items it pays
for, so that items are paid in full and on time, and each method is charged
its amount plus its surcharge.

Acceptance criteria:

* ONE-304.1: When the airline accepts a payment, the system shall charge each
  payment method its requested amount plus its surcharge.
* ONE-304.2: If the requested amounts of a payment do not add up to the price
  of the order items it covers, then the system shall reject the payment.
* ONE-304.3: When the airline accepts a payment, the system shall charge in
  total the price of the order items it covers plus the surcharges of its
  payment methods.
* ONE-304.4: If a payment is made at or after the payment time limit of an
  order item it covers, then the system shall reject the payment.
* ONE-304.5: If a payment uses the commitment method with an amount other than
  zero, then the system shall reject the payment.
* ONE-304.6: If a payment uses the commitment method for order items with an
  amount to pay, then the system shall reject the payment.
* ONE-304.7: If a payment has no payment method, then the system shall reject
  the payment.

The checks run in this order: payment time limits, a payment method present,
currencies, commitment amounts, commitments for items with an amount to pay,
and the requested total.  The result is the amount charged to each method, in
the order of the methods. -/
@[ears "ONE-304",
  source "easd-multiple-payment-methods easd-pay-for-an-existing-order easd-payment-simulation"]
def acceptPayment (o : PayableOrder) (p : Transaction) (now : Instant) :
    Except PaymentRejection (List Money) :=
  if (o.coveredBy p).any (fun pi => pi.timeLimit.any (· ≤ now)) then .error .timeLimitPassed
  else if p.parts.isEmpty then .error .noMethod
  else if (o.coveredBy p).any (·.item.price.currency ≠ p.currency) ||
      p.parts.any (fun m => m.requested.currency ≠ p.currency || m.surcharge.currency ≠ p.currency) then
    .error .mixedCurrency
  else if p.parts.any (fun m => m.method = .commitment ∧ (m.requested.amount ≠ 0 ∨ m.surcharge.amount ≠ 0)) then
    .error .commitmentNotZero
  else if p.parts.any (·.method = .commitment) && priceTotal (o.coveredBy p) ≠ 0 then
    .error .commitmentWithAmountDue
  else if p.requestedTotal ≠ priceTotal (o.coveredBy p) then .error .amountMismatch
  else .ok (p.parts.map (·.charged p.currency))

end Rules.OneOrder.Payment
