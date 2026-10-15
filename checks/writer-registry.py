#!/usr/bin/env python3
"""writer-registry.py — §3.7a / invariant 47: every writer of routing state is registered,
classified, and each field has exactly one owner.
Exit codes: 0 pass, 1 fail, 2 cannot-observe.
Inputs (environment):
  WRITER_REGISTRY   path to the registry (registry key: writer_registry_file)
  REQUIRED_FIELDS   space-separated fields that must each have exactly one owner
                    (default: "model.default")
"""
import os, sys
try:
    import yaml
except ImportError:
    print("CANNOT-OBSERVE: PyYAML not installed"); sys.exit(2)

KINDS = {"owner", "manual-tool", "integrated", "advisory", "legacy", "unknown"}
STATUSES = {"active", "quarantined", "observed", "retired"}

path = os.environ.get("WRITER_REGISTRY", "")
if not path:
    print("CANNOT-OBSERVE: WRITER_REGISTRY not set"); sys.exit(2)
if not os.path.exists(path):
    print(f"FAIL: no writer registry at {path} (invariant 47)"); sys.exit(1)
try:
    text = open(path).read()
except OSError as e:
    print(f"CANNOT-OBSERVE: cannot read {path}: {e}"); sys.exit(2)
try:
    doc = yaml.safe_load(text) or {}
except yaml.YAMLError as e:
    print(f"FAIL: registry is not valid YAML: {e}"); sys.exit(1)

problems = []
writers = doc.get("writers")
if not isinstance(writers, list) or not writers:
    print("FAIL: registry has no 'writers' list"); sys.exit(1)

owners = {}
for i, w in enumerate(writers):
    if not isinstance(w, dict):
        problems.append(f"entry {i}: not a mapping"); continue
    name = w.get("name") or f"entry {i}"
    kind, status = w.get("kind"), w.get("status")
    fields = w.get("fields") or []
    if kind not in KINDS:
        problems.append(f"{name}: kind {kind!r} is not one of {sorted(KINDS)}"); continue
    if status not in STATUSES:
        problems.append(f"{name}: status {status!r} is not one of {sorted(STATUSES)}")
    if not w.get("path"):
        problems.append(f"{name}: no path")
    if not w.get("evidence"):
        problems.append(f"{name}: no evidence for its classification")
    if kind == "unknown":
        problems.append(f"{name}: kind is unknown — classify before any implementation")
    if kind == "legacy" and status == "active":
        problems.append(f"{name}: legacy writer is still active — quarantine it")
    if kind == "advisory" and fields:
        problems.append(f"{name}: advisory components write nothing, but fields are listed: {fields}")
    if kind == "owner" and status == "active":
        for f in fields:
            owners.setdefault(f, []).append(name)

for f, names in sorted(owners.items()):
    if len(names) > 1:
        problems.append(f"field {f}: {len(names)} active owners ({', '.join(names)}) — exactly one allowed")
for f in os.environ.get("REQUIRED_FIELDS", "model.default").split():
    if f not in owners:
        problems.append(f"field {f}: no active owner")

if problems:
    for p in problems: print("FAIL:", p)
    sys.exit(1)
for f, names in sorted(owners.items()):
    print(f"owner of {f}: {names[0]}")
print(f"PASS: {len(writers)} writers registered and classified")
