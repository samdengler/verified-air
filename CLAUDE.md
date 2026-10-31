# CLAUDE.md

Business rules for airline offers and orders as a Lean model, with review documents, requirement specs and implementation checks generated from it. The README explains the design and records every decision; read it before changing structure.

## Working on the site

- Work locally and publish in batches. `scripts/preview.sh` rebuilds the documents and serves the site at http://localhost:8000; a second run takes a minute or two.
- For a visual change, take screenshots (headless Chrome works) and show them before pushing.
- Before pushing, run `scripts/build-site.sh`, which runs everything CI runs. Commit `.kiro/specs` whenever `scripts/render_status.py` changes it; CI fails if the committed specs are stale.
- After changing `impl/rust`, run `scripts/translate-rust.sh` and commit `Verify/Rust/`; CI checks it matches a fresh translation.
- Push straight to `main`. No pull requests, no merge commits.

## What the site may claim

- Statuses and example values are computed by the build. Never type one by hand: change the Lean and rebuild.
- Proven means Lean checked a proof that holds for every input. Open means the theorem has no proof and is tagged `@[open_question]`.
- Nothing in the build searches for counterexamples. Examples are written by hand and Lean computes their results, so say "an example shows the rule breaking it", never "Lean found".
- `Verify/RustRules.lean` proves the Rust `step` and `accept_refund` equal to the model. The WebAssembly wrapper in `impl/wasm` and the try-it panels' script are not proved, and the panels say so.
- This is a proof of concept, not affiliated with IATA. Rules from IATA's public material are described in our own words with a link to the page. Quote nothing from the EASD guide; its notice forbids reproduction.

## Authored and generated files

| Authored | Generated |
| --- | --- |
| `Rules/**/*.lean`: rule docstrings carry `EARS:`, `Story:` and `* OO-00n.m:` criteria; examples state Given, When and Then and return records whose fields label each part | `Review/Review/Generated/` (`scripts/render_status.py`): a chapter per requirement, the front page cards, the EARS table |
| `blueprint/src/content.tex`, without `\leanok`; candidate nodes use `Open point:`, `Counterexample:`, `Source:` and `Capabilities:` paragraphs, which the progress page reads; capability codes must be in `docs/one-order-coverage.md` | `blueprint/src/*.generated.tex`, `.kiro/specs/` (committed) |
| `Review/Review/{Overview,OpenQuestions,Objects}.lean`, `Review/Review.lean`, `Review/Review/Status.lean`, `Review/review.css`, `Review/review.js` | `build/home/index.html` (`scripts/render_home.py`), the site root; `build/progress/index.html` (`scripts/render_progress.py`), at `/progress/`; `build/graph/index.html` (`scripts/render_graph.py` with `scripts/explore.js` and `scripts/explore.css`), the Explore page at `/graph/`; `build/area/<slug>/` (`scripts/render_areas.py`); `build/tour/` (`scripts/render_tour.py`); `build/history/` (`scripts/render_history.py`), which sends readers to the Explore page's History tab |
| `impl/java`, `impl/rust`, `impl/wasm`, `scripts/` | `Verify/Rust/` (committed), `build/try/rules.wasm` |
| `Airline/Fares.lean` (Verified Airline's fares), `Airline/Theorems.lean` (a theorem for each fact and each general rule of the chat's policy) | `build/airline-data/facts.json` (`lake exe airline-facts`), `build/airline-data/model.json` and `build/airline-data/theorems.json` (`scripts/export_airline.py`, the last from `lake exe airline-facts --theorems`), `build/airline-data/ar-policy.json`, `ar-rules.json` and `ar-checks.json` (`scripts/export_airline_policy.py`), served at `/airline-data/` for Verified Airline's site and support chat |
| `motion/src/` (the storyboard and captions are in `story.ts`) | `motion/out/history.mp4` and `history-poster.jpg` (`scripts/render-motion.sh`, committed) |

The bar at the top of every page is defined once in `scripts/site_nav.py`: the site name, which leads to the home page, then Progress, Review document, Explore, Verified Airline and GitHub. `Review/review.js` repeats its links for the review document, so change both together. The home page describes each part of the site; a new part needs a card in `scripts/render_home.py`.

The Explore page, the area pages, the tour, the home page and the progress page's "Decide these first" list read the graph through `scripts/graph_model.py`, so their counts agree. Its `AREA_LAYERS` places each blueprint section in a layer of the area map; a new section stops the build until it is added there. The tour's step 4 and the home page's worked example are the open refund guarantee, `QUESTION` in `scripts/render_tour.py`; if it is proven, the build stops until another open question is picked there.

A new requirement needs `{include 1 Review.Generated.<ID without the dash>}` (such as `ONE301`) in `Review/Review.lean`; `render_status.py` fails until it is there.

## Verified Airline

- Verified Airline's site has its own repository, `samdengler/verified-airline`, usually checked out at `../verified-airline`. Its pages read `/airline-data/facts.json` and `/airline-data/model.json` from this site, and its CLAUDE.md has the rules for their wording.
- To change a fee or refund, change `Airline/Fares.lean` and rebuild here, then run `scripts/update-model.sh ../verified-air/build/airline-data` in the airline's repository. The `Airline` namespace stays outside `Rules`, so the status counts do not change.
- The fares must not depend on a reading of the guide: no expiration dates, no refund both full and fixed. `lake exe airline-facts` fails if two readings disagree.
- Each change and cancellation fact has a theorem in `Airline/Theorems.lean`, named after its key in `facts.json` (`fares.main.cancel.noShow` is `main_cancel_noShow`), stated for every journey, instant, item and reading in its stage. A changed fee or a new fare or stage needs its theorem changed or added; `lake exe airline-facts --theorems` fails until it is there. The airline's support chat cites these theorems from `theorems.json`.
- The support chat's Automated Reasoning policy is written here by `scripts/export_airline_policy.py`. Every rule must have a theorem: a fare rule the theorems of its facts, any other rule its entry in `generalTheorems` (`Airline/Facts.lean`) and `GENERAL` in the script. A rule whose wording a theorem does not back is changed, not left unproved. A changed policy reaches the chat when the airline's repository runs `scripts/update-model.sh` and deploys its chat stack.
- `scripts/check-airline.sh` renders the airline's wording against this build. When a criterion the airline calls still being decided is proven, the build stops: rewrite that wording in the airline's repository and push it before pushing the proof here. Locally the script uses `../verified-airline`, uncommitted wording included; CI clones the airline's `main`.
- `/airline/` and its old page addresses send readers to the airline's site (`scripts/assemble-site.sh`).

## Branches, tags and milestones

- `main` grows toward as much of ONE Order as the public material allows. The `starting-small` branch (tag `snapshot/starting-small`) keeps the version to propose for an internal pilot; fixes to that version go on that branch.
- Each milestone (a survey round's candidates added, a capability's rules in Lean) gets a snapshot and an annotated tag with `python3 scripts/graph_history.py snapshot <name> "<sentence>" --tag`, then `python3 scripts/graph_history.py layout` and `scripts/render-motion.sh`, and commit `motion/out/`. `docs/motion-brief.md` explains why: the snapshots feed a motion piece about how the graph grew. The site build stops while the film is older than the milestones or `motion/src/`, and the storyboard in `motion/src/story.ts` stops the render until it places a new milestone.
- After a milestone, run `scripts/render-motion.sh` and commit `motion/out/history.mp4` and `motion/out/history-poster.jpg`. CI does not render video, so the committed files are the ones the site publishes. A milestone after `accounting` gets an area beat of its own; give it an open question and its example in `AREA_QUESTIONS` in `motion/src/story.ts`. A new survey round needs a beat written there. `motion/README.md` explains the piece.

## ONE Order areas

- `Rules/OneOrder/*.lean` are the foundations (services, statuses, items, orders, accepting an offer). Each area has its own folder and sub-namespace and its own range of requirement IDs:

  | Area | Namespace | IDs | Blueprint file |
  | --- | --- | --- | --- |
  | Delivery | `Rules.OneOrder.Delivery` | ONE-101 to ONE-199 | `areas/delivery.tex` |
  | Change and cancellation | `Rules.OneOrder.Change` | ONE-201 to ONE-299 | `areas/change-cancellation.tex` |
  | Payment | `Rules.OneOrder.Payment` | ONE-301 to ONE-399 | `areas/payment.tex` |
  | Order creation and information | `Rules.OneOrder.Creation` | ONE-401 to ONE-499 | `areas/order-creation.tex` |
  | Offers, prices and conditions | `Rules.OneOrder.Offers` | ONE-501 to ONE-599 | `areas/offers-prices.tex` |
  | Ancillaries, seats and bundles | `Rules.OneOrder.Ancillaries` | ONE-601 to ONE-699 | `areas/ancillaries.tex` |
  | Airline-initiated change | `Rules.OneOrder.AirlineChange` | ONE-701 to ONE-799 | `areas/airline-change.tex` |
  | Commission, accounting and settlement | `Rules.OneOrder.Accounting` | ONE-801 to ONE-899 | `areas/accounting.tex` |

- Where the sources are vague or silent, the rule takes the undecided part as a parameter (a reading, such as `ValueReading` or `RepeatHandling`). A guarantee is proven only if it holds under every reading; otherwise it is open, with an example under the reading that breaks it. A proven version for one reading may follow, named `<open theorem's name>_of_<reading>` and tagged with no criterion; the site pairs the two by that name and shows the proven docstring under "If we decide this", so its docstring should say which reading it assumes. Never pick a reading for the business and then prove the guarantee.
- Tag a theorem `@[checks "ID"]` only if it proves that criterion for every input. A theorem that two statuses never overlap does not prove "mark X when Y". A criterion written as "Where <one reading>" is the same as a proven version for that reading: write the `_of_` theorem instead, with no criterion.
- A rule in any area that ends a service does it through `Delivery.endWith`, so a move the delivery status table refuses leaves the service as it was. Every rule that changes a delivery status, `Payment.markPaid` included, is added to `delivery_moves_follow_table` in `Rules/OneOrder/Consistency.lean`, which proves each one moves only along the table.
- A concept used by more than one area (paid, a service being live) is defined once, in the area that owns it, and the other areas import it.
- Several areas can be written at once in git worktrees, each with `.lake/packages` linked to the main checkout's. Merge by rebasing onto `main`; conflicts in `Rules.lean`, `Review/Review.lean` and `.kiro/specs/README.md` are additive. Keep the requirement chapters in ID order, run `scripts/build-site.sh`, and commit the regenerated specs index.

## Versions

Lean, Mathlib and Verso are on `v4.35.0` because the pinned Aeneas release needs it. The Aeneas commit in `lakefile.toml` and the release in `scripts/translate-rust.sh` move together with the Lean version.

## Writing

Prose on the site, in docstrings and in the README follows one style: no em or en dashes; short declarative sentences; headings that name the topic; no "X, not Y" contrasts, rhetorical setups or filler adverbs. Business-facing text uses the status words already on the site: modelled, proven, open question, needs a decision, ready to build, waiting; and for criteria, proven, example only, open, not checked.
