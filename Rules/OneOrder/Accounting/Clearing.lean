import Rules.Core.Attributes
import Rules.OneOrder.Accounting.Commission
import Rules.OneOrder.Accounting.Clearance

/-!
# Net positions, clearings and short remittances

On each remittance date the Clearance Manager nets every party's clearances
into one position, pays settlement payees through clearings, and collects from
remittance payers.  When a remittance payer pays short, it splits what it
received.  The sources leave open how EasyPay clearances enter the netting,
and give two different rules for splitting a short payment, so the model takes
the answers as parameters.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core

/-! ## Net positions -/

/-- A party to the netting: an airline or seller by its code, or the EasyPay
provider. -/
inductive Party
  /-- An airline or a seller, by its code. -/
  | org (code : String)
  /-- The IATA EasyPay provider, which pays the ORA for EasyPay clearances. -/
  | easyPayProvider
  deriving DecidableEq, Repr, Inhabited

/-- How an EasyPay clearance enters the netting.  The EasyPay provider pays it,
so the source leaves it out of the payer's remittance and keeps it in the
payee's settlement, without saying whether the provider is a party.  The
model takes the answer as a parameter: a reading of the sources. -/
inductive EasyPayReading
  /-- Left out of the payer's position and kept in the payee's. -/
  | leftOut
  /-- The EasyPay provider takes the payer's place in the netting. -/
  | providerPays
  deriving DecidableEq, Repr, Inhabited

/-- The party a clearance is netted against as payer, if any. -/
def netPayer (r : EasyPayReading) (c : Clearance) : Option Party :=
  match c.method, r with
  | .settlementPlan, _ => some (.org c.payer)
  | .easyPay, .leftOut => none
  | .easyPay, .providerPays => some .easyPayProvider

/-- What a clearance adds to a party's net position: its amount if the party
is the payee, less its amount if the party is netted as its payer. -/
def Clearance.netFor (r : EasyPayReading) (p : Party) (c : Clearance) : Int :=
  (if Party.org c.payee = p then (c.amount : Int) else 0) -
    (if netPayer r c = some p then (c.amount : Int) else 0)

/-- A party's net position for a remittance date: what the clearances on that
date add to it. -/
def netPosition (r : EasyPayReading) (cs : List Clearance) (date : String) (p : Party) : Int :=
  ((cs.filter (·.remittanceDate == date)).map (·.netFor r p)).sum

/-- What a party is in the settlement for a remittance date. -/
inductive SettlementRole
  /-- It is paid this amount. -/
  | settlementPayee (amount : Nat)
  /-- It pays this amount. -/
  | remittancePayer (amount : Nat)
  /-- It neither pays nor is paid. -/
  | even
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When the Clearance Manager nets the clearances for a remittance date,
the system shall make each party a settlement payee or a remittance payer for
its net position.

Story: As a Clearance Manager, I want each party's clearances netted into one
amount per remittance date, so that each party makes or receives one transfer
and the transfers balance.

Acceptance criteria:

* ONE-805.1: When the Clearance Manager nets the clearances for a remittance
  date, the system shall give each party the amounts of the clearances it is
  paid less the amounts of those it is netted as payer of.
* ONE-805.2: When a party's net position for a remittance date is positive,
  the system shall make it a settlement payee for that amount.
* ONE-805.3: When a party's net position for a remittance date is negative,
  the system shall make it a remittance payer for that amount.
* ONE-805.4: If a clearance is paid through EasyPay, then the system shall
  leave it out of the net position of its payer.
* ONE-805.5: The system shall make the net positions of all parties for a
  remittance date sum to zero.

How an EasyPay clearance enters the netting is a reading of the sources
({name}`EasyPayReading`).  The model nets one currency. -/
@[ears "ONE-805", source "swo-clearance-manager swo-remittance-of-funds"]
def settlementRole (r : EasyPayReading) (cs : List Clearance) (date : String) (p : Party) :
    SettlementRole :=
  let n := netPosition r cs date p
  if 0 < n then .settlementPayee n.toNat
  else if n < 0 then .remittancePayer (-n).toNat
  else .even

/-! ## Clearing totals -/

/-- One clearance listed in a clearing: its status after the clearing, how it
is settled, and the amounts settled and clawed back in this clearing, in minor
units. -/
structure ClearingLine where
  /-- The clearance ID. -/
  clearanceId : String
  /-- The clearance status after the clearing. -/
  status : ClearanceStatus
  /-- How the clearance is settled. -/
  method : ClearanceMethod
  /-- The amount settled in this clearing. -/
  settled : Nat
  /-- The amount clawed back in this clearing. -/
  clawedBack : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Who a clearing is sent to. -/
inductive ClearingTo
  /-- A settlement payee, which the Clearance Manager pays. -/
  | settlementPayee
  /-- A remittance payer, which pays the Clearance Manager. -/
  | remittancePayer
  deriving DecidableEq, Repr, Inhabited

/-- Whether a clearance status counts as settled in a clearing total. -/
def ClearanceStatus.countsSettled : ClearanceStatus → Bool
  | .fullySettled | .partiallySettled | .finalSettlement => true
  | _ => false

/-- Whether a clearing line enters the total of a clearing: every line in a
clearing to a settlement payee, and every line but EasyPay ones in a clearing
to a remittance payer. -/
def ClearingLine.counts (dest : ClearingTo) (l : ClearingLine) : Bool :=
  dest == .settlementPayee || l.method == .settlementPlan

/-- What a clearing line adds to a clearing total: the amount settled if its
status counts as settled, less the amount clawed back. -/
def ClearingLine.value (l : ClearingLine) : Int :=
  (if l.status.countsSettled then (l.settled : Int) else 0) - l.clawedBack

/-- EARS: When the Clearance Manager sends a clearing, the system shall make
its total, and the bank transfer for it, the amounts settled less the amounts
clawed back.

Story: As a settlement payee, I want each clearing's total to match the bank
transfer I receive, so that I can reconcile the transfer clearance by
clearance.

Acceptance criteria:

* ONE-806.1: When the Clearance Manager sends a clearing to a settlement
  payee, the system shall make its total the amounts settled for clearances
  marked Fully Settled, Partially Settled or Final Settlement, less the
  amounts clawed back.
* ONE-806.2: When the Clearance Manager sends a clearing to a remittance
  payer, the system shall list its EasyPay clearances and leave them out of
  the total.
* ONE-806.3: The system shall never make the total of a clearing to a
  settlement payee negative.

The bank transfer is the total; the model does not separate the two. -/
@[ears "ONE-806", source "swo-financial-and-accounting-systems"]
def clearingTotal (dest : ClearingTo) (lines : List ClearingLine) : Int :=
  ((lines.filter (·.counts dest)).map (·.value)).sum

/-! ## Short remittances -/

/-- What a remittance payer owes on one clearance: the clearance, its
settlement payee and the amount owed, in minor units. -/
structure Obligation where
  /-- The clearance ID. -/
  clearanceId : String
  /-- The settlement payee, by its code. -/
  payee : String
  /-- The amount owed. -/
  owed : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Which source page the Clearance Manager follows when a remittance payer
pays short and there is no credit line.  The two pages disagree, so the model
takes the answer as a parameter: a reading of the sources. -/
inductive AllocationReading
  /-- Remittance of Funds: split the funds across the settlement payees in
  proportion to what each is owed, then settle each payee's clearances oldest
  first. -/
  | proportional
  /-- Transfer of Funds: apply the funds to the payer's obligations in the
  order they were recorded, whatever the payee. -/
  | oldestFirst
  deriving DecidableEq, Repr, Inhabited

/-- Settle obligations in turn from budgets kept per key: each gets what is
left in its key's budget, up to what it owes.  The result lists the amount
settled on each obligation. -/
def fill {K : Type} [DecidableEq K] (key : Obligation → K) (budget : K → Nat) :
    List Obligation → List Nat
  | [] => []
  | o :: os =>
    min (budget (key o)) o.owed ::
      fill key (Function.update budget (key o) (budget (key o) - min (budget (key o)) o.owed)) os

/-- What the obligations owe one settlement payee. -/
def owedTo (os : List Obligation) (payee : String) : Nat :=
  ((os.filter fun o => o.payee = payee).map (·.owed)).sum

/-- What the obligations owe in all. -/
def totalOwed (os : List Obligation) : Nat := (os.map (·.owed)).sum

/-- A settlement payee's proportional share of a payment, rounded to a whole
minor unit. -/
def share (rd : Rounding) (paid : Nat) (os : List Obligation) (payee : String) : Nat :=
  rd.divide (paid * owedTo os payee) (totalOwed os)

/-- EARS: When a remittance payer pays short and the Clearance Manager has no
credit line, the system shall split what was paid across the payer's
clearances.

Story: As a settlement payee, I want a short remittance split by one known
rule, so that I can tell which of my clearances were settled.

Acceptance criteria:

* ONE-807.1: When a remittance payer pays short, the system shall settle no
  clearance for more than the payer owes on it.
* ONE-807.2: When a remittance payer pays short, the system shall settle a
  clearance to a settlement payee only after every older clearance to that
  payee is settled in full.
* ONE-807.3: Where the Clearance Manager follows the Remittance of Funds page,
  the system shall give each settlement payee its share of the payment in
  proportion to what it is owed, rounded to a minor unit and capped at what it
  is owed.
* ONE-807.4: Where the Clearance Manager follows the Transfer of Funds page,
  the system shall apply the payment to the payer's clearances in the order
  they were recorded, whatever the payee.
* ONE-807.5: When a remittance payer pays short, the system shall allocate the
  whole payment and no more.
* ONE-807.6: If a remittance payer pays short, then the system shall settle
  each clearance for the same amount whichever source page the Clearance
  Manager follows.

The clearances are listed in the order they were recorded, oldest first.  The
page followed is a reading of the sources ({name}`AllocationReading`), and so
is the rounding of a proportional share ({name}`Rounding`).  The result lists
the amount settled on each clearance. -/
@[ears "ONE-807", source "swo-remittance-of-funds swo-transfer-of-funds"]
def allocate (a : AllocationReading) (rd : Rounding) (paid : Nat) (os : List Obligation) :
    List Nat :=
  match a with
  | .proportional => fill (·.payee) (share rd paid os) os
  | .oldestFirst => fill (fun _ => ()) (fun _ => paid) os

/-- Obligations paired with the amounts settled on them are settled oldest
first under a key: an obligation not settled in full leaves nothing for any
later obligation with the same key. -/
def OldestFirst {K : Type} (key : Obligation → K) : List (Obligation × Nat) → Prop
  | [] => True
  | (o, a) :: rest => (a < o.owed → ∀ p ∈ rest, key p.1 = key o → p.2 = 0) ∧ OldestFirst key rest

end Rules.OneOrder.Accounting
