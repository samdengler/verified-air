import Mathlib.Data.List.Forall2
import Rules.Core.Attributes
import Rules.OneOrder.Delivery.Moves

/-!
# Ending a service through the delivery status table

Rules in other areas end services: a seller cancels an order or some of its
items, a change drops a service, the airline cancels a flight, and an unpaid
item reaches its payment time limit.  Each of them moves a service's delivery
status, and each does it here, through the delivery status table, so that a
service moves only along a move the table allows, whichever area moves it.
-/

namespace Rules.OneOrder.Delivery

open Rules.Core

/-- Whether a service is live: neither cancelled nor transferred, and not in a
final delivery status. -/
def isLive (s : Service) : Bool :=
  s.status != .cancelled && s.status != .transferred && !isFinal s.delivery

/-- The delivery status an event moves a service to, when the delivery status
table allows the move.  A service does not record the status it left when it
was suspended, so a suspended service can be removed and moves nowhere
else. -/
def nextDelivery (m : MoveReading) (e : DeliveryEvent) (s : Service) : Option DeliveryStatus :=
  (step m ⟨s.delivery, none⟩ e).map (·.status)

/-- EARS: When a rule in any area ends a service, the system shall move the
service's delivery status only along a move of the delivery status table.

Story: As a revenue accountant, I want every area to move a service's delivery
status by the same table, so that a final status I was told about never
changes afterwards.

Acceptance criteria:

* ONE-105.1: When a rule ends a service with an event that the delivery status
  table allows from the service's delivery status, the system shall give the
  service the rule's service status and the delivery status the table gives.
* ONE-105.2: If the delivery status table refuses a rule's event for a
  service's delivery status, then the system shall leave the service as it
  was.
* ONE-105.3: The system shall move a service's delivery status only along a
  move of the delivery status table, whichever area changes it.

The rules that end services call this one: cancelling an unpaid order and
changing an order item, cancelling order items and removing services from a
bundle, the airline cancelling a flight, and an unpaid item reaching its
payment time limit.  A successful payment moves a CONFIRMED service to READY
TO PROCEED, a move of the table.  Accounting keeps its own record of the final
status it is told about and changes no service.  The result is the service
afterwards. -/
@[ears "ONE-105", source "easd-order model-consistency"]
def endWith (m : MoveReading) (e : DeliveryEvent) (st : ServiceStatus) (s : Service) : Service :=
  match nextDelivery m e s with
  | some d => { s with status := st, delivery := d }
  | none => s

/-- Whether one delivery status can follow another through the delivery status
table: it is the same status, or one event the table allows moves the first to
the second. -/
def Follows (m : MoveReading) (a b : DeliveryStatus) : Prop :=
  a = b ∨ ∃ e, (step m ⟨a, none⟩ e).map (·.status) = some b

/-- Whether each service of a list moves along the delivery status table to
the service in the same place of another list, keeping its reference. -/
def MovesAlongTable (m : MoveReading) (before after : List Service) : Prop :=
  List.Forall₂ (fun s s' => s'.id = s.id ∧ Follows m s.delivery s'.delivery) before after

end Rules.OneOrder.Delivery
