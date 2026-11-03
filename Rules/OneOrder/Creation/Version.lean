import Rules.Core.Attributes
import Rules.OneOrder.Order

/-!
# Order versions and history

An order starts at version 1, and each group of changes the airline applies
raises its version by one.  The order's history is the order at version 1
followed by the change groups, from which a seller can rebuild each version.
A seller may send the version it saw with a change, so the airline can tell
whether the change was made on data that still holds.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-- One change to an order, as the order's history records it. -/
inductive OrderChange
  /-- An order item is added. -/
  | add (i : OrderItem)
  /-- The order item with the same reference is replaced, for example to record
  new service statuses. -/
  | replace (i : OrderItem)
  /-- The order item with this reference is removed from the order. -/
  | remove (itemId : String)
  deriving DecidableEq, Repr, Inhabited

/-- The order after one change. -/
def applyChange (o : Order) : OrderChange → Order
  | .add i => { o with items := o.items ++ [i] }
  | .replace i => { o with items := o.items.map fun j => if j.id = i.id then i else j }
  | .remove id => { o with items := o.items.filter (·.id != id) }

/-- The changes the airline applies to an order at once.  Each group produces
the next version. -/
structure ChangeGroup where
  /-- The changes, applied in turn. -/
  changes : List OrderChange
  deriving DecidableEq, Repr, Inhabited

/-- The order after a group of changes. -/
def applyGroup (o : Order) (g : ChangeGroup) : Order :=
  g.changes.foldl applyChange o

/-- The order after a list of change groups, applied in turn. -/
def replay (o : Order) (gs : List ChangeGroup) : Order :=
  gs.foldl applyGroup o

/-- An order as the airline keeps it: the order as created, the change groups
applied since, oldest first, the order as it is now and its version. -/
structure OrderRecord where
  /-- The order as created, at version 1. -/
  initial : Order
  /-- The change groups applied since, oldest first. -/
  groups : List ChangeGroup
  /-- The order as it is now. -/
  current : Order
  /-- The current version. -/
  version : Nat
  deriving DecidableEq, Repr, Inhabited

/-- The record of a new order: version 1, and no change groups yet. -/
def OrderRecord.create (o : Order) : OrderRecord :=
  { initial := o, groups := [], current := o, version := 1 }

/-- How an order's history lists its change groups.  The guide lists them
oldest first, each raising the version by one.  The capability page for order
history lists them newest first and says each lowers the version.  The model
takes the answer as a parameter: a reading of the sources.  A guarantee about
the history counts as proven only when it holds under both readings. -/
inductive HistoryListing
  /-- The oldest change group first. -/
  | oldestFirst
  /-- The newest change group first. -/
  | newestFirst
  deriving DecidableEq, Repr, Inhabited

/-- One entry of an order's history: a change group and the version it
produced. -/
structure HistoryEntry where
  /-- The version the group produced. -/
  version : Nat
  /-- The change group. -/
  group : ChangeGroup
  deriving DecidableEq, Repr, Inhabited

/-- An order's history as the airline returns it: the order at version 1 and
the change groups since, each labelled with the version it produced. -/
structure History where
  /-- The order at version 1, recorded as one addition. -/
  initial : Order
  /-- The change groups, in the order listed. -/
  entries : List HistoryEntry
  deriving DecidableEq, Repr, Inhabited

/-- Change groups, oldest first, labelled with the versions they produced: the
first group produced version 2. -/
def labelled (gs : List ChangeGroup) : List HistoryEntry :=
  gs.mapIdx fun k g => ⟨k + 2, g⟩

/-- The history the airline returns for an order, listed as the reading of the
sources says. -/
def orderHistory (l : HistoryListing) (r : OrderRecord) : History :=
  { initial := r.initial,
    entries := match l with
      | .oldestFirst => labelled r.groups
      | .newestFirst => (labelled r.groups).reverse }

/-- The order a seller rebuilds from a history: the order at version 1 with
each change group applied in the order listed. -/
def History.rebuild (h : History) : Order :=
  replay h.initial (h.entries.map (·.group))

/-- EARS: When the airline applies a group of changes to an order, the system
shall raise the order's version by one and record the group in the order's
history.

Story: As a seller, I want each version of an order to stand for one set of
changes, so that I can rebuild any version from the order's history.

Acceptance criteria:

* ONE-404.1: When an order is created, the system shall give it version 1 and
  a history with no change groups.
* ONE-404.2: When the airline applies a group of changes to an order, the
  system shall apply the group to the order and raise its version by one.
* ONE-404.3: The system shall keep an order's version one more than the number
  of change groups applied since it was created.
* ONE-404.4: When a seller asks for an order's history, the system shall
  return the order at version 1 and each later change group once, labelled
  with the version it produced.
* ONE-404.5: When a seller applies the change groups of an order's history to
  the order at version 1 in the order listed, the system shall give the order
  as it is now.

The history is listed oldest first or newest first, as the reading of the
sources says ({name}`HistoryListing`, {name}`orderHistory`). -/
@[ears "ONE-404", source "easd-order-versioning easd-order-history"]
def recordChanges (r : OrderRecord) (g : ChangeGroup) : OrderRecord :=
  { r with groups := r.groups ++ [g], current := applyGroup r.current g, version := r.version + 1 }

/-- The record of an order created as given and changed by each group in
turn. -/
def OrderRecord.after (o : Order) (gs : List ChangeGroup) : OrderRecord :=
  gs.foldl recordChanges (OrderRecord.create o)

/-- What the airline does with a change request that carries a version other
than the order's current one.  The guide permits an error and does not require
one, so the model takes the answer as a parameter. -/
inductive StaleHandling
  /-- The airline rejects the change. -/
  | reject
  /-- The airline applies the change. -/
  | apply
  deriving DecidableEq, Repr, Inhabited

/-- Why a change request was rejected. -/
inductive VersionRejection
  /-- The request carries a version other than the order's current one. -/
  | stale
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When a seller sends a change request, the system shall compare the
order version the request carries, if any, with the order's current version
before applying the change.

Story: As a seller, I want a change I make on an order I saw at an older
version to be refused, so that I never overwrite a change I have not seen.

Acceptance criteria:

* ONE-405.1: When a change request carries the order's current version, the
  system shall apply the change and raise the version by one.
* ONE-405.2: When a change request carries no version, the system shall apply
  the change.
* ONE-405.3: If a change request carries a version other than the order's
  current version, then the system shall reject the change.

A request without a version proceeds, as the guide says.  A request with
another version is handled as the reading of the guide says
({name}`StaleHandling`). -/
@[ears "ONE-405", source "easd-order-versioning"]
def requestChange (s : StaleHandling) (r : OrderRecord) (seen : Option Nat) (g : ChangeGroup) :
    Except VersionRejection OrderRecord :=
  match seen with
  | none => .ok (recordChanges r g)
  | some v =>
    if v = r.version then .ok (recordChanges r g)
    else
      match s with
      | .reject => .error .stale
      | .apply => .ok (recordChanges r g)

end Rules.OneOrder.Creation
