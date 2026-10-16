#!/usr/bin/env bash
# run.sh — fixture tests for checks/. No network beyond a local stub; never touches a real Hermes home.
# Usage: checks/tests/run.sh      Exit 0 if every case matches its expected exit code.
set -uo pipefail
C="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"; [ -n "${SP:-}" ] && kill "$SP" 2>/dev/null' EXIT
PASS=0; FAILS=0
expect() { # expect CODE NAME -- command...
  local want=$1 name=$2; shift 3
  "$@" >"$T/out" 2>&1; local got=$?
  if [ "$got" -eq "$want" ]; then PASS=$((PASS+1)); else FAILS=$((FAILS+1)); echo "FAIL $name: expected $want got $got"; sed 's/^/    /' "$T/out"; fi
}

# ---------- compare-boxes.sh
for b in a b; do mkdir -p "$T/box/$b/scripts" "$T/box/$b/state"; printf 'model:\n  default: x\nagent: {}\n' > "$T/box/$b/config.yaml"; echo 'echo hi' > "$T/box/$b/scripts/s.sh"; done
printf 'scripts\nconfig_keys\ntools\n' > "$T/box/a/state/shared-properties.txt"
mkdir -p "$T/bin"; printf '#!/usr/bin/env bash\nshift; HERMES_HOME="$PEER_HOME" bash -c "$*"\n' > "$T/bin/ssh"; chmod +x "$T/bin/ssh"
cb() { PATH="$T/bin:$PATH" PEER_HOME="$T/box/b" HERMES_HOME="$T/box/a" SELECTOR_TOOLS="bash" bash "$C/compare-boxes.sh" peer; }
expect 0 "compare: identical boxes" -- cb
echo 'echo changed' > "$T/box/b/scripts/s.sh"; expect 1 "compare: peer script changed" -- cb; echo 'echo hi' > "$T/box/b/scripts/s.sh"
printf 'model:\n  default: OTHER\nagent: {}\n' > "$T/box/b/config.yaml"; expect 0 "compare: different model, same keys" -- cb
printf 'model: {}\nagent: {}\nextra: 1\n' > "$T/box/b/config.yaml"; expect 1 "compare: extra key on peer" -- cb
printf ': [\n' > "$T/box/b/config.yaml"; expect 2 "compare: peer config unreadable" -- cb
printf 'model: {}\nagent: {}\n' > "$T/box/b/config.yaml"
expect 2 "compare: no arguments" -- bash "$C/compare-boxes.sh"
expect 2 "compare: HERMES_HOME unset" -- env HERMES_HOME= bash "$C/compare-boxes.sh" peer
mv "$T/box/a/state/shared-properties.txt" "$T/sp"; expect 2 "compare: nothing declared shared" -- cb; mv "$T/sp" "$T/box/a/state/shared-properties.txt"
expect 2 "compare: peer home unknown" -- env PATH="$T/bin:$PATH" PEER_HOME= HERMES_HOME="$T/box/a" bash "$C/compare-boxes.sh" peer

# ---------- manifest.sh
M="$T/m"; mkdir -p "$M/scripts" "$M/state"; echo x > "$M/scripts/a.sh"
printf 'model:\n  default: x\n  provider: p\nfallback_providers: [api-1]\n' > "$M/config.yaml"
mf() { HERMES_HOME="$M" SELECTOR_TOOLS="bash" bash "$C/manifest.sh" "$1"; }
expect 2 "manifest: check before record" -- mf check
expect 0 "manifest: record" -- mf record
expect 0 "manifest: unchanged" -- mf check
sed -i.bak 's/default: x/default: y/; s/provider: p/provider: q/' "$M/config.yaml"; expect 0 "manifest: model switch only" -- mf check
sed -i.bak 's/\[api-1\]/[api-1, local-card]/' "$M/config.yaml"; expect 1 "manifest: local added to fallback list" -- mf check
sed -i.bak 's/, local-card//' "$M/config.yaml"; echo y > "$M/scripts/a.sh"; expect 1 "manifest: script edited" -- mf check; echo x > "$M/scripts/a.sh"
cp "$M/config.yaml" "$T/cfg"; printf ': [\n' > "$M/config.yaml"; expect 2 "manifest: config unreadable" -- mf check; cp "$T/cfg" "$M/config.yaml"
expect 2 "manifest: HERMES_HOME unset" -- env HERMES_HOME= bash "$C/manifest.sh" check
expect 2 "manifest: bad mode" -- env HERMES_HOME="$M" bash "$C/manifest.sh" bogus

# ---------- switch-path.sh
printf '#!/usr/bin/env bash\nexit 7\n' > "$T/w.sh"; chmod +x "$T/w.sh"
expect 2 "switch-path: refuses without scratch flag" -- env WRAPPER="$T/w.sh" MODEL=m PROVIDER=p bash "$C/switch-path.sh"
expect 1 "switch-path: failing helper" -- env SWITCH_CHECK_SCRATCH=1 WRAPPER="$T/w.sh" MODEL=m PROVIDER=p bash "$C/switch-path.sh"
grep -q 'exit 7' "$T/out" || { FAILS=$((FAILS+1)); echo "FAIL switch-path: message must report the helper's exit code"; }

# ---------- no-hardcoded-ids.sh
mkdir -p "$T/sd"; echo 'm="vend/model-x"' > "$T/sd/bad.py"; echo 'm=choose()' > "$T/sd/good.py"
expect 0 "ids: clean selector" -- env SCRIPTS_DIR="$T/sd" SELECTOR_SCRIPT=good.py VENDOR=vend bash "$C/no-hardcoded-ids.sh"
expect 1 "ids: literal id" -- env SCRIPTS_DIR="$T/sd" SELECTOR_SCRIPT=bad.py VENDOR=vend bash "$C/no-hardcoded-ids.sh"
expect 2 "ids: selector missing" -- env SCRIPTS_DIR="$T/sd" SELECTOR_SCRIPT=nope.py VENDOR=vend bash "$C/no-hardcoded-ids.sh"

# ---------- reserve-vs-spent.sh
rv() { env READ_REMAINING="echo $1" FREE_RESERVE="$2" READ_TIER="echo $3" PAID_BY_POLICY="${4:-0}" bash "$C/reserve-vs-spent.sh"; }
expect 0 "reserve: free above reserve" -- rv 50 10 free
expect 1 "reserve: free at/below reserve" -- rv 5 10 free
expect 0 "reserve: paid below reserve" -- rv 5 10 paid
expect 1 "reserve: paid with free available" -- rv 50 10 paid
expect 0 "reserve: paid by policy" -- rv 50 10 paid 1
expect 2 "reserve: remaining null" -- rv null 10 free
expect 2 "reserve: remaining empty" -- rv "" 10 free
expect 2 "reserve: tier unknown" -- rv 50 10 ""
expect 2 "reserve: reserve unset" -- rv 50 "" free

# ---------- no-secrets-on-argv.sh
sc() { rm -rf "$T/sc"; mkdir "$T/sc"; printf '%s\n' "$1" > "$T/sc/x.sh"; env SCRIPTS_DIR="$T/sc" bash "$C/no-secrets-on-argv.sh"; }
expect 0 "secrets: header in curl --config here-doc" -- sc 'header = "Authorization: Bearer ${OPENROUTER_API_KEY}"'
expect 1 "secrets: -H Authorization on argv" -- sc 'curl -s -H "Authorization: Bearer $KEY" https://x'
expect 1 "secrets: --header= form" -- sc 'curl -s --header=Authorization:x https://x'
expect 1 "secrets: curl -u" -- sc 'curl -u admin:$DASH_PASS https://x'
expect 1 "secrets: jq --arg password" -- sc 'jq -n --arg p "$DASH_PASS" x'
expect 1 "secrets: jq --arg key" -- sc 'jq -n --arg k "${API_KEY}" x'
expect 0 "secrets: jq --arg non-secret" -- sc 'jq -n --arg p "$PROVIDER" x'
expect 2 "secrets: scripts dir missing" -- env SCRIPTS_DIR="$T/none" bash "$C/no-secrets-on-argv.sh"

# ---------- env-duplicates.sh
mkdir -p "$T/hh"
printf 'A=1\nexport A = 2\n' > "$T/hh/.env"; expect 1 "env: duplicate via export and spaces" -- env HERMES_HOME="$T/hh" KEYVAR=A bash "$C/env-duplicates.sh"
printf 'A=1\nAB=2\n' > "$T/hh/.env";       expect 0 "env: prefix is not a duplicate" -- env HERMES_HOME="$T/hh" KEYVAR=A bash "$C/env-duplicates.sh"
expect 2 "env: file missing" -- env HERMES_HOME="$T/none" KEYVAR=A bash "$C/env-duplicates.sh"

# ---------- stream-timeout.py
mkdir -p "$T/th"
st() { printf "$1" > "$T/th/config.yaml"; env HERMES_HOME="$T/th" KEY=agent.t MIN=120 MAX=300 python3 "$C/stream-timeout.py"; }
expect 0 "timeout: in range" -- st 'agent:\n  t: 200\n'
expect 1 "timeout: boolean" -- st 'agent:\n  t: true\n'
expect 1 "timeout: below range" -- st 'agent:\n  t: 30\n'
expect 1 "timeout: absent" -- st 'agent: {}\n'
expect 2 "timeout: config unreadable" -- st ': [\n'

# ---------- writer-registry.py
W="$T/w"; mkdir -p "$W"
wr() { printf '%s\n' "$1" > "$W/writers.yaml"; env WRITER_REGISTRY="$W/writers.yaml" python3 "$C/writer-registry.py"; }
expect 0 "writers: example registry" -- env WRITER_REGISTRY="$C/../docs/examples/writers.example.yaml" python3 "$C/writer-registry.py"
expect 1 "writers: two active owners" -- wr 'writers:
  - {name: a, path: a.py, kind: owner, status: active, fields: [model.default], evidence: x}
  - {name: b, path: b.py, kind: owner, status: active, fields: [model.default], evidence: x}'
expect 1 "writers: no owner of model.default" -- wr 'writers:
  - {name: a, path: a.py, kind: manual-tool, status: active, fields: [model.default], evidence: x}'
expect 1 "writers: unknown kind blocks" -- wr 'writers:
  - {name: a, path: a.py, kind: owner, status: active, fields: [model.default], evidence: x}
  - {name: f, path: failover.sh, kind: unknown, status: active, fields: [], evidence: x}'
expect 1 "writers: active legacy" -- wr 'writers:
  - {name: a, path: a.py, kind: owner, status: active, fields: [model.default], evidence: x}
  - {name: l, path: l.py, kind: legacy, status: active, fields: [model.default], evidence: x}'
expect 1 "writers: advisory that writes" -- wr 'writers:
  - {name: a, path: a.py, kind: owner, status: active, fields: [model.default], evidence: x}
  - {name: c, path: c.py, kind: advisory, status: active, fields: [model.default], evidence: x}'
expect 1 "writers: missing evidence" -- wr 'writers:
  - {name: a, path: a.py, kind: owner, status: active, fields: [model.default]}'
expect 1 "writers: registry missing" -- env WRITER_REGISTRY="$W/none.yaml" python3 "$C/writer-registry.py"
expect 2 "writers: path not set" -- env WRITER_REGISTRY= python3 "$C/writer-registry.py"

# ---------- scratch-preflight.sh
L="$T/live"; SC="$T/scratch"; mkdir -p "$L/cron" "$L/state" "$SC/state"
printf 'model: {default: x}\n' > "$L/config.yaml"; echo '{"jobs": []}' > "$L/cron/jobs.json"
printf 'model: {default: x}\nproviders: {stub: {base_url: "http://127.0.0.1:8080/v1"}}\n' > "$SC/config.yaml"
pf() { env LIVE_HOME="$L" SCRATCH_HOME="$SC" "$@" bash "$C/scratch-preflight.sh"; }
expect 0 "preflight: isolated scratch" -- pf
expect 1 "preflight: scratch is live" -- env LIVE_HOME="$L" SCRATCH_HOME="$L" bash "$C/scratch-preflight.sh"
mkdir -p "$L/inner"; cp "$SC/config.yaml" "$L/inner/"; expect 1 "preflight: scratch inside live" -- env LIVE_HOME="$L" SCRATCH_HOME="$L/inner" bash "$C/scratch-preflight.sh"
ln -s "$L/state" "$SC/state-link"; expect 1 "preflight: symlink into live" -- pf; rm "$SC/state-link"
ln "$L/config.yaml" "$SC/shared.yaml"; expect 1 "preflight: hard link shared with live" -- pf; rm "$SC/shared.yaml"
echo "{\"jobs\": [{\"cmd\": \"run --home $SC\"}]}" > "$L/cron/jobs.json"; expect 1 "preflight: live job references scratch" -- pf; echo '{"jobs": []}' > "$L/cron/jobs.json"
printf 'base_url: "https://openrouter.ai/api/v1"\n' >> "$SC/config.yaml"; expect 1 "preflight: remote provider" -- pf
expect 0 "preflight: remote provider explicitly allowed" -- pf ALLOW_REMOTE_PROVIDERS=1
sed -i.bak '/openrouter/d' "$SC/config.yaml"
expect 1 "preflight: port clash" -- pf LIVE_PORTS="9119 8080" SCRATCH_PORTS="9119"
mv "$SC/config.yaml" "$SC/c.bak"; expect 1 "preflight: scratch has no config" -- pf; mv "$SC/c.bak" "$SC/config.yaml"
expect 2 "preflight: scratch missing" -- env LIVE_HOME="$L" SCRATCH_HOME="$T/nope" bash "$C/scratch-preflight.sh"

# ---------- probe.sh (local stub server)
if command -v jq >/dev/null && command -v curl >/dev/null; then
  PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
  python3 - "$PORT" <<'PY' & SP=$!
import json, sys, time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
R = {'/ok': (200, {'choices': [{'message': {'content': 'OK'}, 'finish_reason': 'stop'}]}),
     '/thinking': (200, {'choices': [{'message': {'content': ''}, 'finish_reason': 'length'}]}),
     '/empty': (200, {'choices': [{'message': {'content': ''}, 'finish_reason': 'stop'}]}),
     '/429': (429, {}), '/500': (500, {}), '/slow': (200, {})}
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length', 0)))
        if self.path == '/slow': time.sleep(10)
        code, body = R[self.path]
        if self.path == '/ok' and self.headers.get('Authorization') != 'Bearer test-key': code, body = 401, {}
        self.send_response(code); self.end_headers(); self.wfile.write(json.dumps(body).encode())
ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
PY
  sleep 1
  pr() { env URL="http://127.0.0.1:$PORT/$1" MODEL=m MAXTOK=16 BUDGET=2 PROVIDER_KEY_VAR=TK TK=test-key bash "$C/probe.sh" | grep -q "outcome=$2\b"; }
  for c in "ok ok" "thinking probe_budget_too_small" "empty empty_answer" "429 http_429" "500 http_error" "slow timeout"; do
    set -- $c; expect 0 "probe: $1 -> $2" -- pr "$1" "$2"
  done
  expect 2 "probe: key variable empty" -- env URL="http://127.0.0.1:$PORT/ok" MODEL=m MAXTOK=16 BUDGET=2 PROVIDER_KEY_VAR=NOPE bash "$C/probe.sh"
else
  echo "SKIP probe tests: jq and curl required"
fi

# ---------- contrib-validate.py
CV="$T/repo/contrib"; mkdir -p "$CV/reports/2026-10" "$CV/findings/edge-cases/2026-10" "$CV/findings/bugs/2026-10"
cp "$C/../docs/examples/contrib-report.example.yaml" "$CV/reports/2026-10/a1b2c3d4.yaml"
cp "$C/../docs/examples/contrib-finding.example.yaml" "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml"
expect 0 "contrib: example report valid" -- python3 "$C/contrib-validate.py" "$CV/reports/2026-10/a1b2c3d4.yaml"
expect 0 "contrib: example finding valid" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml"
sed 's/lane_busy_rate: 0.04/lane_busy_rate: 7/' "$CV/reports/2026-10/a1b2c3d4.yaml" > "$CV/reports/2026-10/bbbbbbbb.yaml"
expect 1 "contrib: rate out of range" -- python3 "$C/contrib-validate.py" "$CV/reports/2026-10/bbbbbbbb.yaml"
printf 'secret_field: 1\n' >> "$CV/reports/2026-10/a1b2c3d4.yaml"
expect 1 "contrib: unknown field" -- python3 "$C/contrib-validate.py" "$CV/reports/2026-10/a1b2c3d4.yaml"
sed 's/minutes apart/minutes apart on 10.0.0.5/' "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml" > "$CV/findings/edge-cases/2026-10/cccccccc.yaml"
expect 1 "contrib: identifying text" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/cccccccc.yaml"
cp "$C/../docs/examples/contrib-finding.example.yaml" "$CV/findings/edge-cases/2026-10/not-hex.yaml"
expect 1 "contrib: bad file name" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/not-hex.yaml"
expect 2 "contrib: missing file" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/dddddddd.yaml"
cp "$C/../docs/examples/contrib-finding.example.yaml" "$CV/findings/bugs/2026-10/eeeeeeee.yaml"
expect 1 "contrib: finding in wrong kind folder" -- python3 "$C/contrib-validate.py" "$CV/findings/bugs/2026-10/eeeeeeee.yaml"
python3 - "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml" "$CV/findings/edge-cases/2026-10/ffffffff.yaml" <<'PY2'
import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); d["why_it_matters"]="it breaks"; yaml.safe_dump(d,open(sys.argv[2],"w"),allow_unicode=True)
PY2
expect 1 "contrib: why too short" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/ffffffff.yaml"
python3 - "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml" "$CV/findings/edge-cases/2026-10/abababab.yaml" <<'PY2'
import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); del d["how_to_reproduce"]; yaml.safe_dump(d,open(sys.argv[2],"w"),allow_unicode=True)
PY2
expect 1 "contrib: missing how_to_reproduce" -- python3 "$C/contrib-validate.py" "$CV/findings/edge-cases/2026-10/abababab.yaml"
printf 'box-alpha\n10.9.9.9\n' > "$T/deny.txt"
sed 's/minutes apart/minutes apart on BOX-ALPHA/' "$C/../docs/examples/contrib-finding.example.yaml" > "$CV/findings/edge-cases/2026-10/12345678.yaml"
expect 1 "contrib: deny-list term (any case)" -- python3 "$C/contrib-validate.py" --deny-file "$T/deny.txt" "$CV/findings/edge-cases/2026-10/12345678.yaml"
expect 0 "contrib: deny list, clean file" -- python3 "$C/contrib-validate.py" --deny-file "$T/deny.txt" "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml"
expect 2 "contrib: deny file missing" -- python3 "$C/contrib-validate.py" --deny-file "$T/nope.txt" "$CV/findings/edge-cases/2026-10/0f0e0d0c.yaml"
sed 's/id: lane-a/id: gpubox1/' "$C/../docs/examples/contrib-report.example.yaml" > "$CV/reports/2026-10/9a9a9a9a.yaml"
expect 1 "contrib: lane named, not lettered" -- python3 "$C/contrib-validate.py" "$CV/reports/2026-10/9a9a9a9a.yaml"
mkdir -p "$T/state/contrib-outbox/reports/2026-10"
cp "$C/../docs/examples/contrib-report.example.yaml" "$T/state/contrib-outbox/reports/2026-10/5e5e5e5e.yaml"
expect 0 "contrib: outbox path accepted" -- python3 "$C/contrib-validate.py" "$T/state/contrib-outbox/reports/2026-10/5e5e5e5e.yaml"
cp "$C/../docs/examples/contrib-report.example.yaml" "$CV/reports/2026-10/3f9a1c07.yaml"
expect 1 "contrib: file named after contributor_id" -- python3 "$C/contrib-validate.py" "$CV/reports/2026-10/3f9a1c07.yaml"
expect 2 "contrib: no arguments" -- python3 "$C/contrib-validate.py"

echo; echo "$PASS passed, $FAILS failed"
[ "$FAILS" -eq 0 ]
