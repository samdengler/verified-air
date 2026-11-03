import Lean
import Rules.Core.Sources

/-!
# Attributes

Tags that mark declarations for the review artifact.  The status executable
reads them from the compiled environment.
-/

namespace Rules.Core

open Lean

/-- {lit}`@[case]` marks a build-time example: a concrete scenario whose value the
build computes and the review artifact shows. -/
initialize caseAttr : TagAttribute ←
  registerTagAttribute `case "a build-time example shown in the review artifact"

/-- {lit}`@[open_question]` marks a theorem left open on purpose because its
proof is waiting on a business decision.  Any other theorem that depends on
{lit}`sorry` fails the status check. -/
initialize openQuestionAttr : TagAttribute ←
  registerTagAttribute `open_question "a theorem left open pending a business decision"

/-- {lit}`@[ears "OO-001"]` gives a rule its stable EARS requirement ID.  IDs are
assigned by this attribute, not by position, so adding a rule never renumbers
the others. -/
syntax (name := ears) "ears " str : attr

/-- The EARS requirement ID attached to a rule by {lit}`@[ears "..."]`. -/
initialize earsAttr : ParametricAttribute String ←
  registerParametricAttribute {
    name := `ears
    descr := "stable EARS requirement ID for a rule"
    getParam := fun _ stx =>
      match stx with
      | `(attr| ears $id:str) => pure id.getString
      | _ => throwError "expected @[ears \"<ID>\"]"
  }

/-- {lit}`@[checks "OO-001.1"]` says which acceptance criteria a theorem or an
example checks.  Several IDs are separated by spaces.  The status executable
computes each criterion's status from the declarations that check it. -/
syntax (name := checks) "checks " str : attr

/-- The acceptance criterion IDs attached to a theorem or example by
{lit}`@[checks "..."]`, as written. -/
initialize checksAttr : ParametricAttribute String ←
  registerParametricAttribute {
    name := `checks
    descr := "acceptance criteria checked by a theorem or example"
    getParam := fun _ stx =>
      match stx with
      | `(attr| checks $ids:str) => pure ids.getString
      | _ => throwError "expected @[checks \"<ID> ...\"]"
  }

/-- {lit}`@[source "easd-order easd-time-limits"]` names the sources a rule was
written from, by their keys in {lit}`Rules.Core.sources`.  Several keys are
separated by spaces.  Every rule with an EARS ID needs one. -/
syntax (name := source) "source " str : attr

/-- The source keys attached to a declaration by {lit}`@[source "..."]`.  A key
that is not in {lit}`Rules.Core.sources` is an error where the attribute is
written. -/
initialize sourceAttr : ParametricAttribute (Array String) ←
  registerParametricAttribute {
    name := `source
    descr := "the sources a rule was written from"
    getParam := fun _ stx => do
      let keys ← match stx with
        | `(attr| source $keys:str) =>
          pure ((keys.getString.splitOn " ").filter (!·.isEmpty)).toArray
        | _ => throwError "expected @[source \"<key> ...\"]"
      if keys.isEmpty then throwError "@[source] needs at least one key"
      for k in keys do
        if (sourceOf? k).isNone then
          throwError "unknown source key {k}; add it to Rules.Core.sources"
        if (keys.filter (· == k)).size > 1 then
          throwError "source key {k} is named twice"
      pure keys
  }

/-- How a rule was confirmed. -/
inductive ConfirmMethod
  /-- A subject matter expert answered a question about the rule. -/
  | sme
  /-- Production data shows the business works as the rule says. -/
  | data
  /-- A second, independent source agrees with the rule: a rules engine, code,
  a test suite or a document. -/
  | crosscheck
  deriving DecidableEq, Repr, Inhabited

/-- The name of a confirmation method, as the status file and the pages show it. -/
def ConfirmMethod.label : ConfirmMethod → String
  | .sme => "sme"
  | .data => "data"
  | .crosscheck => "crosscheck"

/-- A confirmation recorded with {lit}`@[confirmed ...]`. -/
structure Confirmation where
  method : ConfirmMethod
  /-- The day of the confirmation, written YYYY-MM-DD. -/
  date : String
  /-- Who or what confirmed it: a team, a role, a data set or a system. -/
  who : String
  /-- What was confirmed, such as the question answered or the data checked. -/
  note : String
  /-- The rule's fingerprint when it was confirmed.  The status executable
  computes the current fingerprint; when the two differ, the rule changed after
  the confirmation and the confirmation is out of date. -/
  fingerprint : String
  deriving Repr, Inhabited

/-- Whether a string is a date written YYYY-MM-DD. -/
def isIsoDate (s : String) : Bool :=
  let cs := s.toList
  cs.length == 10 && (List.range 10).all fun i =>
    let c := cs.getD i ' '
    if i == 4 || i == 7 then c == '-' else c.isDigit

/-- Whether a string is a fingerprint as the status executable writes it:
sixteen lowercase hexadecimal digits. -/
def isFingerprint (s : String) : Bool :=
  s.length == 16 && s.all fun c => c.isDigit || ('a' ≤ c && c ≤ 'f')

/-- {lit}`@[confirmed sme "2026-11-03" "Offer/Order team" "<what was confirmed>" "<fingerprint>"]`
records that a rule was confirmed outside the model: by a subject matter
expert ({lit}`sme`), by production data ({lit}`data`) or by a second
independent source ({lit}`crosscheck`).  The last field is the rule's
fingerprint from {lit}`build/status.json` at the time.  Add one only for a
confirmation that happened. -/
syntax (name := confirmed) "confirmed " ident str str str str : attr

/-- The confirmation attached to a rule by {lit}`@[confirmed ...]`.  The
method, the date and the fingerprint are checked where the attribute is
written. -/
initialize confirmedAttr : ParametricAttribute Confirmation ←
  registerParametricAttribute {
    name := `confirmed
    descr := "a confirmation of a rule from outside the model"
    getParam := fun _ stx => do
      match stx with
      | `(attr| confirmed $m:ident $d:str $who:str $note:str $fp:str) =>
        let method ← match m.getId.toString with
          | "sme" => pure ConfirmMethod.sme
          | "data" => pure ConfirmMethod.data
          | "crosscheck" => pure ConfirmMethod.crosscheck
          | other => throwError "unknown confirmation method {other}; use sme, data or crosscheck"
        unless isIsoDate d.getString do
          throwError "the date of a confirmation is written YYYY-MM-DD"
        if who.getString.trimAscii.isEmpty || note.getString.trimAscii.isEmpty then
          throwError "a confirmation says who confirmed the rule and what was confirmed"
        unless isFingerprint fp.getString do
          throwError "the last field is the rule's fingerprint from build/status.json: sixteen hexadecimal digits"
        pure { method, date := d.getString, who := who.getString, note := note.getString,
               fingerprint := fp.getString }
      | _ => throwError "expected @[confirmed <method> \"YYYY-MM-DD\" \"<who>\" \"<what was confirmed>\" \"<fingerprint>\"]"
  }

end Rules.Core
