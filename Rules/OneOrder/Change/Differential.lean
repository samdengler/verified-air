import Rules.Core.Attributes
import Rules.Core.Money
import Rules.OneOrder.Order

/-!
# Price differentials of changes and cancellations

When a seller asks to change or cancel order items in a paid order, the airline
answers with an offer that carries a price differential: the old price, the
new price, the penalty, the forfeited amount, what the customer pays and what
the airline returns.  The ONE Order implementation guide shows these amounts
in worked examples and never states the formula that links them.  The model
reads the formula from the worked examples, states only the two non-negative
due amounts (the guide's sign for the total is inconsistent), and takes the
case the guide has no example of as a parameter.
-/

namespace Rules.OneOrder.Change

open Rules.Core

/-- How the penalty of a change or cancellation is charged.  The guide allows
both. -/
inductive PenaltyHandling
  /-- Added to what the airline collects, or deducted from what it returns. -/
  | netted
  /-- Charged on its own, next to the settlement of the price difference. -/
  | separate
  deriving DecidableEq, Repr, Inhabited

/-- How the airline settles money it owes after a change or cancellation. -/
inductive Settlement
  /-- Refunded to the payer, by default to the original form of payment. -/
  | refund
  /-- Kept by the airline as a Value Store order item in the same order. -/
  | valueStore
  /-- Held on the cancelled item for the seller to use again, at the seller's
  request.  The airline works out the amount later. -/
  | respend
  deriving DecidableEq, Repr, Inhabited

/-- What happens to the part of a penalty above the refundable value of the
items replaced or cancelled.  The guide has no example of a penalty that
large, so the model takes the answer as a parameter: a reading of the guide.
A guarantee about the amounts due counts as proven only when it holds under
both readings. -/
inductive ExcessPenalty
  /-- The airline collects the whole penalty, so a cancellation can leave the
  customer owing money. -/
  | collect
  /-- The airline charges no more than the refundable value and waives the
  rest. -/
  | waive
  deriving DecidableEq, Repr, Inhabited

/-- A change or cancellation for the airline to price: the items it replaces
or cancels, the items it adds, and the airline's terms.  A cancellation is a
change whose new price is zero. -/
structure ChangeQuote where
  /-- The price of the order items replaced or cancelled. -/
  oldPrice : Money
  /-- The price of the new order items; zero for a cancellation. -/
  newPrice : Money
  /-- The penalty for the change or cancellation. -/
  penalty : Money
  /-- The part of the old price the airline keeps and never returns, such as a
  non-refundable tax. -/
  forfeited : Money
  /-- Whether the penalty is netted or charged separately. -/
  handling : PenaltyHandling
  /-- How the airline settles money it owes. -/
  settlement : Settlement
  deriving DecidableEq, Repr, Inhabited

/-- The type code that names the outcome of a price differential.  The names
are the ONE Order codes. -/
inductive DifferentialType
  /-- Nothing is due either way.  ONE Order code EvenExchange. -/
  | evenExchange
  /-- The customer pays more.  ONE Order code AddCol. -/
  | addCol
  /-- The airline refunds money.  ONE Order code Refund. -/
  | refund
  /-- The airline keeps what it owes in a value store.  ONE Order code
  Residual. -/
  | residual
  /-- The value stays on the cancelled item for later use.  ONE Order code
  Reusable. -/
  | reusable
  /-- The customer pays a penalty and the airline refunds money.  ONE Order
  code AddColAndRefund. -/
  | addColAndRefund
  /-- The customer pays a penalty and the airline keeps what it owes in a
  value store.  ONE Order code AddColAndResidual. -/
  | addColAndResidual
  deriving DecidableEq, Repr, Inhabited

/-- Whether a type code says the customer pays the airline. -/
def DifferentialType.collects : DifferentialType → Bool
  | .addCol | .addColAndRefund | .addColAndResidual => true
  | _ => false

/-- Whether a type code says the airline pays or stores money for the
customer now. -/
def DifferentialType.pays : DifferentialType → Bool
  | .refund | .residual | .addColAndRefund | .addColAndResidual => true
  | _ => false

/-- The price differential of a change or cancellation offer.  It corresponds
to the ONE Order price differential. -/
structure PriceDifferential where
  /-- The price of the order items replaced or cancelled. -/
  oldPrice : Money
  /-- The price of the new order items. -/
  newPrice : Money
  /-- The penalty for the change or cancellation. -/
  penalty : Money
  /-- The part of the old price the airline keeps. -/
  forfeited : Money
  /-- What the customer pays the airline. -/
  dueToAirline : Money
  /-- What the airline returns or stores for the customer. -/
  dueByAirline : Money
  /-- The type code. -/
  type : DifferentialType
  deriving DecidableEq, Repr, Inhabited

/-- Why a change or cancellation could not be priced. -/
inductive QuoteRejection
  /-- The amounts are not all in one currency. -/
  | mixedCurrency
  deriving DecidableEq, Repr, Inhabited

/-- The refundable value of the items replaced or cancelled: the old price
less the forfeited amount. -/
def ChangeQuote.refundable (q : ChangeQuote) : Nat := q.oldPrice.amount - q.forfeited.amount

/-- The price difference before any penalty, in minor units: the new price,
less the old price, plus the forfeited amount.  It is negative when the new
items cost less than the refundable value of the old ones. -/
def ChangeQuote.difference (q : ChangeQuote) : Int :=
  (q.newPrice.amount : Int) - q.oldPrice.amount + q.forfeited.amount

/-- The penalty the airline charges under a reading of the guide: the whole
penalty, or no more than the refundable value. -/
def ExcessPenalty.charged (r : ExcessPenalty) (q : ChangeQuote) : Nat :=
  match r with
  | .collect => q.penalty.amount
  | .waive => min q.penalty.amount q.refundable

/-- The two amounts a change or cancellation leaves due, in minor units. -/
structure DueAmounts where
  /-- What the customer pays the airline. -/
  toAirline : Nat
  /-- What the airline returns or stores for the customer. -/
  byAirline : Nat
  deriving DecidableEq, Repr, Inhabited

/-- What the customer pays less what the airline returns. -/
def DueAmounts.net (d : DueAmounts) : Int := (d.toAirline : Int) - d.byAirline

/-- EARS: When a change or cancellation carries a penalty, the system shall
either net the penalty against the price difference or charge it separately.

Story: As a customer, I want a penalty to cost me the same whether it is
deducted from what I get back or charged on its own, so that the way the
airline collects it does not change what I pay.

Acceptance criteria:

* ONE-202.1: Where the penalty is netted, the system shall add the penalty
  charged to the price difference and state the result as a single amount, due
  either to or by the airline.
* ONE-202.2: Where the penalty is charged separately, the system shall add the
  penalty charged to the amount due to the airline and settle the price
  difference on its own.
* ONE-202.3: The system shall give the customer the same net amount whether the
  penalty is netted or charged separately.
* ONE-202.4: If the penalty on a cancellation is larger than the refundable
  value of the cancelled items, then the system shall not leave the customer
  owing the airline money.

The price difference is the new price, less the old price, plus the forfeited
amount.  The worked examples fit this formula, though the guide does not state
it.  The penalty charged is the whole penalty, except when the penalty is
larger than the refundable value: then it depends on the reading of the guide
({name}`ExcessPenalty`). -/
@[ears "ONE-202", source "easd-cancellation-of-order-items easd-price-differentials"]
def dueAmounts (r : ExcessPenalty) (q : ChangeQuote) : DueAmounts :=
  match q.handling with
  | .netted =>
    let n := q.difference + r.charged q
    ⟨n.toNat, (-n).toNat⟩
  | .separate => ⟨r.charged q + q.difference.toNat, (-q.difference).toNat⟩

/-- The type code for due amounts and a form of settlement. -/
def typeOf (s : Settlement) (d : DueAmounts) : DifferentialType :=
  if s = .respend then .reusable
  else if d.toAirline = 0 then
    if d.byAirline = 0 then .evenExchange
    else if s = .refund then .refund else .residual
  else if d.byAirline = 0 then .addCol
  else if s = .refund then .addColAndRefund else .addColAndResidual

/-- The due amounts a price differential states: both zero when the seller
asks to keep the value for later use, and otherwise {name}`dueAmounts`. -/
def statedDue (r : ExcessPenalty) (q : ChangeQuote) : DueAmounts :=
  if q.settlement = .respend then ⟨0, 0⟩ else dueAmounts r q

/-- EARS: When the airline prices a change or cancellation of order items, the
system shall state the amount due to the airline, the amount due by the
airline and a type code that names the outcome.

Story: As a seller, I want every change or cancellation offer to state what the
customer pays and what the airline returns, so that I can settle the change
without working the amounts out myself.

Acceptance criteria:

* ONE-201.1: If the prices, penalty and forfeited amount of a change are not
  all in one currency, then the system shall reject the change unpriced.
* ONE-201.2: The system shall give a price differential a type code that names
  a collection exactly when an amount is due to the airline.
* ONE-201.3: The system shall give a price differential a type code that names
  a refund or a value store exactly when an amount is due by the airline.
* ONE-201.4: When the seller asks to keep the value of cancelled items for
  later use, the system shall type the differential Reusable and set both due
  amounts to zero.
* ONE-201.5: When the airline prices a change or cancellation, the system shall
  make the amount due to the airline less the amount due by the airline equal
  the new price, less the old price, plus the penalty, plus the forfeited
  amount.

The due amounts come from {name}`dueAmounts`, except for a request to keep the
value for later use, where the guide shows both amounts as zero
({name}`statedDue`). -/
@[ears "ONE-201",
  source "easd-modification-of-an-order easd-price-differentials easd-reusable-amount"]
def priceDifferential (r : ExcessPenalty) (q : ChangeQuote) :
    Except QuoteRejection PriceDifferential :=
  if q.newPrice.currency ≠ q.oldPrice.currency ∨ q.penalty.currency ≠ q.oldPrice.currency ∨
      q.forfeited.currency ≠ q.oldPrice.currency then
    .error .mixedCurrency
  else
    .ok { oldPrice := q.oldPrice, newPrice := q.newPrice, penalty := q.penalty,
          forfeited := q.forfeited,
          dueToAirline := ⟨(statedDue r q).toAirline, q.oldPrice.currency⟩,
          dueByAirline := ⟨(statedDue r q).byAirline, q.oldPrice.currency⟩,
          type := typeOf q.settlement (statedDue r q) }

end Rules.OneOrder.Change
