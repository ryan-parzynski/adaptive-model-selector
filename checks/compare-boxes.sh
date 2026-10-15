#!/usr/bin/env bash
# compare-boxes.sh — compare this box with a peer on the properties declared shared.
# Exit codes: 0 match, 1 drift, 2 cannot-observe (including usage errors).
# Only properties listed in the shared-properties file are compared; every other
# difference between independent boxes is expected and is not reported (§8.3).
set -uo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <peer-ssh-target>" >&2; exit 2; }
REMOTE="$1"
[ -n "${HERMES_HOME:-}" ] || { echo "CANNOT-OBSERVE: HERMES_HOME not set; resolve it from the runtime (§1.3)" >&2; exit 2; }
SHARED_FILE="${SHARED_FILE:-$HERMES_HOME/state/shared-properties.txt}"
TOOLS="${SELECTOR_TOOLS:-}"            # space-separated; from the registry list selector_tools
FAIL=0; UNOBS=0

fail()   { echo "DRIFT: $1"; FAIL=$((FAIL + 1)); }
unobs()  { echo "CANNOT-OBSERVE: $1"; UNOBS=$((UNOBS + 1)); }
shared() { grep -qx "$1" "$SHARED_FILE"; }
q()      { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }   # quote for the remote shell

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; chmod 700 "$TMP"

[ -r "$SHARED_FILE" ] || { echo "CANNOT-OBSERVE: no shared-properties file at $SHARED_FILE — nothing is declared shared"; exit 2; }

# Programs that run on both sides are sent on stdin, so no quoting crosses ssh.
cat > "$TMP/keys.py" <<'PY'
import os, sys, yaml
try:
    cfg = yaml.safe_load(open(os.path.join(sys.argv[1], "config.yaml"))) or {}
except Exception:
    sys.exit(2)
print("\n".join(sorted(cfg)))
PY
cat > "$TMP/hashes.sh" <<'SH'
cd "$1/scripts" || exit 2
find . -type f -not -path './.git/*' -exec sha256sum {} + | sort
SH
cat > "$TMP/tools.sh" <<'SH'
for t in "$@"; do if command -v "$t" >/dev/null 2>&1; then echo "$t present"; else echo "$t absent"; fi; done
SH

# Resolve the peer's home from its own environment (or an explicit override), never from ~.
REMOTE_HOME="${REMOTE_HERMES_HOME:-}"
if [ -z "$REMOTE_HOME" ]; then
  REMOTE_HOME=$(ssh "$REMOTE" 'printf %s "${HERMES_HOME:-}"') || REMOTE_HOME=""
fi
if [ -z "$REMOTE_HOME" ]; then
  echo "CANNOT-OBSERVE: peer HERMES_HOME unknown (set REMOTE_HERMES_HOME, or export HERMES_HOME for ssh sessions on the peer)"
  exit 2
fi

compare() {
  local name="$1"
  if ! diff -u "$TMP/$name.remote" "$TMP/$name.local" > "$TMP/$name.diff"; then
    fail "$name differs"; cat "$TMP/$name.diff"
  fi
}

if shared scripts; then
  echo "== scripts =="
  if ! bash "$TMP/hashes.sh" "$HERMES_HOME" > "$TMP/scripts.local"; then unobs "local scripts unreadable"
  elif ! ssh "$REMOTE" "bash -s -- $(q "$REMOTE_HOME")" < "$TMP/hashes.sh" > "$TMP/scripts.remote"; then unobs "peer scripts unreadable"
  else compare scripts; fi
fi

if shared config_keys; then
  echo "== top-level config keys =="
  if ! python3 - "$HERMES_HOME" < "$TMP/keys.py" > "$TMP/config_keys.local"; then unobs "local config unreadable"
  elif ! ssh "$REMOTE" "python3 - $(q "$REMOTE_HOME")" < "$TMP/keys.py" > "$TMP/config_keys.remote"; then unobs "peer config unreadable"
  else compare config_keys; fi
fi

if shared tools; then
  echo "== selector tool dependencies =="
  if [ -z "$TOOLS" ]; then unobs "SELECTOR_TOOLS is empty"
  else
    # shellcheck disable=SC2086
    bash "$TMP/tools.sh" $TOOLS > "$TMP/tools.local"
    # shellcheck disable=SC2086
    if ! ssh "$REMOTE" "bash -s -- $TOOLS" < "$TMP/tools.sh" > "$TMP/tools.remote"; then unobs "peer tool check failed"
    else compare tools; fi
    grep ' absent$' "$TMP/tools.local" | sed 's/^/local: /' | while read -r l; do echo "NOTE: $l"; done
  fi
fi

if shared job_names; then
  echo "== scheduled job names =="
  if ! hermes cron list > "$TMP/jobs.l" 2>/dev/null; then unobs "local cron list failed"
  elif ! ssh "$REMOTE" 'hermes cron list' > "$TMP/jobs.r" 2>/dev/null; then unobs "peer cron list failed"
  else
    awk '/^[a-f0-9]+[[:space:]]/{print $2}' "$TMP/jobs.l" | sort -u > "$TMP/job_names.local"
    awk '/^[a-f0-9]+[[:space:]]/{print $2}' "$TMP/jobs.r" | sort -u > "$TMP/job_names.remote"
    compare job_names
  fi
fi

echo
[ "$FAIL" -gt 0 ]  && { echo "DRIFT: $FAIL shared propert(y/ies) differ"; [ "$UNOBS" -gt 0 ] && echo "CANNOT-OBSERVE: $UNOBS comparison(s) also incomplete"; exit 1; }
[ "$UNOBS" -gt 0 ] && { echo "CANNOT-OBSERVE: $UNOBS comparison(s) could not be completed"; exit 2; }
echo "match: every declared-shared property matched"
exit 0
