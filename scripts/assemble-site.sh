#!/usr/bin/env bash
# Assemble site/ from the build outputs, in the layout GitHub Pages serves:
# the home page at the root, the progress page under progress/, the Explore
# page under graph/, a summary page per area under area/, the tour under
# tour/, the review document under review/, the blueprint under blueprint/,
# the try-it panels' WebAssembly under try/, the motion piece under motion/,
# the files Verified Airline's site reads under airline-data/, and the specs
# and exports beside them.  airline/ sends readers to Verified Airline's own
# site.  history/ sends readers to the Explore page's History tab,
# which shows the motion piece.
#
#   scripts/assemble-site.sh
#
# CI, scripts/build-site.sh and scripts/preview.sh all use this script.  The
# blueprint PDF, the conformance vectors and the WebAssembly are required unless
# ALLOW_MISSING=1, which the preview sets because it skips those steps.
set -euo pipefail
cd "$(dirname "$0")/.."

optional() {
  if [ -f "$1" ]; then
    cp "$1" "$2"
  elif [ "${ALLOW_MISSING:-}" != 1 ]; then
    echo "missing $1" >&2
    exit 1
  fi
}

rm -rf site
mkdir -p site/blueprint site/review
cp build/home/index.html site/index.html
mkdir -p site/progress
cp build/progress/index.html site/progress/
mkdir -p site/graph
cp build/graph/index.html build/graph/graph.json site/graph/
# The motion piece is rendered by scripts/render-motion.sh and committed; CI
# does not render video.
mkdir -p site/motion
cp motion/out/history.mp4 motion/out/history-poster.jpg site/motion/
mkdir -p site/history site/tour
cp build/history/index.html site/history/
cp -r build/area site/area
cp build/tour/index.html site/tour/
# The files Verified Airline's site reads: facts.json and model.json.
cp -r build/airline-data site/airline-data
# Verified Airline's pages were under airline/ until they moved to their own
# site.  Each old address sends readers to the same page there, keeping
# ?lean=1 and the anchor.
airline_site=https://air.dengler.io/
for p in "" policies/ policies/fares/ policies/paying/ policies/changes/ policies/refunds/ policies/extras/ \
  policies/schedule-changes/; do
  mkdir -p "site/airline/$p"
  cat > "site/airline/${p}index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Verified Airline has moved</title>
<link rel="canonical" href="$airline_site$p">
<script>location.replace("$airline_site$p" + location.search + location.hash);</script>
<meta http-equiv="refresh" content="0; url=$airline_site$p">
</head>
<body><p>Verified Airline has moved to <a href="$airline_site$p">its own site</a>.</p></body>
</html>
EOF
done
cp -r build/review/html-multi/. site/review/
cp -r pages/. site/
cp -r blueprint/web/. site/blueprint/
python3 scripts/site_nav.py site/blueprint
optional blueprint/print/print.pdf site/blueprint/print.pdf
cp -r .kiro/specs site/specs
cp build/ears.md build/ears.csv build/ears-criteria.csv build/provenance.csv build/status.json site/
optional build/oracle/vectors.jsonl site/conformance-vectors.jsonl
mkdir -p site/try
optional build/try/rules.wasm site/try/rules.wasm
