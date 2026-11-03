import Rules.Core.Attributes
import Rules.OneOrder.Creation.Create

/-!
# Repeated create requests

A seller whose create request times out may send it again.  The sources do
not say whether creating an order uses up its offers, or how the airline
recognizes a repeated request.  The model recognizes one by the offers it
names, and takes what the airline does with it as a parameter: a reading of
the guide.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-- An order the airline created, with the offers it came from. -/
structure CreatedOrder where
  /-- The references of the offers the order came from. -/
  offers : List String
  /-- The order. -/
  order : Order
  deriving DecidableEq, Repr, Inhabited

/-- What the airline does with a create request that names an offer which has
already produced an order.  The sources are silent, so the model takes the
answer as a parameter.  A guarantee about repeated requests counts as proven
only when it holds under every reading. -/
inductive RepeatHandling
  /-- The airline answers with the order the offer already produced. -/
  | returnExisting
  /-- The airline rejects the request. -/
  | reject
  /-- The airline creates another order.  Nothing in the sources stops it. -/
  | createAgain
  deriving DecidableEq, Repr, Inhabited

/-- Whether an order recorded by the airline came from any offer the request
names. -/
def CreatedOrder.fromAny (req : List Selection) (e : CreatedOrder) : Bool :=
  req.any fun s => e.offers.contains s.offer

/-- EARS: When a seller sends a create request, the system shall create the
order and record the offers it came from, unless an offer it names has
already produced an order.

Story: As a seller, I want a request I send again after a timeout to give me
the order I already have, so that the customer is not booked twice.

Acceptance criteria:

* ONE-403.1: When a create request that names no offer with an order is
  accepted, the system shall record the new order against every offer it
  names.
* ONE-403.2: Where the airline returns the existing order for a repeated
  request, the system shall answer a request that names an offer which
  already produced an order with a recorded order from one of its offers, and
  record no new order.
* ONE-403.3: Where the airline rejects repeated requests, the system shall
  reject a request that names an offer which already produced an order.
* ONE-403.4: The system shall create at most one order from each offer.

A request that names an offer with an order is handled as the reading of the
guide says ({name}`RepeatHandling`).  A new order is created as
{name}`createOrder` says, under its own reading.  When it names offers from more than one
recorded order, the first recorded order is the existing one. -/
@[ears "ONE-403", source "easd-create-order-without-payment"]
def createOnce (h : RepeatHandling) (m : MultiOfferHandling) (book : List CreatedOrder)
    (offers : List MarkedOffer) (req : List Selection) (now : Instant) (orderId : String) :
    Except CreateRejection (Order × List CreatedOrder) :=
  let fresh := (createOrder m offers req now orderId).map fun o => (o, book ++ [⟨req.map (·.offer), o⟩])
  match book.find? (·.fromAny req) with
  | none => fresh
  | some e =>
    match h with
    | .returnExisting => .ok (e.order, book)
    | .reject => .error (.offerUsed e.order.id)
    | .createAgain => fresh

/-- Each offer appears in at most one order the airline has recorded. -/
def OncePerOffer (book : List CreatedOrder) : Prop :=
  ∀ offer : String, (book.filter fun e => e.offers.contains offer).length ≤ 1

end Rules.OneOrder.Creation
