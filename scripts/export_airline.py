#!/usr/bin/env python3
"""Write build/airline-data/model.json and theorems.json, the parts of the
model that Verified Airline's site reads, served at /airline-data/ beside
facts.json.

Verified Airline is a fictional airline whose site has its own repository,
https://github.com/samdengler/verified-airline.  Its build reads three files
from here: facts.json, Verified Airline's fares in Airline/Fares.lean evaluated
by the model's functions (lake exe airline-facts); model.json, which this
script writes from build/status.json and the review document's
cross-references:

  * every requirement, with its EARS statement in Kiro's notation, its Lean
    name, the address of its chapter, and its criteria with their statuses;
  * for each criterion an open theorem checks, those theorems, each with the
    start of its question and the address of its section;
  * the commit the files were built from;

and theorems.json, which this script writes from build/airline-theorems.json
(lake exe airline-facts --theorems): for each fact about a change or a
cancellation, keyed by its place in facts.json, the theorem in
Airline/Theorems.lean that states it for every input in its stage, with its
docstring, its rule, and its line on GitHub at the same commit; and under
"general", the same for the support chat's rules that hold for every fare and
for what the chat takes as given about amounts.

Addresses are absolute, on this site, since the airline's pages are served
from another.

  python3 scripts/export_airline.py
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_status import PILOT, kiro_ears, plain, section_tag  # noqa: E402
from site_nav import REPO  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
THEOREMS = ROOT / "build" / "airline-theorems.json"
XREF = ROOT / "build" / "review" / "html-multi" / "xref.json"
OUT = ROOT / "build" / "airline-data"
SITE = "https://samdengler.github.io/verified-air/"


def load_review():
    """The review document's sections by tag, or None when it is not built."""
    if not XREF.exists():
        return None
    x = json.loads(XREF.read_text())
    return {k: v[0] for k, v in x.get("Verso.Genre.Manual.section", {}).get("contents", {}).items()}


def review_url(review, tag):
    if review is None:
        return SITE + "review/find/?domain=Verso.Genre.Manual.section&name=" + tag
    if tag not in review:
        sys.exit(f"export_airline: the review document has no section tagged {tag}")
    e = review[tag]
    # A chapter is a page of its own; a section is an anchor in one.
    anchor = "" if len(e["data"]["context"]) <= 2 else "#" + e["id"]
    return SITE + "review/" + e["address"].strip("/") + "/" + anchor


def opening(docstring):
    """The start of an open theorem's question: its first sentence or two after
    the words "Open question for ...", with names still in backticks."""
    text = plain(docstring)
    m = re.search(r"Open question for [^.]*\.\s*(.*)", text, re.S)
    if not m:
        return ""
    body = " ".join(m.group(1).split())
    sentences = re.split(r"(?<=[.?])\s+(?=[A-Z])", body)
    # The first sentence, and the second too if both are short.
    n = 2 if len(sentences) > 1 and len(sentences[0]) + len(sentences[1]) < 220 else 1
    return " ".join(sentences[:n]) + (" …" if len(sentences) > n else "")


def commit():
    if os.environ.get("GITHUB_SHA"):
        return os.environ["GITHUB_SHA"]
    try:
        return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True,
                              check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def theorem_index(source):
    """Each fact's theorem, and each general theorem, with a link to its line
    at the source's commit."""
    index = json.loads(THEOREMS.read_text())
    blob = f"{REPO}/blob/{source['commit'] or 'main'}/"

    def linked(entries):
        return {key: {**t, "statement": " ".join(t["statement"].split()), "url": f"{blob}{t['path']}#L{t['line']}"}
                for key, t in sorted(entries.items())}
    return {"source": source, "facts": linked(index["facts"]), "general": linked(index["general"])}


def main():
    if not STATUS.exists():
        sys.exit("export_airline: build/status.json is missing; run: lake exe status")
    if not THEOREMS.exists():
        sys.exit("export_airline: build/airline-theorems.json is missing; "
                 "run: lake exe airline-facts --theorems > build/airline-theorems.json")
    decls = json.loads(STATUS.read_text())["declarations"]
    review = load_review()
    requirements = {}
    for d in sorted((d for d in decls if d.get("earsId")), key=lambda d: d["earsId"]):
        requirements[d["earsId"]] = {
            "name": d["name"],
            "ears": kiro_ears(plain(d["ears"])),
            "review": review_url(review, d["earsId"].lower()),
            "criteria": [{"id": c["id"], "status": c["status"], "ears": kiro_ears(plain(c["ears"]))}
                         for c in d["criteria"]],
        }
    questions = {}
    for d in sorted((d for d in decls if d["kind"] == "theorem" and d["status"] == "open"), key=lambda d: d["name"]):
        tag = "open-questions" if d["name"].startswith(PILOT) else section_tag("question", d["name"])
        for c in d.get("checks", []):
            questions.setdefault(c, []).append(
                {"theorem": d["name"], "question": opening(d["docstring"]), "review": review_url(review, tag)})
    source = {"repository": REPO, "commit": commit(), "site": SITE}
    model = {
        "source": source,
        "requirements": requirements,
        "openQuestions": dict(sorted(questions.items())),
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "model.json").write_text(json.dumps(model, indent=1, ensure_ascii=False) + "\n")
    theorems = theorem_index(source)
    (OUT / "theorems.json").write_text(json.dumps(theorems, indent=1, ensure_ascii=False) + "\n")
    print(f"wrote build/airline-data/model.json: {len(requirements)} requirements, "
          f"{len(questions)} criteria with open questions"
          + ("" if review else " (review document not built: links use its lookup page)"))
    print(f"wrote build/airline-data/theorems.json: {len(theorems['facts'])} facts with their theorems, "
          f"{len(theorems['general'])} general theorems")


if __name__ == "__main__":
    main()
