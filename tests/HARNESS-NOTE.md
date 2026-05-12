# HARNESS-NOTE.md — Test harness notes for adaptive-context-pruner v2.0.0

skill: adaptive-context-pruner
version: 2.0.0
node_count: 20
test_generated_by: GOTSCS v4.3.0 N-EMIT

---

## Test file inventory

| file | kind | description |
|---|---|---|
| tests/run-smoke-tests.sh | structural | S01-S15 automated structural checks; no live invocation needed |
| tests/run-regression-suite.sh | regression | R01-R09 v1→v2 regression battery; no live invocation needed |
| tests/behavioral/run-behavioral-tests.sh | behavioral | EC2/EC4/EC15 fixture checks + live invocation stubs |
| tests/behavioral/EC2-minimal-brief.txt | fixture | Minimal MANUAL mode invocation brief |
| tests/behavioral/EC4-contradictory-brief.txt | fixture | Brief with two contradictory constraints |
| tests/behavioral/EC15-refeed-brief.txt | fixture | Dummy SKILL.md stub with v1 frontmatter for ec-refeed testing |

---

## Running structural tests (no live session required)

```bash
# From the skill output directory:
bash tests/run-smoke-tests.sh
bash tests/run-regression-suite.sh
```

Both suites exit 0 on full pass, non-zero on any failure. Counters follow the A02 contract: `PASS=$((PASS+1))` and `FAIL=$((FAIL+1))` (safe under `set -e`).

The smoke test (S01-S15) covers:
- SKILL.md frontmatter (version 2.0.0, name, nodes=20, edges=39, waves=9)
- graph.json integrity (20 nodes, 39 edges, 9 waves, 3 spawns, back-edge caps, AP-V29 edges)
- hats.json validity
- All 20 canonical module files present
- Key v2 module assertions (R(msg) formula, 8-stream AND-join, 13-SC battery, new nodes)
- graph.schema.json validity

The regression suite (R01-R09) covers:
- R01: EC-FC04-1..5 external contracts (skill name, 11 output fields, back-edge caps, 15 signals, sinks)
- R02: N-ANALYZER-CORRECTIONS verbatim preservation (supersession_map, E-14, AP-V7, AP-V29)
- R03: Back-edge caps (E-20/E-21 cap=1) and AP-V29 provenance edges (E-05b, E-16b, E-14)
- R04: N-GENERATOR critical-path output ports (dependency_graph, critical_path_set, boundary_candidates)
- R05: N-CLASSIFIER domain set extension {research, planning}
- R06: N-VERIFIER SC-1..SC-13 battery completeness
- R07: N-AGGREGATION branch_budget_cap=8 and 5-tier priority merge
- R08: N-REFINER scope boundary (FileRef substitution, file_cache_map input)
- R09: graph.json validates against graph.schema.json (jsonschema if available; structural fallback otherwise)

---

## Running behavioral tests (live session required for full coverage)

```bash
# Fixture checks only (no live session):
bash tests/behavioral/run-behavioral-tests.sh

# Full behavioral coverage requires live skill invocation via Claude Code:
# 1. Install skill: cp -r . ~/.claude/skills/adaptive-context-pruner/
# 2. Start a Claude Code session and run /adaptive-context-pruner with each fixture content
# 3. Verify assertions marked [TODO] in run-behavioral-tests.sh
```

Behavioral test cases:

**EC2 (minimal brief, MANUAL mode):**
- Input: `tests/behavioral/EC2-minimal-brief.txt`
- Expected: Pipeline runs W1→W9; N-PERSISTER emits session_artifact; YAML output includes skill_name, version, verify_pass
- Key v2 check: N-TRIGGER-EVAL fires trigger_signal==true (manual mode bypasses threshold); no NO-OP terminal

**EC4 (contradictory brief):**
- Input: `tests/behavioral/EC4-contradictory-brief.txt`
- Expected: N-PREFLIGHT or N-ANALYZER-CORRECTIONS detects the `enable_semantic_clustering` contradiction; output contains conflict_annotations; AP-V7 fires
- Key v2 check: Contradiction not silently dropped; structured conflict_signal emitted

**EC15 (ec-refeed with v1 SKILL.md stub):**
- Input: `tests/behavioral/EC15-refeed-brief.txt`
- Expected: Skill detects ec-refeed context from SKILL.md frontmatter; v1 node names treated as context; output upgraded to v2.0.0 schema
- Key v2 check: EC-FC04 external contracts preserved during evolution from v1 stub

---

## Acceptance test cases (TC-01..TC-18)

v1 carry-forward tests (TC-01..TC-10) remain relevant but several require updating:
- TC-04 (N-GENERATOR output): add dependency_graph, critical_path_set assertions
- TC-06 (N-VERIFIER + N-RECOVERY): extend to SC-9..SC-13 scenarios
- TC-07 (N-AGGREGATION): update for 8-stream AND-join
- TC-08 (N-REFINER): scope is compression-recommendation-only; update eviction assertions to target N-TIER-MANAGER
- TC-09 (N-FORMATTER): add auto_prune_triggered + pruning_phase YAML field assertions

New v2 tests (TC-11..TC-18):
- TC-11: auto-mode input acceptance (N-INGEST dual-path)
- TC-12: dual-mode preflight routing (N-PREFLIGHT mode branch)
- TC-13: trigger threshold gating (N-TRIGGER-EVAL; NO-OP terminal for auto+no-trigger)
- TC-14: SHA-256 FileRef substitution (N-FILE-CACHE; >50% token reduction target)
- TC-15: N-TIER-MANAGER spawn behavior (4-phase Algorithm A; critical-path exclusion from eviction)
- TC-16: TierConfig YAML compliance (hot/warm/cold/meta thresholds; no hardcoded values)
- TC-17: N-CONTINUITY-MARKER fires only when auto_prune_triggered==true (AP-V37)
- TC-18: R(msg) formula applied uniformly (0.3×recency+0.3×semantic_similarity+0.2×graph_centrality+0.2×user_importance)

---

## Known test gaps (see REGRESSION.md FC-08 compliance gate)

- E-22 recontract: no automated check that E-22 source==N-TIER-MANAGER (high priority)
- N-REFINER scope boundary: no automated check that N-REFINER.md does NOT contain eviction language
- E-17b long-carry presence: no automated check (low priority)
- N-TIER-MANAGER AP-3 protected_node_set exclusion: requires runtime execution (TC-15 behavioral only)
