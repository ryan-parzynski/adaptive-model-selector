#!/usr/bin/env python3
"""contrib-validate.py — check community contributions under contrib/ before they are opened as a PR
and again in CI. Exit 0 valid, 1 invalid, 2 cannot-observe.

Two lanes (contrib/README.md):
  contrib/reports/YYYY-MM/<8 hex>.yaml   schema report/v1   — anonymous performance rollups
  contrib/findings/YYYY-MM/<8 hex>.yaml  schema finding/v1  — edge cases, bugs, optimizations, fixes

Wild data is rejected here (unknown keys, wrong types, impossible ranges, oversize text, identifying
strings) and discounted later (contrib/README.md: robust aggregation, quorum before any default changes).
Usage: contrib-validate.py FILE...
"""
import os, re, sys
try:
    import yaml
except ImportError:
    print("CANNOT-OBSERVE: PyYAML missing"); sys.exit(2)

MAX_FILE = 20_000
MAX_TEXT = 600
ID_RE = re.compile(r"^[A-Za-z0-9._/:@+-]{1,120}$")
REASON_RE = re.compile(r"^[a-z][a-z0-9_]{1,40}$")
SECTION_RE = re.compile(r"^§\d+(\.\d+[a-z]?(-bis)?)?$")
IDENTIFYING = [
    (re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"), "IP address"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.]+"), "email address"),
    (re.compile(r"https?://"), "URL"),
    (re.compile(r"\b[\w-]+\.ts\.net\b|\.local\b|\.lan\b", re.I), "host name"),
    (re.compile(r"(^|\s)(/home|/root|/opt|/srv|/Users|[A-Z]:\\)", re.M), "file path"),
    (re.compile(r"\b(sk|pk|ghp|gho|xox[abp])[-_][A-Za-z0-9_-]{8,}"), "key-like string"),
]

def num(lo, hi):
    return ("num", lo, hi)

REPORT = {
    "schema": "report/v1",
    "spec_version": ("str",),
    "month": ("month",),
    "period_days": num(1, 92),
    "box": {
        "gpu_class": ("enum", "none", "<=8GB", "8-16GB", "16-32GB", ">32GB", "multi"),
        "cpu_cores": ("enum", "<=4", "5-8", "9-16", "17-32", ">32"),
        "ram_gb": ("enum", "<=16", "17-32", "33-64", "65-128", ">128"),
        "local_lanes": num(0, 32),
        "peer_lanes": num(0, 32),
        "providers": ("list", ("id",), 12),
    },
    "rollups": {
        "switches_per_day": num(0, 1440),
        "switches_by_reason": ("map", ("reason",), num(0, 1_000_000)),
        "fallback_shared_dependency_rate": num(0, 1),
        "free_requests_per_session_p95": num(0, 100_000),
        "first_token_ms_p50": ("map", ("enum", "local_gpu", "local_cpu", "peer_gpu", "peer_cpu", "api_free", "api_paid"), num(0, 600_000)),
        "lane_busy_rate": num(0, 1),
        "paid_usd_per_day_p50": num(0, 10_000),
        "limit_hits": ("map", ("enum", "box_daily", "session_window", "job_soft", "job_hard", "breaker", "escalation_envelope", "provider"), num(0, 1_000_000)),
    },
    "models": ("list", {
        "id": ("id",),
        "work_type": ("reason",),
        "checked_runs": num(0, 1_000_000),
        "pass_rate": num(0, 1),
    }, 50),
}
FINDING = {
    "schema": "finding/v1",
    "spec_version": ("str",),
    "month": ("month",),
    "kind": ("enum", "bug", "edge_case", "optimization", "fix", "unclear_rule"),
    "sections": ("list", ("section",), 10),
    "observed": ("text",),
    "evidence": ("text",),
    "proposal": ("text",),
    "reason_codes": ("list", ("reason",), 20),
    "boxes_observed": num(1, 1000),
}
REQUIRED = {"report/v1": ["schema", "spec_version", "month", "period_days", "rollups"],
            "finding/v1": ["schema", "spec_version", "month", "kind", "sections", "observed", "proposal"]}

errs = []

def scalar(rule, v, where):
    t = rule[0]
    if t == "num":
        if isinstance(v, bool) or not isinstance(v, (int, float)):
            errs.append(f"{where}: must be a number"); return
        if not (rule[1] <= v <= rule[2]):
            errs.append(f"{where}: {v} outside plausible range {rule[1]}..{rule[2]}")
    elif t == "enum":
        if v not in rule[1:]:
            errs.append(f"{where}: must be one of {', '.join(map(str, rule[1:]))}")
    elif t in ("str", "id", "reason", "section", "month", "text"):
        if not isinstance(v, str):
            errs.append(f"{where}: must be text"); return
        if t == "id" and not ID_RE.match(v): errs.append(f"{where}: not an id")
        if t == "reason" and not REASON_RE.match(v): errs.append(f"{where}: not a snake_case code")
        if t == "section" and not SECTION_RE.match(v): errs.append(f"{where}: not a spec section like §4.20")
        if t == "month" and not re.match(r"^20\d\d-(0[1-9]|1[0-2])$", v): errs.append(f"{where}: month must be YYYY-MM")
        if t == "str" and not re.match(r"^\d+\.\d+(\.\d+)?$", v): errs.append(f"{where}: version like 3.10")
        if len(v) > MAX_TEXT: errs.append(f"{where}: longer than {MAX_TEXT} characters")
        for rx, what in IDENTIFYING:
            if rx.search(v): errs.append(f"{where}: contains a {what}; contributions are anonymous")

def check(rule, v, where):
    if isinstance(rule, dict):
        if not isinstance(v, dict):
            errs.append(f"{where}: must be a mapping"); return
        for k, val in v.items():
            if k not in rule:
                errs.append(f"{where}.{k}: unknown field (only listed fields are accepted)"); continue
            check(rule[k], val, f"{where}.{k}")
    elif isinstance(rule, str):
        if v != rule: errs.append(f"{where}: must be {rule}")
    elif rule[0] == "list":
        if not isinstance(v, list): errs.append(f"{where}: must be a list"); return
        if len(v) > rule[2]: errs.append(f"{where}: at most {rule[2]} items")
        for i, item in enumerate(v): check(rule[1], item, f"{where}[{i}]")
    elif rule[0] == "map":
        if not isinstance(v, dict): errs.append(f"{where}: must be a mapping"); return
        for k, val in v.items():
            scalar(rule[1], k, f"{where} key {k!r}"); scalar(rule[2], val, f"{where}.{k}")
    else:
        scalar(rule, v, where)

def main(paths):
    if not paths:
        print("CANNOT-OBSERVE: no files given"); return 2
    bad = 0
    for p in paths:
        global errs; errs = []
        m = re.search(r"contrib/(reports|findings)/(20\d\d-\d\d)/[0-9a-f]{8}\.yaml$", p.replace(os.sep, "/"))
        if not m:
            errs.append("path must be contrib/reports|findings/YYYY-MM/<8 hex>.yaml")
        try:
            raw = open(p, "rb").read()
        except OSError:
            print(f"CANNOT-OBSERVE: {p} unreadable"); return 2
        if len(raw) > MAX_FILE: errs.append(f"file larger than {MAX_FILE} bytes")
        try:
            doc = yaml.safe_load(raw)
        except yaml.YAMLError:
            doc = None; errs.append("not valid YAML")
        if doc is not None:
            schema = doc.get("schema") if isinstance(doc, dict) else None
            spec = {"report/v1": REPORT, "finding/v1": FINDING}.get(schema)
            if spec is None:
                errs.append("schema must be report/v1 or finding/v1")
            else:
                if m and {"report/v1": "reports", "finding/v1": "findings"}[schema] != m.group(1):
                    errs.append(f"{schema} belongs in contrib/{'reports' if schema=='report/v1' else 'findings'}/")
                for k in REQUIRED[schema]:
                    if k not in doc: errs.append(f"missing required field {k}")
                check(spec, doc, "")
                if m and doc.get("month") and doc.get("month") != m.group(2):
                    errs.append("month field must match the folder")
        for e in errs: print(f"INVALID {p}: {e.lstrip('.')}")
        if errs: bad += 1
        else: print(f"VALID {p}")
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
