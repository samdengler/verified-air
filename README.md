# verified-air

Business rules for airline offers and orders, written as code that a computer
checks, with the review documents and requirement specs generated from that
code on every commit. It covers one slice of the Offer and Order domain: an
offer with priced items and an expiry, the order created when a customer
accepts it, payments against the order, and refunds against payments.

This is a proof of concept built from public material only. It is not
affiliated with or endorsed by IATA, and it is not an implementation of the
standard. The objects follow IATA's public Offers and Orders standard,
[ONE Order](https://www.iata.org/en/programs/airline-distribution/retailing/one-order/).
The rules, prices and data are simplified and invented. Where a rule is
taken from IATA's public documentation, it is described in our own words
with a link to the source page; IATA owns the standard and its documentation.

- Home page, with the model's status and a guide to the site: <https://samdengler.github.io/verified-air/>
- Progress page, for business readers: <https://samdengler.github.io/verified-air/progress/>
- Review document: <https://samdengler.github.io/verified-air/review/>
- Requirement specs, criteria in EARS, in Kiro's format: [`.kiro/specs/`](.kiro/specs/)
- Explore page, with the dependency graph: <https://samdengler.github.io/verified-air/graph/>
- A five-step tour for business readers: <https://samdengler.github.io/verified-air/tour/>
- Verified Airline, a fictional airline's site written from the model, in its own repository: <https://air.dengler.io/>

## Where to start

| You want to | Read |
| --- | --- |
| See at a glance what is proven, what is open, and what needs a business decision | The [home page](https://samdengler.github.io/verified-air/), then the [progress page](https://samdengler.github.io/verified-air/progress/) for every card |
| Understand the rules and the open question, without reading code | The [review document](https://samdengler.github.io/verified-air/review/): one chapter per requirement, with a try-it panel for delivery and refunds, then Open Questions |
| Use the requirements in a spec-driven flow | [`.kiro/specs/README.md`](.kiro/specs/README.md), then one `requirements.md` per area |
| Get the model explained in five steps | The [tour](https://samdengler.github.io/verified-air/tour/) |
| See the rules as an airline's customer policies | The [Verified Airline site](https://air.dengler.io/): fares, payment, changes, refunds, extras and schedule changes in a traveler's words. Show the Lean model to see the requirement behind each answer; [Verified Airline, the airline demo](#verified-airline-the-airline-demo) explains how this repository feeds it |
| See which rules rest on which definitions, and what is proven | The [Explore page](https://samdengler.github.io/verified-air/graph/): a map of the areas, a matrix of the dependencies between them, every card, the history, and any card's neighbourhood. Each area has a summary page under `/area/`. The blueprint's own graph is at [`/blueprint/dep_graph_document.html`](https://samdengler.github.io/verified-air/blueprint/dep_graph_document.html) |
| See which ONE Order rules are candidates for the model next | [`docs/one-order-survey.md`](docs/one-order-survey.md) |
| See how much of ONE Order the model covers | [`docs/one-order-coverage.md`](docs/one-order-coverage.md): IATA's 63 business capabilities, each marked in Lean, candidate or not started |
| Check a service's code against the model | [Checking an implementation against the model](#checking-an-implementation-against-the-model), then [`impl/java`](impl/java/) and [`impl/rust`](impl/rust/) |
| Review or change the model | [`Rules/OfferOrder/`](Rules/OfferOrder/), then the rest of this README |

## Lean, proofs, and the refund example

[Lean](https://lean-lang.org) is a functional programming language and a proof
assistant. People use it to write ordinary programs, to formalize mathematics,
and to prove that software behaves as specified, all in the same language. In
this repository a business rule is an ordinary Lean
function, and a property the rule should have is a theorem: a claim about every
possible input. A test checks the inputs someone thought of; a proof covers all
of them. When the build succeeds, Lean has checked every proof. Checking
programs and rules this way is called formal verification.

The refund rule shows how this works. The rule as the business states it is
"a refund cannot exceed the payment it is made against". In Lean it is a
function that answers true or false for one payment and one refund:

```lean
def acceptRefund (p : Payment) (r : Refund) : Bool :=
  r.payment == p.id && decide (r.amount.amount ≤ p.amount.amount)
```

The property we expect is that refunds on an order never add up to more than
was paid for it (two hypotheses are left out here):

```lean
theorem refunds_le_payments ... :
    totalRefunded ps rs orderId ≤ totalPaid ps orderId := by
  sorry
```

`sorry` marks a proof that is missing. This one cannot be written, because the
claim is false for the rule as stated: two refunds of 60.00 USD against one
payment of 100.00 USD each pass the check and together return 120.00 USD. The
model holds that case as a computed example, and the build marks the theorem
**open**. The open theorem is a question for the business: does the limit apply
to each refund, to all refunds on a payment, or to all refunds on an order?
Once the business answers, the rule changes and the proof can be completed.
That was tried on a scratch branch: with a rule that counts earlier refunds,
the theorem was proven.

<img alt="Diagram: a business rule becomes a Lean definition and a theorem. If Lean accepts the proof, the rule has a guarantee. If not, the build reports a counterexample (two refunds of 60.00 against a payment of 100.00), which becomes a question for the business whose answer changes the rule." src="docs/diagrams/question-loop.svg" width="100%">

What a proof here does and does not cover: it is a statement about the Lean
model. It says nothing yet about whether a production service follows the
model. Comparing services against the model with generated tests is a later
step.

## How the build turns the model into documents

People write the Lean files, the prose chapters and the blueprint statements.
Everything else is computed, so no status or example value is typed by hand.

<img alt="Diagram: people write Rules/*.lean, the Review chapters and the blueprint statements. lake build checks the proofs and example values, lake exe status computes each theorem's and criterion's status, and render_status.py writes the review document, the dependency graph and PDF, and the requirement specs; the progress page shows the status of every rule and candidate. CSV exports come from the status step. CI fails on a rejected proof, a changed example value, a renamed rule, an unmarked open theorem, a malformed EARS line, or out-of-date requirement specs." src="docs/diagrams/build.svg" width="100%">

If someone renames a rule, the review document fails to build. If an example's
value changes, `lake build` fails. If a theorem is left unproven without being
marked as an open question, `lake exe status` fails. CI runs all of these on
every push.

The site's home page, written by `scripts/render_home.py`, is for a reader
with no context. It says what the project is in plain words, works through
one open guarantee (the rule, the guarantee, the example and what the rule
gives for it, and the question for the business), points each kind of
reader to a page, then shows the counts by status, the three questions whose
answers reach the most cards, and a card for each part of the site. The progress page at
`/progress/`, written by `scripts/render_progress.py`, is for business
readers. It shows every rule, guarantee and survey candidate as a card with a
status in plain words (modelled, proven, open question, needs a decision,
ready to build, waiting), the open questions grouped by area with the
counterexample behind each, and the open questions and decisions with the
most cards depending on them. The statuses come from `build/status.json` and
the text from the blueprint statements, so both pages change when the model
does. The review document is under `/review/`.

The model is split by business group. Shared concepts such as money and time
live in `Rules/Core/`, and each group gets its own directory under `Rules/`.
Offer and Order is the first group; the others in the diagram are not built.

<img alt="Diagram: Rules.OfferOrder, built, and Rules.Identity and Rules.DataGovernance, not built, each build on the shared Rules.Core namespace." src="docs/diagrams/namespaces.svg" width="100%">

## Checking an implementation against the model

The proofs above are about the Lean model. A service that a team ships is
separate code, so it needs its own check against the model. There are three
ways to do that, from quick and partial to slow and complete. Options 1 and 2
are built here for a Java implementation of the three rules,
[`impl/java`](impl/java/). Option 3 needs Rust, because Aeneas translates
Rust, and is built for a Rust implementation of two of the rules,
[`impl/rust`](impl/rust/). All three run in CI on every push.

<img alt="Diagram: the Lean model answers requests through a test oracle. Option 1 runs 24 fixed requests with the model's answers through the Java code. Option 2 generates thousands of inputs with jqwik, checks that Java and the oracle agree, and checks the model's theorems as properties of the Java code. Option 3 translates Rust code into Lean with Charon and Aeneas and proves it computes what the model computes, for every input." src="docs/diagrams/implementation-checks.svg" width="100%">

| Option | What it checks | What a pass means |
| --- | --- | --- |
| 1. Test oracle | `lake exe oracle --vectors` writes 24 requests with the model's answers: the inputs of the examples, the boundaries around expiry and the refund limit, and every delivery state and event. [`ConformanceVectorsTest`](impl/java/src/test/java/offerorder/ConformanceVectorsTest.java) runs each one through the Java code. | Java is right on those 24 cases. |
| 2. Property tests | [jqwik](https://jqwik.net) generates thousands of inputs. [`ModelAgreementProperties`](impl/java/src/test/java/offerorder/ModelAgreementProperties.java) sends each one to the running oracle and to the Java code and compares the answers. [`GuaranteeProperties`](impl/java/src/test/java/offerorder/GuaranteeProperties.java) restates each Lean theorem as a property of the Java code, tagged with its acceptance criterion. | Java is right on every input tried. This is strong evidence, but it is not a proof. |
| 3. Aeneas proof | [Charon and Aeneas](https://github.com/AeneasVerif/aeneas) translate the Rust implementation into Lean, and [`Verify/RustRules.lean`](Verify/RustRules.lean) proves it computes what the model's definition computes. | The Rust code is right on every input. |

### The test oracle and the conformance vectors

The oracle is the model itself, run by Lean's interpreter behind a JSON
interface: one request per line in, one answer per line out (see
[`Oracle/Handle.lean`](Oracle/Handle.lean)). The property tests keep it
running and ask it about each generated input.

The conformance vectors are the oracle's answers to a fixed list of requests,
saved as a file:
<https://samdengler.github.io/verified-air/conformance-vectors.jsonl>.
Each line is one case: a name, a request to one of the rules, and the model's
answer. For example, shortened:

```json
{"name": "accept at expiry",
 "request":  {"rule": "accept", "now": 1793102400, "orderId": "ORD-2",
              "offer": {"id": "OFF-1", "expiresAt": 1793102400, "currency": "USD", "items": [...]}},
 "response": {"error": "expired"}}
```

The 24 cases are the inputs of the first six `@[case]` examples in the model; the
boundaries around them (one second before, at and after expiry; a refund
below, equal to and one cent above the payment, and one against a different
payment); and every delivery state paired with every event, which are also the inputs
of the seventh example, `transitionTable`. The answers come
from the model, so nobody types an expected value, and a change to a rule
changes them on the next build.

The file needs nothing but a JSON reader. A team in any language can download
it and run each case through its own code, without installing Lean. The
property tests are more thorough, because they try new inputs on every run,
but they need the oracle running and so need the Lean build.

### What the checks catch

Changing the Java expiry check from `now >= expiresAt`
to `now > expiresAt` fails all three Java test classes: the vector "accept at
expiry", the agreement property (which shrinks to an empty offer accepted
exactly at expiry), and the `accept_rejects_expired` property. The open
question shows up too. The property for `refunds_le_payments` is marked as
expected to fail, and jqwik finds the counterexample on its own, shrunk to one
payment and two refunds against it that together exceed it. If the refund rule
is fixed, that property starts passing and the test fails until the
expectation is removed, just as the Lean theorem's `sorry` would be.

### Running the Java checks

The oracle needs the Lean build first:

```sh
lake build Oracle oracle
mkdir -p build/oracle && lake exe oracle --vectors > build/oracle/vectors.jsonl
mvn -f impl/java/pom.xml verify
```

### The Aeneas proofs for the Rust code

[`impl/rust/src/lib.rs`](impl/rust/src/lib.rs) implements `step` (OO-002) and
`accept_refund` (OO-003) in ordinary Rust. Charon reads the Rust compiler's
view of that file and Aeneas turns it into Lean:
[`Verify/Rust/OfferOrderRules.lean`](Verify/Rust/OfferOrderRules.lean), one
Lean function per Rust function. The translation models Rust exactly: a `u64`
can hold at most 2^64 - 1, and every function returns a result that would
record a panic or an overflow if one could happen.

[`Verify/RustRules.lean`](Verify/RustRules.lean) maps the Rust types to the
model's types and proves two theorems:

- `step_matches_model`: for every delivery state and event, the Rust `step`
  returns without failing and gives the model's answer.
- `accept_refund_matches_model`: for every payment and refund, the Rust
  `accept_refund` returns without failing and gives the model's answer.

The mappings are one-to-one, so no two Rust values stand for the same model
value. References are numbers in the Rust code and strings in the model, so
the refund theorem holds for any way of naming the numbers as strings, as long
as different numbers get different names.

The proofs catch real mistakes. Letting the Rust `step` cancel a delivered
service, or writing `<` instead of `<=` in the refund limit, makes the
corresponding proof fail once the Rust is translated again.

What is not covered: `accept` builds order references by joining strings, and
Aeneas does not handle Rust strings well, so it has no Rust version here. A
proof also says nothing about code outside the translated functions, such as
how a service reads its input or stores its result.

`Verify/Rust/` is generated and committed. CI translates the Rust again with
the pinned Aeneas release and fails if the result differs from the committed
file, so a change to the Rust code has to be translated and proved again
before it can be merged.

The review document's try-it panels run the same two functions in the
reader's browser: `scripts/build-wasm.sh` compiles them to WebAssembly through
`impl/wasm`, a wrapper that passes the panels' inputs to them and is not part
of the proof.

### Running the Rust checks

```sh
cargo test --manifest-path impl/rust/Cargo.toml
scripts/translate-rust.sh     # Charon and Aeneas: impl/rust to Verify/Rust/
lake build Verify             # the proofs
```

`scripts/translate-rust.sh` downloads the pinned Aeneas release, which
includes Charon, into `.aeneas/`, and installs the nightly Rust toolchain
Charon needs with rustup.

## Verified Airline, the airline demo

Verified Airline is a fictional airline whose site, at
<https://air.dengler.io/>, answers a traveler's
questions from the model: a home page, a travel policies hub, and six policy
pages on fares, payment, changes and cancellations, refunds, extras, and
schedule changes. They read as an ordinary airline's pages. The button "Show
the Lean model" adds a ∀ marker beside each section, which opens the
requirement behind it, the statuses of its criteria, and a link to its
chapter in the review document. Where a criterion is open, the page says the
point is still being decided. The site has its own repository,
[`samdengler/verified-airline`](https://github.com/samdengler/verified-airline),
whose README describes the pages; decision 50 explains the move.

This repository builds the files the site reads, served under
`/airline-data/`, so nothing on the airline's pages is typed by hand:

- `facts.json`. `Airline/Fares.lean` writes the three fares, Basic, Main and
  Flex, as change and cancel rules of the model (`Restriction`), one for each
  action and stage of a journey after payment. `lake exe airline-facts` loads
  them in Lean's interpreter, as `lake exe oracle` loads the rules, and
  evaluates `ruleInForce`, `voluntaryChange` and `cancellationRefund` for
  every fare and stage, and `priceDifferential` for the worked change. It does
  so under every reading the model leaves open (whether expiration dates end
  rules, which amount a refund marked full and fixed returns, what happens to
  a penalty above the refundable value) and both ways of charging a fee, and
  fails if any two give different answers. The fares avoid those points, so
  no reading is chosen for the business. The output is
  `build/airline-data/facts.json`.
- `model.json`. `scripts/export_airline.py` writes every requirement from
  `build/status.json`, with its EARS statement, its criteria and their
  statuses, and the address of its chapter; for each criterion an open
  theorem checks, the start of the question and the address of its section;
  and the commit the files were built from.
- `theorems.json`. `Airline/Theorems.lean` states each change and
  cancellation fact as a theorem for every input in its stage: every journey
  and instant in the stage once the fare terms have started, every item or
  change request, and every reading of the guide. `probes_in_stage` proves
  that the journey and instant the facts evaluate are in their stage, so each
  fact is its theorem at that point. `lake exe airline-facts --theorems`
  lists each fact's theorem, named after the fact's key in `facts.json`, and
  fails if a fact has none or its theorem depends on `sorry`.
  `scripts/export_airline.py` adds a link to each theorem's line at the
  build's commit. Under `general` it lists the theorems of the support chat's
  rules that hold for every fare, and of what the chat takes as given about
  amounts. The airline's support chat cites them.
- `ar-policy.json`, `ar-rules.json` and `ar-checks.json`.
  `scripts/export_airline_policy.py` writes the support chat's Automated
  Reasoning policy from `facts.json` and `model.json`: a rule for each fact,
  the general rules, and what the chat takes as given; each rule's Lean rule,
  requirements, sentence for people and theorems from `theorems.json`; and a
  right and a wrong answer for each rule. It stops if a rule has no theorem.

The airline's repository commits a copy of the files, so its site shows a
pinned version of the model until its `scripts/update-model.sh` takes a newer
one.

`scripts/check-airline.sh`, which CI and `scripts/build-site.sh` run, renders
the airline's pages with that repository's own script from this build's
files. It fails if a content file cites a requirement or criterion the model
does not have, lists as still being decided a criterion that is no longer
open, uses a placeholder the facts do not have, types an amount, or leaves a
section without a marker; and if a page shows a requirement ID or the words
rule, theorem or criterion while the model is hidden. So a proof that closes
an open question stops this build until the airline's wording is updated.
The `Airline` namespace is outside `Rules`, so the status counts and the
specs do not include it.

## How this repository was made

[Claude Code](https://claude.com/claude-code), Anthropic's coding agent, built
this repository from a written implementation plan. The plan had six steps:
the Lean project and shared concepts, the Offer and Order rules, the checked
examples, the review documents, the EARS output, and CI. It also had ten
acceptance criteria. Claude Code committed after each step; the
[commit history](https://github.com/samdengler/verified-air/commits/main)
shows them in order. The requirement specs and the implementation checks were
added afterwards on request. Where
the plan left a choice open, the choice is recorded under
[Decisions](#decisions). [Results](#results) gives the check of each
acceptance criterion.

The domain comes from IATA's Offers and Orders standard,
[ONE Order](https://www.iata.org/en/programs/airline-distribution/retailing/one-order/).
The objects in the model (offer, offer item, order, order item, and the
delivery status of a service) follow the standard's concepts, and the
docstrings name the ONE Order concept each corresponds to. The rules, prices
and data are simplified and invented for this proof of concept; they are not
transcribed from the standard. Writing the standard itself as a Lean namespace,
and proving where an airline's own rules match or differ from it, is a planned
next step.

The [ONE Order survey](docs/one-order-survey.md) lists 23 candidate rules for
the next round, from IATA's public implementation guide and Resolution 797.
Each is classified as a decision or an invariant, and by whether the source
states it clearly, vaguely, or not at all; the vague and silent ones are where
formalizing is expected to raise questions for the business. The guide's
notice does not permit reproducing its text, so the survey quotes nothing and
links to each page.

The candidates are also nodes in the second chapter of the
[blueprint](https://samdengler.github.io/verified-air/blueprint/),
so they appear on the dependency graph before any of them is written in Lean.
The 12 vague or silent ones are marked not ready and have an orange border; the
open point in each says what the business has to decide. The git tag
`one-order-candidates` marks the commit that added them, so the graph at that
tag can be compared with the graph after the rules are formalized.

The rules, user stories and acceptance criteria are drafts. The Offer and
Order team has not reviewed them yet.

## The two review layers

| Layer | Source | Published at |
| --- | --- | --- |
| Verso document: prose with checked Lean inside it | `Review/` | `/review/` |
| leanblueprint: dependency graph colored by status, plus a PDF | `blueprint/src/content.tex` | `/blueprint/` and `/blueprint/print.pdf` |

The requirements are also published as requirement specs, one folder per Lean
module that holds rules, in [`.kiro/specs/`](.kiro/specs/). The acceptance
criteria are written in EARS, and the files follow the layout Kiro reads, so
opening this repository in Kiro shows them as specs; other spec-driven tools
can read the same Markdown. Each `requirements.md` has the module's
introduction, and for each rule its user story, its EARS statement, and its
acceptance criteria in Kiro's `WHEN ... THE SYSTEM SHALL ...` notation. Each
criterion carries its ID and the status the build computed for it.
[`.kiro/specs/README.md`](.kiro/specs/README.md) indexes them with every
criterion's status.

The same requirements are also exported as CSV, for tools that import rows
rather than read Markdown: a spreadsheet, a requirements tracker such as Jira,
a dashboard, or a script.

| File | One row per | Columns |
| --- | --- | --- |
| [`ears.csv`](https://samdengler.github.io/verified-air/ears.csv) | rule | ID, EARS statement, Lean declaration, status, theorems that prove it |
| [`ears-criteria.csv`](https://samdengler.github.io/verified-air/ears-criteria.csv) | acceptance criterion | ID, parent rule, EARS statement, EARS template, status, theorems and examples that check it |

Both are rebuilt on every push at fixed URLs, and their IDs never renumber, so
a tool can pull them on a schedule. Because each row carries a computed status,
comparing two versions shows which criteria changed, for example OO-003.2
moving from open to proven once the refund question is answered.

Both layers are built from the same commit and take their status from the same
file, `build/status.json`, which `lake exe status` computes from the compiled
Lean.

## Authored and computed parts

Authored, and reviewed against the Lean by a second person:

- Docstrings in `Rules/` (they are the prose of both layers, written in Verso
  markup). A rule's docstring holds its `EARS:` statement, a `Story:` line, and
  its acceptance criteria as list items (`* OO-001.1: If ...`).
- The `@[checks "OO-001.1"]` tags on theorems and examples, which say which
  criteria each one checks.
- The Verso chapters `Overview`, `Objects`, `Rules` and `Open Questions` in
  `Review/Review/`.
- The review document's stylesheet and script, `Review/review.css` and
  `Review/review.js`, and `Review/Review/Status.lean`, which adds the status
  labels and the block that places generated HTML in a page.
- The Given, When and Then lines in each example's docstring.
- The WebAssembly wrapper in `impl/wasm/`, which passes the try-it panels'
  inputs to the Rust rules.
- The blueprint statements in `blueprint/src/content.tex` (without `\leanok`).
- The Java implementation and its tests in `impl/java/`, and the oracle's JSON
  interface and vector inputs in `Oracle/Handle.lean`.
- The Rust implementation in `impl/rust/`, and the proofs about it in
  `Verify/RustRules.lean`.
- Verified Airline's fares in `Airline/Fares.lean`, and the theorem of each
  fact about them in `Airline/Theorems.lean`. The wording of its pages is in
  the airline's own repository.

Computed by the build, never typed:

- Whether each theorem is proven or open: `lake exe status` checks the axioms
  each theorem depends on for `sorryAx`.
- Example values: each `@[case]` declaration is evaluated by `lake exe status`,
  and each `#guard` in `Rules/OfferOrder/Examples.lean` fails the build if a
  value changes.
- The EARS table (`build/ears.md`, `build/ears.csv`), from the `EARS:` line of
  each rule's docstring and its `@[ears "OO-00n"]` ID.
- Each acceptance criterion's status, from the theorems and examples that
  check it: open if a checking theorem is open, proven if one is proven,
  example only if only examples check it, and not checked otherwise. The
  criteria go to `build/ears-criteria.csv` and into the requirement specs.
- The requirement specs in `.kiro/specs/`. These are committed so they can be read on
  GitHub and opened in Kiro, and CI fails if the committed copies differ from
  what `scripts/render_status.py` writes.
- The Lean translation of the Rust code in `Verify/Rust/`, generated by Charon
  and Aeneas and committed; CI fails if it differs from a fresh translation.
- The conformance vectors' expected answers (`build/oracle/vectors.jsonl`),
  from the model through `lake exe oracle --vectors`.
- The home page at the site root, by `scripts/render_home.py`, and the
  progress page at `/progress/`, from `build/status.json` and the
  blueprint statements, by `scripts/render_progress.py`; the Explore page at
  `/graph/`, from the same sources, by `scripts/render_graph.py`; a summary
  page per area under `/area/`, by `scripts/render_areas.py`; and the tour at
  `/tour/`, by `scripts/render_tour.py`. What they share (counts by area,
  dependencies between areas, how many cards depend on each card) is computed
  once, in `scripts/graph_model.py`.
- `\leanok` markers in the blueprint, and the review document's requirement
  chapters and EARS table, written by `scripts/render_status.py` into
  `blueprint/src/*.generated.tex` and `Review/Review/Generated/`. A
  requirement chapter's criteria table, its guarantee and example sections,
  the readable form of each example's result, and the delivery state diagram
  all come from `build/status.json`.
- The try-it panels' answers, from the Rust functions compiled to
  WebAssembly by `scripts/build-wasm.sh`.
- The motion piece, `motion/out/history.mp4` and its poster, drawn from
  `history/` by `scripts/render-motion.sh`. It is committed, since CI does not
  render video; its storyboard and captions are authored in
  `motion/src/story.ts`.
- Every amount on Verified Airline's pages, in `build/airline-data/facts.json`,
  from the model's functions by `lake exe airline-facts`; and the statuses
  they show, in `build/airline-data/model.json`, by
  `scripts/export_airline.py`; and the theorem of each fact, in
  `build/airline-data/theorems.json`, by `lake exe airline-facts --theorems`
  and the same script; and the support chat's Automated Reasoning policy, in
  `build/airline-data/ar-policy.json`, `ar-rules.json` and `ar-checks.json`,
  by `scripts/export_airline_policy.py`.

`lake exe status` exits nonzero if any declaration depends on `sorry` without
the `@[open_question]` tag, if an EARS statement or acceptance criterion does
not follow exactly one EARS template, if a rule lacks a story or criteria, or if
a `@[checks]` tag names a criterion no rule defines. CI runs it before
rendering anything.

## Building locally

Prerequisites: [elan](https://github.com/leanprover/elan), Python 3.12,
graphviz, a TeX installation with `xelatex` and `latexmk` (TinyTeX works),
Java 21 with Maven, and rustup for the implementation checks.

```sh
lake exe cache get                      # prebuilt Mathlib, once
lake build                              # the Rules library
lake exe status                         # build/status.json, ears.md, ears.csv, ears-criteria.csv
python3 scripts/render_status.py        # .kiro/specs and the generated review sections
python3 scripts/diagrams.py             # the README diagrams in docs/diagrams/
lake build Oracle oracle                # the test oracle for implementation checks
lake build Airline airline-facts        # Verified Airline's fares, then:
lake exe airline-facts > build/airline-data/facts.json
lake exe airline-facts --theorems > build/airline-theorems.json
python3 scripts/export_airline.py       # model.json and theorems.json, after the review document
python3 scripts/export_airline_policy.py  # the support chat's policy, from the three files above
lake build Verify                       # the proofs about the Rust implementation

python3 -m venv .venv && . .venv/bin/activate
pip install leanblueprint               # on macOS with Homebrew graphviz, set
                                        # CFLAGS=-I$(brew --prefix graphviz)/include
                                        # LDFLAGS=-L$(brew --prefix graphviz)/lib
scripts/preview.sh                      # the documents only, served at http://localhost:8000
scripts/build-site.sh                   # everything CI builds, assembled in site/
scripts/render-motion.sh                # the motion piece in motion/out/ (Node 24); commit it
```

`scripts/preview.sh` is the quick loop for changes to the documents: it
rebuilds the model, the status, the review document, the blueprint web pages
and the progress page, assembles `site/`, and serves it. It skips the Java
checks, the Rust proofs and the blueprint PDF, which take the longest; a PDF
or conformance vectors from an earlier full build are included if present.
Lake rebuilds only what changed, so a second run takes a minute or two.

`scripts/build-site.sh` runs everything CI runs, in CI's order, and
assembles `site/` the same way. Both scripts and CI lay out the site with
`scripts/assemble-site.sh`.

CI keeps the compiled Lean from its last run and the compiled Verso,
checkdecls and Aeneas libraries in GitHub's cache, so a push rebuilds only
the modules that changed. A push that changes only the README or `docs/` does
not run CI, since the site does not include them.

## Versions

| Tool | Version |
| --- | --- |
| Lean | `leanprover/lean4:v4.35.0` |
| Mathlib | tag `v4.35.0` |
| Verso | tag `v4.35.0` |
| Aeneas | release `nightly-2026.10.26-da2b22e` (binary, bundled Charon, and Lean library) |
| Rust | stable for `cargo test`; `nightly-2026-09-17` for Charon |
| checkdecls | `master` at `3d42585` |
| leanblueprint | 0.0.20 |
| Java | 21 (Temurin) |
| Maven | 3.9 |
| JUnit | 5.11.4 |
| jqwik | 1.9.2 |

`lake-manifest.json` pins every Lean dependency to a commit, and
`impl/java/pom.xml` pins the Java ones.

## Results

Checked on 2026-10-24 against the plan's acceptance criteria. CI run:
[40113345785](https://github.com/samdengler/verified-air/actions/runs/40113345785).

| # | Criterion | Result |
| --- | --- | --- |
| 1 | `lake build` from a clean clone after `lake exe cache get`, under 10 minutes | Pass. Clean clone: `lake exe cache get` 65 s, `lake build` 15 s. In CI the lean-action step (cache plus build) takes about 3 minutes. |
| 2 | `lake exe status` writes `status.json` and `ears.md`, three proven, one open, exit 0 | Pass. `Rules.OfferOrder`: 3 proven, 1 open (`refunds_le_payments`). It also writes `ears.csv`. |
| 3 | Rejecting a second refund against a payment lets `refunds_le_payments` be proven | Pass, on a discarded branch. `acceptRefund` took the list of refunds already accepted and rejected a second refund against the same payment. The theorem's hypothesis then says each refund was accepted given the ones before it. The proof closed without `sorry`, and `lake exe status` reported 4 proven, 0 open, exit 0. |
| 4 | Changing a `#guard` expected value by one unit fails `lake build` | Pass. `24500` to `24501` failed `Rules.OfferOrder.Examples`; reverted. |
| 5 | `checkdecls` passes; graph shows the open theorem uncolored and the rest green | Pass. All 24 defined or proven nodes are green; `refunds_le_payments` has no fill (see Decisions). |
| 6 | Verso document builds; renaming `accept` to `acceptOffer` fails it | Pass. The rename failed at `Review/Review/Rules.lean:21` ("Unknown identifier `Rules.OfferOrder.accept`"). `render_status.py` also refused, because `content.tex` names `accept`. Reverted. |
| 7 | Examples chapter shows six cases whose values match the `#guard`s | Pass. Six cases; values come from `lake exe status`. |
| 8 | `build/ears.csv` has three rows, OO-001 to OO-003 | Pass. |
| 9 | CI green on `main`; Pages serves the Verso document at the root and the blueprint at `/blueprint/` with a working PDF link | Pass, after making the repository public (see Decisions). |
| 10 | README covers the two layers, authored and computed parts, the local build, and Decisions | Pass. |

**Pages URLs.**

- Progress page: <https://samdengler.github.io/verified-air/>
- Verso document: <https://samdengler.github.io/verified-air/review/>
- Blueprint: <https://samdengler.github.io/verified-air/blueprint/>
- Explore page, with the dependency graph: <https://samdengler.github.io/verified-air/graph/>, and the blueprint's own graph: <https://samdengler.github.io/verified-air/blueprint/dep_graph_document.html>
- Tour: <https://samdengler.github.io/verified-air/tour/>
- PDF: <https://samdengler.github.io/verified-air/blueprint/print.pdf>
- EARS table, one row per rule: <https://samdengler.github.io/verified-air/ears.csv>
- Acceptance criteria, one row per criterion: <https://samdengler.github.io/verified-air/ears-criteria.csv>
- Requirement specs, rendered on GitHub: <https://github.com/samdengler/verified-air/tree/main/.kiro/specs>
  (the same files are on Pages under `/specs/`)
- Conformance vectors for implementation checks: <https://samdengler.github.io/verified-air/conformance-vectors.jsonl>

## Decisions

Choices made where the plan left room, in the order they came up.

1. **Lean version.** Mathlib master pinned `v4.36.0-rc1`, and Verso has a tag
   with the same name, so Mathlib, Verso and the toolchain all used
   `v4.36.0-rc1`. Mathlib and Verso are pinned by tag in `lakefile.toml`. Their
   shared dependencies (plausible, Cli) resolve to the same commits. The
   repository later moved to the `v4.35.0` release; see decision 27.
2. **Cache download.** `lake new ... math` runs `lake exe cache get` itself.
   That first run downloaded the Mathlib cache; the `lake update` and
   `lake exe cache get` in Step 1 then had nothing left to fetch.
3. **Linter.** The template's `weak.linter.mathlibStandardSet` is removed; it
   enforces Mathlib's copyright header and style rules, which do not apply
   here. `autoImplicit = false` is set as the plan asks.
4. **`public` is a keyword** in this Lean version, so the first
   `Classification` constructor is written `«public»`.
5. **`Instant` ordering.** `LinearOrder` cannot be derived, so it is lifted
   from `epochSeconds` with `LinearOrder.lift'`.
6. **Amounts in minor units.** The plan's refund example uses 60, 100 and 120.
   The model stores minor units, so the case uses 6000, 10000 and 12000 cents
   (60.00, 100.00 and 120.00 USD).
7. **`accept` also rejects mixed currencies**, since `Rejection` has a
   `mixedCurrency` constructor. The checks run in the order expiry, empty offer,
   currency.
8. **Distinct payment IDs.** `refunds_le_payments` assumes the payment IDs are
   distinct. Without that, the statement fails even after the refund rule is
   fixed, for a reason unrelated to the business question. The double-refund
   counterexample uses one payment, so it still applies.
9. **What the status executable lists.** Only documented declarations are
   listed, so derived instances, structure projections and helper lemmas
   without docstrings are left out. Proven and open counts are reported per
   namespace. The acceptance count (three proven, one open) refers to
   `Rules.OfferOrder`; `Rules.Core` adds two proven lemmas (`public_le`,
   `Money.add_same_currency`).
10. **Example values** are computed with `Lean.Meta.evalExpr` inside the status
    executable (built with `supportInterpreter = true`). The `#eval` fallback
    was not needed. The executable imports only `Rules.Core.Attributes` and
    loads `Rules` from its `.olean` files at run time. Importing all of `Rules`
    made linking compile Mathlib's native code, which took 14 minutes in CI.
11. **Docstrings use Verso markup** (`doc.verso = true` for the whole
    package). Code spans carry roles: `{name}` for model declarations (a rename
    breaks the docstring), and `{lit}` or `{lean}` for literals and terms.
    `Status/Main.lean` turns the option off, since its comments are for
    developers.
12. **Generated Verso modules.** The plan names one `Generated.lean`. Each Verso
    chapter is its own module, so the script writes three:
    `Review/Review/Generated/Guarantees.lean`, `Examples.lean` and `Ears.lean`.
    They are gitignored and regenerated on every build, as are
    `blueprint/src/*.generated.tex`. (Decision 29 later replaced the Guarantees
    and Examples chapters with one chapter per requirement.)
13. **Verso layout.** The `Review` library has `srcDir = "Review"`, so its
    chapters sit in `Review/Review/`. The `review-doc` executable's root is
    `Review/Main.lean`. Verso writes `build/review/html-multi/`, and that
    directory becomes the site root.
14. **Statement in the Guarantees chapter.** Each guarantee shows its Lean
    statement twice: in the `{docstring}` box, which renders the full signature,
    and in a checked ```` ```lean ```` block (`#check @name`). (Decision 28
    later removed the `#check` block.)
15. **`leanblueprint new` answers:** checkdecls yes; doc-gen4 no (the Verso
    document takes the place of API docs); Jekyll home page no; CI yes. The
    generated `blueprint.yml` and the template's other three workflows were
    then folded into `ci.yml`.
16. **Graph colors.** Proven theorems get `\leanok` on both the statement and
    the proof, so they fill dark green. The open theorem gets neither. By
    default leanblueprint would fill it light blue ("ready to prove");
    `\graphcolor{can_prove}{}{No}` in `macros/web.tex` leaves it unfilled. Its
    blue border still says the statement is ready.
17. **Blueprint to Verso links.** leanblueprint links each `\lean{}` name to
    `{dochome}/find/#doc/<name>`. `\dochome{../docs}` points that link at
    `pages/docs/find/index.html`, a small redirect into Verso's own
    `find/?name=<name>` page, which jumps to the declaration's section.
18. **CI step order.** `render_status.py` runs before the Verso build, because
    it writes chapters the build imports. `leanblueprint web` runs before
    `checkdecls`, because `web` writes the `lean_decls` file that `checkdecls`
    reads.
19. **TeX in CI.** CI installs TinyTeX instead of `texlive-full`, matching the
    local setup, which also uses TinyTeX. It is far smaller, and its default
    package set built the PDF with no additions. CI runs `tlmgr update --self`
    first, because the installer's `tlmgr` refused to install packages until
    it was updated. CI's TinyTeX has fewer packages than the local one, so CI
    installs every package the local PDF build loads, read from `print.fls`. CI also caches the compiled Verso packages, keyed on
    `lake-manifest.json`.
20. **Pages deploys from `main` only.** Pull requests build and upload the
    site but do not deploy it.
21. **The repository is public.** The plan asked for a private repository.
    GitHub refused Pages for it on this account's plan ("Your current plan does
    not support GitHub Pages for this repository"), so the repository was made
    public with Sam's approval, and Pages was enabled with GitHub Actions as
    the source. The deploy job still checks the repository variable
    `PAGES_ENABLED` (set to `true`), so a fork or a copy without Pages keeps a
    green build.
22. **EARS outputs.** The status executable writes `build/ears.csv` along with
    `ears.md`. "Proven by" lists every theorem whose statement mentions the
    rule, so OO-001 lists both `accept` theorems.
23. **Branch protection** is not turned on for the POC. CODEOWNERS names
    `@samdengler` on every path.
24. **Acceptance demos.** The demos (fixing the refund rule, changing a
    `#guard`, renaming `accept`) were run locally on a branch or as uncommitted
    edits, then discarded, as the plan says.
25. **Requirement specs and acceptance criteria** (added after the plan, at
    Sam's request). The requirement specs are Markdown in the layout Kiro
    reads, so they can be used with Kiro's spec-driven flow; `ears.csv` stays
    as an extra export. They were first called Kiro specs; the name changed so
    that it does not suggest Kiro is required. Decisions:
    - One spec folder per Lean module that holds rules, named from the
      namespace and the module's title, for example
      `offer-order-accepting-an-offer`. The module docstring becomes the
      introduction.
    - Criterion IDs extend the rule's ID (`OO-001.1`) and are written by hand
      in the docstring, like the rule IDs, so they never renumber.
    - The EARS text stays in standard form in the docstrings ("When X, the
      system shall Y"). The spec files print it in Kiro's notation
      (`WHEN X THE SYSTEM SHALL Y`, `IF X THEN THE SYSTEM SHALL Y`).
    - A criterion's status is computed from what checks it, but whether a
      theorem's statement covers the criterion's wording is a review question:
      the `@[checks]` tag is authored.
    - An example that checks an open criterion is labelled a counterexample.
    - Four criteria (OO-002.2, OO-002.3, OO-002.5, OO-003.1) have no theorem or
      example yet and are shown as not checked. Adding theorems for them would
      change the proven count the acceptance criteria fix at three. (Decision
      29's `transitionTable` example later checks the first three.)
    - Only `requirements.md` is generated; `design.md` and `tasks.md` belong to
      the team using the spec.
26. **Implementation checks** (added after the plan, at Sam's request). The
    target teams use Java, so options 1 and 2 are shown on a Java
    implementation; option 3 needs Rust because Aeneas translates Rust.
    - The oracle runs the model in Lean's interpreter, loading `Oracle.Handle`
      from its `.olean` files like `lake exe status` does. Compiling the rules
      into the executable would link Mathlib's native code.
    - The JSON shapes are the ones Lean derives for the model's types, so the
      oracle adds no mapping of its own. The Java tests do the mapping.
    - Lean's amounts are natural numbers; Java uses `long`. The generators
      produce only non-negative amounts below 50,000, so the two agree on every
      generated input.
    - Inputs are generated close together (instants around expiry, three
      shared payment IDs) so that boundaries and repeated refunds come up
      often.
    - The open theorem's property uses jqwik's `@ExpectFailure`, the Java
      counterpart of `@[open_question]`.
27. **Aeneas and the move to Lean `v4.35.0`.** The proofs about the Rust
    code need the model and Aeneas's Lean library in one build, and that
    library is pinned to Lean and Mathlib `v4.35.0`. The repository moved from
    `v4.36.0-rc1` to the `v4.35.0` release, which Verso also tags. The status
    counts, the review document and the conformance vectors came out the same.
    - The Aeneas binary and its Lean library are pinned to the same release,
      `nightly-2026.10.26-da2b22e`. Aeneas publishes nightly releases only.
    - The Rust code uses numbers for references, because Aeneas handles
      integers and not strings. The refund theorem therefore takes any
      one-to-one naming of numbers as strings.
    - `accept` has no Rust version, because it joins strings to make order
      references.
    - The generated Lean in `Verify/Rust/` is committed, like the requirement specs,
      and CI checks that it matches a fresh translation.
28. **A progress page at the site root.** The blueprint's layout is fixed by
    leanblueprint and reads like a mathematics paper, so business readers get
    their own page. `scripts/render_progress.py` generates it from the same
    data as the blueprint, so it adds nothing that can drift. The review
    document moved from the site root to `/review/`, and its links to the
    blueprint and the CSV files now go up one level.
    - Cards are grouped by blueprint section, and the graph colors become
      words: modelled, proven, open question, needs a decision, ready to
      build, waiting.
    - The open refund theorem's blueprint text was split into a counterexample
      and an open point, the labels the page and the candidate nodes share.
    - The dependency map is drawn top to bottom without area boxes. With the
      boxes, Graphviz routed long edges across the areas.
    - The review document has the same look. `Review/review.css` overrides
      Verso's theme variables and is read by `lake exe review-doc` when it
      runs, so a change to the stylesheet needs no Lean rebuild. A small Verso
      role, `{status "proven"}[Proven]`, gives the generated chapters the
      same status labels as the progress page.
    - Each docstring is shown as a card: a plain label (object, rule,
      calculation, guarantee, example), the description, the fields or
      values as a list, and the Lean form in a small footer. Guarantees are
      titled with their blueprint titles and examples with their names in
      words, and the sidebar lists sections without every Lean name. The
      Guarantees chapter no longer repeats each statement in a `#check`
      block, since the docstring card already fails the build if the name is
      wrong.
29. **The review document is organized by requirement** (added at Sam's
    request, with the readable examples, the state diagram and the try-it
    panels). Business readers think one rule at a time, so each requirement
    gets a chapter: the rule, a table of how each acceptance criterion is
    checked and its status, the guarantees, the examples and any open
    question. Objects and the EARS table follow as reference chapters.
    - `scripts/render_status.py` writes the chapters as
      `Review/Review/Generated/OO00n.lean` and fails if `Review/Review.lean`
      does not include one of them.
    - Examples state Given, When and Then in their docstrings. Their results
      are parsed from the value Lean prints and shown in business terms:
      amounts as 245.00 USD, instants as UTC times, lists of records as
      tables. A result that does not parse is shown as Lean printed it. The
      two examples that returned tuples now return records whose field names
      label each part.
    - A new example, `transitionTable`, runs every delivery state and event
      through `step`. Its `#guard`s fix the three allowed moves and the count
      of 12, and the review document draws the state diagram from its value.
      It also checks OO-002.2, OO-002.3 and OO-002.5, which no example
      checked before.
    - The try-it panels call `step` and `accept_refund` from `impl/rust`,
      compiled to WebAssembly through a wrapper crate, `impl/wasm`. The
      proofs in `Verify/RustRules.lean` are about those two functions; the
      wrapper and the page's script are not proved, and the panels say so.
      The refund panel adds up the accepted refunds itself to show the open
      question.
    - The review document's front page shows a card per requirement, with its
      user story and the computed status of its criteria, then the reference
      chapters as a list. `scripts/render_status.py` writes the cards into
      `Review/Review/Generated/Front.lean`. Verso's own chapter list is
      hidden there, since the sidebar shows it.
    - Every page has the same bar at the top: the site name and links to the
      progress page, the review document, the dependency graph and GitHub.
      `scripts/site_nav.py` defines it. The progress page uses it directly,
      `scripts/assemble-site.sh` runs it on the blueprint's pages to replace
      their header (keeping the blueprint's contents button), and
      `Review/review.js` builds the same bar inside Verso's header, which
      keeps Verso's search box.
    - The dependency graph has its own page, `/graph/`, drawn by
      `scripts/render_graph.py` in the style of the progress page. The script
      places the nodes in rows below the nodes they use, at most 14 to a
      row; the page draws flat cards with a status line and
      light connectors. Every status has its own color, used the same way on
      every page: In Lean magenta, Proven green, Open question red, Needs a
      decision amber, Ready to build blue, Waiting grey and dashed. Finished
      states get a lighter rim than the ones that need attention. The colors
      were checked against each other for color-blind readers, and every
      status also carries its label. A reader
      can move and zoom, and clicking a card dims the rest and opens a panel
      with its statement, open point, source, Lean names, and what it
      depends on and what uses it. leanblueprint's graph stays at
      `/blueprint/dep_graph_document.html` for the blueprint's own legend.
    - Every card and map box on the progress page is a link, resolved
      through Verso's own lookup (`review/find/?…`) so a moved chapter keeps
      working: a rule opens its requirement chapter at the top, a guarantee
      opens its section heading in that chapter (tagged
      `guarantee-<name>` by `scripts/render_status.py`), and a candidate opens
      its node in the dependency graph. A graph address ending in `#` and a node's label,
      such as `graph/#def%3Ac06-item-status`, opens with that node selected;
      selecting a node updates the address, so a selection can be shared.
    - The blueprint follows the reader's dark-mode setting too, through
      `blueprint/src/extra_styles.css`. In the dependency graph only the
      black edges and text change, and blue borders lighten; the green fills
      keep the meaning the legend gives them.
30. **Renamed from `business-rules-verified` to `airline-order-verified`.**
    The new name says what the rules are about without using IATA's name,
    which could suggest the project is IATA's or endorsed by it. The site
    moved with the repository to `samdengler.github.io/airline-order-verified/`.
    GitHub redirects the old repository URLs; GitHub Pages does not redirect
    a renamed project's site. The site is called Airline Order in its top
    bar, page titles and document titles, with a plane as its mark and tab
    icon (`PLANE_PATH` in `scripts/site_nav.py`, repeated in
    `Review/review.js`).
31. **The review-doc program loads the document when it runs.** CI spent most
    of its time compiling about 2,800 Mathlib modules to native code so that
    `review-doc` could link the document, whose rules import `Mathlib.Tactic`.
    `Review/Main.lean` now imports only Verso and `Review.Status` (the
    document's own extensions, which Verso must have compiled in), and loads
    the compiled `Review` modules with `importModules`, as `lake exe status`
    and `lake exe oracle` already do. The program builds in 471 jobs instead
    of 6,767, and the HTML it writes is byte for byte the same.
32. **A starting-small branch, milestones and a graph history.** The
    `starting-small` branch and tag `snapshot/starting-small` keep the
    version to propose for an internal pilot, while `main` grows toward as
    much of ONE Order as the public material allows. Each milestone gets an
    annotated tag `milestone/<name>` and a snapshot of the graph in
    `history/`, written by `scripts/graph_history.py`, which also computes one
    layout for every node that has appeared so nodes keep their place across
    snapshots. The first three milestones were recorded after the fact from
    the blueprint's history. The site publishes the current graph at
    `/graph/graph.json`. `docs/motion-brief.md` describes how the snapshots
    can drive a motion piece about the graph's growth.
33. **ONE Order as published, in its own namespace.** `Rules.OneOrder`
    models the standard as IATA's public guide describes it: services with a
    service status and a delivery status, order items and orders, accepting an
    offer for several passengers and segments, and the item and order status
    rules (ONE-001 to ONE-003). The pilot rules in `Rules.OfferOrder` and
    their Java and Rust checks stay as they are; a later theorem can relate
    the two. The guide says which of five delivery statuses hold value and is
    silent on the other eight, so the model takes the answer as a parameter
    (`ValueReading`). A guarantee about value is proven only when it holds for
    every reading the guide allows; where a reading breaks it, the guarantee
    is open and an example shows the case. Open guarantees outside the pilot
    get a generated chapter, Questions from the ONE Order rules. Chapters find
    their guarantees and examples by criterion ID in any namespace, and section
    tags carry the namespace when a name repeats.
34. **A second survey round, C-24 to C-161.** Eight surveys, one per area,
    read each area's public pages in full and returned 160 candidates; 22
    duplicates across areas were merged. Every candidate is a blueprint node
    with its rule, a case to check where the sources suggest one, the open
    point for vague and silent rules, and links to its pages.
    `docs/one-order-survey.md` lists them and `docs/one-order-coverage.md`
    maps them to capabilities: every capability with high rule content now
    has candidates. With 200 nodes, Graphviz laid the dependency graph out
    in one row many thousands of pixels wide, so `scripts/render_graph.py`
    now places cards itself, in rows of at most 14 below the cards they use,
    ordered to keep connectors short. The progress page links to the graph
    instead of drawing its own map.
35. **Lenses on the dependency graph.** The whole graph shows how much there
    is; a reader needs a smaller view to follow it. The graph page lays out
    the cards in the browser, with the same row layout, so it can redraw a
    subset: one area with the cards it builds on (faded), or one card with
    everything it depends on and the cards that use it. The lens is kept in
    the address (`?area=Payment`, `?focus=<label>`), so a view can be shared.
    Areas are the blueprint sections. A lens by IATA capability code would
    need the codes on the blueprint nodes; they are in the survey data only.
36. **The ONE Order areas, written in parallel.** After the foundations, each
    area of the coverage map got its own folder, sub-namespace and range of
    requirement IDs (CLAUDE.md lists them), so several could be written at
    once. Each was written by an agent in its own git worktree, from a shared
    brief, and merged onto `main` by rebase after review and a full site
    build, with a milestone tag per area. Two were sent back before merging
    because they proved a guarantee by choosing a reading the sources leave
    open: creating one order from several offers, and the balance of an
    order's accounts. The rule for that is now in CLAUDE.md: the undecided
    part is a parameter, a guarantee is proven only under every reading, and
    a proven version for one reading is named with `_of_` and checks no
    criterion. The progress cards link to the dependency graph for anything
    the review document has no page for, using the review's cross-reference
    index, and the Objects chapter has the ONE Order foundation objects.
37. **A history page.** `/history/` plays the milestones on the dependency
    graph: cards appear as surveys find them and change color as areas are
    written in Lean, with the camera easing out as the graph grows. It is
    in the top bar, reads the same `history/` files as the motion piece
    (`scripts/render_history.py`), and keeps the milestone in the address
    (`?m=13`). Card titles in the shared layout come from the latest
    snapshot that has the card.
38. **An Explore page in place of the dependency graph and history pages.**
    With 429 cards the full graph shows how much there is and little else.
    Most of its dependencies stay inside one area, so the ones between areas
    reduce to a graph a reader can follow. The top bar's Dependency graph and
    History links become one link, Explore, which stays at `/graph/` so older
    links keep working. It has five views, kept in the address as
    `?view=area-map`, `matrix`, `all-cards`, `history` and `card`, with a
    selected card in the hash as before.
    - The area map is the first view: one box per blueprint section, with its
      status bar and counts, in layers from the foundations down, and an
      arrow to each area that builds on it, as thick as the number of
      dependencies. A box opens the area's summary page. Arrows for fewer
      than five dependencies are left out; the matrix counts them all.
    - The layers are set by hand in `AREA_LAYERS` in `scripts/graph_model.py`,
      since no ordering of the areas has every dependency pointing one way.
      A new blueprint section stops the build until it is placed there. A
      dependency on an area listed later points back: dashed on the map, and
      outlined in the matrix, where it sits above the diagonal.
    - The dependency matrix counts the dependencies between each pair of
      areas. Clicking a cell lists the cards behind the count.
    - All cards is the earlier graph page, with its area lens, and a lens by
      IATA capability.
    - History is the earlier `/history/` page drawn as clusters of dots: a
      box per area and a dot per card, which appear and change color by
      milestone. `/history/` sends readers to this view and keeps `?m=`.
    - A card's neighbourhood replaces the focus lens: the card in the middle,
      what it depends on to the left by distance, and what builds on it to the
      right, grouped by area, with the side panel's text beside it. Any card
      link (`graph/#<label>`) and the search box open it. The neighbourhood
      shows the cards that build on it directly, and all of them on request.
    - The area map, the matrix and the clusters are drawn by the build
      (`scripts/area_views.py`); the page's script (`scripts/explore.js`)
      draws the full graph and the neighbourhood, and is written into the
      page with `scripts/explore.css`.
39. **Decide these first.** The progress page ranks the ten open questions
    and decisions with the most cards depending on them, directly or through
    other cards, above the open question cards. Ties go to the one whose
    dependent cards span more areas. Each links to its neighbourhood.
40. **A summary page per area.** `/area/<slug>/` shows an area's cards by
    status, the areas it builds on and the areas that build on it, its open
    questions and decisions with the number of cards depending on each, its
    requirements with links to their chapters, and its IATA capabilities.
    Requirements are found through the Lean names on the area's blueprint
    nodes.
41. **If we decide this.** Many open guarantees have a version proven for
    one reading of the sources, named `<open name>_of_<reading>` and tagged
    with no criterion. The build pairs them by name only, and shows the
    proven theorem's docstring beside the open question, on the card's panel
    and on its area page, as a choice the business can make. When this was
    written, 18 of the 58 open guarantees had a pair; `python3 scripts/render_areas.py --unpaired`
    lists the others. Three proven `_of_` theorems name no open theorem
    (`history_rebuilds_of_oldestFirst`, `createOrder_guaranteed_of_reprice`,
    `recordOutcome_final_of_reading`), so their open guarantees show no pair
    until one of the names changes.
42. **IATA capability codes on the blueprint nodes.** Decision 35 noted that
    a lens by capability needed the codes on the nodes. Each candidate node
    now ends with a paragraph such as "Capabilities: ORDCAN, ORDCA2.", which
    `scripts/render_progress.py` reads like "Source:". The codes for C-24 to
    C-161 come from the survey data; those for C-01 to C-23 come from the
    coverage map's "In the model or blueprint" column, leaving out the two
    rows that say a capability is only close to a node. The names come from
    `docs/one-order-coverage.md`, and the build fails on a code it does not
    list. The All cards view filters by capability, and the area pages list
    their codes.
43. **A guided tour.** `/tour/` takes a business reader through the model in
    five static steps: the cards by status, the area map, the decisions that
    reach the most cards, the refund question with the example that breaks
    it, and the cards that depend on that question. The progress page links
    to it. The build stops if the refund guarantee is no longer open, since
    the tour's text would then be wrong.
44. **A motion piece rendered with Remotion.** `docs/motion-brief.md` left
    the tool open. Remotion renders a React composition frame by frame in
    headless Chrome, so the piece is code that reads the history files.
    `motion/` imports the snapshots, `history/layout.json` and
    `build/frames/frames.json`, checks them against each other, and draws the
    cards, connectors and counters from them, so no count or status is typed
    by hand. It follows the storyboard; the brief lists where it departs.
    Rendering needs Node and a headless Chrome and takes about a minute, so CI
    does not do it: `scripts/render-motion.sh` writes
    `motion/out/history.mp4` (1920 by 1080, H.264, about 9 MB) and its poster,
    both are committed, and `scripts/assemble-site.sh` copies them to
    `/motion/`. They are rendered again after each milestone. The History tab
    of the Explore page shows the film above the step control. It never
    starts by itself, so a reader who asks for reduced motion sees the poster
    until they press play. Remotion is free for individuals, for-profit
    companies of up to three employees and non-profits, and a larger company
    needs a company licence (`motion/README.md` links the terms).
45. **A fictional airline's policy pages.** `/airline/` shows the model as a
    traveler would meet it: Verified Airline's policies in plain words, with the
    Lean model hidden until a reader asks for it. The pages are static HTML
    with every popover already in the page, so they need no data fetching and
    read with scripts off. The fares are values of the model's existing
    `Restriction` type, evaluated by the model's own functions, so the fare
    table and worked examples could not be written without the model
    changing. The model's readings stay open: `lake exe airline-facts`
    evaluates every reading and fails if two disagree, and the fares are
    written so they do not (no expiration dates, no refund that is both full
    and fixed). The fares are invented. The six rows of the fare table extend
    the design mockup's four with changes after a missed flight and
    cancellations after the first flight. The page sources are in
    `airline-site/` because `airline/` and the Lean directory `Airline/` are
    one directory on macOS's default file system. A "still being decided"
    item names its open criterion, and the build stops when that criterion
    is proven, so the pages never keep a stale caveat.
46. **A home page, with the progress page at `/progress/`.** Decision 28 put
    the progress page at the site root. By the time the model had 58 open
    questions and over 400 cards, the page was about 100 screens long, and
    the open questions alone took 15, each in full and again as a card
    further down. The root is now a home page: the introduction and status
    tiles, a card for each part of the site with counts from the build, and
    the top three of "Decide these first". The progress page keeps every
    card. Its open questions are one line each, grouped by area, with the
    example and open point behind a click, and a table of contents beside
    the page (across its top on a phone) links every section. A script on
    the home page sends links to the old sections, such as `/#found`, to
    the same section of `/progress/`. On a phone the site bar keeps the
    plane, which leads home, and drops the site name.
47. **Fixes from the independent critique.** A review on 30 October compared
    every criterion with its theorems and the areas with each other, and
    found 30 problems. The fixes for the modelling errors:
    - Five rules outside Delivery set a service's delivery status directly,
      so a DELIVERED service could become REMOVED. Every rule that ends a
      service now goes through `Delivery.endWith`, which applies the event
      through the delivery status table and leaves the service as it was
      when the table refuses the move. `delivery_moves_follow_table` in
      `Rules/OneOrder/Consistency.lean` proves, for every rule that changes a
      delivery status, that it moves only along the table (ONE-105).
    - A cancellation is priced from the items that still hold a live
      service, so an item a change replaced is not refunded twice
      (ONE-203.5). The balance of an order still counts value, so an item
      whose services are all REMOVED HOLD VALUE counts there and not in a
      cancellation; which of the two a refund follows is open.
    - A payment with no payment method is FAILED, and is never accepted
      (ONE-301.4, ONE-304.7).
    - The reading of what an unpaid item becomes at its time limit is now the
      event that ends its services: REMOVED, REMOVED HOLD VALUE or EXPIRED,
      with the services cancelled.
    - Five criteria written for one reading were removed (ONE-101.5, 703.3,
      803.5, 804.6, 805.6); their theorems are `_of_` versions with no
      criterion.

    Going through the table made two gaps visible, which are now open
    questions: the table has no way to cancel a REQUESTED or UNABLE TO
    DELIVER service, so an unpaid order with one is not closed by
    cancelling it (ONE-203.2), and a flight the airline cancels can leave a
    REQUESTED or IN PROGRESS service live (ONE-704.6). The graph snapshot
    `critique-before-fixes` records the model as the critique found it, and
    the milestone `critique-fixes` the model after the fixes.
48. **The film plays one step at a time, and the build stops when it is
    stale.** The film was rendered before the critique's first snapshot was
    recorded, and nothing noticed. Its storyboard treated every milestone
    after the second survey as an area being written, so it could not even
    be rendered again. It now has a step for the review and one for the
    fixes. `scripts/render-motion.sh` records the milestones and a hash of
    `motion/src/` in `motion/out/history-film.json`, and
    `scripts/render_graph.py` stops the site build when they no longer
    match. The History tab plays the film in the nine steps of `STEPS` in
    `motion/src/story.ts`, listed under it with their start times: a step
    plays and stops on its last frame, and buttons go to the previous or
    next step, replay one, or play to the end. The story checks that
    nothing moves in the half second before each pause, so the page stops
    on a still frame with its caption in full. `motion/README.md` shows the
    film's last frame, linked to the History tab, with the same list of
    steps. A GIF of the film for GitHub was tried and left out: at a size
    where captions stay readable it was 8 MB, and the site plays the MP4.
49. **Renamed to Verified Air.** The site is called Verified Air, from
    "rarefied air", and the repository is `verified-air`, so the site moves
    to `samdengler.github.io/verified-air/`. As with decision 30, GitHub
    redirects the old repository URLs and GitHub Pages does not redirect
    the old site. The plane stays as the mark. The home page's heading names
    the subject, rules for airline offers and orders, since the site's name
    no longer does. The fictional airline of `/airline/`, called Parliament
    Air until then with a serif P as its mark, is now Verified Airline with
    the site's plane in its own indigo. The Lake package keeps the name
    `airline-order-verified`, which nothing outside the build shows.
50. **Verified Airline has its own repository.** The airline's pages moved
    from `/airline/` to
    [`samdengler/verified-airline`](https://github.com/samdengler/verified-airline),
    served at <https://samdengler.github.io/verified-airline/>, so the airline
    can grow a booking flow and a customer support widget. Those need a
    JavaScript toolchain, and the widget a server, which do not belong in
    this repository's CI. The fares stay in `Airline/Fares.lean`, since they
    are values of the model's types and need Lean to evaluate. This
    repository publishes what the pages read under `/airline-data/`:
    `facts.json`, and `model.json` from `scripts/export_airline.py`, with
    every requirement's statuses and absolute links into the review
    document. The airline's repository commits a copy, so its version of the
    model is pinned and each update shows as a diff. Decision 45's check still
    stops a stale caveat: `scripts/check-airline.sh` renders the airline's
    current wording against each build here and fails if it calls a proven
    criterion still being decided, so the wording changes there before the
    proof is pushed here. The old addresses under `/airline/` send readers to
    the same pages on the new site.
51. **A home page for a reader with no context.** The home page opened
    with Lean and proofs, then six count tiles, so a reader new to the
    project met the method and the numbers before the problem. It now says
    what the project is in plain words: an airline's offers and orders, IATA's
    ONE Order standard written in prose, and Lean checking rules written as
    code. One open guarantee follows, worked through from the model: the
    rule's EARS statement, the guarantee from its blueprint card, the
    example's Given and When, what Lean computes for it, and the open point.
    It is the same guarantee as the tour's step 4 (`QUESTION` in
    `scripts/render_tour.py`), so the build stops for both pages when it is
    proven. Four links by kind of reader come next, then the status tiles
    with a sentence on what each status means. The not-affiliated line moved
    under the introduction.
52. **Verified Airline is served at air.dengler.io.** The airline's site
    moved from GitHub Pages to <https://air.dengler.io/>, an Angular app on
    AWS whose design is recorded in the airline's own README. The top bar,
    the home page card, the review document's bar and the old `/airline/`
    addresses here now lead there. The files the site reads stay at
    `/airline-data/`, and `scripts/check-airline.sh` still renders the
    airline's wording against each build.
53. **Each fare fact has a theorem.** Verified Airline's support chat
    answers fare questions through an Automated Reasoning check whose rules
    come from `facts.json`, and shows the facts an answer rests on. A fact
    was a value Lean evaluated for one journey at one instant, and no theorem
    named it. `Airline/Theorems.lean` now states each change and cancellation
    fact for every journey and instant in its stage after the fare terms
    start, every item or change request, and every reading of the guide,
    since the chat's rules say "returns the full price paid" for any price.
    A theorem about the evaluated journey alone would be an example. Each
    proof unfolds the rule in force with `simp`. `/airline-data/theorems.json`
    lists each fact's theorem with a link to its line; `facts.json` keeps its
    shape. Lean checks the facts; whether an answer's words state them is
    still the Automated Reasoning check. The chat's general rules (the fare
    difference, the amount due on a change, the refund limit) rest on
    theorems in `Rules` whose statements are not yet matched to the chat's
    wording, so the file does not list them.
54. **The support chat's policy is written here, and every rule has a
    theorem.** Verified Airline's support chat checks answers with an
    Automated Reasoning policy generated from the model's files. Its exporter
    moved from the airline's repository to `scripts/export_airline_policy.py`,
    which writes `ar-policy.json`, `ar-rules.json` and `ar-checks.json` under
    `/airline-data/` beside the files they come from. The policy is now one of
    the model's files, built and checked with the theorems it cites. Each rule
    in `ar-rules.json` names the theorems that prove it, and the export stops
    if one has none. The general rules got theorems in `Airline/Theorems.lean`,
    stated for every rule list: the fare difference of an allowed change, the
    amount due on one, and the two halves of `acceptRefund`'s limit, with
    theorems for what the chat takes as given (money is never negative, every
    fare's price is positive). `lake exe airline-facts --theorems` lists them
    under `general` and checks them as it checks the facts' theorems. Matching
    them to the chat's wording found one gap: the amount due was the fee plus
    the fare difference whenever the new flight costs more, but under the
    reading that waives a fee above the refundable value, that holds only when
    the price paid covers the fee. The rule now says so. Every Verified
    Airline fare in the worked examples costs more than its fee, and the
    policy's 40 tests in Bedrock still pass.
