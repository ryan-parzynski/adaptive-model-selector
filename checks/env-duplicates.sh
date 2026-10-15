#!/usr/bin/env bash
# env-duplicates.sh — §10.10: the provider key appears at most once in .env (export and spacing variants included).
# Exit codes: 0 pass, 1 fail, 2 cannot-observe.
# Inputs (environment): HERMES_HOME, KEYVAR (registry: provider_key_var — the variable NAME, never its value)
set -uo pipefail
f="$HERMES_HOME/.env"; k="$KEYVAR"
[ -r "$f" ] || { echo "CANNOT-OBSERVE: $f not readable"; exit 2; }
n=$(grep -cE "^[[:space:]]*(export[[:space:]]+)?${k}[[:space:]]*=" "$f")
echo "$k entries: $n"; [ "$n" -le 1 ] || exit 1; exit 0
