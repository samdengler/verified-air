import Rules.Core.Attributes
import Rules.OneOrder.Change.Differential

/-!
# Order balance after a change

The money recorded on an order: what the customer paid, what the airline
returned, and the penalties and forfeited amounts.  Settling a change or
cancellation offer adds to each.  The guide asks that a seller can reconcile
an order's values against its payments and refunds, and gives no equation.
The model states the equation the worked examples fit and checks whether a
change keeps it.
-/

namespace Rules.OneOrder.Change

open Rules.Core

/-- The money recorded on an order, in minor units of the order's currency. -/
structure Ledger where
  /-- Everything the customer has paid. -/
  paid : Nat
  /-- Everything the airline has returned. -/
  refunded : Nat
  /-- Every penalty recorded on the order. -/
  penalties : Nat
  /-- Every forfeited amount recorded on the order. -/
  forfeited : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The total price of an order's live items: those active under a reading of
the guide, which counts value store and reusable items at their price. -/
def liveValue (v : ValueReading) (o : Order) : Nat :=
  ((o.items.filter (·.isActive v)).map (·.price.amount)).sum

/-- An order is balanced when its payments less its refunds equal the price
of its live items plus the recorded penalties and forfeited amounts. -/
def Ledger.Balanced (v : ValueReading) (o : Order) (l : Ledger) : Prop :=
  (l.paid : Int) - l.refunded = liveValue v o + l.penalties + l.forfeited

/-- EARS: When a seller settles a change or cancellation offer, the system
shall record on the order what the customer paid, what the airline returned,
the penalty and the forfeited amount.

Story: As a revenue accountant, I want every settled change recorded on the
order, so that I can reconcile the order's items against its payments and
refunds.

Acceptance criteria:

* ONE-205.1: When a seller settles a change or cancellation offer, the system
  shall add the amount due to the airline to the order's payments and the
  amount due by the airline to its refunds.
* ONE-205.2: When a seller settles a change or cancellation offer, the system
  shall add its penalty and forfeited amount to the totals recorded on the
  order and lower no total recorded before.
* ONE-205.3: When a seller settles a paid change of an order item, the system
  shall keep the order's payments less refunds equal to the price of its live
  items plus the recorded penalties and forfeited amounts.

The penalties and forfeited amounts are kept at order level, as the guide
records them from release 24.1, so they stay when the item they came from is
replaced.  The model keeps totals; the guide's individual records with their
links to order items are not modelled. -/
@[ears "ONE-205", source "armi-ordpen"]
def settle (l : Ledger) (d : PriceDifferential) : Ledger :=
  { paid := l.paid + d.dueToAirline.amount, refunded := l.refunded + d.dueByAirline.amount,
    penalties := l.penalties + d.penalty.amount, forfeited := l.forfeited + d.forfeited.amount }

end Rules.OneOrder.Change
