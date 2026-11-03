import Rules.Core.Attributes
import Rules.Core.Money

/-!
# Commission and net clearance amounts

The commission an airline owes a seller on an order item, and the money that
moves between the airline that owns the order (the ORA) and the seller for
each payment.  The sources state the commission rule and show net clearance
amounts only in worked examples.  The model reads the formulas from those
examples and takes what the sources leave open as parameters.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core

/-- The code of a commission.  An order item may carry several commissions,
each with its own code. -/
inductive CommissionCode
  /-- The airline's standard commission. -/
  | standard
  /-- A supplemental commission on top of the standard one. -/
  | supplemental
  /-- An incentive for clearing the payment through Settlement with Orders. -/
  | clearanceIncentive
  deriving DecidableEq, Repr, Inhabited

/-- How a commission is stated: a fixed amount, or a percentage of a stated
base amount.  A commission is one or the other, never both. -/
inductive CommissionTerms
  /-- A fixed amount. -/
  | fixed (amount : Money)
  /-- A percentage of a base amount, in hundredths of a percent: 500 is
  5 percent. -/
  | percentage (basisPoints : Nat) (base : Money)
  deriving DecidableEq, Repr, Inhabited

/-- One commission on an order item.  It corresponds to a ONE Order
commission. -/
structure Commission where
  /-- The commission code. -/
  code : CommissionCode
  /-- The fixed amount, or the percentage and its base. -/
  terms : CommissionTerms
  deriving DecidableEq, Repr, Inhabited

/-- How a percentage is rounded to a whole minor unit.  The guide does not
say, so the model takes the answer as a parameter: a reading of the guide. -/
inductive Rounding
  /-- Down to the minor unit below. -/
  | down
  /-- To the nearest minor unit, with a half rounded up. -/
  | halfUp
  /-- Up to the minor unit above. -/
  | up
  deriving DecidableEq, Repr, Inhabited

/-- A quotient of whole numbers, rounded to a whole number under a reading. -/
def Rounding.divide (r : Rounding) (n d : Nat) : Nat :=
  match r with
  | .down => n / d
  | .halfUp => (2 * n + d) / (2 * d)
  | .up => (n + d - 1) / d

/-- The amount a commission comes to: the fixed amount, or the percentage of
its base rounded to a whole minor unit. -/
def CommissionTerms.value (r : Rounding) : CommissionTerms → Money
  | .fixed m => m
  | .percentage bp base => ⟨r.divide (bp * base.amount) 10000, base.currency⟩

/-- EARS: The system shall owe the seller of an order item the total of the
item's commissions, each a fixed amount or a percentage of a stated base
amount.

Story: As a seller, I want every commission on an order item worked out the
same way and added up, so that I know what the airline owes me for the sale.

Acceptance criteria:

* ONE-801.1: Where a commission is a fixed amount, the system shall owe the
  seller that amount.
* ONE-801.2: Where a commission is a percentage of a stated base amount, the
  system shall owe the seller that share of the base to within one minor unit.
* ONE-801.3: When an order item carries several commissions in the item's
  currency, the system shall owe the seller their total.
* ONE-801.4: If the commissions on an order item are not all in the item's
  currency, then the system shall state no total.
* ONE-801.5: Where a commission is a percentage of no more than 100 percent,
  the system shall never owe more than its base amount.

The guide says several commissions apply without saying how they combine; the
model adds them.  How a percentage is rounded is a reading of the guide
({name}`Rounding`).  Whether the base is the fare alone or includes taxes, and
whether a commission subject to consumption tax is stated gross or net of that
tax, are left to the amounts the airline states.  The result is the total, or
{lean}`none` when the currencies differ. -/
@[ears "ONE-801", source "easd-commission-and-margin"]
def commissionOwed (r : Rounding) (c : Currency) (cs : List Commission) : Option Money :=
  if cs.all (fun x => (x.terms.value r).currency == c) then
    some ⟨(cs.map fun x => (x.terms.value r).amount).sum, c⟩
  else none

/-- Who collected the customer's money for a payment. -/
inductive Collector
  /-- The seller collected it, for example through IATA EasyPay. -/
  | seller
  /-- The airline collected it, for example as the card merchant. -/
  | airline
  deriving DecidableEq, Repr, Inhabited

/-- How the seller's commission on a payment the seller collected is
cleared. -/
inductive CommissionHandling
  /-- Deducted from the amount the seller pays the ORA. -/
  | netted
  /-- Cleared on its own, with the ORA paying the seller. -/
  | separate
  deriving DecidableEq, Repr, Inhabited

/-- A party to the clearances for one payment. -/
inductive Role
  /-- The airline that owns the order. -/
  | ora
  /-- The seller. -/
  | seller
  deriving DecidableEq, Repr, Inhabited

/-- A payment commitment as clearance sees it: the payment amount and the
seller's commission on it, in minor units of the payment's currency, who
collected the customer's money, and how the commission is cleared. -/
structure PaymentCommitment where
  /-- The order the payment is for. -/
  orderId : String
  /-- The payment reference. -/
  paymentId : String
  /-- The currency of the payment. -/
  currency : Currency
  /-- The payment amount, in minor units. -/
  amount : Nat
  /-- The seller's commission on the payment, in minor units. -/
  commission : Nat
  /-- Who collected the customer's money. -/
  collector : Collector
  /-- How the commission is cleared, when the seller collected the money. -/
  handling : CommissionHandling
  deriving DecidableEq, Repr, Inhabited

/-- One clearance the net clearance amount rule states: who pays whom how much,
in minor units of the payment's currency.  The rule as written can give a
negative amount, which would mean the payee pays the payer. -/
structure ClearanceLeg where
  /-- The party that pays. -/
  payer : Role
  /-- The party that is paid. -/
  payee : Role
  /-- The net clearance amount. -/
  amount : Int
  deriving DecidableEq, Repr, Inhabited

/-- What a clearance leaves a party with: the amount if it is the payee, less
the amount if it is the payer. -/
def ClearanceLeg.netFor (role : Role) (l : ClearanceLeg) : Int :=
  (if l.payee = role then l.amount else 0) - (if l.payer = role then l.amount else 0)

/-- How much of the commission first paid on a payment the airline recalls when
the payment is refunded through the seller.  The source recalls it only where
the market allows and gives no rule for a partial refund, so the model takes
the answer as a parameter: a reading of the sources. -/
inductive RecallReading
  /-- The market allows no recall: the seller keeps the commission. -/
  | noRecall
  /-- The commission first paid is recalled in full, as in the source's refund
  example. -/
  | full
  /-- The share of the commission that matches the share of the payment
  refunded, rounded down. -/
  | proportional
  deriving DecidableEq, Repr, Inhabited

/-- A refund made through the seller: the amount refunded, the payment it
refunds and the commission first paid on that payment, in minor units. -/
structure SellerRefund where
  /-- The amount refunded to the customer. -/
  refund : Nat
  /-- The amount of the payment refunded. -/
  payment : Nat
  /-- The commission first paid on that payment. -/
  commission : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The commission recalled on a refund under a reading. -/
def RecallReading.recalled (rr : RecallReading) (r : SellerRefund) : Nat :=
  match rr with
  | .noRecall => 0
  | .full => r.commission
  | .proportional => r.commission * r.refund / r.payment

/-- The clearance for a refund made through the seller: the ORA pays the
seller the refund less the commission recalled on it. -/
def refundClearance (rr : RecallReading) (r : SellerRefund) : ClearanceLeg :=
  ⟨.ora, .seller, (r.refund : Int) - rr.recalled r⟩

/-- EARS: When a payment commitment is made, the system shall state the
clearances between the ORA and the seller for it, with their net clearance
amounts.

Story: As a seller, I want each payment cleared with the ORA by one rule, so
that I receive my commission once and the airline receives the rest.

Acceptance criteria:

* ONE-802.1: When the seller collected the customer's payment and nets its
  commission, the system shall state one clearance in which the seller pays
  the ORA the payment amount less the commission.
* ONE-802.2: When the seller collected the customer's payment and its
  commission is cleared separately, the system shall state one clearance in
  which the seller pays the ORA the payment amount and one in which the ORA
  pays the seller the commission.
* ONE-802.3: When the airline collected the customer's payment, the system
  shall state one clearance in which the ORA pays the seller the commission.
* ONE-802.4: The system shall clear the seller's commission on each payment
  exactly once, leaving the ORA the payment amount less the commission and the
  seller the commission.
* ONE-802.5: When a payment is refunded through the seller, the system shall
  state one clearance in which the ORA pays the seller the refund less the
  commission recalled on it.
* ONE-802.6: If a payment is refunded through the seller, then the system
  shall not leave the seller paying the ORA for the refund.

The standard defines the net clearance amount only as what the two parties
agreed; the formulas come from the worked examples.  A refund is cleared by
{name}`refundClearance`, and how much commission it recalls is a reading of
the sources ({name}`RecallReading`). -/
@[ears "ONE-802",
  source "swo-request-for-clearance armi-paycmt swo-enhanced-and-simplified-distribution swo-settlement"]
def clearancesFor (p : PaymentCommitment) : List ClearanceLeg :=
  match p.collector, p.handling with
  | .seller, .netted => [⟨.seller, .ora, (p.amount : Int) - p.commission⟩]
  | .seller, .separate => [⟨.seller, .ora, p.amount⟩, ⟨.ora, .seller, p.commission⟩]
  | .airline, _ => [⟨.ora, .seller, p.commission⟩]

/-- The customer's money a party collected for a payment. -/
def PaymentCommitment.collected (p : PaymentCommitment) (role : Role) : Int :=
  match p.collector, role with
  | .seller, .seller => p.amount
  | .airline, .ora => p.amount
  | _, _ => 0

/-- What a party ends with for a payment: the customer's money it collected,
plus what the payment's clearances leave it. -/
def PaymentCommitment.endsWith (p : PaymentCommitment) (role : Role) : Int :=
  p.collected role + ((clearancesFor p).map (·.netFor role)).sum

end Rules.OneOrder.Accounting
