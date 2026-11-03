import Lean
import Rules.Core.Attributes
import Rules.Core.Sources



set_option doc.verso false

/-!
# Status executable

`lake exe status` loads the compiled `Rules` environment and reports, for
every documented declaration under `Rules.Core`, `Rules.OfferOrder` and
`Rules.OneOrder`, what kind of declaration it is, its docstring and EARS
statement, and its status.
A theorem's status comes from the axioms it depends on, so nobody can mark a
rule proven by hand.

A rule's docstring also carries a user story (`Story:`) and acceptance
criteria (list items `* OO-001.1: ...`).  Theorems and examples name the
criteria they check with `@[checks "..."]`, and a criterion's status comes
from them: open if a checking theorem is open, proven if one is proven,
example if only examples check it, and not checked otherwise.

Each rule also names the sources it was written from with `@[source]`, and
may carry a confirmation from outside the model with `@[confirmed]`.  The
executable computes a fingerprint of each rule from its docstring, type and
definition, and a rule's provenance from its sources and its confirmation:
confirmed if the confirmation's fingerprint is the current one, out of date if
the rule changed after it was confirmed, sourced if it has a source other than
the modeller, and assumed if the modeller is its only source.

It writes `build/status.json`, the EARS table as `build/ears.md` and
`build/ears.csv`, the acceptance criteria as `build/ears-criteria.csv`, and
each rule's sources and confirmation as `build/provenance.csv`.
It exits nonzero if a declaration depends on `sorry` without being tagged
`@[open_question]`, if an EARS statement or criterion does not follow exactly
one EARS template, if a story or a criterion ID is missing or wrong, if a rule
has no `@[source]`, or if a declaration without an EARS ID carries
`@[confirmed]`.  An out-of-date confirmation is reported as a warning.
-/

open Lean Meta

namespace Status

/-- The namespaces whose declarations make up the model. -/
def roots : List Name := [`Rules.Core, `Rules.OfferOrder, `Rules.OneOrder]

/-- One acceptance criterion of a rule. -/
structure Criterion where
  id : String
  ears : String
  /-- Theorems and examples tagged `@[checks]` with this criterion's ID. -/
  checkedBy : Array Name := #[]
  status : String := "not checked"
  deriving Inhabited

structure Entry where
  name : Name
  module : Name
  kind : String
  docstring : String
  ears : Option String
  earsId : Option String
  story : Option String
  criteria : Array Criterion
  /-- The criterion IDs this theorem or example checks. -/
  checks : Array String
  status : String
  /-- Theorems whose statement mentions this declaration. -/
  provenBy : Array Name
  value : Option String
  /-- The keys of the sources named with `@[source]`. -/
  sources : Array String := #[]
  /-- The confirmation recorded with `@[confirmed]`. -/
  confirmation : Option Rules.Core.Confirmation := none
  /-- A hash of a rule's docstring, type and definition, for rules with an EARS ID. -/
  fingerprint : Option String := none
  deriving Inhabited

/-- Line breaks and runs of spaces folded into single spaces. -/
def fold (s : String) : String :=
  " ".intercalate (((s.replace "\n" " ").splitOn " ").filter (!·.isEmpty))

/-- The text after `label` in a docstring, up to the first blank line, with
line breaks folded into spaces. -/
def fieldOf (label doc : String) : Option String := do
  let parts := doc.splitOn label
  guard (parts.length ≥ 2)
  let rest := label.intercalate (parts.drop 1)
  return fold (rest.splitOn "\n\n").head!

def earsOf := fieldOf "EARS:"

/-- The top-level `* ` list items of a docstring, with their indented
continuation lines folded in. -/
def listItems (doc : String) : Array String := Id.run do
  let mut items := #[]
  let mut cur : Option String := none
  for line in doc.splitOn "\n" do
    if line.startsWith "* " then
      if let some c := cur then items := items.push (fold c)
      cur := some ("* ".intercalate ((line.splitOn "* ").drop 1))
    else if line.startsWith " " && !line.trimAscii.isEmpty && cur.isSome then
      cur := cur.map (· ++ " " ++ line)
    else
      if let some c := cur then items := items.push (fold c)
      cur := none
  if let some c := cur then items := items.push (fold c)
  return items

/-- The list items of the form `ID: statement` whose ID starts with `ID.`
of the rule. -/
def criteriaOf (earsId : String) (doc : String) : Array Criterion :=
  (listItems doc).filterMap fun item =>
    match item.splitOn ": " with
    | id :: rest@(_ :: _) =>
      if id.startsWith (earsId ++ ".") then some { id, ears := ": ".intercalate rest } else none
    | _ => none

/-- The EARS templates, as the opening words a statement starts with. -/
def templates : List (String × String) :=
  [("ubiquitous", "The system shall"), ("event-driven", "When "),
   ("state-driven", "While "), ("unwanted behavior", "If "), ("optional", "Where ")]

/-- The template a statement follows, if it follows exactly one.  Every
template but the ubiquitous one must also contain "the system shall". -/
def templateOf (ears : String) : Option String :=
  match templates.filter (fun (_, p) => ears.startsWith p) with
  | [(t, _)] => if t == "ubiquitous" || (ears.splitOn "the system shall").length == 2 then some t else none
  | _ => none

def inModel (n : Name) : Bool :=
  roots.any (·.isPrefixOf n) && !n.isInternalDetail

def kindOf (env : Environment) (n : Name) (ci : ConstantInfo) : Option String :=
  if Rules.Core.caseAttr.hasTag env n then some "case" else
  match ci with
  | .thmInfo _ => some "theorem"
  | .axiomInfo _ => some "axiom"
  | .defnInfo _ => some "def"
  | .inductInfo _ => some (if isStructure env n then "structure" else "inductive")
  | _ => none

def usesSorry (n : Name) : CoreM Bool :=
  return (← collectAxioms n).contains ``sorryAx

def statusOf (n : Name) (kind : String) : CoreM String :=
  match kind with
  | "theorem" => return if ← usesSorry n then "open" else "proven"
  | "axiom" => return "assumption"
  | _ => return "definition"

/-- Sixteen lowercase hexadecimal digits for a 64-bit hash. -/
def hex16 (h : UInt64) : String :=
  let digits := Nat.toDigits 16 h.toNat
  String.ofList (List.replicate (16 - digits.length) '0' ++ digits)

/-- A rule's fingerprint: a hash of its docstring, its type and its
definition.  Editing the rule's text or its Lean changes it, and so does a
Lean or Mathlib upgrade that elaborates the rule differently. -/
def fingerprintOf (ci : ConstantInfo) (doc : String) : String :=
  let value := match ci.value? with | some v => v.hash | none => 0
  hex16 (mixHash (hash doc) (mixHash ci.type.hash value))

/-- A rule's provenance: `confirmed` if its confirmation's fingerprint is the
current one, `out of date` if the rule changed after it was confirmed,
`sourced` if a source other than the modeller is named, and `assumed` if the
modeller is the only source.  Declarations without an EARS ID have none. -/
def provenanceOf (e : Entry) : Option String := do
  guard e.earsId.isSome
  match e.confirmation with
  | some c => return if some c.fingerprint == e.fingerprint then "confirmed" else "out of date"
  | none =>
    let kinds := e.sources.filterMap fun k => (Rules.Core.sourceOf? k).map (·.kind)
    return if kinds.all (· == .modeller) then "assumed" else "sourced"

/-- The provenance values, in the order the counts are reported. -/
def provenances : List String := ["confirmed", "out of date", "sourced", "assumed"]

/-- The `Repr` rendering of a case's computed value. -/
def evalCase (n : Name) : MetaM String := do
  let e ← mkAppM ``reprStr #[mkConst n]
  unsafe evalExpr String (mkConst ``String) e

def collect (env : Environment) : MetaM (Array Entry) := do
  let mut out := #[]
  for (n, ci) in env.constants.toList do
    unless inModel n do continue
    if env.isProjectionFn n || (← isInstance n) then continue
    -- Syntax declarations such as `ears` are tooling, not part of the model.
    if ci.type.isConstOf ``ParserDescr || ci.type.isConstOf ``TrailingParserDescr then continue
    let some kind := kindOf env n ci | continue
    let some doc ← findDocString? env n | continue
    let some modIdx := env.getModuleIdxFor? n | continue
    let module := env.header.moduleNames[modIdx.toNat]!
    let value ← if kind == "case" then some <$> evalCase n else pure none
    let earsId := Rules.Core.earsAttr.getParam? env n
    let checks := ((Rules.Core.checksAttr.getParam? env n).getD "").splitOn " "
      |>.filter (!·.isEmpty) |>.toArray
    let docstring := doc.trimAscii.toString
    out := out.push
      { name := n, module, kind, docstring, ears := earsOf doc,
        earsId, story := fieldOf "Story:" doc,
        criteria := match earsId with | some id => criteriaOf id doc | none => #[],
        checks, status := ← statusOf n kind, value, provenBy := #[],
        sources := (Rules.Core.sourceAttr.getParam? env n).getD #[],
        confirmation := Rules.Core.confirmedAttr.getParam? env n,
        fingerprint := earsId.map fun _ => fingerprintOf ci docstring }
  -- A theorem proves something about every model declaration its statement mentions.
  let theorems := out.filter (·.kind == "theorem")
  out := out.map fun e =>
    { e with provenBy := (theorems.filter fun t =>
        t.name != e.name && ((env.find? t.name).map (·.type.getUsedConstants.contains e.name)).getD false).map (·.name) }
  -- A criterion's status comes from the theorems and examples that check it.
  let entries := out
  out := out.map fun e =>
    { e with criteria := e.criteria.map fun c =>
        let by_ := entries.filter (·.checks.contains c.id)
        let has kind status := by_.any fun x => x.kind == kind && x.status == status
        let status :=
          if has "theorem" "open" then "open"
          else if has "theorem" "proven" then "proven"
          else if by_.any (·.kind == "case") then "example"
          else "not checked"
        { c with checkedBy := by_.map (·.name), status } }
  return out.qsort (fun a b => a.name.toString < b.name.toString)

/-- Declarations anywhere under the model's namespaces that depend on `sorry`. -/
def sorryDecls : CoreM (Array Name) := do
  let mut out := #[]
  for (n, ci) in (← getEnv).constants.toList do
    if roots.any (·.isPrefixOf n) && (ci matches .thmInfo _ || ci matches .defnInfo _) then
      if ← usesSorry n then out := out.push n
  return out

def Entry.json (e : Entry) : Json :=
  Json.mkObj <|
    [("name", toJson e.name.toString), ("module", toJson e.module.toString),
     ("kind", toJson e.kind), ("docstring", toJson e.docstring),
     ("ears", toJson e.ears), ("earsId", toJson e.earsId), ("story", toJson e.story),
     ("criteria", Json.arr (e.criteria.map fun c => Json.mkObj
        [("id", toJson c.id), ("ears", toJson c.ears), ("template", toJson (templateOf c.ears)),
         ("status", toJson c.status), ("checkedBy", toJson (c.checkedBy.map (·.toString)))])),
     ("checks", toJson e.checks), ("status", toJson e.status),
     ("provenBy", toJson (e.provenBy.map (·.toString)))] ++
    (match e.value with | some v => [("value", toJson v)] | none => []) ++
    (if e.sources.isEmpty then [] else [("sources", toJson e.sources)]) ++
    (match e.fingerprint with | some f => [("fingerprint", toJson f)] | none => []) ++
    (match provenanceOf e with | some p => [("provenance", toJson p)] | none => []) ++
    (match e.confirmation with
     | some c => [("confirmation", Json.mkObj
         [("method", toJson c.method.label), ("date", toJson c.date), ("who", toJson c.who),
          ("note", toJson c.note), ("fingerprint", toJson c.fingerprint)])]
     | none => [])

/-- The list of sources the rules may cite, as JSON. -/
def sourcesJson : Json :=
  Json.arr (Rules.Core.sources.toArray.map fun s => Json.mkObj
    [("key", toJson s.key), ("kind", toJson s.kind.label), ("title", toJson s.title),
     ("url", toJson s.url)])

def countIn (es : Array Entry) (ns : Name) (status : String) : Nat :=
  (es.filter fun e => ns.isPrefixOf e.name && e.kind == "theorem" && e.status == status).size

/-- Declarations with an EARS statement, ordered by EARS ID. -/
def earsRows (es : Array Entry) : Array Entry :=
  (es.filter (·.ears.isSome)).qsort fun a b => (a.earsId.getD "~") < (b.earsId.getD "~")

def provenByText (es : Array Entry) (e : Entry) (sep : String) (fmt : Name → String) : String :=
  let parts := e.provenBy.toList.map fun t =>
    let isOpen := es.any fun x => x.name == t && x.status == "open"
    fmt t ++ (if isOpen then " (open)" else "")
  if parts.isEmpty then "none" else sep.intercalate parts

def earsTable (es : Array Entry) : String := Id.run do
  let mut s := "| ID | EARS statement | Declaration | Status | Proven by |\n| --- | --- | --- | --- | --- |\n"
  for e in earsRows es do
    let pb := provenByText es e ", " fun t => s!"`{t.getString!}`"
    s := s ++ s!"| {e.earsId.getD ""} | {e.ears.getD ""} | `{e.name}` | {e.status} | {pb} |\n"
  return s

def csvField (s : String) : String :=
  if s.any (fun c => c == ',' || c == '"' || c == '\n') then
    "\"" ++ s.replace "\"" "\"\"" ++ "\""
  else s

def earsCsv (es : Array Entry) : String := Id.run do
  let mut s := "id,ears,declaration,status,proven_by\n"
  for e in earsRows es do
    let pb := provenByText es e "; " toString
    let row := [e.earsId.getD "", e.ears.getD "", e.name.toString, e.status, pb]
    s := s ++ ",".intercalate (row.map csvField) ++ "\n"
  return s

/-- One row per acceptance criterion, with the declarations that check it. -/
def criteriaCsv (es : Array Entry) : String := Id.run do
  let mut s := "id,requirement,ears,template,status,checked_by\n"
  for e in earsRows es do
    for c in e.criteria do
      let cb := c.checkedBy.toList.map fun n =>
        let x := es.find? (·.name == n)
        let st := match x with
          | some x => if x.kind == "case" then "example" else x.status
          | none => "unknown"
        s!"{n} ({st})"
      let row := [c.id, e.earsId.getD "", c.ears, (templateOf c.ears).getD "", c.status,
        if cb.isEmpty then "none" else "; ".intercalate cb]
      s := s ++ ",".intercalate (row.map csvField) ++ "\n"
  return s

/-- One row per rule: its provenance, its sources and its confirmation. -/
def provenanceCsv (es : Array Entry) : String := Id.run do
  let mut s := "id,declaration,provenance,sources,source_kinds,confirmed_by,confirmed_on,method,what_was_confirmed,fingerprint\n"
  for e in earsRows es do
    let srcs := e.sources.toList.filterMap Rules.Core.sourceOf?
    let c := e.confirmation
    let row := [e.earsId.getD "", e.name.toString, (provenanceOf e).getD "",
      "; ".intercalate (srcs.map (·.title)), "; ".intercalate (srcs.map (·.kind.label)),
      (c.map (·.who)).getD "", (c.map (·.date)).getD "", (c.map (·.method.label)).getD "",
      (c.map (·.note)).getD "", e.fingerprint.getD ""]
    s := s ++ ",".intercalate (row.map csvField) ++ "\n"
  return s

end Status

open Status in
def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Rules }] {} (loadExts := true)
  let ctx : Core.Context := { fileName := "<status>", fileMap := default }
  let (entries, _) ← (collect env).toIO ctx { env }
  let summary := Json.mkObj <| roots.map fun ns =>
    (ns.toString, Json.mkObj
      [("proven", toJson (countIn entries ns "proven")),
       ("open", toJson (countIn entries ns "open"))])
  let rules := earsRows entries
  let countProvenance p := (rules.filter (provenanceOf · == some p)).size
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/status.json" <| (Json.mkObj
    [("summary", summary),
     ("provenance", Json.mkObj (provenances.map fun p => (p, toJson (countProvenance p)))),
     ("sources", sourcesJson),
     ("declarations", Json.arr (entries.map (·.json)))]).pretty ++ "\n"
  IO.FS.writeFile "build/ears.md" (earsTable entries)
  IO.FS.writeFile "build/ears.csv" (earsCsv entries)
  IO.FS.writeFile "build/ears-criteria.csv" (criteriaCsv entries)
  IO.FS.writeFile "build/provenance.csv" (provenanceCsv entries)
  let mut ok := true
  let (sorries, _) ← sorryDecls.toIO ctx { env }
  for n in sorries do
    unless Rules.Core.openQuestionAttr.hasTag env n do
      IO.eprintln s!"error: {n} depends on sorry but is not tagged @[open_question]"
      ok := false
  for e in earsRows entries do
    if templateOf (e.ears.getD "") |>.isNone then
      IO.eprintln s!"error: the EARS statement of {e.name} does not follow exactly one EARS template"
      ok := false
    if e.earsId.isNone then
      IO.eprintln s!"error: {e.name} has an EARS statement but no @[ears \"ID\"] attribute"
      ok := false
    if e.story.isNone then
      IO.eprintln s!"error: {e.name} has an EARS statement but no Story: line"
      ok := false
    if e.criteria.isEmpty then
      IO.eprintln s!"error: {e.name} has an EARS statement but no acceptance criteria"
      ok := false
    if e.sources.isEmpty then
      IO.eprintln s!"error: {e.name} has an EARS statement but no @[source \"...\"] attribute"
      ok := false
    if provenanceOf e == some "out of date" then
      IO.eprintln s!"warning: {e.name} changed after it was confirmed; its confirmation is out of date (fingerprint now {e.fingerprint.getD ""})"
    for c in e.criteria do
      if templateOf c.ears |>.isNone then
        IO.eprintln s!"error: criterion {c.id} of {e.name} does not follow exactly one EARS template"
        ok := false
  let criterionIds := (earsRows entries).flatMap (·.criteria.map (·.id))
  for id in criterionIds do
    if (criterionIds.filter (· == id)).size > 1 then
      IO.eprintln s!"error: criterion ID {id} is used more than once"
      ok := false
  for e in entries do
    for id in e.checks do
      unless criterionIds.contains id do
        IO.eprintln s!"error: {e.name} checks {id}, which no rule defines"
        ok := false
  -- A confirmation is of a rule as written, so only rules with an EARS ID carry one.
  for (n, _) in env.constants.toList do
    if inModel n && (Rules.Core.confirmedAttr.getParam? env n).isSome then
      unless (entries.find? (·.name == n)).any (·.earsId.isSome) do
        IO.eprintln s!"error: {n} carries @[confirmed] but has no EARS ID; confirm the rule it belongs to"
        ok := false
  for ns in roots do
    IO.println s!"{ns}: {countIn entries ns "proven"} proven, {countIn entries ns "open"} open"
  let criteria := (earsRows entries).flatMap (·.criteria)
  let countStatus st := (criteria.filter (·.status == st)).size
  IO.println s!"{criteria.size} acceptance criteria: {countStatus "proven"} proven, {countStatus "example"} example only, {countStatus "open"} open, {countStatus "not checked"} not checked"
  IO.println s!"{rules.size} rules: {countProvenance "confirmed"} confirmed, {countProvenance "out of date"} confirmed but out of date, {countProvenance "sourced"} from a source, {countProvenance "assumed"} assumed by the modeller"
  IO.println s!"{entries.size} declarations written to build/status.json; {(earsRows entries).size} EARS rows to build/ears.md and build/ears.csv; {criteria.size} criteria to build/ears-criteria.csv; {rules.size} rules to build/provenance.csv"
  return if ok then 0 else 1
