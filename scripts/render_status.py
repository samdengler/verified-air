#!/usr/bin/env python3
"""Render the computed status into both review layers.

Reads build/status.json (written by `lake exe status`) and writes:

  blueprint/src/content.generated.tex   content.tex with \\leanok added from the build
  blueprint/src/ears.generated.tex      the EARS table as a blueprint section
  Review/Review/Generated/OO00n.lean        Verso chapter per requirement: the rule, how each
                                            criterion is checked, its guarantees and examples
  Review/Review/Generated/Ears.lean         Verso chapter: the EARS table
  .kiro/specs/<spec>/requirements.md        one requirement spec per module that holds rules
  .kiro/specs/README.md                     index of the specs, with every criterion's status

The .kiro/specs files are committed so they can be read on GitHub and opened
in Kiro; CI fails if the committed copies differ from what this script writes.

Nothing here decides a status.  Every status and example value comes from
status.json, which the status executable computes from the compiled Lean.
"""

import datetime
import html
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
BLUEPRINT = ROOT / "blueprint" / "src"
GENERATED = ROOT / "Review" / "Review" / "Generated"
SPECS = ROOT / ".kiro" / "specs"
REPO = "https://github.com/samdengler/verified-air/blob/main"

# The pilot's open question is set out by hand in Review/Review/OpenQuestions.lean;
# every other open guarantee gets a section in the generated questions chapter.
PILOT = "Rules.OfferOrder."
QUESTIONS_TITLE = "Questions from the ONE Order rules"

DONE = {"definition", "proven"}

ENV_RE = re.compile(
    r"\\begin\{(definition|theorem|lemma|proposition|corollary|proof)\}(.*?)\\end\{\1\}",
    re.S,
)
LEAN_RE = re.compile(r"\\lean\{([^}]*)\}")


def load_status():
    if not STATUS.exists():
        sys.exit(f"{STATUS} not found; run `lake exe status` first")
    data = json.loads(STATUS.read_text())
    return {d["name"]: d for d in data["declarations"]}


def load_sources():
    """The sources the rules may cite, by key, as the status executable lists them."""
    return {s["key"]: s for s in json.loads(STATUS.read_text())["sources"]}


# How a confirmation was made, in words.
METHOD_TEXT = {"sme": "subject matter expert", "data": "production data", "crosscheck": "independent source"}

# A rule's provenance, as the status executable computes it, in words.
PROVENANCE_TEXT = {
    "confirmed": "confirmed",
    "out of date": "confirmed but out of date",
    "sourced": "written from a source",
    "assumed": "assumed by the modeller",
}


def rule_sources(d, sources):
    """The sources a rule names with @[source], in the order it names them."""
    return [sources[k] for k in d.get("sources", [])]


def confirmation_text(d):
    """One or two sentences on whether anyone outside the model confirmed a rule."""
    c = d.get("confirmation")
    p = d.get("provenance")
    if c:
        said = f"Confirmed on {c['date']} by {c['who']} ({METHOD_TEXT[c['method']]}): {c['note'].rstrip('.')}."
        if p == "out of date":
            said += " The rule changed after that, so the confirmation is out of date."
        return said
    if p == "assumed":
        return "Not confirmed. The modeller wrote this rule where no source states it."
    return "Not confirmed yet."


def ears_rows(decls):
    """One row per declaration with an EARS statement, ordered by ID then name."""
    rows = [d for d in decls.values() if d.get("ears")]
    return sorted(rows, key=lambda d: (d.get("earsId") or "~", d["name"]))


def proven_by(d, decls):
    names = d.get("provenBy") or []
    out = []
    for n in names:
        short = n.rsplit(".", 1)[-1]
        status = decls.get(n, {}).get("status")
        out.append((n, short, status))
    return out


# ---------------------------------------------------------------- blueprint


AREA_INPUT_RE = re.compile(r"\\input\{(areas/[^}]+)\}")


def read_blueprint(read=None):
    """content.tex with each \\input{areas/...} replaced by that file's text.

    The candidate rules live in one file per area under blueprint/src/areas/,
    so that work on different areas does not edit the same file.  `read`
    reads a path relative to blueprint/src; by default, from the working
    tree (scripts/graph_history.py passes one that reads an earlier commit)."""
    read = read or (lambda rel: (BLUEPRINT / rel).read_text())
    src = read("content.tex")
    return AREA_INPUT_RE.sub(lambda m: read(m.group(1) if m.group(1).endswith(".tex") else m.group(1) + ".tex"), src)


def render_content(decls):
    src = read_blueprint()
    uncommented = "\n".join(line.split("%", 1)[0] for line in src.splitlines())
    if "\\leanok" in uncommented:
        sys.exit("content.tex must not contain \\leanok; the build adds it")
    last_theorem_done = None
    missing = []

    def replace(m):
        nonlocal last_theorem_done
        env, body = m.group(1), m.group(2)
        if env == "proof":
            done = last_theorem_done
            last_theorem_done = None
        else:
            names = [n.strip() for lm in LEAN_RE.finditer(body) for n in lm.group(1).split(",")]
            names = [n for n in names if n]
            for n in names:
                if n not in decls:
                    missing.append(n)
            done = bool(names) and all(decls.get(n, {}).get("status") in DONE for n in names)
            last_theorem_done = done if env != "definition" else None
        if not done:
            return m.group(0)
        opt = re.match(r"\[[^\]]*\]", body)
        title, rest = (opt.group(0), body[opt.end():]) if opt else ("", body)
        return f"\\begin{{{env}}}{title}\n  \\leanok{rest}\\end{{{env}}}"

    out = ENV_RE.sub(replace, src)
    if missing:
        sys.exit("content.tex names declarations the build does not report: " + ", ".join(missing))
    header = "% Generated by scripts/render_status.py from content.tex and build/status.json.\n% Do not edit.\n\n"
    (BLUEPRINT / "content.generated.tex").write_text(header + out)


def tex_escape(s):
    for a, b in [("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"), ("$", r"\$"),
                 ("#", r"\#"), ("_", r"\_"), ("{", r"\{"), ("}", r"\}")]:
        s = s.replace(a, b)
    return s


def render_ears_tex(decls):
    lines = [
        "% Generated by scripts/render_status.py from build/status.json.  Do not edit.",
        "",
        "\\section{EARS requirements}",
        "",
        "Each requirement below is the EARS statement in a rule's Lean docstring.",
        "The status and the proving theorems are computed by the build.",
        "",
        "\\begin{tabular}{|p{0.07\\textwidth}|p{0.4\\textwidth}|p{0.18\\textwidth}|p{0.2\\textwidth}|}",
        "\\hline",
        "ID & EARS statement & Declaration & Proven by \\\\",
        "\\hline",
    ]
    for d in ears_rows(decls):
        pb = ", ".join(
            "\\texttt{" + tex_escape(short) + "}" + (" (open)" if st == "open" else "")
            for _, short, st in proven_by(d, decls)
        ) or "none"
        lines.append(
            f"{tex_escape(d.get('earsId') or '')} & {tex_escape(d['ears'])} & "
            f"\\texttt{{{tex_escape(d['name'].rsplit('.', 1)[-1])}}} & {pb} \\\\"
        )
        lines.append("\\hline")
    lines += ["\\end{tabular}", ""]
    (BLUEPRINT / "ears.generated.tex").write_text("\n".join(lines))


# -------------------------------------------------------------------- verso


def verso_escape(s):
    return re.sub(r"([\\*_\[\]{}`#])", r"\\\1", s)


VERSO_HEADER = """\
-- Generated by scripts/render_status.py from build/status.json.  Do not edit.
import VersoManual
import Rules
import Review.Status

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean
open Review

set_option pp.rawOnError true
"""

STATUS_TEXT = {
    "proven": '{status "proven"}[Proven] Lean checked the proof, and the proof depends on no unproven step.',
    "open": '{status "open"}[Open] The proof is not complete. See the open questions chapter.',
}

# The EARS table's status column, as status labels.
DECL_STATUS = {
    "definition": '{status "modelled"}[Modelled]',
    "proven": '{status "proven"}[Proven]',
    "open": '{status "open"}[Open]',
}


def blueprint_titles():
    """The title of each blueprint node, by the Lean names in its \\lean{}.
    A survey candidate's ID, such as " (C-06)", is left off."""
    src = read_blueprint()
    titles = {}
    for m in re.finditer(r"\\begin\{(?:theorem|lemma|definition)\}\[([^\]]*)\](.*?)\\end", src, re.S):
        title = re.sub(r"\s*\(C-\d+\)$", "", m.group(1).strip())
        for lm in LEAN_RE.finditer(m.group(2)):
            for n in lm.group(1).split(","):
                titles[n.strip()] = title
    return titles


def humanize(name):
    """acceptBeforeExpiry or accept_before_expiry as "Accept before expiry"."""
    words = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name).replace("_", " ").lower()
    return words[:1].upper() + words[1:]


# ------------------------------------------------------- computed values
#
# The status executable stores each example's value as Lean prints it.  The
# functions below parse that text and show it in business terms: amounts as
# "245.00 USD", instants as UTC times, constructor names as words, and lists
# of records as tables.  If a value does not parse, it is shown as Lean
# printed it.

VALUE_TOKEN = re.compile(r'\s*(?:(:=)|([{}\[\](),])|("(?:[^"\\]|\\.)*")|(\d+)|([^\s{}\[\](),:"]+))')


def parse_value(text):
    tokens, pos = [], 0
    while pos < len(text):
        m = VALUE_TOKEN.match(text, pos)
        if not m or m.end() == pos:
            if text[pos:].strip():
                raise ValueError(f"cannot read {text[pos:pos + 20]!r}")
            break
        pos = m.end()
        assign, punct, string, number, ident = m.groups()
        if assign:
            tokens.append((":=", None))
        elif punct:
            tokens.append((punct, None))
        elif string:
            tokens.append(("str", json.loads(string)))
        elif number:
            tokens.append(("num", int(number)))
        elif ident:
            tokens.append(("id", ident))
    i = 0

    def peek():
        return tokens[i][0] if i < len(tokens) else None

    def take(kind=None):
        nonlocal i
        tok = tokens[i]
        if kind and tok[0] != kind:
            raise ValueError(f"expected {kind}, found {tok}")
        i += 1
        return tok

    def primary():
        kind, val = take()
        if kind == "{":
            fields = {}
            while peek() != "}":
                name = take("id")[1]
                take(":=")
                fields[name] = term()
                if peek() == ",":
                    take()
            take("}")
            return {"record": fields}
        if kind in ("[", "("):
            close = "]" if kind == "[" else ")"
            items = []
            while peek() != close:
                items.append(term())
                if peek() == ",":
                    take()
            take(close)
            if kind == "[":
                return {"list": items}
            return items[0] if len(items) == 1 else {"tuple": items}
        if kind in ("str", "num"):
            return val
        if kind == "id":
            return {"id": val}
        raise ValueError(f"unexpected {kind}")

    def term():
        head = primary()
        args = []
        while isinstance(head, dict) and "id" in head and peek() in ("{", "[", "(", "str", "num", "id"):
            args.append(primary())
        return {"app": head["id"], "args": args} if args else head

    value = term()
    if i != len(tokens):
        raise ValueError("trailing text")
    return value


def words(name):
    """The last part of a Lean name in words: emptyOffer as "empty offer"; USD stays USD."""
    last = name.rsplit(".", 1)[-1]
    if last.isupper():
        return last
    return re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", last).replace("_", " ").lower()


def field_label(name):
    w = words(name)
    return w[:1].upper() + w[1:]


def inline(v):
    """A value as one line of Verso text."""
    if isinstance(v, str):
        return verso_escape(v)
    if isinstance(v, int):
        return str(v)
    if "record" in v:
        f = v["record"]
        if set(f) == {"amount", "currency"} and isinstance(f["amount"], int):
            return f"{f['amount'] // 100}.{f['amount'] % 100:02d} {inline(f['currency'])}"
        if set(f) == {"epochSeconds"} and isinstance(f["epochSeconds"], int):
            t = datetime.datetime.fromtimestamp(f["epochSeconds"], datetime.UTC)
            return t.strftime("%Y-%m-%d %H:%M UTC")
        return ", ".join(f"{words(k)} {inline(x)}" for k, x in f.items())
    if "id" in v:
        return {"true": "yes", "false": "no", "none": "none"}.get(v["id"], words(v["id"]))
    if "app" in v:
        if v["app"] == "some" and len(v["args"]) == 1:
            return inline(v["args"][0])
        return words(v["app"]) + " " + " ".join(inline(a) for a in v["args"])
    if "list" in v:
        return ", ".join(inline(x) for x in v["list"]) or "none"
    if "tuple" in v:
        return ", ".join(inline(x) for x in v["tuple"])
    return verso_escape(str(v))


def record_table(rows):
    """A list of records with the same fields as a Verso table."""
    keys = list(rows[0]["record"])
    out = [":::table +header", "*"] + [f"  * {field_label(k)}" for k in keys]
    for r in rows:
        out.append("*")
        out += [f"  * {inline(r['record'][k])}" for k in keys]
    return out + [":::"]


def is_record_list(v):
    return (isinstance(v, dict) and "list" in v and v["list"]
            and all(isinstance(x, dict) and "record" in x for x in v["list"])
            and len({tuple(x["record"]) for x in v["list"]}) == 1)


def readable(v):
    """Verso blocks that show a computed value."""
    if isinstance(v, dict) and "app" in v and v["app"] == "Except.error" and len(v["args"]) == 1:
        return [f"Rejected: {inline(v['args'][0])}."]
    if isinstance(v, dict) and "app" in v and v["app"] == "Except.ok" and len(v["args"]) == 1:
        return ["Accepted. The result:", ""] + readable(v["args"][0])
    if is_record_list(v):
        return record_table(v["list"])
    if isinstance(v, dict) and "record" in v:
        out, tables = [], []
        for k, x in v["record"].items():
            if is_record_list(x):
                out.append(f" * {field_label(k)}: see the table below.")
                tables += ["", f"{field_label(k)}:", ""] + record_table(x["list"])
            else:
                out.append(f" * {field_label(k)}: {inline(x)}")
        return out + tables
    return [inline(v)]


def computed_blocks(value):
    try:
        return readable(parse_value(value))
    except (ValueError, IndexError, KeyError, TypeError):
        fence = "```"
        while fence in value:
            fence += "`"
        return [fence, value, fence]


def state_diagram(rows):
    """An SVG of the moves in a transition table (records with before, event, after)."""
    states = []
    for r in rows:
        for k in ("before", "after"):
            x = r["record"][k]
            name = inline(x)
            if name != "none" and name not in states:
                states.append(name)
    lines = [
        "digraph G {",
        '  graph [rankdir=LR, bgcolor="transparent", nodesep=0.5, ranksep=0.9, pad=0.1];',
        '  node [shape=box, style="rounded", fontname="Helvetica", fontsize=12, margin="0.18,0.08", class="state"];',
        '  edge [fontname="Helvetica", fontsize=11, arrowsize=0.7, class="move"];',
    ]
    for s in states:
        lines.append(f'  "{s}" [label="{s}"];')
    for r in rows:
        f = r["record"]
        after = inline(f["after"])
        if after != "none":
            lines.append(f'  "{inline(f["before"])}" -> "{after}" [label=" {inline(f["event"])} "];')
    lines.append("}")
    svg = subprocess.run(["dot", "-Tsvg"], input="\n".join(lines), capture_output=True, text=True, check=True).stdout
    svg = svg[svg.index("<svg"):]
    svg = re.sub(r"<title>[^<]*</title>\n?", "", svg)
    svg = re.sub(r' (fill|stroke)="(?!none)[^"]*"', "", svg)
    svg = svg.replace("<svg ", '<svg class="state-diagram" role="img" aria-label="Delivery state diagram" ', 1)
    return svg


# ----------------------------------------------------------- requirements

# Try-it panels, by rule.  Review/review.js loads build/try/rules.wasm (the
# Rust functions from impl/rust, compiled by scripts/build-wasm.sh) and wires
# the panels to it.
TRY_NOTE = (
    '<p class="try-note">The answer comes from the Rust function <code>{fn}</code>, compiled to WebAssembly '
    'and running in your browser. Lean proves that this function computes what the model computes, for every '
    'input (<a href="https://github.com/samdengler/verified-air/blob/main/Verify/RustRules.lean">'
    'Verify/RustRules.lean</a>). The few lines that pass your choices to it are not part of the proof.</p>'
)
STATE_OPTIONS = "".join(f'<option value="{i}">{s}</option>' for i, s in enumerate(["ready", "delivered", "cancelled", "refunded"]))
EVENT_OPTIONS = "".join(f'<option value="{i}">{e}</option>' for i, e in enumerate(["deliver", "cancel", "refund"]))
PAYMENT_OPTIONS = '<option value="1">PAY-1</option><option value="2">another payment</option>'
TRY_PANELS = {
    "Rules.OfferOrder.step": (
        '<div class="try-it" data-try="step">'
        '<p class="try-title">Try the rule</p>'
        f'<div class="try-row"><label>State <select name="state">{STATE_OPTIONS}</select></label>'
        f'<label>Event <select name="event">{EVENT_OPTIONS}</select></label></div>'
        '<p class="try-result" aria-live="polite">Loading the rule...</p>'
        + TRY_NOTE.format(fn="step") + "</div>"
    ),
    "Rules.OfferOrder.acceptRefund": (
        '<div class="try-it" data-try="refund">'
        '<p class="try-title">Try the rule</p>'
        '<div class="try-row"><label>Payment PAY-1 of <input name="paid" type="number" min="0" step="0.01" value="100.00"> USD</label></div>'
        f'<div class="try-row"><label>Refund 1 of <input name="r1" type="number" min="0" step="0.01" value="60.00"> USD against <select name="p1">{PAYMENT_OPTIONS}</select></label></div>'
        f'<div class="try-row"><label>Refund 2 of <input name="r2" type="number" min="0" step="0.01" value="60.00"> USD against <select name="p2">{PAYMENT_OPTIONS}</select></label></div>'
        '<p class="try-result" aria-live="polite">Loading the rule...</p>'
        + TRY_NOTE.format(fn="accept_refund")
        + '<p class="try-note">The rule checks each refund on its own. The total of the accepted refunds is added up by this page.</p>'
        "</div>"
    ),
}

CRITERION_STATUS = {
    "proven": '{status "proven"}[Proven]',
    "example": '{status "example"}[Example only]',
    "open": '{status "open"}[Open]',
    "not checked": '{status "notChecked"}[Not checked]',
}


def requirement_module(ears_id):
    return ears_id.replace("-", "")


def check_title(name, decls, titles):
    d = decls.get(name, {})
    short = name.rsplit(".", 1)[-1]
    return titles.get(name, humanize(short)) if d.get("kind") == "theorem" else humanize(short)


def section_tag(kind, name):
    """The Verso tag of a guarantee's or example's section, such as
    guarantee-delivered-not-cancellable.  Links elsewhere on the site find the
    section through Verso's lookup with this tag (scripts/render_progress.py)."""
    ns, short = name.rsplit(".", 1)
    # Pilot tags keep their original form; other namespaces add theirs, since
    # the ONE Order rules reuse names such as accept_rejects_expired.
    prefix = "" if name.startswith(PILOT) else kebab(ns.rsplit(".", 1)[-1]) + "-"
    return f"{kind}-{prefix}" + short.replace("_", "-")


def chapter_tag(kind, d, ears_id):
    """The section tag of a guarantee or example in one requirement's chapter.  A
    declaration that checks several requirements appears in each chapter; the
    chapter of its first criterion keeps the plain tag, which other pages link to."""
    tag = section_tag(kind, d["name"])
    home = min(d["checks"]).rsplit(".", 1)[0]
    return tag if home == ears_id else f"{tag}-in-{ears_id.lower()}"


def render_requirement(rule, decls, titles, sources):
    ears_id = rule["earsId"]
    prefix = ears_id + "."
    def checks_this(d):
        return any(c.startswith(prefix) for c in d.get("checks", []))
    theorems = sorted((d for d in decls.values() if d["kind"] == "theorem" and checks_this(d)),
                      key=lambda d: (min(d["checks"]), d["name"]))
    cases = sorted((d for d in decls.values() if d["kind"] == "case" and checks_this(d)),
                   key=lambda d: (min(d["checks"]), d["name"]))
    title = titles.get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
    criteria = rule.get("criteria", [])
    counts = {}
    for c in criteria:
        counts[c["status"]] = counts.get(c["status"], 0) + 1
    phrases = {"proven": "proven", "example": "checked by examples only", "open": "open",
               "not checked": "not checked yet"}
    parts_ = [f"{n} {'is' if n == 1 else 'are'} {phrases[s]}"
              for s, n in sorted(counts.items(), key=lambda x: list(CRITERION_TEXT).index(x[0]))]
    summary = parts_[0] if len(parts_) == 1 else ", ".join(parts_[:-1]) + " and " + parts_[-1]
    parts = [VERSO_HEADER, f'#doc (Manual) "{title}" =>', "%%%", f'tag := "{ears_id.lower()}"', "%%%", ""]
    links = ", ".join(f"[{verso_escape(s['title'])}]({s['url']})" for s in rule_sources(rule, sources))
    parts += [
        f"Requirement {ears_id}. Of its {len(criteria)} acceptance criteria, {summary}.",
        "",
        f"Sources: {links}. {verso_escape(confirmation_text(rule))}",
        "",
        f'{{docstring {rule["name"]} +hideStructureConstructor (label := "rule")}}',
        "",
        "# How each acceptance criterion is checked",
        "",
        "A criterion is proven when a guarantee below proves it for every input, and example only when only "
        "examples check it.",
        "",
        ":::table +header",
        "*",
        "  * Criterion",
        "  * Status",
        "  * Checked by",
    ]
    for c in criteria:
        by = ", ".join(check_title(n, decls, titles) for n in c.get("checkedBy", [])) or "nothing yet"
        parts += ["*", f"  * {c['id']}", f"  * {CRITERION_STATUS[c['status']]}", f"  * {verso_escape(by)}"]
    parts += [":::", ""]

    for d in cases:
        try:
            v = parse_value(d["value"])
        except (ValueError, IndexError, KeyError):
            continue
        if is_record_list(v) and set(v["list"][0]["record"]) == {"before", "event", "after"}:
            parts += [
                "# Delivery state diagram",
                "",
                f"The build runs every state and event through the model in the example "
                f"{{lean}}`{d['name']}` and draws the moves the rule allows. Any event without an arrow is refused.",
                "",
                "```rawHtml",
                f'<figure class="diagram">{state_diagram(v["list"])}</figure>',
                "```",
                "",
            ]

    if rule["name"] in TRY_PANELS:
        parts += [
            "# Try it",
            "",
            "Choose the inputs and see what the rule decides.",
            "",
            "```rawHtml",
            TRY_PANELS[rule["name"]],
            "```",
            "",
        ]
    if theorems:
        parts += ["# Guarantees", ""]
        for d in theorems:
            parts += [
                f"## {verso_escape(check_title(d['name'], decls, titles))}",
                "%%%",
                f'tag := "{chapter_tag("guarantee", d, ears_id)}"',
                "%%%",
                "",
                f'{{docstring {d["name"]} (label := "guarantee")}}',
                "",
                STATUS_TEXT[d["status"]],
                "",
                f"Checks acceptance criteria {', '.join(d['checks'])}.",
                "",
            ]
    if cases:
        parts += ["# Examples", ""]
        for d in cases:
            parts += [
                f"## {humanize(d['name'].rsplit('.', 1)[-1])}",
                "%%%",
                f'tag := "{chapter_tag("example", d, ears_id)}"',
                "%%%",
                "",
                f'{{docstring {d["name"]} (label := "example")}}',
                "",
                "*What Lean computed:*",
                "",
            ] + computed_blocks(d["value"]) + [
                "",
                f"Checks acceptance criteria {', '.join(d['checks'])}.",
                "",
            ]
    for d in (t for t in theorems if t["status"] == "open"):
        title = check_title(d["name"], decls, titles)
        shown_by = [humanize(c["name"].rsplit(".", 1)[-1]) for c in cases if set(c["checks"]) & set(d["checks"])]
        why = (f"the example {', '.join(shown_by)} shows the rule as written breaking it"
               if shown_by else "it has no proof yet")
        where = ("[Open Questions](Open-Questions/)" if d["name"].startswith(PILOT)
                 else f"[{QUESTIONS_TITLE}]({slug(QUESTIONS_TITLE)}/)")
        parts += [
            "# Open question",
            "",
            f"The guarantee {verso_escape(title)} is open: {why}. "
            f"{where} sets out the question for the team.",
            "",
        ]
    module = requirement_module(ears_id)
    (GENERATED / f"{module}.lean").write_text("\n".join(parts))
    return module


def lean_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


STATUS_ICON = {"proven": "✓", "example": "◆", "open": "!", "not checked": "…"}
CHIP_TEXT = {"proven": "proven", "example": "by example", "open": "open", "not checked": "not checked"}
STATUS_CLASS = {"proven": "s-proven", "example": "s-example", "open": "s-open", "not checked": "s-notChecked"}
REFERENCE_CHAPTERS = [
    ("Overview", "How to read this document, where the material comes from, and what the build computes."),
    ("Open Questions", "What the pilot model could not settle, and the decision it needs from the team."),
    (QUESTIONS_TITLE, "The open guarantees in the ONE Order rules, each with the example that breaks it."),
    ("Objects", "The offers, orders, payments and refunds the rules talk about."),
    ("EARS requirements", "Every requirement statement in one table."),
]


def slug(title):
    return re.sub(r"[^A-Za-z0-9-]", "", title.replace(" ", "-"))


def render_front(decls, titles):
    """The review document's front page: a card per requirement, then the reference chapters."""
    cards = []
    for rule in ears_rows(decls):
        title = titles.get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
        counts = {}
        for c in rule.get("criteria", []):
            counts[c["status"]] = counts.get(c["status"], 0) + 1
        chips = "".join(
            f'<span class="status {STATUS_CLASS[st]}"><span class="ico" aria-hidden="true">{STATUS_ICON[st]}</span>'
            f'{n} {CHIP_TEXT[st]}</span>'
            for st, n in sorted(counts.items(), key=lambda x: list(CRITERION_TEXT).index(x[0])))
        story = html.escape(plain(rule.get("story") or ""))
        cards.append(
            f'<a class="req-card" href="{slug(title)}/">'
            f'<span class="req-id">{rule["earsId"]}</span>'
            f'<span class="req-title">{html.escape(title)}</span>'
            f'<span class="req-story">{story}</span>'
            f'<span class="req-stats">{chips}</span></a>')
    refs = "".join(f'<li><a href="{slug(t)}/">{html.escape(t)}</a>: {html.escape(d)}</li>' for t, d in REFERENCE_CHAPTERS)
    page = (
        '<section class="front">'
        '<h2>Requirements</h2>'
        '<p class="front-note">One chapter per requirement: the rule, how each acceptance criterion is checked, '
        'the guarantees Lean proves, examples, and a panel to try the rule where there is one.</p>'
        f'<div class="req-cards">{"".join(cards)}</div>'
        '<h2>Reference</h2>'
        f'<ul class="ref-list">{refs}</ul>'
        '</section>'
    )
    (GENERATED / "Front.lean").write_text(
        "-- Generated by scripts/render_status.py from build/status.json.  Do not edit.\n\n"
        "namespace Review.Generated.Front\n\n"
        "/-- The front page's requirement cards and reference list, as HTML. -/\n"
        f"def html : String := {lean_string(page)}\n\n"
        "end Review.Generated.Front\n")


def render_requirements(decls):
    titles = blueprint_titles()
    sources = load_sources()
    modules = [render_requirement(r, decls, titles, sources) for r in ears_rows(decls)]
    render_front(decls, titles)
    render_questions(decls, titles)
    modules.append("Questions")
    review = (ROOT / "Review" / "Review.lean").read_text()
    missing = [m for m in modules if f"{{include 1 Review.Generated.{m}}}" not in review]
    if missing:
        sys.exit("Review/Review.lean does not include " + ", ".join(f"Review.Generated.{m}" for m in missing))
    return modules


def render_questions(decls, titles):
    """A chapter with one section per open guarantee outside the pilot rules."""
    open_ = sorted((d for d in decls.values()
                    if d["kind"] == "theorem" and d["status"] == "open" and not d["name"].startswith(PILOT)),
                   key=lambda d: (min(d["checks"] or ["~"]), d["name"]))
    rules = {c["id"]: r for r in ears_rows(decls) for c in r.get("criteria", [])}
    n = len(open_)
    parts = [VERSO_HEADER, f'#doc (Manual) "{QUESTIONS_TITLE}" =>', "%%%", 'tag := "one-order-questions"', "%%%", ""]
    parts += [
        f"{n} {'guarantee is' if n == 1 else 'guarantees are'} open in the ONE Order rules. "
        "Each is a place where IATA's public material is vague or silent, so the rule as written allows a case "
        "the guarantee forbids. An example the build computes shows that case, and the question under it is "
        "for the business to answer. The model does not decide it.",
        "",
    ]
    for d in open_:
        title = check_title(d["name"], decls, titles)
        owner = next((rules[c] for c in d["checks"] if c in rules), None)
        parts += [f"# {verso_escape(title)}", "%%%", f'tag := "{section_tag("question", d["name"])}"', "%%%", ""]
        parts += [f'{{docstring {d["name"]} (label := "open question")}}', ""]
        if owner:
            chapter = titles.get(owner["name"], humanize(owner["name"].rsplit(".", 1)[-1]))
            parts += [f"It checks acceptance criteria {', '.join(d['checks'])} of requirement {owner['earsId']}, "
                      f"[{verso_escape(chapter)}]({slug(chapter)}/).", ""]
    (GENERATED / "Questions.lean").write_text("\n".join(parts))


def render_ears_verso(decls):
    parts = [VERSO_HEADER, '#doc (Manual) "EARS requirements" =>', "%%%", 'tag := "ears"', "%%%", ""]
    parts.append(
        "This table lists every EARS statement in the model, with the rule that implements it and the "
        "guarantees that mention that rule. The build generates it from the docstrings; the same table "
        "is in the blueprint and in [ears.csv](../ears.csv)."
    )
    parts.append("")
    parts += [":::table +header", "*", "  * ID", "  * EARS statement", "  * Rule", "  * Status", "  * Proven by"]
    for d in ears_rows(decls):
        pb = ", ".join(
            f"`{short}`" + (" (open)" if st == "open" else "") for _, short, st in proven_by(d, decls)
        ) or "none"
        parts += [
            "*",
            f"  * {d.get('earsId') or ''}",
            f"  * {verso_escape(d['ears'])}",
            f"  * `{d['name'].rsplit('.', 1)[-1]}`",
            f"  * {DECL_STATUS.get(d['status'], d['status'])}",
            f"  * {pb}",
        ]
    parts += [":::", ""]
    (GENERATED / "Ears.lean").write_text("\n".join(parts))


# -------------------------------------------------------------------- kiro

SPEC_MARK = "<!-- Generated by scripts/render_status.py"

CRITERION_TEXT = {
    "proven": "proven",
    "example": "example only",
    "open": "open",
    "not checked": "not checked",
}


def plain(s):
    """Docstring text with Verso roles such as {name}`x` reduced to `x`."""
    return re.sub(r"\{(?:name|lit|lean|attr)\}`", "`", s)


def kiro_ears(s):
    """An EARS statement in Kiro's notation: WHEN ... THE SYSTEM SHALL ..."""
    s = re.sub(r",? then the system shall ", " THEN THE SYSTEM SHALL ", s)
    s = re.sub(r", the system shall ", " THE SYSTEM SHALL ", s)
    s = re.sub(r"^The system shall ", "THE SYSTEM SHALL ", s)
    return re.sub(r"^(When|While|If|Where) ", lambda m: m.group(1).upper() + " ", s)


def module_doc(module):
    """The title and the paragraphs of a module's `/-! ... -/` docstring."""
    path = ROOT / (module.replace(".", "/") + ".lean")
    m = re.search(r"/-!(.*?)-/", path.read_text(), re.S)
    lines = m.group(1).strip().splitlines()
    title = lines[0].lstrip("# ").strip()
    body = "\n".join(lines[1:]).strip()
    return path.relative_to(ROOT).as_posix(), title, plain(body)


def kebab(s):
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", s)
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def checked_by_text(c, decls):
    parts = []
    # Theorems first, then examples.
    for n in sorted(c["checkedBy"], key=lambda n: (decls[n]["kind"] == "case", n)):
        d = decls[n]
        short = d["name"].rsplit(".", 1)[-1]
        if d["kind"] == "case":
            label = "counterexample" if c["status"] == "open" else "example"
        else:
            label = f"{d['status']} theorem"
        parts.append(f"{label} `{short}`")
    return "; ".join(parts) if parts else "nothing in the build checks this yet"


def spec_dirs(decls):
    """Rules grouped by module, with each group's spec folder name."""
    groups = {}
    for d in ears_rows(decls):
        groups.setdefault(d["module"], []).append(d)
    out = []
    for module, rules in groups.items():
        source, title, intro = module_doc(module)
        group = kebab(module.split(".")[1])
        out.append((f"{group}-{kebab(title)}", module, source, title, intro, rules))
    return sorted(out, key=lambda g: g[5][0]["earsId"])


SPEC_PROVENANCE_NOTE = (
    " *Sources* lists the pages each rule was written from, and *Confirmation* says whether anyone outside "
    "the model has confirmed the rule as written."
)


def spec_provenance_lines(d, sources):
    """The Sources and Confirmation lines under a requirement's rule in its spec."""
    links = "; ".join(f"[{s['title']}]({s['url']}) ({s['kind']})" for s in rule_sources(d, sources))
    return ["", f"**Sources:** {links}", "", f"**Confirmation:** {confirmation_text(d)}"]


def render_spec(folder, source, title, intro, rules, decls, sources):
    lines = [
        f"{SPEC_MARK} from {source}. Edit the docstrings there, not this file. -->",
        "",
        f"# Requirements Document: {title}",
        "",
        "## Introduction",
        "",
        intro,
        "",
        f"These requirements are generated from the Lean model in [`{source}`]({REPO}/{source}). "
        "Each acceptance criterion carries the status the build computed for it: *proven* means a "
        "theorem the build checked, *example only* means a computed example, *open* means a theorem "
        "the build could not prove, and *not checked* means no theorem or example covers it yet."
        + SPEC_PROVENANCE_NOTE,
        "",
        "## Requirements",
        "",
    ]
    for d in rules:
        rule = d["name"].rsplit(".", 1)[-1]
        lines += [
            f"### Requirement {d['earsId']}",
            "",
            f"**User Story:** {d['story']}",
            "",
            f"**Rule:** {kiro_ears(d['ears'])} (Lean: `{rule}`)",
        ] + spec_provenance_lines(d, sources) + [
            "",
            "#### Acceptance Criteria",
            "",
        ]
        for i, c in enumerate(d["criteria"], 1):
            lines += [
                f"{i}. {kiro_ears(c['ears'])}",
                f"   - {c['id']}, {CRITERION_TEXT[c['status']]}: {checked_by_text(c, decls)}",
            ]
        lines.append("")
        for c in d["criteria"]:
            for n in c["checkedBy"]:
                t = decls[n]
                if t["kind"] == "theorem" and t["status"] == "open":
                    lines += [f"#### Open question on {c['id']}", ""]
                    lines += ["> " + l if l else ">" for l in plain(t["docstring"]).splitlines()]
                    lines.append("")
    (SPECS / folder).mkdir(parents=True, exist_ok=True)
    (SPECS / folder / "requirements.md").write_text("\n".join(lines))


def render_specs_index(groups, decls):
    criteria = [c for *_, rules in groups for d in rules for c in d["criteria"]]
    counts = {k: sum(c["status"] == k for c in criteria) for k in CRITERION_TEXT}
    lines = [
        f"{SPEC_MARK} from build/status.json. Do not edit. -->",
        "",
        "# Specs generated from the Lean model",
        "",
        "Each folder is a requirement spec with one `requirements.md`, generated from the rules in one Lean "
        "module. The acceptance criteria are in EARS notation, and the folders follow the layout Kiro reads. "
        "The rule's docstring holds the user story and the acceptance criteria; the build "
        "computes each criterion's status from the theorems and examples tagged `@[checks]` with its ID. "
        "To change a requirement, edit the docstring and rebuild.",
        "",
        f"{len(criteria)} acceptance criteria: {counts['proven']} proven, {counts['example']} example only, "
        f"{counts['open']} open, {counts['not checked']} not checked.",
        "",
        provenance_summary([d for *_, rules in groups for d in rules]),
        "",
        "| Spec | Requirement | User story | Criteria | Proven | Example only | Open | Not checked |",
        "| --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for folder, _, _, title, _, rules in groups:
        for d in rules:
            n = lambda k: sum(c["status"] == k for c in d["criteria"])
            lines.append(
                f"| [{title}]({folder}/requirements.md) | {d['earsId']} | {d['story']} | {len(d['criteria'])} "
                f"| {n('proven')} | {n('example')} | {n('open')} | {n('not checked')} |"
            )
    lines += ["", "## Acceptance criteria", "", "| ID | Criterion | Status | Checked by |", "| --- | --- | --- | --- |"]
    for c in criteria:
        lines.append(f"| {c['id']} | {kiro_ears(c['ears'])} | {CRITERION_TEXT[c['status']]} | {checked_by_text(c, decls)} |")
    lines += [
        "",
        "The same rows are in [`ears-criteria.csv`](https://samdengler.github.io/verified-air/ears-criteria.csv), "
        "and one row per rule is in [`ears.csv`](https://samdengler.github.io/verified-air/ears.csv). "
        "Each rule's sources and confirmation are in "
        "[`provenance.csv`](https://samdengler.github.io/verified-air/provenance.csv).",
        "",
    ]
    (SPECS / "README.md").write_text("\n".join(lines))


def provenance_summary(rules):
    """One sentence counting the rules by provenance."""
    n = {p: sum(d.get("provenance") == p for d in rules) for p in PROVENANCE_TEXT}
    return (f"{len(rules)} rules: {n['confirmed']} {PROVENANCE_TEXT['confirmed']}, "
            f"{n['out of date']} {PROVENANCE_TEXT['out of date']}, {n['sourced']} {PROVENANCE_TEXT['sourced']}, "
            f"{n['assumed']} {PROVENANCE_TEXT['assumed']}.")


def render_specs(decls):
    groups = spec_dirs(decls)
    written = {g[0] for g in groups}
    # Remove spec folders this script wrote earlier for modules that no longer have rules.
    if SPECS.exists():
        for f in SPECS.glob("*/requirements.md"):
            if f.parent.name not in written and f.read_text().startswith(SPEC_MARK):
                f.unlink()
                f.parent.rmdir()
    sources = load_sources()
    for folder, _, source, title, intro, rules in groups:
        render_spec(folder, source, title, intro, rules, decls, sources)
    render_specs_index(groups, decls)


def main():
    decls = load_status()
    GENERATED.mkdir(parents=True, exist_ok=True)
    render_content(decls)
    render_ears_tex(decls)
    modules = render_requirements(decls)
    render_ears_verso(decls)
    for stale in GENERATED.glob("*.lean"):
        if stale.stem not in modules + ["Ears", "Front"]:
            stale.unlink()
    render_specs(decls)
    print("rendered blueprint/src/content.generated.tex, ears.generated.tex, "
          "Review/Review/Generated/*.lean, .kiro/specs/")


if __name__ == "__main__":
    main()
