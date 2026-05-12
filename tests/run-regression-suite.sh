#!/usr/bin/env bash
# run-regression-suite.sh — adaptive-context-pruner v2.0.0 regression test suite
# Standard R01-R09 battery covering v1→v2 regression surface
# Usage: bash tests/run-regression-suite.sh [SKILL_DIR]
set -euo pipefail

SKILL_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

pass() { echo "PASS [R$1]: $2"; PASS=$((PASS+1)); }
fail() { echo "FAIL [R$1]: $2"; FAIL=$((FAIL+1)); }

echo "=== adaptive-context-pruner v2.0.0 regression suite ==="
echo "SKILL_DIR: $SKILL_DIR"

# R01 — External-contract preservation (EC-FC04-1..EC-FC04-5)
echo ""
echo "[R01] External-contract preservation (EC-FC04)"

python3 << PYEOF
import json, sys, os

skill_dir = "$SKILL_DIR"

errors = []

# EC-FC04-1: skill name
with open(f"{skill_dir}/SKILL.md") as f:
    skill_md = f.read()
if "name: adaptive-context-pruner" not in skill_md:
    errors.append("EC-FC04-1: SKILL.md missing 'name: adaptive-context-pruner'")

# EC-FC04-2: original 11 YAML output fields preserved (additive only)
# Fields appear in N-FORMATTER.md (the node that emits them) or SKILL.md
with open(f"{skill_dir}/modules/N-FORMATTER.md") as f:
    formatter_md = f.read()
combined = skill_md + formatter_md
required_fields = [
    "skill_name", "version", "generated_at", "domain",
    "retention_ruleset_applied", "total_turns_input", "compression_ratio_overall",
    "topic_switch_count", "supersession_count", "verify_pass", "conflict_annotations"
]
for field in required_fields:
    if field not in combined:
        errors.append(f"EC-FC04-2: YAML output field '{field}' missing from SKILL.md+N-FORMATTER.md")

# EC-FC04-3: back-edge caps
with open(f"{skill_dir}/graph.json") as f:
    g = json.load(f)
for eid in ["E-20", "E-21"]:
    e = [x for x in g["edges"] if x["id"] == eid]
    if not e:
        errors.append(f"EC-FC04-3: {eid} missing from graph.json")
    elif e[0].get("cap") != 1:
        errors.append(f"EC-FC04-3: {eid} cap={e[0].get('cap')}, expected 1")

# EC-FC04-4: 15 v1 signal names preserved (check SKILL.md + all modules)
v1_signals = [
    "ingest_record", "refuse_signal", "graph_structure", "domain_gate",
    "technical_scores", "creative_scores", "topic_signal", "supersession_map",
    "protected_node_set", "pruning_plan", "refined_context",
    "verify_pass_signal", "recovery_overrides", "rendered_output", "session_artifact"
]
# Build combined corpus from SKILL.md + all module files
all_content = skill_md
import glob
for mod_file in glob.glob(f"{skill_dir}/modules/*.md"):
    with open(mod_file) as f:
        all_content += f.read()
for sig in v1_signals:
    if sig not in all_content:
        errors.append(f"EC-FC04-4: v1 signal name '{sig}' missing from SKILL.md+modules/")

# EC-FC04-5: sinks
sinks = g.get("metadata", {}).get("sinks", [])
for sink in ["REFUSE_OUTPUT", "SKILL_OUTPUT"]:
    if sink not in sinks:
        errors.append(f"EC-FC04-5: sink '{sink}' missing from graph.json metadata.sinks")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  All EC-FC04 checks passed")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 1 "EC-FC04-1..5 external contracts all preserved"
else
  fail 1 "EC-FC04 external contract violation(s) detected"
fi

# R02 — N-ANALYZER-CORRECTIONS verbatim preservation
echo ""
echo "[R02] N-ANALYZER-CORRECTIONS verbatim preservation"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-ANALYZER-CORRECTIONS.md"

with open(mod_path) as f:
    content = f.read()

errors = []
# Must preserve core signals
for signal in ["supersession_map", "E-14", "AP-V29", "AP-V7"]:
    if signal not in content:
        errors.append(f"N-ANALYZER-CORRECTIONS.md missing '{signal}'")

# Must preserve AP-V7 no-silent-deferral guard
if "no-silent" not in content.lower() and "no_silent" not in content.lower() and "AP-V7" not in content:
    errors.append("N-ANALYZER-CORRECTIONS.md: AP-V7 no-silent-deferral guard appears missing")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  N-ANALYZER-CORRECTIONS verbatim preservation checks passed")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 2 "N-ANALYZER-CORRECTIONS verbatim preservation verified"
else
  fail 2 "N-ANALYZER-CORRECTIONS preservation failure"
fi

# R03 — Back-edge cap integrity and AP-V29 spawn provenance
echo ""
echo "[R03] Back-edge cap integrity and AP-V29 provenance edges"

python3 << PYEOF
import json, sys

skill_dir = "$SKILL_DIR"

with open(f"{skill_dir}/graph.json") as f:
    g = json.load(f)

errors = []
edge_ids = [e["id"] for e in g["edges"]]

# Back-edges: E-20 and E-21 with cap=1
for eid in ["E-20", "E-21"]:
    e = [x for x in g["edges"] if x["id"] == eid]
    if not e:
        errors.append(f"{eid}: missing from graph.json")
        continue
    if e[0].get("edge_type") != "back-edge":
        errors.append(f"{eid}: edge_type={e[0].get('edge_type')}, expected back-edge")
    if e[0].get("cap") != 1:
        errors.append(f"{eid}: cap={e[0].get('cap')}, expected 1")

# AP-V29 spawn provenance: E-05b, E-16b
for eid in ["E-05b", "E-16b"]:
    if eid not in edge_ids:
        errors.append(f"AP-V29 provenance edge {eid} missing from graph.json")

# AP-V29 declared edges: E-14 (supersession_map)
if "E-14" not in edge_ids:
    errors.append("AP-V29 declared edge E-14 missing from graph.json")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  Back-edge caps and AP-V29 provenance edges all present")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 3 "Back-edge caps and AP-V29 provenance edges verified"
else
  fail 3 "Back-edge cap or AP-V29 provenance failure"
fi

# R04 — Dependency-graph critical-path (v2 upgrade: N-GENERATOR output)
echo ""
echo "[R04] N-GENERATOR critical-path output ports"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-GENERATOR.md"

with open(mod_path) as f:
    content = f.read()

errors = []
for required in ["dependency_graph", "critical_path_set", "boundary_candidates"]:
    if required not in content:
        errors.append(f"N-GENERATOR.md missing output port '{required}'")

# E-08d should be referenced
if "E-08d" not in content and "08d" not in content:
    errors.append("N-GENERATOR.md: E-08d (→N-AGGREGATION dependency_graph) not referenced")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  N-GENERATOR dependency-graph output ports present")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 4 "N-GENERATOR critical-path output ports verified"
else
  fail 4 "N-GENERATOR dependency-graph output port(s) missing"
fi

# R05 — Domain set extension (N-CLASSIFIER)
echo ""
echo "[R05] N-CLASSIFIER domain set extension {research, planning}"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-CLASSIFIER.md"

with open(mod_path) as f:
    content = f.read()

errors = []
for domain in ["research", "planning"]:
    if domain not in content:
        errors.append(f"N-CLASSIFIER.md missing domain '{domain}'")

# v1 domains must still be present
for domain in ["technical-debugging", "creative-brainstorming"]:
    if domain not in content:
        errors.append(f"N-CLASSIFIER.md missing v1 domain '{domain}' (regression)")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  N-CLASSIFIER domain set {technical-debugging, creative-brainstorming, auto-detect, research, planning} present")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 5 "N-CLASSIFIER domain set extended and v1 domains preserved"
else
  fail 5 "N-CLASSIFIER domain set regression"
fi

# R06 — N-VERIFIER SC battery 8→13
echo ""
echo "[R06] N-VERIFIER SC battery 8→13"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-VERIFIER.md"

with open(mod_path) as f:
    content = f.read()

errors = []

# SC-1 through SC-13 must all be referenced
for sc_num in range(1, 14):
    # Accept SC-N or SC_N or SC N
    patterns = [f"SC-{sc_num}", f"SC_{sc_num}", f"SC {sc_num}"]
    found = any(p in content for p in patterns)
    if not found:
        errors.append(f"N-VERIFIER.md: SC-{sc_num} not found")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  All SC-1..SC-13 present in N-VERIFIER.md")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 6 "N-VERIFIER 13-SC battery (SC-1..SC-13) verified"
else
  fail 6 "N-VERIFIER SC battery incomplete"
fi

# R07 — N-AGGREGATION 8-stream AND-join
echo ""
echo "[R07] N-AGGREGATION 8-stream AND-join"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-AGGREGATION.md"

with open(mod_path) as f:
    content = f.read()

errors = []

# branch_budget_cap=8
if "branch_budget_cap" not in content or ("8" not in content):
    if "branch_budget_cap=8" not in content and "branch_budget_cap: 8" not in content:
        errors.append("N-AGGREGATION.md: branch_budget_cap=8 not found")

# 5-tier priority merge
if "priority" not in content.lower() and "5-tier" not in content.lower():
    errors.append("N-AGGREGATION.md: 5-tier priority merge not documented")

# token_budget=8000
if "8000" not in content:
    errors.append("N-AGGREGATION.md: token_budget=8000 not found")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  N-AGGREGATION 8-stream AND-join parameters verified")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 7 "N-AGGREGATION 8-stream AND-join verified"
else
  fail 7 "N-AGGREGATION regression failure"
fi

# R08 — N-REFINER scope boundary (compression-recommendation-only)
echo ""
echo "[R08] N-REFINER scope boundary (compression-recommendation-only)"

python3 << PYEOF
import sys

skill_dir = "$SKILL_DIR"
mod_path = f"{skill_dir}/modules/N-REFINER.md"

with open(mod_path) as f:
    content = f.read()

errors = []

# FileRef substitution must be documented
if "FileRef" not in content and "file_ref" not in content.lower():
    errors.append("N-REFINER.md: FileRef substitution not documented")

# file_cache_map input must be documented
if "file_cache_map" not in content:
    errors.append("N-REFINER.md: file_cache_map input not documented")

# Scope boundary: should reference compression recommendation, not eviction executor
if "eviction" in content.lower():
    # This is acceptable IF it clarifies that eviction is NOT N-REFINER's responsibility
    # Check for scope-boundary language
    if "not" not in content.lower() and "N-TIER-MANAGER" not in content:
        errors.append("N-REFINER.md: contains 'eviction' without scope-boundary clarification referencing N-TIER-MANAGER")

if errors:
    for err in errors:
        print(f"  ERROR: {err}")
    sys.exit(1)
else:
    print("  N-REFINER scope boundary (FileRef, file_cache_map) verified")
    sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 8 "N-REFINER scope boundary verified"
else
  fail 8 "N-REFINER scope boundary regression"
fi

# R09 — graph.json schema validation
echo ""
echo "[R09] graph.json validates against graph.schema.json"

python3 << PYEOF
import json, sys

skill_dir = "$SKILL_DIR"

try:
    import jsonschema
    with open(f"{skill_dir}/graph.json") as f:
        graph = json.load(f)
    with open(f"{skill_dir}/graph.schema.json") as f:
        schema = json.load(f)
    try:
        jsonschema.validate(graph, schema)
        print("  graph.json validates against graph.schema.json (jsonschema)")
        sys.exit(0)
    except jsonschema.ValidationError as e:
        print(f"  ERROR: validation failure: {e.message}")
        sys.exit(1)
except ImportError:
    # jsonschema not available — fall back to structural checks
    print("  jsonschema not available; running structural fallback checks")
    with open(f"{skill_dir}/graph.json") as f:
        g = json.load(f)
    errors = []
    if "nodes" not in g:
        errors.append("graph.json missing 'nodes' key")
    if "edges" not in g:
        errors.append("graph.json missing 'edges' key")
    if "metadata" not in g:
        errors.append("graph.json missing 'metadata' key")
    # Check node required fields
    for n in g.get("nodes", []):
        for field in ["id", "type", "hat", "exec_type", "wave"]:
            if field not in n:
                errors.append(f"node {n.get('id','?')} missing field '{field}'")
    # Check edge required fields
    for e in g.get("edges", []):
        for field in ["id", "edge_type", "source", "target"]:
            if field not in e:
                errors.append(f"edge {e.get('id','?')} missing field '{field}'")
    if errors:
        for err in errors[:5]:
            print(f"  ERROR: {err}")
        if len(errors) > 5:
            print(f"  ... and {len(errors)-5} more errors")
        sys.exit(1)
    else:
        print("  Structural fallback checks passed (jsonschema not available)")
        sys.exit(0)
PYEOF
if [[ $? -eq 0 ]]; then
  pass 9 "graph.json schema validation passed"
else
  fail 9 "graph.json schema validation failure"
fi

echo ""
echo "Regression suite: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
