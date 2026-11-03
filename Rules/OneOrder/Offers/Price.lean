import Rules.Core.Attributes
import Rules.Core.Money

/-!
# Prices from their parts

A price in an offer is stated with its parts: an amount before discounts and
the discount, surcharges, fees, a tax summary, and consumption taxes such as
VAT or HST.  The guide names the parts and shows examples, and states no
formula.  The model adds the parts up, and takes as a parameter the one choice
the examples leave open: whether the consumption tax not included in the price
comes from the tax lines or from the stated total of excluded tax.
-/

namespace Rules.OneOrder.Offers

open Rules.Core

/-- A tax, fee or charge on a price, with its own refund flag. -/
structure Charge where
  /-- The code of the tax, fee or charge, such as an airport tax code. -/
  code : String
  /-- The amount. -/
  amount : Money
  /-- Whether the amount is refunded when the item is cancelled unused. -/
  refundable : Bool
  deriving DecidableEq, Repr, Inhabited

/-- One consumption tax line, such as VAT or HST: the taxable base, the tax
charged on it, and whether the tax is already included in the price. -/
structure ConsumptionTax where
  /-- The code of the tax, such as HST. -/
  code : String
  /-- The amount the tax is charged on. -/
  taxable : Money
  /-- The tax. -/
  tax : Money
  /-- Whether the tax is already included in the price. -/
  included : Bool
  deriving DecidableEq, Repr, Inhabited

/-- A price stated with its parts.  It corresponds to a ONE Order price with
its tax summary and consumption tax detail. -/
structure PriceParts where
  /-- The amount before discounts. -/
  beforeDiscount : Money
  /-- The discount, as an amount. -/
  discount : Money
  /-- The surcharges. -/
  surcharges : List Money
  /-- The fees, each with its refund flag. -/
  fees : List Charge
  /-- The entries of the tax summary: taxes, fees and charges, each with its
  refund flag. -/
  taxes : List Charge
  /-- The consumption tax lines. -/
  consumption : List ConsumptionTax
  /-- The stated total of consumption tax not included in the price. -/
  excludedTax : Money
  deriving DecidableEq, Repr, Inhabited

/-- Where the consumption tax not included in a price comes from.  The guide's
examples state both the tax lines and a total of excluded tax, and one example
marks lines as not included while stating a total of zero, so the model takes
the answer as a parameter: a reading of the guide. -/
inductive ExcludedTax
  /-- The tax of every line marked as not included. -/
  | lines
  /-- The stated total of excluded tax. -/
  | statedTotal
  deriving DecidableEq, Repr, Inhabited

/-- The amounts a price works out to. -/
structure PriceTotal where
  /-- The base amount: the amount before discounts less the discount. -/
  base : Money
  /-- The total of the tax summary. -/
  taxTotal : Money
  /-- The consumption tax added because it is not included in the price. -/
  excludedTax : Money
  /-- The total price. -/
  total : Money
  deriving DecidableEq, Repr, Inhabited

/-- Why a price could not be totalled. -/
inductive PriceRejection
  /-- The amounts are not all in one currency. -/
  | mixedCurrency
  /-- The discount is larger than the amount before discounts. -/
  | discountAboveBase
  deriving DecidableEq, Repr, Inhabited

/-- The sum of some amounts, in minor units, whatever their currencies. -/
def sumOf (l : List Money) : Nat := (l.map (·.amount)).sum

/-- Every amount stated in a price. -/
def PriceParts.amounts (p : PriceParts) : List Money :=
  [p.beforeDiscount, p.discount, p.excludedTax] ++ p.surcharges ++ p.fees.map (·.amount) ++
    p.taxes.map (·.amount) ++ p.consumption.flatMap (fun c => [c.taxable, c.tax])

/-- The tax of the consumption tax lines marked as not included, in minor
units. -/
def PriceParts.lineExcluded (p : PriceParts) : Nat :=
  sumOf ((p.consumption.filter (!·.included)).map (·.tax))

/-- The consumption tax not included in the price, in minor units, under a
reading of the guide. -/
def ExcludedTax.amount (x : ExcludedTax) (p : PriceParts) : Nat :=
  match x with
  | .lines => p.lineExcluded
  | .statedTotal => p.excludedTax.amount

/-- The amounts a price works out to, in the currency of its amount before
discounts. -/
def PriceTotal.of (x : ExcludedTax) (p : PriceParts) : PriceTotal :=
  let c := p.beforeDiscount.currency
  let base := p.beforeDiscount.amount - p.discount.amount
  let taxTotal := sumOf (p.taxes.map (·.amount))
  { base := ⟨base, c⟩, taxTotal := ⟨taxTotal, c⟩, excludedTax := ⟨x.amount p, c⟩,
    total := ⟨base + sumOf p.surcharges + sumOf (p.fees.map (·.amount)) + taxTotal + x.amount p, c⟩ }

/-- EARS: When an airline states a price with its parts, the system shall total
the price as its base amount plus its surcharges, fees, taxes and the
consumption tax not included in it.

Story: As a seller, I want every price to add up from its parts, so that the
total I show the customer is the total the airline charges.

Acceptance criteria:

* ONE-506.1: If the amounts of a price are not all in one currency, then the
  system shall reject the price.
* ONE-506.2: If a price's discount is larger than its amount before discounts,
  then the system shall reject the price.
* ONE-506.3: The system shall state a price's base amount as its amount before
  discounts less its discount.
* ONE-506.4: The system shall make a tax summary's total the sum of its
  entries.
* ONE-506.5: The system shall make a price's total its base amount plus its
  surcharges, its fees, its tax summary total and the consumption tax not
  included in it.
* ONE-506.6: When a consumption tax line is marked as not included in the
  price, the system shall add its tax to the price's total.

Where the consumption tax not included comes from is a reading of the guide
({name}`ExcludedTax`). -/
@[ears "ONE-506",
  source "easd-currency-in-monetary-amounts easd-discounts easd-taxes-fees-and-charges"]
def priceTotal (x : ExcludedTax) (p : PriceParts) : Except PriceRejection PriceTotal :=
  if p.amounts.any (·.currency ≠ p.beforeDiscount.currency) then .error .mixedCurrency
  else if p.beforeDiscount.amount < p.discount.amount then .error .discountAboveBase
  else .ok (PriceTotal.of x p)

end Rules.OneOrder.Offers
