# checks/

Tested versions of the checks the specification describes. Each exits **0 pass, 1 fail, 2 cannot-observe**, and never reports pass when it could not read its input (invariant 33).

| File | Spec | What it checks | Writes anything? |
|---|---|---|---|
| `compare-boxes.sh` | §8.2 | This box vs. a peer, on properties **declared shared** in `state/shared-properties.txt` (`scripts`, `config_keys`, `tools`, `job_names`) | No |
| `manifest.sh` | §8.4 | This box vs. its own recorded known-good state; config fingerprinted with the model keys excluded, so a switch is not drift but an edited fallback list is | `record` writes the manifest only |
| `switch-path.sh` | §10.1 | The sanctioned switch wrapper succeeds | **Yes — config.** Refuses unless `SWITCH_CHECK_SCRATCH=1` |
| `no-hardcoded-ids.sh` | §10.2 | No literal paid-family model ids in the selector | No |
| `env-duplicates.sh` | §10.10 | The provider key appears at most once in `.env` (including `export` and spaced forms) | No |
| `stream-timeout.py` | §10.13 | Stream-stale timeout set, numeric, in range | No |
| `reserve-vs-spent.sh` | §10.16 | Default tier agrees with remaining budget and reserve, in both directions | No |
| `no-secrets-on-argv.sh` | §10.27 | No script puts a secret on a command line | No |
| `writer-registry.py` | §3.7a | Every writer of routing state registered and classified; exactly one active owner per field; no `unknown` kinds; legacy writers not active | No |
| `scratch-preflight.sh` | §10.36 | A scratch Hermes home is isolated from the live one (paths, links, scheduler, ports, provider endpoints) before any write-test | No |
| `probe.sh` | §3.11, §7.2 | Liveness that asserts on answer **content**; distinguishes a too-small probe budget from a broken model | Spends one request |

Inputs are environment variables, named at the top of each file, and map to registry keys. Nothing reads a hardcoded path; `HERMES_HOME` must be set, resolved from the runtime (§1.3).

## Testing

```bash
checks/tests/run.sh
```

Runs every check against generated fixtures (fake boxes, a fake `ssh`, a local stub HTTP server). It never touches a real Hermes home. Requires bash, python3 with PyYAML, and — for the probe tests — curl and jq.

**What "tested" means here:** each check behaves correctly against fixtures. None has been run against a live Hermes box yet; the Hermes-specific parts (`hermes cron list` parsing, the stream-timeout key's location, the switch wrapper) still need confirming on a real build. Record that confirmation in the box's §12 record.
