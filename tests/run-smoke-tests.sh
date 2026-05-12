#!/usr/bin/env bash
# run-smoke-tests.sh — adaptive-context-pruner v2.0.0 structural smoke test
# Usage: bash tests/run-smoke-tests.sh [SKILL_DIR]
set -euo pipefail

SKILL_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
PASS=0
FAIL=0

pass() { echo "  PASS [S$(printf '%02d' $1)]: $2"; PASS=$((PASS+1)); }
fail() { echo "  FAIL [S$(printf '%02d' $1)]: $2"; FAIL=$((FAIL+1)); }

run_check() {
  local id="$1"; local desc="$2"; local result
  result="$(eval "$3" 2>&1)" || result="ERROR: $result"
  if [[ "$result" == "PASS" ]]; then
    pass "$id" "$desc"
  else
    fail "$id" "$desc — $result"
  fi
}

echo "=== adaptive-context-pruner v2.0.0 smoke tests ==="
echo "SKILL_DIR: $SKILL_DIR"

# S01 — SKILL.md frontmatter version and skill name
run_check 1 "SKILL.md frontmatter: version=2.0.0" \
  "grep -q 'version: 2\.0\.0' \"$SKILL_DIR/SKILL.md\" && echo PASS || echo 'version: 2.0.0 not found in SKILL.md'"

run_check 1 "SKILL.md frontmatter: name=adaptive-context-pruner" \
  "grep -q 'name: adaptive-context-pruner' \"$SKILL_DIR/SKILL.md\" && echo PASS || echo 'name: adaptive-context-pruner not found in SKILL.md'"

# S02 — graph.json metadata: 20 nodes, 39 edges, 9 waves, 3 spawns, sinks
run_check 2 "graph.json valid JSON" \
  "python3 -c \"import json; json.load(open('$SKILL_DIR/graph.json')); print('PASS')\""

run_check 2 "graph.json: 20 nodes" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); n=len(g['nodes']); print('PASS' if n==20 else f'expected 20 nodes, got {n}')\""

run_check 2 "graph.json: 39 edges" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); n=len(g['edges']); print('PASS' if n==39 else f'expected 39 edges, got {n}')\""

run_check 2 "graph.json metadata: total_waves=9" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); v=g.get('metadata',{}).get('total_waves'); print('PASS' if v==9 else f'expected total_waves=9, got {v}')\""

run_check 2 "graph.json metadata: spawn_node_count=3" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); v=g.get('metadata',{}).get('spawn_node_count'); print('PASS' if v==3 else f'expected spawn_node_count=3, got {v}')\""

run_check 2 "graph.json metadata: version=2.0.0" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); v=g.get('metadata',{}).get('version'); print('PASS' if v=='2.0.0' else f'expected version=2.0.0, got {v}')\""

# S03 — AP-V29: named long-carry/provenance/back edges declared
run_check 3 "graph.json: E-05b declared (AP-V29 N-INGEST→N-AGGREGATION)" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[e['id'] for e in g['edges']]; print('PASS' if 'E-05b' in ids else 'E-05b missing')\""

run_check 3 "graph.json: E-16b declared (AP-V29 N-INGEST→N-REFINER)" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[e['id'] for e in g['edges']]; print('PASS' if 'E-16b' in ids else 'E-16b missing')\""

run_check 3 "graph.json: E-14 declared (AP-V29 N-ANALYZER-CORRECTIONS→N-AGGREGATION)" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[e['id'] for e in g['edges']]; print('PASS' if 'E-14' in ids else 'E-14 missing')\""

run_check 3 "graph.json: E-17 declared (long-carry N-FILTER→N-FORMATTER W2→W8)" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[e['id'] for e in g['edges']]; print('PASS' if 'E-17' in ids else 'E-17 missing')\""

run_check 3 "graph.json: E-17b declared (long-carry N-TIER-MANAGER→N-FORMATTER W7→W8)" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[e['id'] for e in g['edges']]; print('PASS' if 'E-17b' in ids else 'E-17b missing')\""

# S04 — sinks: REFUSE_OUTPUT, SKILL_OUTPUT, NO-OP-TERMINAL
run_check 4 "graph.json metadata: REFUSE_OUTPUT in sinks" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); s=g.get('metadata',{}).get('sinks',[]); print('PASS' if 'REFUSE_OUTPUT' in s else f'REFUSE_OUTPUT missing from sinks {s}')\""

run_check 4 "graph.json metadata: SKILL_OUTPUT in sinks" \
  "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); s=g.get('metadata',{}).get('sinks',[]); print('PASS' if 'SKILL_OUTPUT' in s else f'SKILL_OUTPUT missing from sinks {s}')\""

# S05 — hats.json
run_check 5 "hats.json valid JSON" \
  "python3 -c \"import json; h=json.load(open('$SKILL_DIR/hats.json')); print('PASS' if isinstance(h, list) else 'hats.json not a list')\""

run_check 5 "hats.json: all hats have model field" \
  "python3 -c \"import json; h=json.load(open('$SKILL_DIR/hats.json')); bad=[x.get('hat_id','?') for x in h if 'model' not in x]; print('PASS' if not bad else f'missing model: {bad}')\""

# S06 — module keyword checks (R(msg) formula, node-specific)
run_check 6 "N-SCORER-TECHNICAL.md: R(msg) formula present" \
  "grep -q 'R(msg)' \"$SKILL_DIR/modules/N-SCORER-TECHNICAL.md\" && echo PASS || echo 'R(msg) formula missing from N-SCORER-TECHNICAL.md'"

run_check 6 "N-SCORER-CREATIVE.md: R(msg) formula present" \
  "grep -q 'R(msg)' \"$SKILL_DIR/modules/N-SCORER-CREATIVE.md\" && echo PASS || echo 'R(msg) formula missing from N-SCORER-CREATIVE.md'"

run_check 6 "N-FILTER.md: tiered_node_set_hint present" \
  "grep -q 'tiered_node_set_hint' \"$SKILL_DIR/modules/N-FILTER.md\" && echo PASS || echo 'tiered_node_set_hint missing from N-FILTER.md'"

run_check 6 "N-ANALYZER-TOPIC-SWITCH.md: episode_boundaries present" \
  "grep -q 'episode_boundaries' \"$SKILL_DIR/modules/N-ANALYZER-TOPIC-SWITCH.md\" && echo PASS || echo 'episode_boundaries missing from N-ANALYZER-TOPIC-SWITCH.md'"

# S07 — 20 module files present
run_check 7 "modules/ directory has exactly 20 .md files" \
  "python3 -c \"import os; n=len([f for f in os.listdir('$SKILL_DIR/modules') if f.endswith('.md')]); print('PASS' if n==20 else f'expected 20 modules, got {n}')\""

EXPECTED_MODULES=(
  N-AGGREGATION.md N-ANALYZER-CORRECTIONS.md N-ANALYZER-TOPIC-SWITCH.md N-CLASSIFIER.md
  N-CONTINUITY-MARKER.md N-FILE-CACHE.md N-FILTER.md N-FORMATTER.md N-GENERATOR.md
  N-INGEST.md N-PERSISTER.md N-PREFLIGHT.md N-RECOVERY.md N-REFINER.md
  N-SCORER-CREATIVE.md N-SCORER-TECHNICAL.md N-SEMANTIC-CLUSTER.md N-TIER-MANAGER.md
  N-TRIGGER-EVAL.md N-VERIFIER.md
)
MODULE_FAIL=0
for mod in "${EXPECTED_MODULES[@]}"; do
  if [[ ! -f "$SKILL_DIR/modules/$mod" ]]; then
    echo "  FAIL [S07]: modules/$mod missing"
    MODULE_FAIL=$((MODULE_FAIL+1))
  fi
done
if [[ $MODULE_FAIL -eq 0 ]]; then
  pass 7 "All 20 canonical module files present"
else
  fail 7 "$MODULE_FAIL canonical module file(s) missing"
fi

# S08 — back-edge caps
run_check 8 "graph.json: E-20 is back-edge with cap=1" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
e=[x for x in g['edges'] if x['id']=='E-20']
if not e: print('E-20 missing')
elif e[0].get('edge_type') != 'back-edge': print(f'E-20 type={e[0].get(\"edge_type\")}, expected back-edge')
elif e[0].get('cap') != 1: print(f'E-20 cap={e[0].get(\"cap\")}, expected 1')
else: print('PASS')
\""

run_check 8 "graph.json: E-21 is back-edge with cap=1" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
e=[x for x in g['edges'] if x['id']=='E-21']
if not e: print('E-21 missing')
elif e[0].get('edge_type') != 'back-edge': print(f'E-21 type={e[0].get(\"edge_type\")}, expected back-edge')
elif e[0].get('cap') != 1: print(f'E-21 cap={e[0].get(\"cap\")}, expected 1')
else: print('PASS')
\""

# S09 — N-VERIFIER 13-SC battery
run_check 9 "N-VERIFIER.md: 13-SC battery documented" \
  "grep -q 'SC-13\|13-SC\|thirteen' \"$SKILL_DIR/modules/N-VERIFIER.md\" && echo PASS || echo 'SC-13 / 13-SC not found in N-VERIFIER.md'"

run_check 9 "N-VERIFIER.md: SC-9 present" \
  "grep -q 'SC-9\|SC_9\|sc-9' \"$SKILL_DIR/modules/N-VERIFIER.md\" && echo PASS || echo 'SC-9 not found in N-VERIFIER.md'"

# S10 — N-ANALYZER-CORRECTIONS verbatim (preserved node)
run_check 10 "N-ANALYZER-CORRECTIONS.md: supersession_map present (AP-V29)" \
  "grep -q 'supersession_map' \"$SKILL_DIR/modules/N-ANALYZER-CORRECTIONS.md\" && echo PASS || echo 'supersession_map missing from N-ANALYZER-CORRECTIONS.md'"

run_check 10 "N-ANALYZER-CORRECTIONS.md: E-14 declared edge reference" \
  "grep -q 'E-14' \"$SKILL_DIR/modules/N-ANALYZER-CORRECTIONS.md\" && echo PASS || echo 'E-14 reference missing from N-ANALYZER-CORRECTIONS.md'"

# S11 — N-TIER-MANAGER 4-phase Algorithm A
run_check 11 "N-TIER-MANAGER.md: Algorithm A or 4-phase eviction present" \
  "grep -qE 'Algorithm A|4-phase|eviction' \"$SKILL_DIR/modules/N-TIER-MANAGER.md\" && echo PASS || echo 'Algorithm A / 4-phase eviction not found in N-TIER-MANAGER.md'"

run_check 11 "N-TIER-MANAGER.md: protected_node_set exclusion documented" \
  "grep -q 'protected_node_set' \"$SKILL_DIR/modules/N-TIER-MANAGER.md\" && echo PASS || echo 'protected_node_set missing from N-TIER-MANAGER.md'"

# S12 — New v2 nodes present in graph.json
for new_node in N-TRIGGER-EVAL N-FILE-CACHE N-SEMANTIC-CLUSTER N-TIER-MANAGER N-CONTINUITY-MARKER; do
  run_check 12 "graph.json: $new_node present (new v2 node)" \
    "python3 -c \"import json; g=json.load(open('$SKILL_DIR/graph.json')); ids=[n['id'] for n in g['nodes']]; print('PASS' if '$new_node' in ids else '$new_node missing from graph.json nodes')\""
done

# S13 — N-AGGREGATION 8-stream
run_check 13 "N-AGGREGATION.md: 8-stream AND-join documented" \
  "grep -qE '8.stream|eight.stream|AND.join' \"$SKILL_DIR/modules/N-AGGREGATION.md\" && echo PASS || echo '8-stream AND-join not found in N-AGGREGATION.md'"

run_check 13 "N-AGGREGATION.md: branch_budget_cap=8 present" \
  "grep -q 'branch_budget_cap.*8\|8.*branch_budget_cap' \"$SKILL_DIR/modules/N-AGGREGATION.md\" && echo PASS || echo 'branch_budget_cap=8 not found in N-AGGREGATION.md'"

# S14 — SKILL.md section structure
run_check 14 "SKILL.md: nodes field = 20" \
  "grep -q 'nodes: 20' \"$SKILL_DIR/SKILL.md\" && echo PASS || echo 'nodes: 20 not found in SKILL.md'"

run_check 14 "SKILL.md: edges field = 39" \
  "grep -q 'edges: 39' \"$SKILL_DIR/SKILL.md\" && echo PASS || echo 'edges: 39 not found in SKILL.md'"

run_check 14 "SKILL.md: waves field = 9" \
  "grep -q 'waves: 9' \"$SKILL_DIR/SKILL.md\" && echo PASS || echo 'waves: 9 not found in SKILL.md'"

# S15 — graph.schema.json valid and references required fields
run_check 15 "graph.schema.json exists and is valid JSON" \
  "python3 -c \"import json; json.load(open('$SKILL_DIR/graph.schema.json')); print('PASS')\""

run_check 15 "graph.schema.json: references 'nodes' property" \
  "python3 -c \"import json; s=json.load(open('$SKILL_DIR/graph.schema.json')); print('PASS' if 'nodes' in str(s) else 'nodes not referenced in schema')\""

# FC-08 compliance assertions — divergence_map upgraded/recontracted nodes
# V26(e): every node with origin in {upgraded,replaced,merged,recontracted} must have an assertion line

# N-INGEST (upgraded: dual-mode input shape)
run_check 16 "N-INGEST (FC-08): module has auto-mode input documentation" \
  "grep -qE 'auto.mode|turn_delta|current_token_count|auto_prune' \"$SKILL_DIR/modules/N-INGEST.md\" && echo PASS || echo 'N-INGEST.md missing auto-mode input documentation'"

# N-PREFLIGHT (upgraded: mode detection branch)
run_check 16 "N-PREFLIGHT (FC-08): module has mode detection logic" \
  "grep -iqE 'mode.*detect|auto.*mode|manual.*mode|trigger_signal|MANUAL mode|AUTOMATIC mode' \"$SKILL_DIR/modules/N-PREFLIGHT.md\" && echo PASS || echo 'N-PREFLIGHT.md missing mode detection logic'"

# N-GENERATOR (upgraded: dependency DAG + critical-path)
run_check 16 "N-GENERATOR (FC-08): module has dependency_graph output port" \
  "grep -q 'dependency_graph' \"$SKILL_DIR/modules/N-GENERATOR.md\" && echo PASS || echo 'N-GENERATOR.md missing dependency_graph output port'"

run_check 16 "N-GENERATOR (FC-08): module has critical_path_set output port" \
  "grep -q 'critical_path_set' \"$SKILL_DIR/modules/N-GENERATOR.md\" && echo PASS || echo 'N-GENERATOR.md missing critical_path_set output port'"

# N-CLASSIFIER (upgraded: research/planning domains added per SC-8)
run_check 16 "N-CLASSIFIER (FC-08): module has research/planning domain support" \
  "grep -qE 'research|planning' \"$SKILL_DIR/modules/N-CLASSIFIER.md\" && echo PASS || echo 'N-CLASSIFIER.md missing research/planning domain extension'"

# N-REFINER (upgraded: scope change — compression annotation only; eviction moves to N-TIER-MANAGER)
run_check 16 "N-REFINER (FC-08): module scoped to annotation/compression not tier eviction" \
  "grep -qE 'N-TIER-MANAGER|tier.*evict|eviction.*N-TIER|FileRef' \"$SKILL_DIR/modules/N-REFINER.md\" && echo PASS || echo 'N-REFINER.md missing scope boundary / N-TIER-MANAGER delegation'"

# N-RECOVERY (upgraded: SC-9..SC-13 override procedures added)
run_check 16 "N-RECOVERY (FC-08): module has SC-9 through SC-13 override procedures" \
  "grep -qE 'SC-9|SC-10|SC-11|SC-12|SC-13' \"$SKILL_DIR/modules/N-RECOVERY.md\" && echo PASS || echo 'N-RECOVERY.md missing SC-9..SC-13 override procedures'"

# N-FORMATTER (upgraded: W8 placement, tier_state input, new YAML fields)
run_check 16 "N-FORMATTER (FC-08): module references tier_state input (E-17b)" \
  "grep -qE 'tier_state|E-17b' \"$SKILL_DIR/modules/N-FORMATTER.md\" && echo PASS || echo 'N-FORMATTER.md missing tier_state/E-17b input port'"

run_check 16 "N-FORMATTER (FC-08): module references auto_prune_triggered YAML field" \
  "grep -q 'auto_prune_triggered' \"$SKILL_DIR/modules/N-FORMATTER.md\" && echo PASS || echo 'N-FORMATTER.md missing auto_prune_triggered YAML field'"

# Edge recontract assertions (E-18/E-19/E-22 are medium-risk)
run_check 16 "E-18 (FC-08 recontract): graph.json E-18 target is N-VERIFIER" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
e=[x for x in g['edges'] if x['id']=='E-18']
if not e: print('E-18 missing')
elif e[0].get('target') != 'N-VERIFIER': print(f'E-18 target={e[0].get(\"target\")}, expected N-VERIFIER')
else: print('PASS')
\""

run_check 16 "E-19 (FC-08 recontract): graph.json E-19 target is N-TIER-MANAGER" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
e=[x for x in g['edges'] if x['id']=='E-19']
if not e: print('E-19 missing')
elif e[0].get('target') != 'N-TIER-MANAGER': print(f'E-19 target={e[0].get(\"target\")}, expected N-TIER-MANAGER')
else: print('PASS')
\""

run_check 16 "E-22 (FC-08 recontract): graph.json E-22 source is N-TIER-MANAGER" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
e=[x for x in g['edges'] if x['id']=='E-22']
if not e: print('E-22 missing')
elif e[0].get('source') != 'N-TIER-MANAGER': print(f'E-22 source={e[0].get(\"source\")}, expected N-TIER-MANAGER')
else: print('PASS')
\""

# V20b: hc23_parallel_dispatch_waves declared
run_check 17 "V20b: graph.json hc23_parallel_dispatch_waves contains W2 and W3" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
waves=g.get('metadata',{}).get('hc23_parallel_dispatch_waves',[])
ok = 'W2' in waves and 'W3' in waves
print('PASS' if ok else f'hc23_parallel_dispatch_waves={waves}, expected [W2,W3]')
\""

run_check 17 "V20b: W2 nodes all have parallel_dispatch_required=true" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
w2={'N-GENERATOR','N-CLASSIFIER','N-FILTER','N-FILE-CACHE'}
bad=[n['id'] for n in g['nodes'] if n['id'] in w2 and not n.get('parallel_dispatch_required')]
print('PASS' if not bad else f'W2 nodes missing parallel_dispatch_required: {bad}')
\""

run_check 17 "V20b: W3 nodes all have parallel_dispatch_required=true" \
  "python3 -c \"
import json; g=json.load(open('$SKILL_DIR/graph.json'))
w3={'N-SCORER-TECHNICAL','N-SCORER-CREATIVE','N-SEMANTIC-CLUSTER','N-ANALYZER-TOPIC-SWITCH','N-ANALYZER-CORRECTIONS'}
bad=[n['id'] for n in g['nodes'] if n['id'] in w3 and not n.get('parallel_dispatch_required')]
print('PASS' if not bad else f'W3 nodes missing parallel_dispatch_required: {bad}')
\""

echo ""
echo "Smoke tests: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
