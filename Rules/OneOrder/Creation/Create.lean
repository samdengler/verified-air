import Rules.Core.Attributes
import Rules.OneOrder.Accept
import Rules.OneOrder.Change.Cancel

/-!
# Ordering selected offer items

A seller creates an order from a selection of offer items, and one request
may select from several offers.  The selection must include every item an
offer marks mandatory; the other items are optional.  The request succeeds
as a whole or is rejected as a whole.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-- An offer as a seller orders from it: the offer, and the items it marks
mandatory.  An item without the mark is optional. -/
structure MarkedOffer where
  /-- The offer. -/
  offer : Offer
  /-- The references of the items the offer marks mandatory. -/
  mandatory : List String
  deriving DecidableEq, Repr, Inhabited

/-- The items a seller selects from one offer. -/
structure Selection where
  /-- The reference of the offer. -/
  offer : String
  /-- The references of the offer items selected. -/
  items : List String
  deriving DecidableEq, Repr, Inhabited

/-- Why a create request was rejected. -/
inductive CreateRejection
  /-- The request names an offer the airline does not hold. -/
  | unknownOffer (offer : String)
  /-- The offer had expired at the instant of the request. -/
  | expired (offer : String)
  /-- The selection names an item the offer does not hold. -/
  | unknownItem (offer item : String)
  /-- The selection leaves out an item the offer marks mandatory. -/
  | missingMandatory (offer item : String)
  /-- A selected item is priced in a currency other than its offer's. -/
  | mixedCurrency (offer : String)
  /-- The request selects no item from any offer. -/
  | noItems
  /-- The request names an offer that has already produced this order. -/
  | offerUsed (order : String)
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When a seller selects items from an offer, the system shall accept
the selection only if it names items the offer holds and includes every item
the offer marks mandatory.

Story: As a seller, I want to leave out the optional items of an offer, so
that the customer pays only for what they chose.

Acceptance criteria:

* ONE-401.1: If a selection names an item the offer does not hold, then the
  system shall reject the selection.
* ONE-401.2: If a selection leaves out an item the offer marks mandatory, then
  the system shall reject the selection.
* ONE-401.3: When a selection is accepted, the system shall take every offer
  item it names and no other.
* ONE-401.4: When a selection is accepted, the system shall include at least
  one item the offer marks mandatory.

An item without the mandatory mark is optional.  An empty selection is not
rejected here: a request that selects nothing from any offer is rejected when
the order is created ({lit}`createOrder`), since an order holds at least one
item.  The guide also asks a selection to name the passengers each item was
built for; the model does not check that. -/
@[ears "ONE-401", source "armi-ordwpm armi-general-guidance"]
def selectItems (o : MarkedOffer) (sel : List String) : Except CreateRejection (List OfferItem) :=
  match sel.find? (fun id => !o.offer.items.any (·.id == id)) with
  | some id => .error (.unknownItem o.offer.id id)
  | none =>
    match o.mandatory.find? (fun id => !sel.contains id) with
    | some id => .error (.missingMandatory o.offer.id id)
    | none => .ok (o.offer.items.filter (fun oi => sel.contains oi.id))

/-- The offer items a selection names, from the offer it names: each item of
the offer whose reference the selection names.  None when the airline holds no
offer with that reference. -/
def selectedFrom (offers : List MarkedOffer) (s : Selection) : List OfferItem :=
  match offers.find? (·.offer.id == s.offer) with
  | some o => o.offer.items.filter (fun oi => s.items.contains oi.id)
  | none => []

/-- The reference of an order item made from an offer: the order reference,
then the offer reference.  {name}`toOrderItem` adds the offer item
reference. -/
def itemPrefix (orderId offerId : String) : String := orderId ++ "-" ++ offerId

/-- The order items one selection becomes, or why it is rejected.  The offer
must be one the airline holds and not expired, the selection must be
accepted, and every selected item must be priced in the offer's currency. -/
def orderItemsFor (offers : List MarkedOffer) (now : Instant) (orderId : String) (s : Selection) :
    Except CreateRejection (List OrderItem) :=
  match offers.find? (·.offer.id == s.offer) with
  | none => .error (.unknownOffer s.offer)
  | some o =>
    if now ≥ o.offer.expiresAt then .error (.expired s.offer)
    else
      match selectItems o s.items with
      | .error e => .error e
      | .ok items =>
        if items.any (·.price.currency != o.offer.currency) then .error (.mixedCurrency s.offer)
        else .ok (items.map (toOrderItem (itemPrefix orderId s.offer)))

/-- The order items of every selection of a request, in turn, or the first
rejection. -/
def orderItemsForAll (offers : List MarkedOffer) (now : Instant) (orderId : String) :
    List Selection → Except CreateRejection (List OrderItem)
  | [] => .ok []
  | s :: rest =>
    match orderItemsFor offers now orderId s, orderItemsForAll offers now orderId rest with
    | .error e, _ => .error e
    | .ok _, .error e => .error e
    | .ok items, .ok more => .ok (items ++ more)

/-- What the airline does with a create request when a selection in it is
rejected.  The sources allow one request to select from several offers and do
not say, so the model takes the answer as a parameter: a reading of the
sources.  A guarantee about creation counts as proven only when it holds
under both readings. -/
inductive MultiOfferHandling
  /-- A rejected selection rejects the whole request. -/
  | wholeRequest
  /-- The selections that pass go ahead, and those rejected are left out. -/
  | passingOffers
  deriving DecidableEq, Repr, Inhabited

/-- The order items of the selections of a request that pass, in turn,
leaving out those rejected. -/
def passingItems (offers : List MarkedOffer) (now : Instant) (orderId : String)
    (req : List Selection) : List OrderItem :=
  req.flatMap fun s =>
    match orderItemsFor offers now orderId s with
    | .ok items => items
    | .error _ => []

/-- The order items a request becomes under a reading of the sources, or why
it is rejected.  When every selection passes, both readings give the items of
every selection.  When one is rejected, the whole request is rejected, or the
items of the selections that pass are kept; if none passes, the first
rejection is returned. -/
def pickItems (m : MultiOfferHandling) (offers : List MarkedOffer) (now : Instant) (orderId : String)
    (req : List Selection) : Except CreateRejection (List OrderItem) :=
  match orderItemsForAll offers now orderId req, m with
  | .ok items, _ => .ok items
  | .error e, .wholeRequest => .error e
  | .error e, .passingOffers =>
    if passingItems offers now orderId req = [] then .error e else .ok (passingItems offers now orderId req)

/-- EARS: When a seller sends a create request with selections from one or
more offers, the system shall check each selection and create one order from
them, or reject the request.

Story: As a customer, I want a trip I chose as a whole to be ordered as a
whole, so that I never hold half of it.

Acceptance criteria:

* ONE-402.1: When a create request is accepted, the system shall create one
  order item for each item selected from each offer and none for the items
  left out.
* ONE-402.2: When an order is created from offers priced in one currency, the
  system shall make the order's total price the sum of the prices of the
  selected items.
* ONE-402.3: If any offer named in a create request has expired at the
  instant of the request, then the system shall reject the whole request and
  create no order.
* ONE-402.4: If a create request selects no item from any offer, then the
  system shall reject it.
* ONE-402.5: When an order is created, the system shall be able to state its
  total price in a single currency.

Each selection is checked as {name}`orderItemsFor` says.  What happens when
one is rejected depends on the reading of the sources
({name}`MultiOfferHandling`, {name}`pickItems`).  The order's total is the sum
of its item prices when they share a currency
({name}`Rules.OneOrder.Change.orderPrice`), since the guide no longer stores a
total on the order. -/
@[ears "ONE-402", source "easd-order"]
def createOrder (m : MultiOfferHandling) (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) : Except CreateRejection Order :=
  match pickItems m offers now orderId req with
  | .error e => .error e
  | .ok [] => .error .noItems
  | .ok items => .ok { id := orderId, items, createdAt := now }

end Rules.OneOrder.Creation
