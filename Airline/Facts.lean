import Lean

set_option doc.verso false

/-!
# `lake exe airline-facts`

Loads `Airline.Theorems`, which imports `Airline.Evaluate`, from its compiled
`.olean` files and runs it in Lean's interpreter, the same way
`lake exe oracle` runs the rules.  Importing the rules directly would make the
executable link Mathlib's native code.

    lake exe airline-facts > build/airline-data/facts.json
    lake exe airline-facts --theorems > build/airline-theorems.json

Prints the facts the airline's pages read: Verified Airline's fares evaluated
with the model's functions.  Exits nonzero, printing nothing on standard
output, if two readings of the guide give different answers for any fact.

With `--theorems` it prints instead, for each fact about a change or a
cancellation, the theorem in `Airline/Theorems.lean` that states it for every
input in its stage: its name, its docstring, and the file and line it is on.
Under `general` it lists the same for the support chat's rules that hold for
every fare and for what the chat takes as given about amounts
(`generalTheorems`).  `scripts/export_airline.py` publishes the list as
`/airline-data/theorems.json`.  It exits nonzero if a fact has no theorem, or
if a theorem is missing, depends on `sorry`, or does not mention the model's
names it is about: a fact's fare and the function the fact comes from, or the
names `generalTheorems` gives.
-/

open Lean

/-- The theorem of the fact at `fares.<fare>.<action>.<stage>` in the facts. -/
def theoremOf (fare action stage : String) : Name :=
  .str `Airline s!"{fare}_{action}_{stage}"

/-- The model's function the facts of an action come from. -/
def functionOf (action : String) : Name :=
  if action == "change" then `Rules.OneOrder.Offers.voluntaryChange
  else `Rules.OneOrder.Offers.cancellationRefund

/-- The theorems of the support chat's rules that hold for every fare, and of
what it takes as given about amounts: each one's key under `general`, its
name, the names its statement must mention, and the Lean name of the rule or
type it is about, as the chat's policy names it. -/
def generalTheorems : List (String × Name × List Name × String) := [
  ("fareDifference", `Airline.change_fareDifference,
    [`Rules.OneOrder.Offers.voluntaryChange, `Rules.OneOrder.Change.ChangeQuote.difference],
    "Rules.OneOrder.Change.priceDifferential"),
  ("amountDue", `Airline.change_amountDue,
    [`Rules.OneOrder.Offers.voluntaryChange, `Rules.OneOrder.Change.dueAmounts],
    "Rules.OneOrder.Change.dueAmounts"),
  ("refundOverPayment", `Airline.refund_overPayment, [`Rules.OfferOrder.acceptRefund],
    "Rules.OfferOrder.acceptRefund"),
  ("refundWithinPayment", `Airline.refund_withinPayment, [`Rules.OfferOrder.acceptRefund],
    "Rules.OfferOrder.acceptRefund"),
  ("moneyNonNegative", `Airline.money_nonNegative, [`Rules.Core.Money], "Rules.Core.Money"),
  ("farePricePositive", `Airline.fares_pricePositive, [`Airline.fares], "Airline.Fares")]

/-- The entry of a theorem under its key, or what is wrong with it: it must
exist, mention each of `must` and not depend on `sorry`. -/
def entryOf (key : String) (n : Name) (must : List Name) (rule : String) :
    CoreM (Except String (String × Json)) := do
  let env ← getEnv
  let some (.thmInfo t) := env.find? n
    | return .error s!"{key} has no theorem {n}"
  let used := t.type.getUsedConstants
  if let some m := must.find? (fun m => !used.contains m) then
    return .error s!"{n} does not mention {m}"
  if (← collectAxioms n).contains ``sorryAx then
    return .error s!"{n} depends on sorry"
  let some ranges ← findDeclarationRanges? n
    | return .error s!"{n} has no position in its file"
  let some idx := env.getModuleIdxFor? n
    | return .error s!"{n} has no module"
  let path := "/".intercalate (env.header.moduleNames[idx.toNat]!.components.map (·.toString)) ++ ".lean"
  let doc := (← findDocString? env n).getD ""
  return .ok (key, Json.mkObj [
    ("rule", toJson rule), ("theorem", toJson n.toString), ("statement", toJson doc.trimAscii.toString),
    ("path", toJson path), ("line", toJson ranges.selectionRange.pos.line)])

/-- The entry of one fact's theorem, or what is wrong with the theorem. -/
def theoremEntry (fare action stage rule : String) : CoreM (Except String (String × Json)) :=
  entryOf s!"fares.{fare}.{action}.{stage}" (theoremOf fare action stage)
    [.str `Airline s!"{fare}Fare", functionOf action] rule

/-- Every change and cancellation fact in the facts, as fare, action, stage
and the reference of its rule. -/
def factKeys (facts : Json) : Except String (List (String × String × String × String)) := do
  let fares ← facts.getObjVal? "fares"
  let order ← fromJson? (α := List String) (← facts.getObjVal? "fareOrder")
  order.flatMapM fun fare => do
    let f ← fares.getObjVal? fare
    ["change", "cancel"].flatMapM fun action => do
      let stages ← (← f.getObjVal? action).getObj?
      stages.toList.mapM fun (stage, fact) => do
        return (fare, action, stage, ← fromJson? (← fact.getObjVal? "rule"))

/-- The theorem of every fact, or every fact whose theorem is missing or
wrong. -/
def theoremIndex (facts : Json) : CoreM (Except String Json) := do
  let keys ← match factKeys facts with
    | .ok ks => pure ks
    | .error e => return .error s!"the facts are not in the expected shape: {e}"
  let mut entries := #[]
  let mut errors := #[]
  for (fare, action, stage, rule) in keys do
    match ← theoremEntry fare action stage rule with
    | .ok e => entries := entries.push e
    | .error e => errors := errors.push e
  let mut general := #[]
  for (key, n, must, rule) in generalTheorems do
    match ← entryOf key n must rule with
    | .ok e => general := general.push e
    | .error e => errors := errors.push e
  if !errors.isEmpty then return .error ("\n".intercalate errors.toList)
  return .ok (Json.mkObj [
    ("generatedBy", toJson "lake exe airline-facts --theorems"),
    ("facts", Json.mkObj entries.toList),
    ("general", Json.mkObj general.toList)])

def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Airline.Theorems }] {} (loadExts := true)
  let facts ← IO.ofExcept <| unsafe env.evalConst (Except String String) {} `Airline.factsText
  match facts, args with
  | .error e, _ =>
    IO.eprintln s!"airline-facts: {e}"
    return 1
  | .ok text, [] =>
    IO.println text
    return 0
  | .ok text, ["--theorems"] =>
    let json ← IO.ofExcept (Json.parse text)
    let ctx : Core.Context := { fileName := "<airline-facts>", fileMap := default }
    let (index, _) ← (theoremIndex json).toIO ctx { env }
    match index with
    | .ok j =>
      IO.println j.pretty
      return 0
    | .error e =>
      IO.eprintln s!"airline-facts: {e}"
      return 1
  | .ok _, _ =>
    IO.eprintln "usage: lake exe airline-facts [--theorems]"
    return 2
