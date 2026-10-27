#!/usr/bin/env bash
# template-lib.sh — helpers shared by new-project.sh and adopt-into.sh. SOURCED, not run.
# Template-only: it is NOT copied into new or adopted projects.

# tl_strip_record <in> <out>
# Keep a record file's header, rules, entry template and the illustrative
# worked example (D-000/F-000/L-000 — they sit ABOVE "## Entries", so the
# SessionStart briefing never shows them), and drop every real entry: output
# stops at the "<!-- Append new ... below this line. -->" marker.
tl_strip_record() {
  awk '{ print } /^<!-- Append new .* below this line\. -->/ { exit }' "$1" > "$2"
  if ! grep -q '^<!-- Append new .* below this line\. -->' "$2"; then
    echo "WARNING: no 'Append new ... below this line' marker in $1 — copied whole" >&2
  fi
}

# tl_strip_mistakes <in> <out>
# Keep every pattern (P1, P2, ...) but empty its instance list: drop dated
# instance lines ("- YYYY-MM-DD — ...") outside fenced code blocks.
tl_strip_mistakes() {
  awk '/^```/ { code = !code }
       !code && /^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ { next }
       { print }' "$1" > "$2"
}

# tl_real_entries <file>  -> prints real (non-example) entry headings, if any
tl_real_entries() {
  awk '/^## Entries/ { on = 1; next } on && /^### [DFL]-[0-9]+/' "$1"
}

# tl_subst <file> <name> <date>  -> replace {{PROJECT_NAME}} / {{CREATED_DATE}} in place
tl_subst() {
  local esc
  esc="$(printf '%s' "$2" | sed -e 's/[\/&|]/\\&/g')"
  sed -i.tlbak -e "s|{{PROJECT_NAME}}|$esc|g" -e "s|{{CREATED_DATE}}|$3|g" "$1" && rm -f "$1.tlbak"
}

# Files that belong to the template itself and are never copied into a project.
TL_TEMPLATE_ONLY="scripts/new-project.sh scripts/adopt-into.sh scripts/template-lib.sh tests/test_adopt.sh tests/test_global_install.sh"
