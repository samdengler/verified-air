import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Basic

/-!
# Choosing seats

A seller asks for a seat map, which marks each seat of a flight available or
occupied, and chooses seats for passengers.  Each seat chosen becomes its own
order item at the seat's price, holding one seat service for the passenger on
that segment, as in the seat worked example.  The guide states no rule that a
seat goes to one passenger only, or that a passenger holds one seat per
segment; the model checks each choice against the seat map and nothing else.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive)

/-- A seat held by a passenger on a flight segment. -/
structure SeatAssignment where
  /-- The passenger holding the seat. -/
  passenger : Passenger
  /-- The flight segment. -/
  segment : String
  /-- The seat number. -/
  seat : String
  deriving DecidableEq, Repr, Inhabited

/-- The seat number of a seat service, and none for any other service. -/
def seatOf (d : ServiceDetails) (s : Service) : Option String :=
  match d.kind s.id with
  | .seat n => some n
  | _ => none

/-- The seats the live seat services of an order hold. -/
def seatsHeld (d : ServiceDetails) (o : Order) : List SeatAssignment :=
  (services o).filterMap fun s =>
    if isLive s then (seatOf d s).map fun n => ⟨s.passenger, s.segment, n⟩ else none

/-- The seat map of a flight segment: the seats the airline marks available.
Every other seat is occupied. -/
structure SeatMap where
  /-- The flight segment. -/
  segment : String
  /-- The seat numbers marked available. -/
  available : List String
  deriving DecidableEq, Repr, Inhabited

/-- A seat a seller chooses for a passenger on a segment, through the price
point offer item the seat map gives it. -/
structure SeatChoice where
  /-- The passenger. -/
  passenger : Passenger
  /-- The flight segment. -/
  segment : String
  /-- The seat number. -/
  seat : String
  /-- The price point offer item of the seat. -/
  offerItem : String
  /-- The seat's price; zero for a free seat. -/
  price : Money
  deriving DecidableEq, Repr, Inhabited

/-- Why a seat request was refused. -/
inductive SeatRejection
  /-- There is no seat map for the segment of a choice. -/
  | noSeatMap (segment : String)
  /-- The seat map does not mark the seat chosen available. -/
  | notAvailable (segment seat : String)
  deriving DecidableEq, Repr, Inhabited

/-- Why a seat choice is refused, if it is: its segment has no seat map, or the
seat map does not mark the seat available. -/
def checkSeat (maps : List SeatMap) (c : SeatChoice) : Option SeatRejection :=
  match maps.find? (·.segment == c.segment) with
  | none => some (.noSeatMap c.segment)
  | some m => if m.available.contains c.seat then none else some (.notAvailable c.segment c.seat)

/-- The reference of the order item a seat choice becomes. -/
def seatItemRef (orderId : String) (c : SeatChoice) : String :=
  orderId ++ "-SEAT-" ++ c.passenger.id ++ "-" ++ c.segment ++ "-" ++ c.seat

/-- The seat service of a seat choice: for the passenger on the segment,
confirmed and waiting for payment, with no reference to a flight service, as
in the seat worked example. -/
def seatService (orderId : String) (c : SeatChoice) : Service :=
  { id := seatItemRef orderId c ++ "-SVC", passenger := c.passenger, segment := c.segment,
    status := .confirmed, delivery := .confirmed }

/-- The order item a seat choice becomes: its own item at the seat's price,
holding the seat service. -/
def seatItem (orderId : String) (c : SeatChoice) : OrderItem :=
  { id := seatItemRef orderId c, fromOfferItem := c.offerItem, price := c.price,
    services := [seatService orderId c] }

/-- EARS: When a seller chooses seats for passengers, the system shall add one
order item for each seat the seat map marks available, and refuse the request
if any seat chosen is not.

Story: As a passenger, I want the seat I chose to be mine alone, so that I do
not find someone else in it.

Acceptance criteria:

* ONE-605.1: If a seat choice names a seat that the seat map of its segment
  does not mark available, then the system shall refuse the request.
* ONE-605.2: When a seat request is accepted, the system shall keep the
  existing order items and add one order item for each seat chosen, at the
  seat's price, holding one seat service for that passenger on that segment.
* ONE-605.3: The system shall never let two passengers hold the same seat on
  the same segment.
* ONE-605.4: The system shall let a passenger hold at most one live seat on
  each segment.

The rule records each new seat service as a seat with its number in the
service details it returns.  It checks each choice against the seat map only,
which is all the guide describes. -/
@[ears "ONE-605", source "easd-seat-map-and-availability easd-add-ancillary-seats"]
def chooseSeats (maps : List SeatMap) (d : ServiceDetails) (o : Order) (cs : List SeatChoice) :
    Except SeatRejection (Order × ServiceDetails) :=
  match cs.findSome? (checkSeat maps) with
  | some e => .error e
  | none =>
    .ok ({ o with items := o.items ++ cs.map (seatItem o.id) },
      cs.foldl (fun d c => d.record (seatService o.id c).id (.seat c.seat) none) d)

end Rules.OneOrder.Ancillaries
