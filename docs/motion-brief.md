# Motion brief: how the dependency graph grows

This brief prepares a motion piece that shows the model growing: nodes are identified from the ONE Order material, wait on business decisions, and turn into Lean rules and proven guarantees, while a few stay open with a counterexample. It describes the story, the data the piece can be built from, and the visual language the site already uses. The History tab of the site's [Explore page](https://verified.dengler.io/graph/?view=history) plays the same milestones in the browser, with each area as a box of dots that appear and change color. The old `/history/` address sends readers there.

The piece exists and follows the storyboard below. [`motion/`](../motion/) is a [Remotion](https://www.remotion.dev) project: a React composition that reads `history/` and `build/frames/frames.json` when it is bundled, draws the cards and connectors on the shared canvas, and is rendered frame by frame in headless Chrome. `scripts/render-motion.sh` renders it to `motion/out/history.mp4` (1920 by 1080, 30 fps, H.264, 85 seconds) and its poster, the final state, to `motion/out/history-poster.jpg`. They are committed, since CI does not render video. The History tab shows the film above its milestone player and plays it one step at a time. [`motion/README.md`](../motion/README.md) explains how it is made. [The piece as rendered](#the-piece-as-rendered) lists where it departs from the storyboard.

## The story, by milestone

Each milestone is a commit with a git tag `milestone/<name>` and a snapshot in [`history/`](../history/). Counts are graph nodes: definitions, rules, guarantees and candidates. The review document counts acceptance criteria instead, so its numbers differ.

| # | Milestone | Nodes | What changes on screen |
| --- | --- | --- | --- |
| 1 | `first-slice` | 25 | The pilot appears: shared definitions (money, time, passenger), offers and orders, payments and refunds. Rules are In Lean; four guarantees turn Proven. One turns red: two refunds of 60.00 against one payment of 100.00 return 120.00. |
| 2 | `candidates-identified` | 48 | The first survey of IATA's public pages adds 23 candidates: 12 amber (needs a decision), 2 blue (ready to build), 9 grey and dashed (waiting). |
| 3 | `starting-small` | 48 | No change. The state to propose for an internal pilot, and the place to pause on "what if we kept going?". |
| 4 | `oneorder-foundations` | 63 | ONE Order's own structure arrives: services, order items, orders and their statuses. Ten candidates change color, seven to In Lean or Proven and three to Ready to build, and two new red cards appear: an item can have two statuses at once, and an order with an expired service can be neither opened nor closed. |
| 5 | `second-survey` | 201 | The second survey reads every area in full. 138 cards arrive, almost all amber, and fill the canvas. This is the moment that shows how much the public material leaves to each airline. |
| 6 | `change-cancellation` | 221 | Change and cancellation is written in Lean: 20 cards appear, 17 more guarantees turn green, 5 turn red. |
| 7 | `payment` | 243 | Payment: 22 cards appear, 22 more green, 3 red. |
| 8 | `delivery` | 261 | Delivery: 18 cards appear, 15 more green, 2 red. |
| 9 | `order-creation` | 290 | Order creation: 29 cards appear, 22 more green, 9 red. |
| 10 | `airline-change` | 314 | Airline-initiated change: 24 cards appear, 19 more green, 8 red. |
| 11 | `offers-prices` | 348 | Offers and prices: 34 cards appear, 28 more green, 7 red. |
| 12 | `ancillaries` | 382 | Ancillaries, seats and bundles: 34 cards appear, 24 more green, 11 red. |
| 13 | `accounting` | 429 | Commission, accounting and settlement: 47 cards appear, 41 more green, 10 red. |
| 14 | `critique-before-fixes` | 429 | No change. The model as an independent review found it on 30 October: rules in four areas changed a service's delivery status without the delivery status table. |
| 15 | `critique-fixes` | 432 | The fixes: a shared way to end a service from another area, a theorem that every rule changing a delivery status moves along the table, and a new red card, a cancelled flight that keeps a live service. One green card, orders cancelled at once are closed, turns red. The canvas ends with 93 In Lean, 204 Proven, 60 open questions, 67 still needing a decision, 7 ready to build and 1 waiting. |

Amber falls from 133 at milestone 5 to 67 at milestone 15, while red rises from 3 to 60. Both directions are the point: the model settles what the sources settle, and turns the rest into questions with examples.

## Storyboard

About 85 seconds, in the nine steps the History tab plays one at a time. Every frame uses the same canvas, so cards never move; they appear, change color, or pulse.

1. **The pilot** (0 to 8 s). Milestone 1 fades in at the top centre, zoomed to its box. The red card pulses once, with the caption "Two refunds of 60.00 against a payment of 100.00 return 120.00."
2. **First survey** (8 to 14 s). Milestone 2's candidates fade in amber, grey and blue. The camera eases out to milestone 2's box.
3. **Starting small** (14 to 18 s). Hold on milestone 3. Caption: "Where a pilot could stop."
4. **Foundations** (18 to 24 s). Milestone 4: ten cards recolor to magenta, green and blue; two red cards pulse.
5. **The whole standard** (24 to 33 s). Milestone 5: 138 cards, 124 of them amber, cascade in, row by row from the top, while the camera pulls back to the full canvas. Caption: "The second survey reads every area: 138 candidate rules, 124 of them left to the business to decide."
6. **Eight areas** (33 to 60 s). Milestones 6 to 13, about 3 seconds each. Dim every area except the one being written, as the site's area lens does; its new cards fade in, its amber cards turn green, and its new red cards pulse. A caption names the area and one of its open questions:
   * Change and cancellation: a partly paid order is offered a refund of its full price.
   * Payment: a redirected payment captured a minute after its time limit leaves the trip removed.
   * Delivery: an order whose services all end not claimed never closes.
   * Order creation: a request resent after a timeout creates a second order from the same offer.
   * Airline-initiated change: declining the airline's own change costs a 50 EUR cancellation fee.
   * Offers and prices: with a zero payment duration, the item can never be paid on time.
   * Ancillaries: one request gives seat 12B to two passengers.
   * Accounting: two pages split a 100.00 short payment 50 and 50, or 100 and 0.
7. **An independent review** (60 to 67 s). Milestone 14 changes nothing. Caption: "An independent review compares each criterion with its theorems, and each area with the others." Then every card dims except the rules that change a delivery status, with the caption "Rules in four areas change a delivery status without the table: changing a trip after its first flight turns that flight from DELIVERED to REMOVED."
8. **The fixes** (67 to 75 s). Milestone 15's three cards fade in, with connectors from the rules to the new theorem, and "orders cancelled at once are closed" turns red. Caption: "Every rule that ends a service now goes through the table, and one theorem checks every rule that changes a delivery status." Then both new red cards pulse, a callout names the one that turned, and the caption reads "The table cannot end a REQUESTED service, so a cancelled unpaid order is not closed and a cancelled flight keeps a live bag."
9. **Where it stands** (75 to 85 s). Undim, hold on the full canvas, and count up: 204 proven, 60 open questions, 67 still need a decision. Closing line: "Every red card is a question for the business, with the example that breaks the rule."

Motion: a new card fades in and scales from 96 to 100 percent over about 300 ms; a status change crossfades the rim and tint over about 400 ms; a new red card pulses its rim once. The camera moves are slow eases between the boxes in `frames.json`.

## The data

| File | What it holds |
| --- | --- |
| [`history/index.json`](../history/index.json) | Every milestone in order: name, description, commit, date, tag, node count, and the count of nodes in each status. |
| `history/NNNN-<name>.json` | The graph at that milestone: every node with its id, title, candidate ID (C-01 and so on), kind (definition or theorem), area, status, Lean names, and the ids of the nodes it uses. |
| [`history/layout.json`](../history/layout.json) | One position for every node that appears in any milestone, and the connector paths. It uses the site's row layout with rows of up to 26 cards, so the full graph is about 16:9 (5516 by 3164). A node keeps its place from frame to frame, so the piece can fade nodes in and recolor them without the graph jumping. |
| `build/frames/NNNN-<name>-light.svg`, `-dark.svg` | One frame per milestone, drawn on the shared canvas in the site's colors. Each card is a group with the node id as its `id`, so a tool can address it. Generated by `python3 scripts/graph_history.py frames` (add `--dark` for the dark frames); not committed. |
| `build/frames/frames.json` | For each milestone: the frame file, the node and status counts, the ids of the nodes that appear, the nodes whose status changes and from what to what, and a box around the nodes present, for the camera. |
| `/graph/graph.json` on the site | The current graph in the same shape as a snapshot, rebuilt on every push, with each candidate's IATA capability codes. |

Node ids are the blueprint labels (`def:c08-delivery-status`) and do not change between milestones. Statuses are `modelled` (In Lean), `proven`, `open`, `decision` (needs a decision), `ready` (ready to build) and `waiting`.

Two accuracy notes:

* For milestones recorded after the fact (1 to 3), the statuses of nodes in Lean come from the build at the time of recording. No guarantee in those nodes has changed status since the model was built, so they are exact. Milestones 4 to 13 were recorded as they were reached, so they are exact by construction.
* Nothing in the build searches for counterexamples. Examples are written by hand and Lean computes their results, so the piece should show the counterexample as an example that breaks the rule, not as something Lean discovered.

## Visual language

The piece should look like the All cards view of the site's Explore page.

* Cards: 184 wide, corner radius 8, the title in 13 px at weight 600, and a status line in 11.5 px with a colored dot. Finished states have a 1.5 px colored rim and a light tint of the same color; states that need attention have a 2 px rim and a stronger tint; waiting cards have a dashed grey rim.
* Connectors: 1.25 px, neutral grey (`#b9b8b0` light, `#55544f` dark), with a small filled arrowhead. A selected node's connectors darken.
* Status colors, the same in light and dark mode: In Lean magenta `#e87ba4`, Proven green `#0ca30c`, Open question red `#d03b3b`, Needs a decision amber `#fab219`, Ready to build blue `#2a78d6` (`#3987e5` in dark mode), Waiting grey `#898781`. They were checked against each other for color-blind readers; every status also carries its label.
* Type: the system sans-serif (`system-ui`). Surfaces: `#fcfcfb` on `#f9f9f7` in light mode, `#1a1a19` on `#0d0d0d` in dark mode.
* Mark: a plane taking off and the words "Verified Air" (`PLANE_PATH` in `scripts/site_nav.py`).

## Recording a milestone

```sh
lake exe status                                   # current statuses
python3 scripts/graph_history.py snapshot <name> "<one sentence on what changed>" --tag
python3 scripts/graph_history.py layout           # recompute shared positions
python3 scripts/graph_history.py frames           # redraw build/frames/ (add --dark for dark frames)
scripts/render-motion.sh                          # the film and its poster; commit motion/out/
git push origin main --follow-tags
```

`--commit REF` records an earlier commit. Name milestones by what they add, such as `orders-change-identified` for a survey round or `ordpen-formalized` when a capability's rules are in Lean.

## The piece as rendered

The beats run as the storyboard times them: the pilot 0 to 8 s, the first survey 8 to 14 s, starting small 14 to 18 s, the foundations 18 to 24 s, the second survey 24 to 33 s, the eight areas 3.375 s each from 33 to 60 s, the review 60 to 67 s, the fixes 67 to 75 s, and where it stands 75 to 85 s. The steps are the storyboard's sections, in `STEPS` in `motion/src/story.ts`. A new milestone stops the bundle until the storyboard places it, and the steps move with it. Where the piece departs from the storyboard:

* Each step ends on a still frame, since the History tab pauses there: `motion/src/story.ts` checks that nothing moves in the half second before. To make room, the pilot's camera reaches the refund card at 7 s instead of 7.8 s, the camera moves to the foundations' box between 18 and 20 s instead of drifting from 11 to 18 s, an area's new cards fade in within its first second and its changes within 1.3 s, and an area's callout fades with the end of its beat.

* The captions, the milestone and the counts of each status are in a band at the top of the frame. A browser's video controls sit at the bottom, so on the paused poster they cover cards and leave the captions readable.
* The counters count the cards on screen as they appear and change, with the change from the previous milestone beside each count. At the end of every beat they equal that milestone's counts in `history/index.json`; the composition stops if they do not.
* Every number in a caption that counts cards is computed from the snapshots. The storyboard's caption for milestone 5, "138 rules the public material leaves to the business to decide", was wrong: 124 of the 138 need a decision, 8 are waiting and 6 are ready to build. The caption and the storyboard above now say so. Milestone 4's ten recolored cards include three that turn Ready to build.
* The storyboard gives no caption for the first survey or the foundations. The piece says that the first survey adds 23 candidate rules, 12 of which need a business decision, and names the foundations' two open questions. The pilot opens with a line on what it covers before the refund example, and the camera moves in a little toward the refund card while that example is on screen.
* Each area's caption shows its example with an "Open question" label, and a callout beside the card gives the card's title at a readable size, since on the full canvas a card's text is too small to read. Two captions are reworded to match the Lean examples: for payment, the late payment succeeds and the trip stays removed; for accounting, the two pages split a short payment of 100.00 between two airlines.
* During an area's beat, cards of other areas that change status in that milestone stay bright with the area's own cards. Change and cancellation recolors two such cards.
* Every card that becomes an open question pulses once, a moment after it turns red. In the pilot and the foundations, the red cards the caption is about pulse when it appears.
* On the full canvas a card is about a quarter of its size on the site, so rims are kept at least about a pixel wide, tints are stronger and card text is lighter. Close up, the cards are drawn exactly as on the site.

## Open for the follow-up

* The captions above are our own words about the model's examples. They quote nothing from IATA's material.
* The counts above will change as open questions are answered. After a new milestone, run `scripts/render-motion.sh` (which reruns `frames`) and commit `motion/out/`. The site build stops until the film is rendered again, since `motion/out/history-film.json` records the milestones it was drawn from.
* The film is rendered in the light theme. The composition takes `theme: "dark"`, and the page could offer a dark film with `<source media="(prefers-color-scheme: dark)">`, at the cost of a second file of about the same size in the repository.
