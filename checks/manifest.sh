#!/usr/bin/env bash
# manifest.sh — record a known-good state of one box; compare each run against it.
# Exit codes: 0 match, 1 drift, 2 cannot-observe (including usage errors).
# The config fingerprint covers every key and value EXCEPT the paths a legitimate
# switch changes (VOLATILE), so a model switch is not drift but an edited fallback
# list is.
set -uo pipefail

[ -n "${HERMES_HOME:-}" ] || { echo "CANNOT-OBSERVE: HERMES_HOME not set; resolve it from the runtime (§1.3)" >&2; exit 2; }
MANIFEST="${MANIFEST:-$HERMES_HOME/state/known-good.manifest}"
VOLATILE="${VOLATILE:-model.default model.provider}"   # registry: {{model_default}} {{model_provider}}
TOOLS="${SELECTOR_TOOLS:-}"                            # registry list: selector_tools
REQUIRED="${REQUIRED_FILES:-}"                         # optional: files under scripts/ that must exist
MODE="${1:-check}"

compute() {
  ( cd "$HERMES_HOME/scripts" && find . -type f -not -path './.git/*' -exec sha256sum {} + | sort ) \
    || { echo "CANNOT-OBSERVE: scripts unreadable"; return 2; }
  for f in $REQUIRED; do
    [ -f "$HERMES_HOME/scripts/$f" ] || { echo "CANNOT-OBSERVE: required file missing: $f"; return 2; }
  done
  VOLATILE="$VOLATILE" python3 - "$HERMES_HOME/config.yaml" <<'PY' || { echo "CANNOT-OBSERVE: config unreadable"; return 2; }
import hashlib, json, os, sys, yaml
try:
    cfg = yaml.safe_load(open(sys.argv[1])) or {}
except Exception:
    sys.exit(2)
for path in os.environ["VOLATILE"].split():
    keys = path.split(".")
    d = cfg
    for k in keys[:-1]:
        d = d.get(k) if isinstance(d, dict) else None
    if isinstance(d, dict):
        d.pop(keys[-1], None)
print(hashlib.sha256(json.dumps(cfg, sort_keys=True, default=str).encode()).hexdigest(), "config (volatile keys excluded)")
PY
  for t in $TOOLS; do
    if command -v "$t" >/dev/null 2>&1; then echo "tool $t present"; else echo "tool $t absent"; fi
  done
}

case "$MODE" in
  record)
    out=$(compute) || { echo "$out" | tail -1; echo "record refused: state unreadable" >&2; exit 2; }
    printf '%s\n' "$out" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST" && echo "recorded: $MANIFEST" ;;
  check)
    [ -r "$MANIFEST" ] || { echo "CANNOT-OBSERVE: no manifest at $MANIFEST"; exit 2; }
    out=$(compute) || { echo "$out" | tail -1; exit 2; }
    if diff -u "$MANIFEST" <(printf '%s\n' "$out"); then echo "matches recorded state"; exit 0; fi
    echo "DRIFT from recorded state"; exit 1 ;;
  *) echo "usage: $0 {record|check}" >&2; exit 2 ;;
esac
