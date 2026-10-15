#!/usr/bin/env python3
"""stream-timeout.py — §10.13: the stream-stale timeout is set, numeric, and in range.
Exit codes: 0 pass, 1 fail, 2 cannot-observe.
Inputs (environment): HERMES_HOME; KEY = dotted path of the key the runtime reads
(registry: stream_stale_timeout_key); MIN, MAX (registry: stream_stale_min, stream_stale_max).
"""
import os, sys, yaml
h = os.environ.get("HERMES_HOME")
if not h:
    print("CANNOT-OBSERVE: HERMES_HOME not set"); sys.exit(2)
try:
    cfg = yaml.safe_load(open(os.path.join(h, "config.yaml"))) or {}
except Exception as e:
    print(f"CANNOT-OBSERVE: config unreadable: {e}"); sys.exit(2)
path = os.environ["KEY"]            # dotted path from the registry, e.g. "agent.<key>"
v = cfg
for part in path.split("."):
    v = v.get(part) if isinstance(v, dict) else None
if v is None:
    print(f"{path} is not set (a missing value is a defect)"); sys.exit(1)
if isinstance(v, bool) or not isinstance(v, (int, float)) or v <= 0:
    print(f"{path} is not a positive number: {v!r}"); sys.exit(1)
mn, mx = float(os.environ["MIN"]), float(os.environ["MAX"])
if not mn <= v <= mx:
    print(f"{path} = {v} outside working range {mn}-{mx}"); sys.exit(1)
print(f"{path} = {v} (in range)")
