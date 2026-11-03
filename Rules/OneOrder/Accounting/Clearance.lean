import Rules.Core.Attributes
import Rules.Core.Money

/-!
# Clearances and their settlement

In Settlement with Orders the ORA sends each clearance to a Clearance Manager,
which accepts or rejects it and then settles it in clearings on remittance
dates.  The sources name the clearance statuses without a table of the moves
between them, and leave open how repeated clearances for one payment are
caught.  The model takes those answers as parameters.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core

/-- How a clearance is settled. -/
inductive ClearanceMethod
  /-- Through a settlement plan, such as an IATA settlement plan. -/
  | settlementPlan
  /-- Through IATA EasyPay; the EasyPay provider pays the ORA. -/
  | easyPay
  deriving DecidableEq, Repr, Inhabited

/-- A clearance the ORA sends to the Clearance Manager.  Amounts are in minor
units of one settlement currency. -/
structure Clearance where
  /-- The clearance ID. -/
  id : String
  /-- The order the payment commitment belongs to. -/
  orderId : String
  /-- The payment the commitment is for. -/
  paymentId : String
  /-- The party that pays, by its code. -/
  payer : String
  /-- The party that is paid, by its code. -/
  payee : String
  /-- The net clearance amount, in minor units. -/
  amount : Nat
  /-- How the clearance is settled. -/
  method : ClearanceMethod
  /-- The remittance date it is settled on, as an ISO date. -/
  remittanceDate : String
  /-- Whether the clearance data is signed by both parties. -/
  signed : Bool
  deriving DecidableEq, Repr, Inhabited

/-- The payment commitment a clearance comes from: its order ID and payment
ID. -/
def Clearance.commitment (c : Clearance) : String × String := (c.orderId, c.paymentId)

/-- Why the Clearance Manager rejects a clearance. -/
inductive ClearanceRejection
  /-- A clearance with the same clearance ID is already accepted. -/
  | repeatedId
  /-- A clearance for the same order and payment is already accepted. -/
  | repeatedPayment
  deriving DecidableEq, Repr, Inhabited

/-- Whether the Clearance Manager checks a clearance signed by both parties for
a repeated order and payment.  The source checks only the clearance ID of
signed data, so the model takes the answer as a parameter: a reading of the
sources. -/
structure RepeatReading where
  /-- Whether signed clearances are also checked for a repeated order and
  payment. -/
  checkSigned : Bool
  deriving DecidableEq, Repr

/-- EARS: When the ORA sends a clearance, the system shall accept it unless it
repeats a clearance already accepted, and record only accepted clearances.

Story: As an airline, I want the Clearance Manager to accept each payment's
clearance once, so that no payment is settled twice.

Acceptance criteria:

* ONE-803.1: If a clearance repeats the clearance ID of one already accepted,
  then the system shall reject it.
* ONE-803.2: If a clearance not signed by both parties repeats the order ID
  and payment ID of one already accepted, then the system shall reject it.
* ONE-803.3: When the Clearance Manager accepts a clearance, the system shall
  add it to the accepted clearances and change none of the others.
* ONE-803.4: The system shall accept at most one clearance for each pair of
  order ID and payment ID.

A payment split across two payment methods has a transaction per method, each
with its own payment ID, and so two clearances.  Whether a signed clearance is
checked for a repeated order and payment is a reading of the sources
({name}`RepeatReading`).  The result is the accepted clearances afterwards, or
the reason for the rejection. -/
@[ears "ONE-803", source "swo-clearance-manager"]
def submit (r : RepeatReading) (accepted : List Clearance) (c : Clearance) :
    Except ClearanceRejection (List Clearance) :=
  if accepted.any (·.id == c.id) then .error .repeatedId
  else if (!c.signed || r.checkSigned) && accepted.any (·.commitment == c.commitment) then
    .error .repeatedPayment
  else .ok (accepted ++ [c])

/-- The accepted clearances after the ORA sends clearances one after another.
A rejected clearance leaves them as they were. -/
def submitAll (r : RepeatReading) (accepted : List Clearance) : List Clearance → List Clearance
  | [] => accepted
  | c :: cs =>
    match submit r accepted c with
    | .ok acc => submitAll r acc cs
    | .error _ => submitAll r accepted cs

/-- The status of an accepted clearance.  The names follow the Settlement with
Orders code list. -/
inductive ClearanceStatus
  /-- Accepted by the Clearance Manager and not yet in a clearing. -/
  | accepted
  /-- Cancelled by the ORA; it is never settled. -/
  | cancelled
  /-- In a clearing that paid nothing toward it. -/
  | notSettled
  /-- Part of it is settled. -/
  | partiallySettled
  /-- Settled in full in its first clearing. -/
  | fullySettled
  /-- Settled in full in a later clearing. -/
  | finalSettlement
  /-- Settled money was taken back from the payee. -/
  | clawedBack
  /-- The Clearance Manager could not collect the rest and wrote it off. -/
  | writtenOff
  deriving DecidableEq, Repr, Inhabited

/-- A clearance's status and its amounts, in minor units: the agreed net
clearance amount, everything settled across clearings, everything clawed
back, what is still unsettled and what was written off. -/
structure SettlementRecord where
  /-- The clearance status. -/
  status : ClearanceStatus
  /-- The net clearance amount agreed when the clearance was accepted. -/
  agreed : Nat
  /-- Everything settled toward it across clearings. -/
  settled : Nat
  /-- Everything clawed back from the payee. -/
  clawedBack : Nat
  /-- What is still unsettled. -/
  unsettled : Nat
  /-- What was written off. -/
  writtenOff : Nat
  deriving DecidableEq, Repr, Inhabited

/-- A clearance as the Clearance Manager accepts it: nothing settled yet. -/
def SettlementRecord.new (agreed : Nat) : SettlementRecord :=
  { status := .accepted, agreed, settled := 0, clawedBack := 0, unsettled := agreed, writtenOff := 0 }

/-- Something that happens to an accepted clearance. -/
inductive SettlementEvent
  /-- The ORA cancels it. -/
  | cancel
  /-- A clearing pays this amount toward it; zero if it pays nothing. -/
  | settle (amount : Nat)
  /-- The Clearance Manager takes back this amount from the payee. -/
  | clawBack (amount : Nat)
  /-- The Clearance Manager writes off what it cannot collect. -/
  | writeOff
  deriving DecidableEq, Repr, Inhabited

/-- The moves between clearance statuses that the sources leave undecided.
The code list names the statuses but gives no table of moves and no final
statuses, so the model takes the answers as a parameter: a reading of the
sources. -/
structure SettlementReading where
  /-- Whether a clawed-back amount counts as unsettled again, so that a later
  clearing can settle it once the Clearance Manager collects the funds. -/
  clawBackReopens : Bool
  /-- Whether a clearance in Final Settlement can be clawed back. -/
  clawBackFinal : Bool
  deriving DecidableEq, Repr

/-- Whether a clearing can pay toward a clearance in a status. -/
def ClearanceStatus.settleable (r : SettlementReading) : ClearanceStatus → Bool
  | .accepted | .notSettled | .partiallySettled => true
  | .clawedBack => r.clawBackReopens
  | _ => false

/-- Whether money settled on a clearance in a status can be clawed back. -/
def ClearanceStatus.clawable (r : SettlementReading) : ClearanceStatus → Bool
  | .fullySettled | .partiallySettled => true
  | .finalSettlement => r.clawBackFinal
  | _ => false

/-- Whether a clearance in a status can be written off. -/
def ClearanceStatus.writable : ClearanceStatus → Bool
  | .notSettled | .partiallySettled | .clawedBack => true
  | _ => false

/-- The status after a clearing pays an amount toward a clearance: fully
settled when it pays all that is unsettled, partially settled when it pays
part, and not settled when it pays nothing toward an accepted clearance. -/
def settledStatus (before : ClearanceStatus) (paid unsettled : Nat) : ClearanceStatus :=
  if paid = unsettled then (if before = .accepted then .fullySettled else .finalSettlement)
  else if paid = 0 then (if before = .accepted then .notSettled else before)
  else .partiallySettled

/-- EARS: When the ORA cancels a clearance or the Clearance Manager settles,
claws back or writes off money on it, the system shall move the clearance's
status and amounts as the clearance statuses describe.

Story: As an airline, I want each clearance's status to say how much of it is
settled, so that I can match every clearing to what I am owed.

Acceptance criteria:

* ONE-804.1: When the ORA cancels an Accepted clearance, the system shall mark
  it Cancelled and refuse every clearing for it afterwards.
* ONE-804.2: When a clearing pays all that is unsettled on a clearance, the
  system shall mark it Fully Settled if it was Accepted and Final Settlement
  otherwise.
* ONE-804.3: When a clearing pays part of what is unsettled on a clearance, the
  system shall mark it Partially Settled and settle no more than the amount
  still unsettled.
* ONE-804.4: When the Clearance Manager writes off a clearance, the system
  shall remove exactly the amount still unsettled.
* ONE-804.5: The system shall keep the amounts settled on a clearance, less
  those clawed back, plus the amount unsettled and the amount written off,
  equal to its agreed amount.

A clearing that pays nothing toward an Accepted clearance marks it Not
Settled.  Whether a clawed-back clearance can be settled again, and whether
Final Settlement can be clawed back, are a reading of the sources
({name}`SettlementReading`).  The EasyPay statuses Funds Collected and Funds
Partially Collected are not modelled.  The result is the record afterwards, or
{lean}`none` when the event is refused. -/
@[ears "ONE-804", source "swo-codeset-list swo-remittance-of-funds"]
def settleStep (r : SettlementReading) (c : SettlementRecord) :
    SettlementEvent → Option SettlementRecord
  | .cancel => if c.status = .accepted then some { c with status := .cancelled } else none
  | .settle x =>
    if c.status.settleable r then
      some { c with status := settledStatus c.status (min x c.unsettled) c.unsettled,
                    settled := c.settled + min x c.unsettled,
                    unsettled := c.unsettled - min x c.unsettled }
    else none
  | .clawBack x =>
    if c.status.clawable r then
      some { c with status := .clawedBack,
                    clawedBack := c.clawedBack + min x (c.settled - c.clawedBack),
                    unsettled := if r.clawBackReopens then c.unsettled + min x (c.settled - c.clawedBack)
                                 else c.unsettled }
    else none
  | .writeOff =>
    if c.status.writable then
      some { c with status := .writtenOff, writtenOff := c.writtenOff + c.unsettled, unsettled := 0 }
    else none

/-- A clearance's record after a sequence of events, each applied in turn.  An
event the rule refuses leaves the record as it was. -/
def settleRun (r : SettlementReading) (c : SettlementRecord) : List SettlementEvent → SettlementRecord
  | [] => c
  | e :: es => settleRun r ((settleStep r c e).getD c) es

/-- Every part of a clearance's agreed amount is settled and kept, still
unsettled, or written off: the amounts settled less those clawed back, plus
the amount unsettled and the amount written off, equal the agreed amount. -/
def SettlementRecord.Accounted (c : SettlementRecord) : Prop :=
  c.clawedBack ≤ c.settled ∧
    (c.settled : Int) - c.clawedBack + c.unsettled + c.writtenOff = c.agreed

end Rules.OneOrder.Accounting
