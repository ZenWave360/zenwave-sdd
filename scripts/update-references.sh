#!/usr/bin/env bash
# Refreshes the third-party and ZenWave reference material in templates/ by copying the latest versions, then
# copies it into the skills (sync-references.sh). Review the result with `git diff`.
#
#   scripts/update-references.sh
#
# Sources, overridable with environment variables:
#   GRILLING_URL     Matt Pocock's grilling skill (MIT), and its LICENSE next to it
#   ZENWAVE_DOCS     ZenWave360.github.io/src/content/docs/ZenWave360   (ZFL-Flow-Language.mdx, ZDL-Domain-Language.mdx)
#   DSL_GRAMMAR      dsl-kotlin/dsl-kotlin/src/commonMain/antlr/io.zenwave360.language.antlr   (Zfl.g4, Zdl.g4)
#   ARCADIA          the folder with the arcadia-editions repositories (the examples)
# A source that is missing is reported and its current copy kept.
set -uo pipefail
cd "$(dirname "$0")/.."
here=$(pwd)
workspace=$(cd .. && pwd)

GRILLING_URL=${GRILLING_URL:-https://raw.githubusercontent.com/mattpocock/skills/main}
ZENWAVE_DOCS=${ZENWAVE_DOCS:-$workspace/ZenWave360.github.io/src/content/docs/ZenWave360}
DSL_GRAMMAR=${DSL_GRAMMAR:-$workspace/dsl-kotlin/dsl-kotlin/src/commonMain/antlr/io.zenwave360.language.antlr}
ARCADIA=${ARCADIA:-$(cd "$workspace/../arcadia-editions" 2>/dev/null && pwd)}

missing=0
fetch() {   # fetch <url> <target>
  local tmp; tmp=$(mktemp)
  if curl -fsSL "$1" -o "$tmp"; then mkdir -p "$(dirname "$2")"; mv "$tmp" "$2"; echo "updated $2"
  else rm -f "$tmp"; echo "MISSING $1 (kept $2)"; missing=1; fi
}
copy() {    # copy <source> <target>
  if [[ -f "$1" ]]; then mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "updated $2"
  else echo "MISSING $1 (kept $2)"; missing=1; fi
}

# Grilling: Matt Pocock's skill, verbatim, with its licence.
fetch "$GRILLING_URL/skills/productivity/grilling/SKILL.md" templates/grilling/mattpocock-grilling.md
fetch "$GRILLING_URL/LICENSE" templates/grilling/LICENSE-mattpocock

# The ZenWave languages: the docs pages as they are, the grammar, and the Arcadia Editions examples.
L=templates/zenwave-languages
copy "$ZENWAVE_DOCS/ZFL-Flow-Language.mdx" "$L/ZFL-Flow-Language.mdx"
copy "$ZENWAVE_DOCS/ZDL-Domain-Language.mdx" "$L/ZDL-Domain-Language.mdx"
copy "$DSL_GRAMMAR/Zfl.g4" "$L/grammar/Zfl.g4"
copy "$DSL_GRAMMAR/Zdl.g4" "$L/grammar/Zdl.g4"
copy "$ARCADIA/arcadia-editions-architecture/business-flows/place-order-flow.zfl" "$L/examples/place-order-flow.zfl"
copy "$ARCADIA/orders-checkout-api/domain-model.zdl" "$L/examples/microservices/orders-checkout-domain-model.zdl"
copy "$ARCADIA/payments-processing-api/domain-model.zdl" "$L/examples/microservices/payments-processing-domain-model.zdl"
copy "$ARCADIA/arcadia-editions-modulith-api/orders-checkout-domain-model.zdl" "$L/examples/modulith/orders-checkout-domain-model.zdl"
copy "$ARCADIA/arcadia-editions-modulith-api/payments-processing-domain-model.zdl" "$L/examples/modulith/payments-processing-domain-model.zdl"

cd "$here" && bash scripts/sync-references.sh >/dev/null && echo "synced into the skills"
exit $missing
