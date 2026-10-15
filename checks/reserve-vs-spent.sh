#!/usr/bin/env bash
# reserve-vs-spent.sh — §10.16: the default tier agrees with the free budget and the reserve.
# Exit codes: 0 pass, 1 fail, 2 cannot-observe.
# Inputs (environment): READ_REMAINING, READ_TIER (commands; registry: read_remaining, read_current_tier), FREE_RESERVE, PAID_BY_POLICY=1 when paid is a policy choice
set -uo pipefail
remaining=$(eval "$READ_REMAINING"); reserve=${FREE_RESERVE:-}; cur=$(eval "$READ_TIER")
is_int() { case "$1" in ''|*[!0-9]*) return 1 ;; esac; }
is_int "$remaining" || { echo "CANNOT-OBSERVE: remaining not a number: '$remaining'"; exit 2; }
is_int "$reserve"   || { echo "CANNOT-OBSERVE: reserve not set"; exit 2; }
case "$cur" in free|paid) ;; *) echo "CANNOT-OBSERVE: current tier unknown: '$cur'"; exit 2 ;; esac
if [ "$remaining" -le "$reserve" ] && [ "$cur" = free ]; then
  echo "FAIL: free default at or below the reserve"; exit 1; fi
if [ "$remaining" -gt "$reserve" ] && [ "$cur" = paid ] && [ "${PAID_BY_POLICY:-0}" != 1 ]; then
  echo "FAIL: on paid with free budget above the reserve, and paid is not a policy choice"; exit 1; fi
echo "PASS"; exit 0
