import Rules.Core.Attributes
import Rules.OfferOrder.Offer
import Rules.OfferOrder.Order

/-!
# Accepting an offer

The decision that turns an offer into an order, or rejects it with a reason.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- Why an offer could not be accepted. -/
inductive Rejection
  /-- The offer was accepted at or after its expiry instant. -/
  | expired
  /-- The offer has no items. -/
  | emptyOffer
  /-- At least one item is priced in a currency other than the offer's. -/
  | mixedCurrency
  deriving DecidableEq, Repr, Inhabited

/-- The order item created when an offer item is bought.  It starts ready for
delivery at the offer item's price. -/
def toOrderItem (orderId : String) (i : OfferItem) : OrderItem where
  id := orderId ++ "-" ++ i.id
  fromOfferItem := i.id
  price := i.price
  delivery := .ready

/-- EARS: When a customer accepts an offer, the system shall create an order
only if the offer has not expired and contains at least one item.

Story: As a customer, I want to accept an offer I was shown, so that I get an
order for exactly those services at the offered price.

Acceptance criteria:

* OO-001.1: If a customer accepts an offer at or after its expiry instant,
  then the system shall reject it as expired.
* OO-001.2: If a customer accepts an unexpired offer that has no items, then
  the system shall reject it as empty.
* OO-001.3: If a customer accepts an unexpired offer with an item priced in a
  currency other than the offer's, then the system shall reject it for mixed
  currencies.
* OO-001.4: When a customer accepts an unexpired offer with at least one item
  and every item priced in the offer's currency, the system shall create an
  order.
* OO-001.5: When an order is created from an offer, the system shall price the
  order at the sum of the offer's item prices.

The checks run in order: expiry first, then an empty offer, then items priced
in a currency other than the offer's.  The order's price is the sum of the
item prices, in the offer's currency. -/
@[ears "OO-001", source "pilot-slice"]
def accept (o : Offer) (now : Instant) (orderId : String) : Except Rejection Order :=
  if now ≥ o.expiresAt then .error .expired
  else if o.items.isEmpty then .error .emptyOffer
  else if o.items.any (·.price.currency != o.currency) then .error .mixedCurrency
  else .ok
    { id := orderId
      fromOffer := o.id
      items := o.items.map (toOrderItem orderId)
      price := ⟨(o.items.map (·.price.amount)).sum, o.currency⟩
      createdAt := now }

end Rules.OfferOrder
