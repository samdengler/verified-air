import Rules.Core.Attributes
import Rules.OneOrder.Payment.Status

/-!
# Applying a payment outcome

What a payment's outcome does to the order items it covers.  A successful
payment moves their confirmed services to ready to proceed and removes their
payment time limits; a failed or pending payment changes nothing.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- An order item once paid: every CONFIRMED service moves to READY TO PROCEED,
services in other delivery statuses keep them, and the item loses its payment
time limit. -/
def PayableItem.markPaid (pi : PayableItem) : PayableItem :=
  { item := { pi.item with services := pi.item.services.map fun s =>
      if s.delivery = .confirmed then { s with delivery := .readyToProceed } else s },
    timeLimit := none }

/-- EARS: When a payment becomes SUCCESSFUL, the system shall move every
CONFIRMED service of the order items it covers to READY TO PROCEED and remove
their payment time limits.

Story: As an airline, I want a successful payment to release the order items
it paid for, so that their services can be delivered and are no longer at
risk of removal.

Acceptance criteria:

* ONE-305.1: When a payment is SUCCESSFUL, the system shall move every
  CONFIRMED service of the order items it covers to READY TO PROCEED.
* ONE-305.2: When a payment is SUCCESSFUL, the system shall remove the payment
  time limits of the order items it covers.
* ONE-305.3: If a payment is FAILED, then the system shall leave the services
  and payment time limits of the order items it covers unchanged.
* ONE-305.4: While a payment is PENDING, the system shall leave the services
  and payment time limits of the order items it covers unchanged.
* ONE-305.5: The system shall leave the order items a payment does not cover
  unchanged.

The guide states these effects for redirected payments.  The model applies
them to a payment of any method. -/
@[ears "ONE-305", source "easd-pay-offline-using-redirection"]
def applyOutcome (p : Transaction) (items : List PayableItem) : List PayableItem :=
  if p.status = .successful then
    items.map fun pi => if pi.item.id ∈ p.covers then pi.markPaid else pi
  else items

end Rules.OneOrder.Payment
