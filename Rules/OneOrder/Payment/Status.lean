import Rules.Core.Attributes
import Rules.OneOrder.Payment.Basic

/-!
# Payment status and paid items

A payment's status follows from the transactions of its payment methods, and
an order item counts as paid once a successful payment covers it.  The airline
records each method's outcome as it learns it.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- EARS: The system shall give a payment the status FAILED if it has no payment
method or the transaction of any of its payment methods failed, SUCCESSFUL if
all of them succeeded, and PENDING otherwise.

Story: As an airline, I want a payment made with several methods to succeed
only when every method succeeds, so that I never treat an order item as paid
when part of its money will not arrive.

Acceptance criteria:

* ONE-301.1: If the transaction of any payment method in a payment fails, then
  the system shall mark the whole payment FAILED.
* ONE-301.2: When a payment has at least one payment method and the
  transactions of all its payment methods succeed, the system shall mark the
  payment SUCCESSFUL.
* ONE-301.3: While no payment method's transaction in a payment has failed and
  at least one is still pending, the system shall mark the payment PENDING.
* ONE-301.4: If a payment has no payment method, then the system shall mark it
  FAILED.

The guide describes a payment as made with one or more payment methods.  A
payment with none collects nothing, so it is FAILED.  Without that case, every
method of an empty payment would count as succeeded, and the payment with
them. -/
@[ears "ONE-301", source "easd-multiple-payment-methods"]
def Transaction.status (p : Transaction) : PaymentStatus :=
  if p.parts.isEmpty then .failed
  else if p.parts.any (·.status = .failed) then .failed
  else if p.parts.all (·.status = .successful) then .successful
  else .pending

/-- Whether a payment pays for an order item: the payment is SUCCESSFUL and
covers the item. -/
def Transaction.pays (p : Transaction) (ref : String) : Bool :=
  decide (p.status = .successful ∧ ref ∈ p.covers)

/-- EARS: The system shall count an order item paid once a SUCCESSFUL payment
covers it.

Story: As an airline, I want an order item counted as paid only when a payment
for it has succeeded, so that I release nothing on money I may not collect.

Acceptance criteria:

* ONE-302.1: When a SUCCESSFUL payment covers an order item, the system shall
  count the item paid.
* ONE-302.2: If every payment covering an order item is PENDING or FAILED, then
  the system shall not count the item paid.
* ONE-302.3: If the transaction of any payment method in a payment fails, then
  the system shall count none of the order items it covers as paid by that
  payment and shall leave their services unchanged.

The amounts are checked when the payment is accepted: the requested amounts of
a payment add up to the price of the items it covers.  Value carried over from
an item that a change replaced is not modelled. -/
@[ears "ONE-302", source "armi-payord"]
def isPaid (payments : List Transaction) (ref : String) : Bool :=
  payments.any (·.pays ref)

/-- Which moves between statuses the airline may record for a payment method's
transaction.  The guide settles two: a PENDING transaction moves to SUCCESSFUL
or to FAILED.  It does not say whether SUCCESSFUL and FAILED are final, for
example after a card chargeback or a redirected payment completed late, so the
model takes the answer as a parameter: a reading of the guide. -/
structure OutcomeReading where
  /-- Whether a transaction may move from one status to another. -/
  allows : PaymentStatus → PaymentStatus → Bool
  /-- A PENDING transaction may become SUCCESSFUL. -/
  pendingToSuccessful : allows .pending .successful = true
  /-- A PENDING transaction may become FAILED. -/
  pendingToFailed : allows .pending .failed = true

/-- A method's transaction with a reported outcome recorded, when the reading
allows the move from its current status. -/
def MethodPart.record (r : OutcomeReading) (s : PaymentStatus) (m : MethodPart) : MethodPart :=
  if r.allows m.status s then { m with status := s } else m

/-- EARS: When the airline reports the outcome of a payment method's
transaction, the system shall record it as the transaction's status if the
move from the recorded status is allowed.

Story: As an airline, I want the outcome of each payment method's transaction
recorded as it arrives, so that a payment's status follows what I know about
its funds.

Acceptance criteria:

* ONE-303.1: When the airline reports a SUCCESSFUL or FAILED outcome for a
  payment method's transaction that is still PENDING, the system shall record
  the outcome.
* ONE-303.2: When the airline reports the outcome of one payment method's
  transaction, the system shall leave the transactions of the payment's other
  methods unchanged.
* ONE-303.3: The system shall never change the status of a payment that is
  SUCCESSFUL or FAILED.

Which moves are allowed besides those out of PENDING is a reading of the guide
(see {name}`OutcomeReading`). -/
@[ears "ONE-303", source "easd-pay-offline-using-redirection easd-multiple-payment-methods"]
def recordOutcome (r : OutcomeReading) (p : Transaction) (ref : String) (s : PaymentStatus) : Transaction :=
  { p with parts := p.parts.map fun m => if m.id = ref then m.record r s else m }

end Rules.OneOrder.Payment
