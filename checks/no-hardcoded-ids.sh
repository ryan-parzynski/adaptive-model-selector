#!/usr/bin/env bash
# no-hardcoded-ids.sh — §10.2: the selector has no literal model ids of the paid family.
# Exit codes: 0 pass, 1 fail, 2 cannot-observe.
# Inputs (environment): SCRIPTS_DIR, SELECTOR_SCRIPT, VENDOR (registry: specific_vendor)
set -uo pipefail
f="${SCRIPTS_DIR}/${SELECTOR_SCRIPT}"
[ -r "$f" ] || { echo "CANNOT-OBSERVE: $f not readable"; exit 2; }
grep -n "${VENDOR}/" "$f"; rc=$?
case "$rc" in
  0) echo "hardcoded model id found"; exit 1 ;;
  1) echo "no hardcoded ids"; exit 0 ;;
  *) echo "CANNOT-OBSERVE: grep failed (rc=$rc)"; exit 2 ;;
esac
