#!/usr/bin/env bash
# no-secrets-on-argv.sh — §10.27: no script puts a secret on a command line.
# Exit codes: 0 pass, 1 fail, 2 cannot-observe.
# Inputs (environment): SCRIPTS_DIR
set -uo pipefail
d="$SCRIPTS_DIR"
[ -d "$d" ] && [ -r "$d" ] || { echo "CANNOT-OBSERVE: $d not readable"; exit 2; }
# Shapes that put a secret on a command line (argv is visible via /proc):
#   curl/wget with an inline auth header or -u user:pass; jq --arg <name> "$SECRET".
# A header inside a curl --config here-document is the SAFE pattern and is not matched.
pat='(curl|wget)[^#]*((-H|--header)[ =]*["'"'"']?Authorization|(-u|--user)[ =]|Bearer[[:space:]]+\$)|--arg[[:space:]]+[A-Za-z_]+[[:space:]]+"?\$\{?[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)'
grep -rnIE "$pat" "$d"; rc=$?
case "$rc" in 0) exit 1 ;; 1) exit 0 ;; *) echo "CANNOT-OBSERVE: scan failed"; exit 2 ;; esac
