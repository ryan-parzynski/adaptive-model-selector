#!/usr/bin/env bash
# switch-path.sh — §10.1: the sanctioned switch wrapper works. WRITES CONFIG: scratch HERMES_HOME only.
# Exit codes: 0 pass, 1 fail, 2 cannot-observe.
# Inputs (environment): WRAPPER, MODEL, PROVIDER, SWITCH_CHECK_SCRATCH=1
set -uo pipefail
[ "${SWITCH_CHECK_SCRATCH:-}" = 1 ] || { echo "CANNOT-OBSERVE: this check writes config; run it only against a scratch HERMES_HOME and set SWITCH_CHECK_SCRATCH=1"; exit 2; }
"$WRAPPER" "$MODEL" "$PROVIDER"; rc=$?
if [ "$rc" -ne 0 ]; then echo "switch helper failed (exit $rc)"; exit 1; fi
echo "switch helper OK"; exit 0
