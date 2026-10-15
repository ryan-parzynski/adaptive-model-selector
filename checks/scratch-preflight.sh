#!/usr/bin/env bash
# scratch-preflight.sh — §10.36: prove a scratch Hermes home cannot touch live state
# before any write-test runs against it.
# Exit codes: 0 isolated, 1 not isolated, 2 cannot-observe.
# Inputs (environment):
#   LIVE_HOME, SCRATCH_HOME       the live and scratch Hermes homes
#   LIVE_JOBS                     live scheduled-job file (default: $LIVE_HOME/cron/jobs.json)
#   LIVE_PORTS, SCRATCH_PORTS     space-separated ports (optional)
#   ALLOW_REMOTE_PROVIDERS=1      operator allows non-loopback endpoints in the scratch copy
set -uo pipefail
FAIL=0
bad() { echo "NOT ISOLATED: $1"; FAIL=$((FAIL + 1)); }
for v in LIVE_HOME SCRATCH_HOME; do
  [ -n "${!v:-}" ] || { echo "CANNOT-OBSERVE: $v not set"; exit 2; }
  [ -d "${!v}" ] && [ -r "${!v}" ] || { echo "CANNOT-OBSERVE: $v (${!v}) not a readable directory"; exit 2; }
done
rp() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
L=$(rp "$LIVE_HOME"); S=$(rp "$SCRATCH_HOME")

# Path: distinct, neither inside the other.
[ "$L" = "$S" ] && bad "scratch and live are the same directory"
case "$S/" in "$L"/*) bad "scratch is inside the live home" ;; esac
case "$L/" in "$S"/*) bad "live home is inside the scratch home" ;; esac

# Symlinks and hard links that could reach live files.
while IFS= read -r -d '' link; do
  t=$(rp "$link")
  case "$t/" in "$L"/*|"$L/") bad "symlink $link resolves into the live home" ;; esac
done < <(find "$S" -type l -print0 2>/dev/null)
hl=$(find "$S" -type f -links +1 2>/dev/null | head -5)
[ -n "$hl" ] && bad "hard-linked files in scratch (may be shared with live): $(echo "$hl" | tr '\n' ' ')"

# Files the scratch home must have of its own.
[ -f "$S/config.yaml" ] || bad "scratch has no config.yaml of its own"

# Scheduler: no live job may reference the scratch path.
LJ="${LIVE_JOBS:-$L/cron/jobs.json}"
if [ -e "$LJ" ]; then
  if [ ! -r "$LJ" ]; then echo "CANNOT-OBSERVE: cannot read live jobs file $LJ"; exit 2; fi
  grep -qF -- "$S" "$LJ" && bad "a live scheduled job references the scratch path"
  [ "$S" != "$SCRATCH_HOME" ] && grep -qF -- "$SCRATCH_HOME" "$LJ" && bad "a live scheduled job references the scratch path"
fi

# Ports.
for sp in ${SCRATCH_PORTS:-}; do for lp in ${LIVE_PORTS:-}; do
  [ "$sp" = "$lp" ] && bad "scratch port $sp is a live port"
done; done

# Providers: only loopback endpoints unless explicitly allowed.
if [ "${ALLOW_REMOTE_PROVIDERS:-0}" != 1 ]; then
  remote=$(cat "$S/config.yaml" "$S/.env" 2>/dev/null | grep -oE 'https?://[^[:space:]"'"'"']+' \
           | grep -vE '^https?://(127\.[0-9.]+|localhost|\[::1\])(:[0-9]+)?(/|$)' | sort -u | head -5)
  [ -n "$remote" ] && bad "non-loopback provider endpoints in scratch (real calls can spend budget): $(echo "$remote" | tr '\n' ' ')"
fi

[ "$FAIL" -eq 0 ] && { echo "ISOLATED: scratch home passes pre-flight"; exit 0; }
echo "$FAIL isolation problem(s); do not run write-tests"; exit 1
