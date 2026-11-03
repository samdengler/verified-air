import Rules.Core.Attributes
import Rules.OneOrder.Service
import Rules.OneOrder.Delivery.Moves

/-!
# Billing and the airline's books

What a service provider may bill the ORA, and how the ORA's accounting treats
the money paid for each service: held as a liability until the service
reaches a final delivery status, then recognized as revenue, refunded or kept.
The sources tie billing and revenue to delivery without saying which final
statuses count, so the model takes the answers as parameters.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core
open Rules.OneOrder.Delivery (isFinal)

/-! ## Billing by service providers -/

/-- A service as its provider bills for it: the service, the provider that
delivers it, and its settlement value, the amount that provider may bill the
ORA, in minor units. -/
structure ProvidedService where
  /-- The service, with its delivery status. -/
  service : Service
  /-- The provider that delivers it, by its code. -/
  provider : String
  /-- The settlement value: what the provider may bill the ORA for it. -/
  settlementValue : Nat
  deriving DecidableEq, Repr, Inhabited

/-- Which delivery statuses count as delivered or consumed for billing.
Resolution 797 says delivered or consumed without naming statuses.  The
settled part: a delivered service counts, and a service that is not yet
delivered or was cancelled does not.  The model takes the answer for the
others, such as NOT CLAIMED and EXPIRED, as a parameter: a reading of the
sources. -/
structure ConsumptionReading where
  /-- Whether a service in a delivery status counts as delivered or consumed. -/
  consumed : DeliveryStatus → Bool
  /-- A delivered service counts. -/
  delivered : consumed .delivered = true
  /-- A service not yet delivered, or cancelled, does not count. -/
  notYet : ∀ s, s = .requested ∨ s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver ∨
    s = .removed ∨ s = .removedHoldValue → consumed s = false

/-- A bill a service provider sends the ORA for one service. -/
structure Bill where
  /-- The provider that bills, by its code. -/
  provider : String
  /-- The service billed for. -/
  serviceId : String
  /-- The amount billed, in minor units. -/
  amount : Nat
  deriving DecidableEq, Repr, Inhabited

/-- What has been billed for a service so far. -/
def billedFor (bills : List Bill) (serviceId : String) : Nat :=
  ((bills.filter (·.serviceId == serviceId)).map (·.amount)).sum

/-- EARS: If a service provider bills the ORA for a service before it has been
delivered or consumed, then the system shall refuse the bill unless a
bilateral agreement allows earlier billing.

Story: As an airline, I want providers to bill me only for what they have
delivered, so that I never pay a provider for a service the customer did not
receive.

Acceptance criteria:

* ONE-808.1: If a service provider bills for a service that has not been
  delivered or consumed, then the system shall refuse the bill unless a
  bilateral agreement with that provider allows earlier billing.
* ONE-808.2: If a service provider bills for a service another provider
  delivers, then the system shall refuse the bill.
* ONE-808.3: The system shall keep the total billed for each service within
  its settlement value, and at zero while it has not been delivered or
  consumed unless a bilateral agreement allows earlier billing.
* ONE-808.4: When a provider bills for a delivered service within what is
  left of its settlement value, the system shall accept the bill.

The bills are checked against the services' delivery statuses when they
arrive.  Which statuses count as delivered or consumed is a reading of the
sources ({name}`ConsumptionReading`).  The result says whether the bill is
accepted. -/
@[ears "ONE-808", source "iata-r797"]
def acceptBill (c : ConsumptionReading) (agreement : String → Bool) (services : List ProvidedService)
    (billed : List Bill) (b : Bill) : Bool :=
  match services.find? (·.service.id == b.serviceId) with
  | none => false
  | some s =>
    s.provider == b.provider && (c.consumed s.service.delivery || agreement b.provider) &&
      decide (billedFor billed b.serviceId + b.amount ≤ s.settlementValue)

/-- The bills accepted after providers send bills one after another. -/
def billAll (c : ConsumptionReading) (agreement : String → Bool) (services : List ProvidedService)
    (billed : List Bill) : List Bill → List Bill
  | [] => billed
  | b :: bs =>
    billAll c agreement services (if acceptBill c agreement services billed b then billed ++ [b] else billed) bs

/-! ## Revenue and liability -/

/-- What accounting does with the amount paid for a service once it reaches a
final delivery status. -/
inductive Treatment
  /-- Recognize it as revenue. -/
  | earn
  /-- Refund it and release the liability. -/
  | refund
  /-- Keep it as a liability. -/
  | keep
  deriving DecidableEq, Repr, Inhabited

/-- What each final delivery status does with the amount paid for a service.
The sources tie revenue to the final delivery status without saying which
final statuses earn it, except that a delivered service does.  The model takes
the answer for the others, and for a penalty reported at cancellation, as a
parameter: a reading of the sources. -/
structure RevenueReading where
  /-- The treatment of the amount paid once a service reaches a final status
  other than REMOVED. -/
  treat : DeliveryStatus → Treatment
  /-- A delivered service earns revenue. -/
  delivered : treat .delivered = .earn
  /-- Whether a penalty reported at cancellation is recognized as revenue at
  once.  If not, it stays a liability. -/
  penaltyEarned : Bool

/-- The money on one service as accounting sees it, in minor units: its
delivery status, what was paid for it, and what was refunded, charged as a
penalty or forfeited when it ended. -/
structure ServiceBooks where
  /-- The service reference. -/
  id : String
  /-- The delivery status. -/
  delivery : DeliveryStatus
  /-- Everything paid for the service. -/
  paid : Nat
  /-- Everything refunded for it. -/
  refunded : Nat
  /-- The penalty charged when it was cancelled. -/
  penalty : Nat
  /-- The amount forfeited when it was cancelled, such as a non-refundable tax. -/
  forfeited : Nat
  deriving DecidableEq, Repr, Inhabited

/-- A service's books before anything is paid. -/
def ServiceBooks.new (id : String) : ServiceBooks :=
  { id, delivery := .confirmed, paid := 0, refunded := 0, penalty := 0, forfeited := 0 }

/-- Something accounting is told about a service. -/
inductive BookEvent
  /-- A payment for the service succeeds. -/
  | pay (amount : Nat)
  /-- The service reaches a final delivery status other than REMOVED. -/
  | finish (status : DeliveryStatus)
  /-- The service is cancelled and removed; the amount paid for it is split
  into a refund, a penalty and a forfeited amount. -/
  | cancel (refund penalty forfeited : Nat)
  deriving DecidableEq, Repr, Inhabited

/-- What accounting does with a cancellation whose refund, penalty and
forfeited amount do not add up to the amount paid for the service.  The
sources send the three amounts to accounting without saying they must add up,
so the model takes the answer as a parameter: a reading of the sources. -/
inductive CancelCheck
  /-- The airline checks the amounts and refuses a report that does not add
  up, as the worked examples would. -/
  | checked
  /-- Accounting records the amounts as the airline sends them. -/
  | asSent
  deriving DecidableEq, Repr, Inhabited

/-- The part of the amount paid for a service held as a liability. -/
def ServiceBooks.liability (r : RevenueReading) (b : ServiceBooks) : Nat :=
  if !isFinal b.delivery then b.paid
  else if b.delivery = .removed then (if r.penaltyEarned then 0 else b.penalty)
  else if r.treat b.delivery = .keep then b.paid
  else 0

/-- The part of the amount paid for a service recognized as revenue. -/
def ServiceBooks.revenue (r : RevenueReading) (b : ServiceBooks) : Nat :=
  if !isFinal b.delivery then 0
  else if b.delivery = .removed then (if r.penaltyEarned then b.penalty else 0)
  else if r.treat b.delivery = .earn then b.paid
  else 0

/-- EARS: The system shall hold the amount paid for a service as a liability
until the service reaches a final delivery status, and only then recognize it
as revenue.

Story: As a revenue accountant, I want revenue recognized only when a service
reaches a final status, and every payment accounted for, so that the books of
each order balance.

Acceptance criteria:

* ONE-809.1: While a paid service has not reached a final delivery status,
  the system shall hold the amount paid for it as a liability and recognize
  none of it as revenue.
* ONE-809.2: When a paid service is DELIVERED, the system shall recognize the
  amount paid for it as revenue.
* ONE-809.3: When a paid service reaches a final delivery status, the system
  shall hold none of the amount paid for it as a liability.
* ONE-809.4: The system shall keep each order's payments equal to its refunds,
  plus the amount held as liability, plus the revenue recognized, plus the
  forfeited amounts.
* ONE-809.5: The system shall never refund more for an order than was paid
  for it.
* ONE-809.6: Where the airline checks the amounts of a cancellation, the
  system shall refuse a report whose refund, penalty and forfeited amount do
  not add up to the amount paid for the service.

The final statuses are those of ONE-103 ({name}`isFinal`).  Whether a final
status other than DELIVERED earns revenue, refunds the amount paid or keeps it
as a liability, and whether a penalty is recognized at cancellation, are a
reading of the sources ({name}`RevenueReading`).  Payments for a
service in a final status are refused, and a service is cancelled only before
it reaches one.  The sources send payments, refunds, penalties and forfeited
amounts to accounting but state no balance, and do not say whether the
amounts of a cancellation must add up to what was paid; that is a reading too
({name}`CancelCheck`).  The result is the books afterwards, or {lean}`none`
when the event is refused. -/
@[ears "ONE-809", source "oa-service-consumption oa-paid-cancellation oa-partial-refund-penalty"]
def bookStep (r : RevenueReading) (k : CancelCheck) (b : ServiceBooks) :
    BookEvent → Option ServiceBooks
  | .pay x => if isFinal b.delivery then none else some { b with paid := b.paid + x }
  | .finish s =>
    if isFinal b.delivery || !isFinal s || s == .removed then none
    else some { b with delivery := s, refunded := if r.treat s = .refund then b.paid else b.refunded }
  | .cancel rf pen forf =>
    if isFinal b.delivery || (k == .checked && rf + pen + forf != b.paid) then none
    else some { b with delivery := .removed, refunded := rf, penalty := pen, forfeited := forf }

/-- An order's books: the books of each of its services. -/
abbrev OrderBooks := List ServiceBooks

/-- The order's books after an event for one of its services.  A refused event
leaves them as they were. -/
def OrderBooks.apply (r : RevenueReading) (k : CancelCheck) (o : OrderBooks) (serviceId : String)
    (e : BookEvent) : OrderBooks :=
  o.map fun b => if b.id = serviceId then (bookStep r k b e).getD b else b

/-- The order's books after a sequence of events, each for one service. -/
def OrderBooks.run (r : RevenueReading) (k : CancelCheck) (o : OrderBooks) :
    List (String × BookEvent) → OrderBooks
  | [] => o
  | (id, e) :: es => OrderBooks.run r k (o.apply r k id e) es

/-- The order's payments, refunds, liability, revenue and forfeited amounts:
the totals over its services. -/
structure OrderTotals where
  /-- Everything paid. -/
  paid : Nat
  /-- Everything refunded. -/
  refunded : Nat
  /-- The amount held as liability. -/
  liability : Nat
  /-- The revenue recognized. -/
  revenue : Nat
  /-- The amounts forfeited. -/
  forfeited : Nat
  deriving DecidableEq, Repr, Inhabited

/-- An order's totals balance: its payments equal its refunds, plus the
amount held as liability, plus the revenue recognized, plus the forfeited
amounts. -/
def OrderTotals.Balanced (t : OrderTotals) : Prop :=
  t.paid = t.refunded + t.liability + t.revenue + t.forfeited

/-- A service's books balance: what was paid for it equals what was refunded,
plus what is held as liability, plus the revenue recognized, plus what was
forfeited. -/
def ServiceBooks.Balanced (r : RevenueReading) (b : ServiceBooks) : Prop :=
  b.paid = b.refunded + b.liability r + b.revenue r + b.forfeited

/-- Total an order's books under a reading. -/
def OrderBooks.totals (r : RevenueReading) (o : OrderBooks) : OrderTotals where
  paid := (o.map (·.paid)).sum
  refunded := (o.map (·.refunded)).sum
  liability := (o.map (·.liability r)).sum
  revenue := (o.map (·.revenue r)).sum
  forfeited := (o.map (·.forfeited)).sum

end Rules.OneOrder.Accounting
