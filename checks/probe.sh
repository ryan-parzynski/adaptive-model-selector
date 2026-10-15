#!/usr/bin/env bash
# probe.sh — §3.11 / §7.2: liveness probe that asserts on answer content, not transport.
# Assumes an OpenAI-compatible chat completions response; the provider adapter owns this
# in the reference implementation.
# Outcomes: ok, probe_budget_too_small (a probe verdict, Class 7), empty_answer, http_429,
# http_error, timeout, cannot-observe.
# Inputs (environment): URL, MODEL, MAXTOK and BUDGET (sized per model class, §7.2),
# PROVIDER_KEY_VAR = the NAME of the variable holding the key (sourced from .env beforehand).
set -uo pipefail
KEY="${!PROVIDER_KEY_VAR:-}"
[ -n "$KEY" ] || { echo "probe outcome=cannot-observe (key variable empty)"; exit 2; }
BODY=$(mktemp); REQ=$(mktemp); trap 'rm -f "$BODY" "$REQ"' EXIT
jq -n --arg m "$MODEL" --argjson n "$MAXTOK" \
  '{model: $m, max_tokens: $n, messages: [{role: "user", content: "Reply with OK."}]}' > "$REQ"
status=$(timeout "$(( BUDGET + 5 ))" curl -sS -o "$BODY" -w '%{http_code}' \
  --connect-timeout 5 --max-time "$BUDGET" -H 'Content-Type: application/json' \
  --data @"$REQ" --config - "$URL" <<CFG
header = "Authorization: Bearer $KEY"
CFG
)
rc=$?
case "$rc" in
  0)  case "$status" in
        200) if   jq -e '(.choices[0].message.content // "") | length > 0' "$BODY" >/dev/null 2>&1; then outcome=ok
             elif jq -e '.choices[0].finish_reason == "length"' "$BODY" >/dev/null 2>&1; then outcome=probe_budget_too_small
             else outcome=empty_answer; fi ;;
        429) outcome=http_429 ;;
        *)   outcome=http_error ;;
      esac ;;
  28|124) outcome=timeout ;;
  *)      outcome=cannot-observe ;;
esac
echo "probe outcome=$outcome http=$status"
