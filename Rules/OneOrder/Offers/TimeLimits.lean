import Rules.Core.Attributes
import Rules.OneOrder.Accept
import Rules.OneOrder.Payment.Basic

/-!
# Time limits on offers and new order items

An offer expires at an instant, and each offer item may carry time limits of
its own: a price guarantee, an inventory guarantee and a payment time limit.
Before an order exists, no limit outlasts the offer.  When an order is
created, each order item takes its payment time limit and its price guarantee
from its offer item.  The guide leaves three points open, so the model takes
them as parameters: whether a guarantee still holds at the instant it ends,
what happens when an offer is accepted after a price guarantee has lapsed, and
which form of payment time limit applies when an offer item states two.
-/

namespace Rules.OneOrder.Offers

open Rules.Core

/-- The instant a number of seconds after another. -/
def secondsAfter (t : Instant) (seconds : Nat) : Instant := ⟨t.epochSeconds + seconds⟩

/-- The time limits an offer item carries.  The guide lets an airline leave
out any of them. -/
structure ItemLimits where
  /-- The instant until which the airline guarantees the item's price. -/
  priceGuarantee : Option Instant
  /-- The instant until which the airline guarantees the item's inventory. -/
  inventoryGuarantee : Option Instant
  /-- The payment time limit as a duration: seconds after the order is
  created. -/
  payWithin : Option Nat
  /-- The payment time limit as a fixed date and time. -/
  payBy : Option Instant
  deriving DecidableEq, Repr, Inhabited

/-- An offer item with its time limits. -/
structure TimedOfferItem where
  /-- The offer item: its reference, price, passengers and segments. -/
  item : OfferItem
  /-- Its time limits. -/
  limits : ItemLimits
  deriving DecidableEq, Repr, Inhabited

/-- An offer whose items carry time limits.  It corresponds to a ONE Order
offer with the time limits of its offer items. -/
structure TimedOffer where
  /-- The offer reference. -/
  id : String
  /-- The items on offer, each with its time limits. -/
  items : List TimedOfferItem
  /-- The instant the offer stops being valid. -/
  expiresAt : Instant
  /-- The currency the offer is priced in. -/
  currency : Currency
  deriving DecidableEq, Repr, Inhabited

/-- The offer without its items' time limits, as the order creation rule of
ONE-001 takes it. -/
def TimedOffer.toOffer (o : TimedOffer) : Offer :=
  { id := o.id, items := o.items.map (·.item), expiresAt := o.expiresAt, currency := o.currency }

/-- Whether a guarantee still holds at the instant it ends.  The guide says a
price is guaranteed until its time limit and does not say whether the limit's
own instant is inside, so the model takes the answer as a parameter: a reading
of the guide. -/
inductive GuaranteeEnd
  /-- The guarantee ends at its instant, as an offer expires at its expiry
  instant. -/
  | exclusive
  /-- The guarantee still holds at its instant and ends after it. -/
  | inclusive
  deriving DecidableEq, Repr, Inhabited

/-- Whether an instant is inside a guarantee that runs until a limit, under a
reading of the guide. -/
def GuaranteeEnd.within (b : GuaranteeEnd) (now limit : Instant) : Bool :=
  match b with
  | .exclusive => decide (now < limit)
  | .inclusive => decide (now ≤ limit)

/-- Whether a guarantee limit on an offer item holds at an instant before an
order exists: the item carries the limit, and the instant is inside the
earlier of the limit and the offer's expiry. -/
def TimedOffer.holds (b : GuaranteeEnd) (o : TimedOffer) (limit : Option Instant)
    (now : Instant) : Bool :=
  limit.any fun t => b.within now (min t o.expiresAt)

/-- What an offer item guarantees at an instant. -/
structure Guarantees where
  /-- Whether the item's price is guaranteed. -/
  price : Bool
  /-- Whether the item's inventory is guaranteed. -/
  inventory : Bool
  deriving DecidableEq, Repr, Inhabited

/-- EARS: While no order has been created from an offer, the system shall treat
an offer item's price and inventory as guaranteed only until both the item's
guarantee time limit and the offer's expiry.

Story: As an airline, I want an offer's guarantees to end when the offer
expires, so that I never stand behind a price or a seat for an offer that can
no longer be accepted.

Acceptance criteria:

* ONE-501.1: If an offer item carries no price guarantee time limit, then the
  system shall treat its price as not guaranteed.
* ONE-501.2: While an instant is before an offer item's price guarantee time
  limit and before the offer's expiry, the system shall treat the item's price
  as guaranteed.
* ONE-501.3: While an instant is before an offer item's inventory guarantee
  time limit and before the offer's expiry, the system shall treat the item's
  inventory as guaranteed.
* ONE-501.4: The system shall end every price and inventory guarantee of an
  offer no later than the offer's expiry.
* ONE-501.5: The system shall not treat an offer item's price as guaranteed at
  an instant at which the offer can no longer be accepted.

A guarantee runs until the earlier of its own limit and the offer's expiry.
Whether it still holds at that instant is a reading of the guide
({name}`GuaranteeEnd`).  The offer's expiry on its own guarantees nothing. -/
@[ears "ONE-501", source "easd-time-limits"]
def guaranteesAt (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem) (now : Instant) :
    Guarantees :=
  { price := o.holds b oi.limits.priceGuarantee now,
    inventory := o.holds b oi.limits.inventoryGuarantee now }

/-- Which form of payment time limit applies when an offer item states both a
duration and a fixed date and time.  The guide does not say, so the model
takes the answer as a parameter: a reading of the guide. -/
inductive BothForms
  /-- The duration applies. -/
  | duration
  /-- The fixed date and time applies. -/
  | fixed
  /-- Whichever comes first applies. -/
  | earlier
  deriving DecidableEq, Repr, Inhabited

/-- The payment time limit an order item takes from its offer item's limits
when the order is created at an instant: the creation instant plus the
duration, or the fixed date and time. -/
def paymentLimitAt (r : BothForms) (createdAt : Instant) (l : ItemLimits) : Option Instant :=
  match l.payWithin, l.payBy with
  | none, none => none
  | some d, none => some (secondsAfter createdAt d)
  | none, some t => some t
  | some d, some t =>
    match r with
    | .duration => some (secondsAfter createdAt d)
    | .fixed => some t
    | .earlier => some (min (secondsAfter createdAt d) t)

/-- What happens when a customer accepts an unexpired offer after the price
guarantee of one of its items has lapsed.  The guide recommends repricing into
a new offer and does not say what the airline must do, so the model takes the
answer as a parameter: a reading of the guide. -/
inductive LapsedPrice
  /-- The acceptance is refused, and the seller asks for a new offer at a
  current price. -/
  | reprice
  /-- The order is created at the offered price. -/
  | offeredPrice
  deriving DecidableEq, Repr, Inhabited

/-- The readings of the guide that order creation from a timed offer depends
on. -/
structure CreationReading where
  /-- Whether a guarantee still holds at the instant it ends. -/
  guaranteeEnd : GuaranteeEnd
  /-- What happens when a price guarantee has lapsed at acceptance. -/
  lapsedPrice : LapsedPrice
  /-- Which payment time limit applies when an offer item states two. -/
  bothForms : BothForms
  deriving DecidableEq, Repr, Inhabited

/-- An order item as created from a timed offer item: the order item, its
payment time limit and its price guarantee. -/
structure NewOrderItem where
  /-- The order item. -/
  item : OrderItem
  /-- The instant by which the item must be paid, if it has a limit. -/
  paymentBy : Option Instant
  /-- The instant until which the item's price is guaranteed, if it is. -/
  priceGuarantee : Option Instant
  deriving DecidableEq, Repr, Inhabited

/-- An order created from a timed offer, with each order item's time limits. -/
structure NewOrder where
  /-- The order reference. -/
  id : String
  /-- The order items with their time limits. -/
  items : List NewOrderItem
  /-- When the order was created. -/
  createdAt : Instant
  deriving DecidableEq, Repr, Inhabited

/-- The order without its items' time limits. -/
def NewOrder.toOrder (o : NewOrder) : Order :=
  { id := o.id, items := o.items.map (·.item), createdAt := o.createdAt }

/-- The order as the payment rules see it: its items with their payment time
limits, and no payments yet. -/
def NewOrder.payable (o : NewOrder) : Payment.PayableOrder :=
  { items := o.items.map fun i => ⟨i.item, i.paymentBy⟩, payments := [] }

/-- Why an order could not be created from a timed offer. -/
inductive CreateRejection
  /-- The offer failed a check of ONE-001: it expired, is empty, or mixes
  currencies. -/
  | offer (r : Rules.OfferOrder.Rejection)
  /-- The price guarantee of an item has lapsed and the seller must ask for a
  new offer. -/
  | priceGuaranteeLapsed
  deriving DecidableEq, Repr, Inhabited

/-- Whether an offer item's price guarantee has lapsed at an instant: the item
carries one, and its price is no longer guaranteed. -/
def TimedOffer.guaranteeLapsed (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now : Instant) : Bool :=
  oi.limits.priceGuarantee.isSome && !(guaranteesAt b o oi now).price

/-- The order item an offer item becomes, with its time limits. -/
def newItem (r : CreationReading) (orderId : String) (now : Instant) (oi : TimedOfferItem) :
    NewOrderItem :=
  { item := toOrderItem orderId oi.item, paymentBy := paymentLimitAt r.bothForms now oi.limits,
    priceGuarantee := oi.limits.priceGuarantee }

/-- EARS: When a customer accepts an offer whose items carry time limits, the
system shall create the order as ONE-001 does and give each order item its
payment time limit and price guarantee from its offer item.

Story: As an airline, I want each new order item to start with the payment
time limit and price guarantee its offer item promised, so that the customer
gets the time to pay and the price the offer stated.

Acceptance criteria:

* ONE-502.1: When an order is created from an offer item whose payment time
  limit is stated only as a duration, the system shall set the order item's
  payment time limit to the creation instant plus that duration.
* ONE-502.2: When an order is created from an offer item whose payment time
  limit is stated only as a fixed date and time, the system shall set the
  order item's payment time limit to that instant.
* ONE-502.3: When an order is created, the system shall carry each offer
  item's price guarantee time limit into its order item.
* ONE-502.4: If a customer accepts an offer after the price guarantee of one of
  its items has lapsed, then the system shall not create the order at the
  offered price.
* ONE-502.5: When an order is created, the system shall give no order item a
  payment time limit before the order's creation.
* ONE-502.6: When an offer item's payment time limit is a duration of zero, the
  system shall accept a payment for its order item made at the instant the
  order is created.

The checks of ONE-001 run first ({name}`accept`).  Then, under the reading that
asks for a new offer, an item whose price guarantee has lapsed refuses the
acceptance.  Which payment time limit applies when an offer item states both
forms is a reading of the guide ({name}`BothForms`). -/
@[ears "ONE-502", source "easd-time-limits"]
def createOrder (r : CreationReading) (o : TimedOffer) (now : Instant) (orderId : String) :
    Except CreateRejection NewOrder :=
  match accept o.toOffer now orderId with
  | .error e => .error (.offer e)
  | .ok _ =>
    if r.lapsedPrice = .reprice ∧ o.items.any (o.guaranteeLapsed r.guaranteeEnd · now) then
      .error .priceGuaranteeLapsed
    else .ok { id := orderId, items := o.items.map (newItem r orderId now), createdAt := now }

end Rules.OneOrder.Offers
