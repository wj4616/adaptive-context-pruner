# REGRESSION.md — Regression and acceptance test manifest

evolution_mode: evolve
gotscs_version: 4.3.0
timestamp: 2026-05-12T00:00:00Z
evolved_from: adaptive-context-pruner v1.0.0
evolved_to: adaptive-context-pruner v2.0.0

This file documents regression targets derived from the preservation_map and divergence_map in FUSION.md. It is documentation-only; executable tests live in tests/.

---

## Preserved-functionality regression tests

One entry per item in the preservation_map. These MUST NOT regress across v1→v2.

### Preserved nodes (1)

| item_id | kind | original_signature | regression_test_target | test_status |
|---|---|---|---|---|
| N-ANALYZER-CORRECTIONS | node | ANALYZER W3 inline; hat=analyzer; tier=model-medium; inputs: turn_records:list, graph_structure:object; outputs: supersession_map:object; AP-V7 no-silent-deferral; latest-explicit-instruction-wins canonicalization; AP-V29 declared edge E-14 | SKILL.md §N-ANALYZER-CORRECTIONS module verbatim-preserved; supersession_map present in output; E-14 declared in graph.json | TC-01 (preserved) |

### Preserved edges (18)

| item_id | kind | original_signature | regression_test_target | test_status |
|---|---|---|---|---|
| E-01 | edge | N-INGEST→N-PREFLIGHT required; ingest_record; null gate | graph.json edge E-01: source=N-INGEST target=N-PREFLIGHT type=required | S02 (graph structure) |
| E-02 | edge | N-PREFLIGHT→REFUSE_OUTPUT terminal; refuse_signal; preflight_pass==false | graph.json edge E-02: source=N-PREFLIGHT target=REFUSE_OUTPUT; REFUSE_OUTPUT in sinks | S02, TC-02 |
| E-05b | edge | N-INGEST→N-AGGREGATION required; ingest_record; AP-V29 spawn provenance | graph.json edge E-05b: source=N-INGEST target=N-AGGREGATION; AP-V29 note present | TC-03 |
| E-06 | edge | N-GENERATOR→N-SCORER-TECHNICAL required; graph_structure | graph.json edge E-06: source=N-GENERATOR target=N-SCORER-TECHNICAL | S02 |
| E-07 | edge | N-GENERATOR→N-SCORER-CREATIVE required; graph_structure | graph.json edge E-07: source=N-GENERATOR target=N-SCORER-CREATIVE | S02 |
| E-08 | edge | N-GENERATOR→N-ANALYZER-TOPIC-SWITCH required; graph_structure | graph.json edge E-08: source=N-GENERATOR target=N-ANALYZER-TOPIC-SWITCH | S02 |
| E-08b | edge | N-GENERATOR→N-ANALYZER-CORRECTIONS required; graph_structure | graph.json edge E-08b: source=N-GENERATOR target=N-ANALYZER-CORRECTIONS | S02 |
| E-09 | edge | N-CLASSIFIER→N-SCORER-TECHNICAL forward-conditional; domain_gate | graph.json edge E-09: type=forward-conditional; condition=domain_gate | S02 |
| E-10 | edge | N-CLASSIFIER→N-SCORER-CREATIVE forward-conditional; domain_gate | graph.json edge E-10: type=forward-conditional; condition=domain_gate | S02 |
| E-11 | edge | N-SCORER-TECHNICAL→N-AGGREGATION required; technical_scores; null-signal tolerated | graph.json edge E-11: source=N-SCORER-TECHNICAL target=N-AGGREGATION; null_tolerated=true | S02 |
| E-12 | edge | N-SCORER-CREATIVE→N-AGGREGATION required; creative_scores; null-signal tolerated | graph.json edge E-12: source=N-SCORER-CREATIVE target=N-AGGREGATION; null_tolerated=true | S02 |
| E-13 | edge | N-ANALYZER-TOPIC-SWITCH→N-AGGREGATION required; topic_signal | graph.json edge E-13: source=N-ANALYZER-TOPIC-SWITCH target=N-AGGREGATION | S02 |
| E-14 | edge | N-ANALYZER-CORRECTIONS→N-AGGREGATION required; supersession_map; AP-V29 | graph.json edge E-14: source=N-ANALYZER-CORRECTIONS target=N-AGGREGATION; AP-V29 note present | S02, TC-01 |
| E-15 | edge | N-FILTER→N-AGGREGATION required; protected_node_set | graph.json edge E-15: source=N-FILTER target=N-AGGREGATION | S02 |
| E-16 | edge | N-AGGREGATION→N-REFINER required; pruning_plan | graph.json edge E-16: source=N-AGGREGATION target=N-REFINER | S02 |
| E-16b | edge | N-INGEST→N-REFINER required; ingest_record; AP-V29 spawn provenance | graph.json edge E-16b: source=N-INGEST target=N-REFINER; AP-V29 note present | TC-03 |
| E-20 | edge | N-VERIFIER→N-RECOVERY back-edge; violation_signal; verify_pass==false AND retry_count_artifact<1; cap=1 | graph.json edge E-20: type=back-edge; cap=1; condition=verify_pass==false | S08, TC-06 |
| E-21 | edge | N-RECOVERY→N-REFINER back-edge; recovery_overrides; E-20 fired; cap=1 | graph.json edge E-21: type=back-edge; cap=1; condition=E-20 fired | S08, TC-06 |

### Preserved constraints and external contracts (5)

| item_id | kind | authority | external_contract_locked | regression_test_target |
|---|---|---|---|---|
| EC-FC04-1 / [SKILL-NAME] | inventory | P3+P1 confirm | true | SKILL.md frontmatter `name: adaptive-context-pruner`; graph.json metadata.skill_name == "adaptive-context-pruner" |
| EC-FC04-2 / output YAML fields (original 11) | inventory | P3 original | true | SKILL.md output schema includes all 11 v1 fields; 2 additive fields (auto_prune_triggered, pruning_phase) do not remove any v1 field |
| EC-FC04-3 / HC-02 caps | inventory | P3+P4 | true | back-edge cap=1 present on E-20 and E-21 in graph.json |
| EC-FC04-4 / signal names (15 v1 names) | inventory | P3 original | true | All 15 v1 signal names present in modules/ — none renamed; 8 new signals are additive |
| EC-FC04-5 / sinks [REFUSE_OUTPUT, SKILL_OUTPUT] | inventory | P3 original | true | graph.json metadata.sinks includes both REFUSE_OUTPUT and SKILL_OUTPUT; NO-OP-TERMINAL is additive |

---

## Diverged-functionality acceptance tests

One entry per row in the divergence_map. These require new acceptance criteria.

### Node divergences

| item_id | origin | authority | regression_risk | acceptance_criterion | risk_acknowledgment |
|---|---|---|---|---|---|
| N-INGEST | upgrade | P1 brief | low | v2 N-INGEST module: dual input shape documented; auto-mode input {turn_delta, current_token_count, current_graph_state, pending_tool_calls} accepted; manual-mode input {conversation_history, session_metadata} accepted | TC-11: auto-mode input acceptance |
| N-PREFLIGHT | upgrade | P1 brief | medium | v2 N-PREFLIGHT module: mode field detection documented; two validation branches explicit; routes to N-TRIGGER-EVAL not N-GENERATOR | TC-12: dual-mode preflight routing |
| N-TRIGGER-EVAL | add | P1 brief | low | N-TRIGGER-EVAL present in graph.json nodes; module N-TRIGGER-EVAL.md present; emits trigger_signal bool; E-02b (NO-OP terminal) declared | TC-13: trigger threshold gating |
| N-GENERATOR | upgrade | P1 brief | medium | v2 N-GENERATOR module: dependency_graph output port present; critical_path_set in outputs; boundary_candidates in outputs; E-08d declared in graph.json | TC-04 (upgraded): dependency_graph output |
| N-CLASSIFIER | upgrade | P1 brief | low | v2 N-CLASSIFIER module: domain set includes {research, planning} in addition to v1 domains | TC-05 (upgraded): domain set |
| N-FILTER | upgrade | P1 brief | low | v2 N-FILTER module: tiered_node_set_hint in outputs; avoid_cache_hint in outputs; E-15b and E-15c declared in graph.json | S06 |
| N-FILE-CACHE | add | P1 brief | low | N-FILE-CACHE present in graph.json nodes; module N-FILE-CACHE.md present; file_cache_map in outputs; SHA-256 FileRef substitution documented | S12, TC-14 |
| N-SCORER-TECHNICAL | upgrade | P1 brief | low | v2 N-SCORER-TECHNICAL module: R(msg) formula explicit (0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance); graph_centrality in formula inputs | S06 |
| N-SCORER-CREATIVE | upgrade | P1 brief | low | v2 N-SCORER-CREATIVE module: R(msg) formula explicit (same weights as N-SCORER-TECHNICAL) | S06 |
| N-SEMANTIC-CLUSTER | add | P1 brief | low | N-SEMANTIC-CLUSTER present in graph.json nodes; module N-SEMANTIC-CLUSTER.md present; cluster_summaries in outputs; conditional on enable_semantic_clustering | S12 |
| N-ANALYZER-TOPIC-SWITCH | upgrade | P1 brief | low | v2 N-ANALYZER-TOPIC-SWITCH module: episode_boundaries output port documented; E-13b (→N-SEMANTIC-CLUSTER) declared in graph.json | S06 |
| N-AGGREGATION | upgrade | P1 brief | medium | v2 N-AGGREGATION module: 8-stream AND-join documented; branch_budget_cap=8; token_budget=8000; 5-tier priority merge described | TC-07 (upgraded): 8-stream AND-join |
| N-REFINER | upgrade | P1 brief | medium | v2 N-REFINER module: scope = compression recommendation only (not eviction actuator); file_cache_map accepted in inputs; FileRef substitution documented; N-TIER-MANAGER handles eviction | TC-08 (upgraded): scope boundary |
| N-VERIFIER | upgrade | P1 brief | low | v2 N-VERIFIER module: 13-SC battery documented; SC-9..SC-13 present; token_budget=4000 | S09, TC-06 (upgraded) |
| N-RECOVERY | upgrade | P1 brief | low | v2 N-RECOVERY module: SC-9..SC-13 override procedures present | TC-06 (upgraded) |
| N-TIER-MANAGER | add | P1 brief | low | N-TIER-MANAGER present in graph.json nodes and as static spawn; module N-TIER-MANAGER.md present; 4-phase Algorithm A eviction documented; AP-3 policy includes protected_node_set exclusion; critical-path nodes never evicted; wave=7 | S12, TC-15, TC-16 |
| N-FORMATTER | upgrade + resequence | P1 brief | medium | v2 N-FORMATTER module: wave=8 (not W7); 4-input AND-join; auto_prune_triggered and pruning_phase in YAML output; 6th conditional section documented; tier_state input (E-17b) accepted | TC-09 (upgraded): YAML fields |
| N-CONTINUITY-MARKER | add | P1 brief | low | N-CONTINUITY-MARKER present in graph.json nodes; module N-CONTINUITY-MARKER.md present; forward-conditional on auto_prune_triggered==true; wave=8 | S12, TC-17 |
| N-PERSISTER | resequence | P1 brief | low | N-PERSISTER wave=9 in graph.json; protocol unchanged from v1 | S02 |

### Edge divergences (recontracts)

| item_id | origin | authority | regression_risk | acceptance_criterion | risk_acknowledgment |
|---|---|---|---|---|---|
| E-03 (v2) | recontract | P1 brief | low | graph.json E-03: source=N-PREFLIGHT target=N-TRIGGER-EVAL (not N-GENERATOR) | n/a |
| E-04 (v2) | recontract | P1 brief | low | graph.json E-04: source=N-TRIGGER-EVAL target=N-CLASSIFIER (not N-PREFLIGHT) | n/a |
| E-05 (v2) | recontract | P1 brief | low | graph.json E-05: source=N-TRIGGER-EVAL target=N-FILTER (not N-PREFLIGHT) | n/a |
| E-17 (v2) | recontract | P1 brief | low | graph.json E-17: source=N-FILTER target=N-FORMATTER; wave long-carry now W2→W8 | n/a |
| E-18 (v2) | recontract | P1 brief | medium | graph.json E-18: source=N-REFINER target=N-VERIFIER (not N-FORMATTER); N-FORMATTER is downstream of N-TIER-MANAGER | RISK-01 mitigation: SC-9 checks N-TIER-MANAGER respects protected_node_set |
| E-19 (v2) | recontract | P1 brief | medium | graph.json E-19: source=N-VERIFIER target=N-TIER-MANAGER gate-open; condition=verify_pass==true | RISK-02 mitigation: W7 mutual-exclusion (N-RECOVERY vs N-TIER-MANAGER) enforced by GoT controller |
| E-22 (v2) | recontract | P1 brief | medium | graph.json E-22: source=N-TIER-MANAGER target=N-FORMATTER type=required; signal=tier_state_final (NOT the former N-FORMATTER→N-PERSISTER edge) | RISK-05: any tooling hard-coding E-22 as render→persist edge must update; E-24b is the new render→persist edge |
| E-23 (v2) | recontract | P1 brief | low | graph.json E-23: source=N-FORMATTER target=N-CONTINUITY-MARKER type=forward-conditional; condition=auto_prune_triggered==true (NOT the former terminal) | n/a |

### Inventory divergences

| item_id | origin | authority | regression_risk | acceptance_criterion | risk_acknowledgment |
|---|---|---|---|---|---|
| spawn_count | upgrade | P1 brief | medium | graph.json metadata.spawn_node_count == 3; N-AGGREGATION, N-REFINER, N-TIER-MANAGER all listed as static spawns | TC-07, TC-15 |
| wave_count | upgrade | P1 brief | low | graph.json metadata.total_waves == 9 | S02 |
| SC_battery | upgrade | P1 brief | medium | SKILL.md and N-VERIFIER.md document exactly 13 SC checks (SC-1..SC-13); SC-9..SC-13 definitions present | S09, TC-06 (upgraded) |
| R(msg) formula | upgrade | P1 brief | low | N-SCORER-TECHNICAL.md and N-SCORER-CREATIVE.md both contain explicit R(msg)=0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance | TC-18 |

---

## High-risk divergence summary

Rows from divergence_map where origin ∈ {replaced, removed, recontract} AND regression_risk ∈ {medium, high}.

| item_id | origin | regression_risk | primary_risk | required_test |
|---|---|---|---|---|
| N-PREFLIGHT | upgrade | medium | Dual-mode routing could silently fall through to wrong branch | TC-12 |
| N-GENERATOR | upgrade | medium | dependency_graph output absent → N-AGGREGATION 8-stream AND-join receives null on E-08d | TC-04 (upgraded) |
| N-AGGREGATION | upgrade | medium | 8-stream AND-join: 2 conditional null-signal streams must not stall AND-join | TC-07 (upgraded) |
| N-REFINER | upgrade | medium | Old N-REFINER eviction callers expect N-REFINER to execute eviction; must be re-pointed to N-TIER-MANAGER | TC-08 (upgraded) |
| N-FORMATTER | upgrade + resequence | medium | Wave move W7→W8 and new 4th input (tier_state E-17b): if E-17b absent, YAML fields auto_prune_triggered/pruning_phase will be null | TC-09 (upgraded) |
| E-18 (v2) | recontract | medium | v1 callers expecting N-REFINER→N-FORMATTER direct path will see routing mismatch | RISK-01 mitigation in place (SC-9) |
| E-19 (v2) | recontract | medium | v1 callers expecting N-VERIFIER→N-FORMATTER gate will see empty formatter input on verify_pass | RISK-02 mitigation in place (W7 mutual-exclusion) |
| E-22 (v2) | recontract | medium | ID E-22 semantics change: old render→persist; new tier-state→formatter. Hard-coded references break. | RISK-05 — update all tooling referencing E-22 |
| spawn_count | upgrade | medium | 3rd spawn N-TIER-MANAGER not present in v1 orchestration harnesses | TC-15 |
| SC_battery | upgrade | medium | 5 new SC checks unevaluated in v1 test suites | S09 (upgraded), TC-06 (upgraded) |

---

## FC-08 compliance gate

FC-08 requires every redesign to have a corresponding regression test in the smoke-test battery.

### Covered by run-smoke-tests.sh

| item_id | smoke_check | status |
|---|---|---|
| N-ANALYZER-CORRECTIONS (preserved) | S02 (graph structure check) | COVERED |
| E-14 (AP-V29 preserved) | S02, S03 (AP-V29 edge declarations) | COVERED |
| E-20, E-21 back-edges | S08 (back-edge cap check) | COVERED |
| N-VERIFIER 13-SC | S09 (SC battery count check) | COVERED |
| N-TIER-MANAGER new spawn | S12 (new-node presence check) | COVERED |
| N-FILE-CACHE new node | S12 | COVERED |
| N-SEMANTIC-CLUSTER new node | S12 | COVERED |
| N-CONTINUITY-MARKER new node | S12 | COVERED |
| wave_count == 9 | S02 (metadata check) | COVERED |
| spawn_count == 3 | S02 (metadata check) | COVERED |
| EC-FC04-1 skill name | S01 (SKILL.md frontmatter) | COVERED |
| EC-FC04-5 sinks | S04 (sinks check) | COVERED |
| R(msg) formula | S06 (module keyword check) | COVERED |
| SKILL.md frontmatter version | S01 | COVERED |

### TODO: tighten after first manual run

| item_id | missing_assertion | priority |
|---|---|---|
| E-22 recontract semantics | No automated check that E-22 source==N-TIER-MANAGER (not N-FORMATTER); graph.json parse required | HIGH |
| N-REFINER scope boundary | No automated check that N-REFINER.md does NOT contain eviction language | MEDIUM |
| N-PREFLIGHT dual-mode routing | Behavioral test EC4 covers contradictory brief but not explicit mode-routing path | MEDIUM |
| E-17b long-carry presence | No automated check that E-17b declared in graph.json | LOW |
| N-TIER-MANAGER AP-3 protected_node_set exclusion | Requires runtime execution; TC-15 behavioral only | LOW |
