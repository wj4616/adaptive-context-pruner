# FUSION.md — Fusion audit trail

This file documents how this skill was synthesized from multiple context sources via GOTSCS evolve mode. It is documentation-only; the runtime skill behavior is fully determined by SKILL.md, graph.json, and modules/. To re-derive the skill from scratch, see RATIONALE.md.

evolution_mode: evolve
gotscs_version: 4.3.0
timestamp: 2026-05-12T00:00:00Z

## fusion_sources

| path | detected_type | confidence | role | override_applied | auto_detect_uncertain |
|---|---|---|---|---|---|
| /home/myuser/docs/gotscs-output/adaptive-context-pruner-v2-20260512-094549/skill_concept_brief.txt | design_brief | 1.00 | optimization_objective | false | false |
| /home/myuser/.claude/skills/adaptive-context-pruner/ | skill_executable | 0.98 | reference | false | false |

**Detection rationale:**
- `skill_concept_brief.txt`: Always classified as `design_brief` at confidence 1.00 per auto-detection protocol.
- `adaptive-context-pruner/`: Contains `SKILL.md`, `graph.json`, and `modules/` directory — all three presence signals fire; `skill_executable` confidence 0.98. No `--context-type` override supplied.
- P2 (`--context-spec`): Not supplied. No spec_enhancement source in this run.

## precedence_stack

P1 (highest) — design_brief: skill_concept_brief.txt (adaptive-context-pruner v2.0.0 briefing). Authority: optimization objective; wins on all design questions except HC-02/03/04 hard constraints.

P2 — spec_enhancement: NOT APPLICABLE (no --context-spec supplied). Authority: N/A.

P3 — skill_executable: /home/myuser/.claude/skills/adaptive-context-pruner/ (v1.0.0). Authority: reference implementation; wins when brief is silent on a specific design question and no spec exists.

P4 — GOTSCS defaults / H.1-H.9 schema. Authority: baseline fallback only.

## delta_matrix

### Node-level delta matrix (15 v1 nodes + 5 net-new + name reconciliations)

#### Name reconciliation note (P1 authority — CRITICAL)

| N-CONTEXT-ANALYZE proposed name | Brief §5.2 canonical name | Resolution | Conflict_ID |
|---|---|---|---|
| N-AUTO-ROUTER | N-TRIGGER-EVAL | Brief wins (P1). Use N-TRIGGER-EVAL throughout. | CN-01 |
| N-CRITICAL-PATH | (no separate node — brief §4.2 extends N-GENERATOR for dependency DAG; critical-path marking is a N-GENERATOR output port, not a separate node) | Brief wins (P1). No standalone N-CRITICAL-PATH node. | CN-02 |
| N-DELTA-CACHE | N-FILE-CACHE | Brief wins (P1). Use N-FILE-CACHE throughout. | CN-03 |
| N-TIER-MANAGER | N-TIER-MANAGER | Names agree. No conflict. | — |
| N-SEMANTIC-CLUSTER | N-SEMANTIC-CLUSTER | Names agree. No conflict. | — |

**Impact on node arithmetic:** N-CONTEXT-ANALYZE proposed 5 new nodes; after P1 reconciliation the count remains 5 net-new (N-TRIGGER-EVAL, N-FILE-CACHE, N-SEMANTIC-CLUSTER, N-TIER-MANAGER, N-CONTINUITY-MARKER). N-CRITICAL-PATH does NOT exist as a node; its function is absorbed into N-GENERATOR (upgrade action). This preserves the 20-node budget exactly.

| item_id | item_kind | original_skill | spec/brief | resolved_action | authority | rationale |
|---|---|---|---|---|---|---|
| N-INGEST | node | preserve: INGEST W1 inline; emits ingest_record, turn_records, corpus_stats | Brief §3.1 + §2.2: adds auto-mode input shape {turn_delta, current_token_count, current_graph_state, pending_tool_calls} | upgrade | P1 brief | Brief §2.2 adds new auto-mode input shape. N-INGEST must handle both input shapes. Node ID preserved; input port set expands. |
| N-PREFLIGHT | node | preserve: PREFLIGHT W1 inline; fail-fast validation | Brief §2.1: must branch on `mode` field; dual-mode routing | upgrade | P1 brief | Dual-mode demands [DUAL-INVOCATION-MODE] constraint 27; mode detection and validation-per-mode must live at N-PREFLIGHT entry. |
| N-TRIGGER-EVAL | node | absent | Brief §4.1 / §5.2: canonical new W1 node; evaluate trigger thresholds | add | P1 brief | Net-new node mandated by [DUAL-INVOCATION-MODE] + [AUTO-PRUNE-THRESHOLDS]. P1-canonical name: N-TRIGGER-EVAL (not N-AUTO-ROUTER). |
| N-GENERATOR | node | GENERATOR W2 inline; turn-graph with sequential/reference/correction edges | Brief §4.2: extend to full dependency DAG; absorb N-CRITICAL-PATH per OPT-01/FD-02 | upgrade | P1 brief | P1 mandates [DEPENDENCY-GRAPH-CRITICAL-PATH] constraint 30. Critical-path marking added to N-GENERATOR's output. dependency_graph is new output port. |
| N-CLASSIFIER | node | CLASSIFIER W2 inline; domain_gate, retention_ruleset | Brief §3.1 SC-8: adds research + planning to valid domain set | upgrade | P1 brief | Brief extends domain set: domain ∈ {technical-debugging, creative-brainstorming, auto-detect, research, planning}. |
| N-FILTER | node | FILTER W2 inline; emits protected_node_set | Brief §4.2: add tiered_node_set_hint; new edges E-15b, E-15c | upgrade | P1 brief | N-FILTER adds tiered_node_set_hint (advisory for N-TIER-MANAGER). New signals: tiered_node_set_hint, avoid_cache_hint. |
| N-FILE-CACHE | node | absent | Brief §4.2 / §5.2: canonical new W2 inline node; delta/diff file caching | add | P1 brief | Net-new; P1-canonical name N-FILE-CACHE (N-DELTA-CACHE name from N-CONTEXT-ANALYZE is superseded). |
| N-SCORER-TECHNICAL | node | SCORER W3 inline; technical scoring; technical_scores | Brief §1.1: R(msg)=0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance | upgrade | P1 brief | Brief §1.1 specifies explicit scoring formula replacing v1 ad-hoc weights. |
| N-SCORER-CREATIVE | node | SCORER W3 inline; creative scoring; creative_scores | Same as N-SCORER-TECHNICAL (formula upgrade) | upgrade | P1 brief | Same rationale as N-SCORER-TECHNICAL. |
| N-SEMANTIC-CLUSTER | node | absent | Brief §4.2 / §5.2: canonical new W3 inline node; episode-level clustering | add | P1 brief | Net-new; [SEMANTIC-CLUSTERING] constraint 31. |
| N-ANALYZER-TOPIC-SWITCH | node | ANALYZER W3 inline; topic_signal, topic_switch_map | Brief §3.1: add episode_boundaries output port feeding N-SEMANTIC-CLUSTER | upgrade | P1 brief | New output port: episode_boundaries (feeds E-08c → N-SEMANTIC-CLUSTER). |
| N-ANALYZER-CORRECTIONS | node | ANALYZER W3 inline; supersession_map | Brief §3.1: "Preserve — unchanged; still flows via declared edge E-14 to aggregation." | preserve | P3 original | Brief confirms no change. v1 protocol carries forward verbatim. |
| N-AGGREGATION | node | AGGREGATION W4 spawn; AND-join 6 streams; pruning_plan | Brief §4.2: expand AND-join to 8 streams; 5-tier priority merge | upgrade | P1 brief | AND-join grows from 6 streams to 8 streams. branch_budget_cap rises 5→8. token_budget: 6000→8000. |
| N-REFINER | node | REFINER W5 spawn; pruning_plan + ingest_record + recovery_overrides | Brief §4.2: compression-recommendation-only; add file_cache_map input; FileRef substitution | upgrade | P1 brief | N-REFINER role clarification: scoring refinement and compression recommendation only. Eviction is N-TIER-MANAGER. |
| N-VERIFIER | node | VERIFIER W6 inline; 8-SC battery | Brief §4.2 / [VERIFIER-13-SC]: extend to 13-SC battery | upgrade | P1 brief | [VERIFIER-13-SC] is explicit P1 mandate. token_budget: 3000→4000. |
| N-RECOVERY | node | RECOVERY W7 conditional inline; recovery_overrides | Brief §4.2: add SC-9..SC-13 override procedures | upgrade | P1 brief | Protocol section expands with SC-9..SC-13 override procedures. |
| N-TIER-MANAGER | node | absent | Brief §4.2 / §5.2: canonical new W7 spawn node; 4-phase eviction; AP-3 aggregation carrier | add | P1 brief | Net-new; [HOT-WARM-COLD-TIERS] + [TIER-CONFIG-YAML]. Wave 7 placement is P1-authoritative (W2 placement from N-CONTEXT-ANALYZE overridden). |
| N-FORMATTER | node | FORMATTER W7 inline; 5-section body + YAML frontmatter | Brief §3.1: add auto_prune_triggered, pruning_phase; resequence to W8 | upgrade | P1 brief | Wave resequenced: v1 W7 → v2 W8. New frontmatter fields. Input ports expand: tier_state (E-17b long-carry from N-TIER-MANAGER W7→W8). |
| N-CONTINUITY-MARKER | node | absent | Brief §4.1 / §5.2: canonical new W8 conditional inline node; forward-conditional on auto_prune_triggered==true | add | P1 brief | Net-new; [CONTINUITY-MARKER] constraint 33. P1 canonical: standalone node (not inlined into N-FORMATTER). |
| N-PERSISTER | node | PERSISTER W8 no-llm inline; session_artifact terminal | v1 W8; v2 brief §4.1 places it at W9. Wave resequenced. Protocol unchanged. | resequence | P1 brief | Wave moves W8→W9 to accommodate N-FORMATTER (W8) + N-CONTINUITY-MARKER (W8 conditional). |

### Edge-level delta matrix (26 v1 edges + net-new v2 edges)

| item_id | original_skill | brief | resolved_action | authority | rationale |
|---|---|---|---|---|---|
| E-01 | N-INGEST→N-PREFLIGHT required; ingest_record | Brief silent; v1 carries forward | preserve | P3 original | Core sequential edge unchanged. |
| E-02 | N-PREFLIGHT→REFUSE_OUTPUT terminal; refuse_signal | Brief silent | preserve | P3 original | Fail-fast terminal preserved. |
| E-02b | absent | Brief §4.1: N-TRIGGER-EVAL→NO-OP terminal; forward-conditional; auto mode, trigger==false | add | P1 brief | New NO-OP path for auto mode with no trigger. |
| E-03 | N-PREFLIGHT→N-GENERATOR gate-open | v2: N-PREFLIGHT→N-TRIGGER-EVAL; N-TRIGGER-EVAL is new W1 gate | recontract | P1 brief | E-03 target changes from N-GENERATOR to N-TRIGGER-EVAL. |
| E-04 | N-PREFLIGHT→N-CLASSIFIER gate-open | v2: now N-TRIGGER-EVAL→N-CLASSIFIER | recontract | P1 brief | Source changes to N-TRIGGER-EVAL (brief §4.1 E-04). |
| E-05 | N-PREFLIGHT→N-FILTER gate-open | v2: now N-TRIGGER-EVAL→N-FILTER | recontract | P1 brief | Source changes to N-TRIGGER-EVAL (brief §4.1 E-05). |
| E-05b | N-INGEST→N-AGGREGATION required; ingest_record (AP-V29) | Brief silent; carries forward | preserve | P3 original | AP-V29 spawn-provenance; preserved. |
| E-05c | absent | Brief §4.1: N-TRIGGER-EVAL→N-GENERATOR gate-open | add | P1 brief | New fan-out from N-TRIGGER-EVAL to N-GENERATOR. |
| E-06 | N-GENERATOR→N-SCORER-TECHNICAL required; graph_structure | Brief silent; carries forward | preserve | P3 original | graph_structure broadcast preserved. |
| E-07 | N-GENERATOR→N-SCORER-CREATIVE required; graph_structure | Brief silent; carries forward | preserve | P3 original | Same as E-06. |
| E-08 | N-GENERATOR→N-ANALYZER-TOPIC-SWITCH required; graph_structure | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-08b | N-GENERATOR→N-ANALYZER-CORRECTIONS required; graph_structure | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-08c | absent | Brief §4.1 E-08: N-GENERATOR→N-SEMANTIC-CLUSTER optional; enable_semantic_clustering==true | add | P1 brief | New optional edge for semantic clustering. |
| E-08d | absent | (new) N-GENERATOR→N-AGGREGATION required; dependency_graph | add | P1 brief | dependency_graph must reach N-AGGREGATION for critical-path-aware pruning_plan. |
| E-09 | N-CLASSIFIER→N-SCORER-TECHNICAL forward-conditional; domain_gate | Brief silent; carries forward | preserve | P3 original | Forward-conditional domain gating preserved. |
| E-10 | N-CLASSIFIER→N-SCORER-CREATIVE forward-conditional; domain_gate | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-11 | N-SCORER-TECHNICAL→N-AGGREGATION required; technical_scores | Brief silent; carries forward | preserve | P3 original | Null-signal accommodation preserved. |
| E-12 | N-SCORER-CREATIVE→N-AGGREGATION required; creative_scores | Brief silent; carries forward | preserve | P3 original | Null-signal accommodation preserved. |
| E-13 | N-ANALYZER-TOPIC-SWITCH→N-AGGREGATION required; topic_signal | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-13b | absent | (new) N-ANALYZER-TOPIC-SWITCH→N-SEMANTIC-CLUSTER; episode_boundaries | add | P1 brief | New output port episode_boundaries feeds N-SEMANTIC-CLUSTER. |
| E-14 | N-ANALYZER-CORRECTIONS→N-AGGREGATION required; supersession_map (AP-V29) | Brief §3.1 preserves declared edge | preserve | P3 original | AP-V29 critical; preserved verbatim. |
| E-14b | absent | (new) N-SEMANTIC-CLUSTER→N-AGGREGATION required; cluster_summaries | add | P1 brief | New stream into expanded 8-stream N-AGGREGATION AND-join. |
| E-15 | N-FILTER→N-AGGREGATION required; protected_node_set | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-15b | absent | Brief §4.1 E-15b: N-FILTER→N-FILE-CACHE; avoid_cache_hint | add | P1 brief | New edge marking always-retain files to avoid redundant caching. |
| E-15c | absent | Brief §4.1 E-15c: N-FILE-CACHE→N-REFINER optional; file_cache_map | add | P1 brief | Delta-cache map for FileRef decisions at N-REFINER. |
| E-16 | N-AGGREGATION→N-REFINER required; pruning_plan | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-16b | N-INGEST→N-REFINER required; ingest_record (AP-V29) | Brief silent; carries forward | preserve | P3 original | Preserved. |
| E-17 | N-FILTER→N-FORMATTER required; protected_node_set long-carry W2→W7 | v2: N-FORMATTER is now W8; long-carry destination shifts W7→W8 | recontract | P1 brief | E-17 wave destination updates W7→W8; same signal, same function. |
| E-17b | absent | Brief §4.1 E-17b: N-TIER-MANAGER→N-FORMATTER long-carry; tier_state W7→W8 | add | P1 brief | New long-carry for tier_state from N-TIER-MANAGER to N-FORMATTER. |
| E-18 | N-REFINER→N-FORMATTER required; refined_context | Brief: N-REFINER→N-VERIFIER now; E-18 retarget | recontract | P1 brief | v2 pipeline: N-REFINER (W5) → N-VERIFIER (W6) via E-18. N-FORMATTER is downstream of N-TIER-MANAGER. |
| E-19 | N-VERIFIER→N-FORMATTER gate-open; verify_pass==true | v2: N-VERIFIER→N-TIER-MANAGER; verify_pass gates tier assignment | recontract | P1 brief | Brief §4.1 E-19: N-VERIFIER→N-TIER-MANAGER gate-open. |
| E-19b | absent | Brief §4.1 E-19b: N-RECOVERY→N-TIER-MANAGER gate-open; after re-fire verify_pass==true | add | P1 brief | Recovery success path to N-TIER-MANAGER. |
| E-20 | N-VERIFIER→N-RECOVERY back-edge; verify_pass==false; cap=1 | Brief §3.1: "Preserve — same caps" | preserve | P3 original | Back-edge preserved. Cap=1 standard. |
| E-21 | N-RECOVERY→N-REFINER back-edge; recovery_overrides; cap=1 | Brief §3.1: "Preserve — same caps" | preserve | P3 original | Back-edge preserved. Cap=1 standard. |
| E-22 | N-FORMATTER→N-PERSISTER required; rendered_output | v2: E-22 ID repurposed; now N-TIER-MANAGER→N-FORMATTER required; tier_state_final | recontract | P1 brief | E-22 becomes N-TIER-MANAGER→N-FORMATTER per brief §4.1 E-22. |
| E-23 | N-PERSISTER→SKILL_OUTPUT terminal; session_artifact | v2: E-23 ID repurposed; now N-FORMATTER→N-CONTINUITY-MARKER forward-conditional | recontract | P1 brief | ID renaming per brief canonical edge IDs. E-23 repurposed; terminal moves to E-25. |
| E-24 | absent | Brief §4.1 E-24: N-CONTINUITY-MARKER→N-PERSISTER required | add | P1 brief | Post-continuity-marker path to persister. |
| E-24b | absent | (new) N-FORMATTER→N-PERSISTER required; rendered_output; direct when auto_prune_triggered==false | add | P1 brief | Direct terminal path when N-CONTINUITY-MARKER not triggered. |
| E-25 | absent | Brief §4.1 E-25: N-PERSISTER→SKILL_OUTPUT terminal | add | P1 brief | New terminal edge ID. |

## preservation_map

### Nodes preserved verbatim (1)

| item_id | kind | authority | original_signature |
|---|---|---|---|
| N-ANALYZER-CORRECTIONS | node | P3 original | ANALYZER W3 inline; hat=analyzer; tier=model-medium; inputs: turn_records:list, graph_structure:object; outputs: supersession_map:object; emits: supersession_map, conflict_entry; AP-V7 no-silent-deferral; latest-explicit-instruction-wins canonicalization; AP-V29 declared edge E-14. Brief §3.1: "Preserve — unchanged; still flows via declared edge E-14 to aggregation." |

### Edges preserved verbatim (16)

| item_id | kind | authority | original_signature |
|---|---|---|---|
| E-01 | edge | P3 original | N-INGEST→N-PREFLIGHT required; ingest_record; null gate |
| E-02 | edge | P3 original | N-PREFLIGHT→REFUSE_OUTPUT terminal; refuse_signal; preflight_pass==false |
| E-05b | edge | P3 original | N-INGEST→N-AGGREGATION required; ingest_record; AP-V29 spawn provenance |
| E-06 | edge | P3 original | N-GENERATOR→N-SCORER-TECHNICAL required; graph_structure |
| E-07 | edge | P3 original | N-GENERATOR→N-SCORER-CREATIVE required; graph_structure |
| E-08 | edge | P3 original | N-GENERATOR→N-ANALYZER-TOPIC-SWITCH required; graph_structure |
| E-08b | edge | P3 original | N-GENERATOR→N-ANALYZER-CORRECTIONS required; graph_structure |
| E-09 | edge | P3 original | N-CLASSIFIER→N-SCORER-TECHNICAL forward-conditional; domain_gate |
| E-10 | edge | P3 original | N-CLASSIFIER→N-SCORER-CREATIVE forward-conditional; domain_gate |
| E-11 | edge | P3 original | N-SCORER-TECHNICAL→N-AGGREGATION required; technical_scores; null-signal tolerated |
| E-12 | edge | P3 original | N-SCORER-CREATIVE→N-AGGREGATION required; creative_scores; null-signal tolerated |
| E-13 | edge | P3 original | N-ANALYZER-TOPIC-SWITCH→N-AGGREGATION required; topic_signal |
| E-14 | edge | P3 original | N-ANALYZER-CORRECTIONS→N-AGGREGATION required; supersession_map; AP-V29 |
| E-15 | edge | P3 original | N-FILTER→N-AGGREGATION required; protected_node_set |
| E-16 | edge | P3 original | N-AGGREGATION→N-REFINER required; pruning_plan |
| E-16b | edge | P3 original | N-INGEST→N-REFINER required; ingest_record; AP-V29 spawn provenance |
| E-20 | edge | P3 original | N-VERIFIER→N-RECOVERY back-edge; violation_signal; verify_pass==false AND retry_count_artifact<1; cap=1 |
| E-21 | edge | P3 original | N-RECOVERY→N-REFINER back-edge; recovery_overrides; E-20 fired; cap=1 |

### Constraints / INVENTORY items preserved verbatim

All 26 v1 carry-forward constraints (items 1-26 in v2 N-NORMALIZE constraint list) are preserved. Key external-contract items locked:

| item_id | kind | authority | external_contract_locked |
|---|---|---|---|
| EC-FC04-1 / [SKILL-NAME] | inventory | P3+P1 confirm | true |
| EC-FC04-2 / output YAML fields (original 11) | inventory | P3 original | true |
| EC-FC04-3 / HC-02 caps | inventory | P3+P4 | true |
| EC-FC04-4 / signal names (15 v1 names) | inventory | P3 original | true |
| EC-FC04-5 / sinks [REFUSE_OUTPUT, SKILL_OUTPUT] | inventory | P3 original | true |

## divergence_map

Items that change from v1.0.0 in v2.0.0.

| item_id | kind | origin | authority | divergence_rationale | original_signature_or_null | new_signature | regression_risk |
|---|---|---|---|---|---|---|---|
| N-INGEST | node | upgrade | P1 brief | Dual-mode input shape adds auto-mode input {turn_delta, current_token_count, current_graph_state, pending_tool_calls} per [DUAL-INVOCATION-MODE] | INGEST W1 inline; input: conversation_history+session_metadata only | INGEST W1 inline; dual-path input: manual OR auto | low |
| N-PREFLIGHT | node | upgrade | P1 brief | Mode detection branch on `mode` field per [DUAL-INVOCATION-MODE]; auto-mode input shape validation | PREFLIGHT W1; validates manual input only | PREFLIGHT W1; validates by mode; two-branch validation; routes to N-TRIGGER-EVAL | medium |
| N-TRIGGER-EVAL | node | add | P1 brief | Net-new W1 gate; threshold evaluation; trigger_signal emission; NO-OP terminal for auto-mode non-triggers | absent | GATE W1 inline; emits trigger_signal (bool) + trigger_phase; forward-conditional E-02b → NO-OP | low |
| N-GENERATOR | node | upgrade | P1 brief | Extend to full dependency DAG; critical-path marking; boundary_candidates for N-SEMANTIC-CLUSTER per [DEPENDENCY-GRAPH-CRITICAL-PATH] | GENERATOR W2; turn-graph with sequential/reference/correction edges; emits graph_structure | GENERATOR W2; extended: dependency edges; emits dependency_graph + critical_path_set + boundary_candidates | medium |
| N-CLASSIFIER | node | upgrade | P1 brief | Domain set extension: {research, planning} added per SC-8 | CLASSIFIER W2; domain ∈ {technical-debugging, creative-brainstorming, auto-detect} | CLASSIFIER W2; domain ∈ {technical-debugging, creative-brainstorming, auto-detect, research, planning} | low |
| N-FILTER | node | upgrade | P1 brief | Add tiered_node_set_hint; critical-path nodes join always-retain; new outbound edges E-15b, E-15c | FILTER W2; emits protected_node_set; sends to E-15 + E-17 | FILTER W2; emits protected_node_set + tiered_node_set_hint + avoid_cache_hint | low |
| N-FILE-CACHE | node | add | P1 brief | Net-new; [DELTA-FILE-CACHE] constraint 32; >50% token reduction on unchanged file re-reads | absent | IO W2 inline; hat=cache; tier=model-small; file_cache {path→{SHA-256, compressed_content, last_read_turn}}; emits file_cache_map | low |
| N-SCORER-TECHNICAL | node | upgrade | P1 brief | Apply explicit R(msg) formula: 0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance | SCORER W3; ad-hoc technical scoring rules | SCORER W3; R(msg) formula applied; scores include graph_centrality from dependency_graph | low |
| N-SCORER-CREATIVE | node | upgrade | P1 brief | Same formula upgrade as N-SCORER-TECHNICAL | SCORER W3; ad-hoc creative scoring rules | SCORER W3; R(msg) formula applied | low |
| N-SEMANTIC-CLUSTER | node | add | P1 brief | Net-new; [SEMANTIC-CLUSTERING] constraint 31; additional token reduction via episode compression | absent | ANALYZER W3 inline; hat=clusterer; tier=model-medium; conditional on enable_semantic_clustering; emits cluster_summaries + episode_map | low |
| N-ANALYZER-TOPIC-SWITCH | node | upgrade | P1 brief | Add episode_boundaries output port for N-SEMANTIC-CLUSTER feed per [SEMANTIC-CLUSTERING] integration | ANALYZER W3; emits topic_signal + topic_switch_map | ANALYZER W3; emits topic_signal + topic_switch_map + episode_boundaries | low |
| N-AGGREGATION | node | upgrade | P1 brief | AND-join expands 6→8 streams; 5-tier priority merge adds critical-path protection; branch_budget_cap 5→8; token_budget 6000→8000 | AGGREGATION W4 spawn; 6-stream AND-join; 4-tier priority merge | AGGREGATION W4 spawn; 8-stream AND-join; 5-tier priority merge; branch_budget_cap=8 | medium |
| N-REFINER | node | upgrade | P1 brief | Scope change: compression recommendation only (eviction moves to N-TIER-MANAGER); add file_cache_map input; R(msg) formula applied | REFINER W5 spawn; applies tier assignments + executes compression | REFINER W5 spawn; scores/annotates for compression; FileRef substitution; does NOT execute tier eviction | medium |
| N-VERIFIER | node | upgrade | P1 brief | SC battery extends 8→13: SC-9 through SC-13 added; token_budget 3000→4000 | VERIFIER W6 inline; 8-SC battery | VERIFIER W6 inline; 13-SC battery; token_budget=4000 | low |
| N-RECOVERY | node | upgrade | P1 brief | Add SC-9..SC-13 override procedures | RECOVERY W7 conditional; SC-1..SC-8 override procedures | RECOVERY W7 conditional; SC-1..SC-13 override procedures | low |
| N-TIER-MANAGER | node | add | P1 brief | Net-new; [HOT-WARM-COLD-TIERS]; 4-phase Algorithm A eviction; critical-path nodes never evicted; 3rd spawn | absent | AGGREGATION W7 spawn; AP-3; hat=aggregator; tier=model-large; emits tier_state + pruning_phase; TierConfig compliance | low |
| N-FORMATTER | node | upgrade + resequence | P1 brief | Wave W7→W8; new input ports (tier_state E-17b); new YAML fields (auto_prune_triggered, pruning_phase); 6th conditional section | FORMATTER W7 inline; 5-section body; 3-input AND-join | FORMATTER W8 inline; 5+1 section body; 4-input AND-join; new frontmatter fields | medium |
| N-CONTINUITY-MARKER | node | add | P1 brief | Net-new; [CONTINUITY-MARKER] constraint 33; auto-mode only; [MICRO-CYCLE-5S] budget applies | absent | GENERATOR W8 conditional inline; hat=generator; forward-conditional on auto_prune_triggered==true | low |
| N-PERSISTER | node | resequence | P1 brief | Wave W8→W9 to accommodate expanded W8 convergence zone | PERSISTER W8 no-llm | PERSISTER W9 no-llm; protocol unchanged | low |
| E-03 (v2) | edge | recontract | P1 brief | Recontraced: N-PREFLIGHT→N-TRIGGER-EVAL (was N-PREFLIGHT→N-GENERATOR) | N-PREFLIGHT→N-GENERATOR gate-open; session_meta | N-PREFLIGHT→N-TRIGGER-EVAL gate-open; session_meta | low |
| E-04 (v2) | edge | recontract | P1 brief | Source changes to N-TRIGGER-EVAL per brief §4.1 fan-out | N-PREFLIGHT→N-CLASSIFIER | N-TRIGGER-EVAL→N-CLASSIFIER | low |
| E-05 (v2) | edge | recontract | P1 brief | Source changes to N-TRIGGER-EVAL | N-PREFLIGHT→N-FILTER | N-TRIGGER-EVAL→N-FILTER | low |
| E-17 (v2) | edge | recontract | P1 brief | Wave target shifts W7→W8 (N-FORMATTER moved) | N-FILTER→N-FORMATTER W2→W7 | N-FILTER→N-FORMATTER W2→W8 | low |
| E-18 (v2) | edge | recontract | P1 brief | Target changes from N-FORMATTER to N-VERIFIER; N-FORMATTER now downstream of N-TIER-MANAGER | N-REFINER→N-FORMATTER required; refined_context | N-REFINER→N-VERIFIER required; refined_context | medium |
| E-19 (v2) | edge | recontract | P1 brief | Target changes to N-TIER-MANAGER (verify_pass gates tier assignment, not final format) | N-VERIFIER→N-FORMATTER gate-open; verify_pass==true | N-VERIFIER→N-TIER-MANAGER gate-open; verify_pass==true | medium |
| E-22 (v2) | edge | recontract | P1 brief | ID repurposed: was N-FORMATTER→N-PERSISTER; now N-TIER-MANAGER→N-FORMATTER (tier_state_final) | N-FORMATTER→N-PERSISTER required; rendered_output | N-TIER-MANAGER→N-FORMATTER required; tier_state_final | medium |
| E-23 (v2) | edge | recontract | P1 brief | ID repurposed: was N-PERSISTER terminal; now N-FORMATTER→N-CONTINUITY-MARKER forward-conditional | N-PERSISTER→SKILL_OUTPUT terminal | N-FORMATTER→N-CONTINUITY-MARKER forward-conditional; auto_prune_triggered==true | low |
| spawn_count | inventory | upgrade | P1 brief | 3rd spawn (N-TIER-MANAGER) added | static_spawns: 2 | static_spawns: 3 (N-AGGREGATION W4, N-REFINER W5, N-TIER-MANAGER W7) | medium |
| wave_count | inventory | upgrade | P1 brief | 9 waves vs v1's 8; W9 added for N-PERSISTER | total_waves: 8 | total_waves: 9 | low |
| SC_battery | inventory | upgrade | P1 brief | SC battery: 8→13; 5 new checks (SC-9..SC-13) | 8-SC battery | 13-SC battery | medium |
| R(msg) formula | inventory | upgrade | P1 brief | Explicit formula replaces ad-hoc weights per brief §1.1 | ad-hoc technical/creative scoring rules | R(msg)=0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance | low |

## inheritance_map

| item_id | kind | inherited_from | lineage_note |
|---|---|---|---|
| N-INGEST | node | v1.0.0 N-INGEST | port-additive upgrade |
| N-PREFLIGHT | node | v1.0.0 N-PREFLIGHT | dual-mode branch added |
| N-TRIGGER-EVAL | node | brief | Net-new; brief §4.1 / §5.2 canonical name |
| N-GENERATOR | node | v1.0.0 N-GENERATOR + brief | v1.0.0 N-GENERATOR; dependency-DAG extension from brief §4.2 |
| N-CLASSIFIER | node | v1.0.0 N-CLASSIFIER + brief | domain set extended by brief SC-8 |
| N-FILTER | node | v1.0.0 N-FILTER + brief | tiered hint + new edges from brief §4.1 |
| N-FILE-CACHE | node | brief | Net-new; brief §4.2; P1-canonical name N-FILE-CACHE |
| N-SCORER-TECHNICAL | node | v1.0.0 N-SCORER-TECHNICAL + brief | R(msg) formula from brief §1.1 |
| N-SCORER-CREATIVE | node | v1.0.0 N-SCORER-CREATIVE + brief | R(msg) formula from brief §1.1 |
| N-SEMANTIC-CLUSTER | node | brief | Net-new; brief §4.2 / §5.2 |
| N-ANALYZER-TOPIC-SWITCH | node | v1.0.0 N-ANALYZER-TOPIC-SWITCH + brief | episode_boundaries port from brief §3.1 |
| N-ANALYZER-CORRECTIONS | node | v1.0.0 N-ANALYZER-CORRECTIONS | verbatim |
| N-AGGREGATION | node | v1.0.0 N-AGGREGATION + brief | 8-stream expansion from brief §4.2 |
| N-REFINER | node | v1.0.0 N-REFINER + brief | scope clarification + file_cache integration |
| N-VERIFIER | node | v1.0.0 N-VERIFIER + brief | 13-SC upgrade from brief §4.2 |
| N-RECOVERY | node | v1.0.0 N-RECOVERY + brief | SC-9..SC-13 overrides from brief §4.2 |
| N-TIER-MANAGER | node | brief | Net-new; brief §4.2 / §5.2; 4-phase Algorithm A from brief §1.1 |
| N-FORMATTER | node | v1.0.0 N-FORMATTER + brief | wave resequence + new ports from brief §2.2 / §4.1 |
| N-CONTINUITY-MARKER | node | brief | Net-new; brief §4.1 / §5.2 |
| N-PERSISTER | node | v1.0.0 N-PERSISTER | wave resequenced only |
| E-01, E-02, E-05b, E-06, E-07, E-08, E-08b, E-09, E-10, E-11, E-12, E-13, E-14, E-15, E-16, E-16b, E-20, E-21 | edges | v1.0.0 | Preserved verbatim from v1 |
| E-02b, E-05c, E-08c, E-08d, E-13b, E-14b, E-15b, E-15c, E-17b, E-19b, E-24, E-24b, E-25 | edges | brief | Net-new from brief §4.1 edge legend |
| E-03, E-04, E-05, E-17, E-18, E-19, E-22, E-23 | edges | v1.0.0 + brief | Recontraced from v1; source or target updated per v2 topology |

## risk_assessment

### HIGH risks

| risk_id | item | risk_description | mitigation |
|---|---|---|---|
| RISK-01 | E-18/E-19 recontract (N-REFINER→N-VERIFIER→N-TIER-MANAGER pipeline section) | v1: N-REFINER→N-FORMATTER directly via E-18 and N-VERIFIER→N-FORMATTER via E-19. v2 inserts N-TIER-MANAGER between N-VERIFIER and N-FORMATTER. Risk: tier eviction could discard nodes that N-FORMATTER would have preserved via the long-carry E-17 protected_node_set. | N-TIER-MANAGER's AP-3 policy must include the protected_node_set as an eviction exclusion list. SC-9 checks this. |
| RISK-02 | N-TIER-MANAGER spawn in W7 mutual-exclusion with N-RECOVERY | W7 contains both N-RECOVERY (conditional on E-20) and N-TIER-MANAGER (conditional on E-19). Risk: if orchestrator does not correctly implement mutual exclusion, both could fire simultaneously. | GoT Controller STEP 7 must enforce: IF E-20 fired → dispatch N-RECOVERY ONLY. IF E-19 opened → dispatch N-TIER-MANAGER ONLY. |
| RISK-03 | [TOKEN-BUDGET-50K] may be exceeded in STANDARD mode full pipeline | v2 adds N-TIER-MANAGER (spawn; ~6000 tokens), expanded N-AGGREGATION (8000), and N-VERIFIER (4000). Rough STANDARD total ≈62,000 tokens. | OPT-07 resolution: re-scope as advisory target for MINIMAL mode and auto-mode micro-cycle; STANDARD full-pipeline budget is ≤65K; MINIMAL ≤40K; auto-mode micro-cycle ≤15K. |

### MEDIUM risks

| risk_id | item | risk_description | mitigation |
|---|---|---|---|
| RISK-04 | N-REFINER scope reduction | v1 N-REFINER was the eviction actuator. v2 N-REFINER produces compression recommendations only; eviction is N-TIER-MANAGER. Risk: v1 TC-01..TC-10 test old N-REFINER behavior. | v2 module spec for N-REFINER must clarify scope boundary. Regression suite must add new TC tests for N-TIER-MANAGER behavior. |
| RISK-05 | E-22 ID repurpose | Any tooling that hard-codes E-22 as the render→persist edge will break. | N-EMIT must produce REGRESSION.md documenting the E-22 repurpose. |
| RISK-06 | N-TRIGGER-EVAL NO-OP terminal (E-02b) behavioral ambiguity | Silent no-op could be confused with a failure condition. | E-02b should emit a structured no_op_signal that the orchestrator logs as "no pruning needed" rather than an error. SC-11 prevents trigger storms. |
| RISK-07 | N-AGGREGATION 8-stream AND-join with 2 conditional streams | 2 additional null-signal sources beyond the 2 v1 scorer null-signals. | AP-1 null-signal accommodation must extend: cluster_summaries and file_cache_map both accepted at AND-join with zero-weight semantics. |

## fusion_decisions

| conflict_id | winning_source | losing_source | rationale | brief_quote_or_null | external_contract_locked |
|---|---|---|---|---|---|
| FD-01 | P1 brief | P3 original (N-CONTEXT-ANALYZE heuristic) | Node name: N-TRIGGER-EVAL vs N-AUTO-ROUTER. Brief §5.2 lists canonical v2 node names; N-TRIGGER-EVAL is the authoritative name. | "N-TRIGGER-EVAL" in §5.2 named entities | false |
| FD-02 | P1 brief | N-CONTEXT-ANALYZE heuristic (N-CRITICAL-PATH standalone) | N-CRITICAL-PATH as a standalone W2 node is NOT in brief §5.2 canonical node list. Brief §4.2 says "Extend N-GENERATOR to build full dependency DAG." | "Extend N-GENERATOR to build full dependency DAG with tool-call edges." §4.2 | false |
| FD-03 | P1 brief | P3 original (N-CONTEXT-ANALYZE name N-DELTA-CACHE) | Node name: N-FILE-CACHE vs N-DELTA-CACHE. Brief §5.2 authoritative. | "N-FILE-CACHE" in §5.2 named entities | false |
| FD-04 | P1 brief | N-CONTEXT-ANALYZE (N-TIER-MANAGER at W2) | N-TIER-MANAGER wave: N-CONTEXT-ANALYZE placed it at W2. Brief §4.1 places it at W7. W7 is architecturally correct: tier eviction requires verified refined_context. | "[Wave 7 (tier manager spawn): ((N-TIER-MANAGER))]" §4.1 | false |
| FD-05 | P1 brief | P3 original (v1 invocation signature manual-only) | Dual-mode invocation: v1 manual-only; v2 adds AUTOMATIC mode per [DUAL-INVOCATION-MODE]. EC-FC04-1 (skill name) preserved. | "The skill MUST support two mutually exclusive runtime modes" §2.1 | false |
| FD-06 | P3 original | — | EC-FC04-1 (skill name) preserved: `adaptive-context-pruner`. Brief [SKILL-NAME-V2] constraint 38 explicitly confirms. | "[SKILL-NAME-V2] Canonical skill name unchanged: `adaptive-context-pruner`; version bumps to 2.0.0." | true |
| FD-07 | P3 original | — | EC-FC04-2 (YAML frontmatter fields, original 11) preserved. Brief adds 2 fields (auto_prune_triggered, pruning_phase); does not remove any v1 fields. | "auto_prune_triggered: bool # NEW v2 / pruning_phase: string # NEW v2" §2.2 | true |
| FD-08 | P3 original | — | EC-FC04-4 (signal names, all 15 v1 names) preserved. | Brief silent on signal renaming. | true |
| FD-09 | P3 original | — | EC-FC04-5 (sinks [REFUSE_OUTPUT, SKILL_OUTPUT]) preserved. | Brief silent on sinks. | true |
| FD-10 | P1 brief | P3 original (v1 N-FORMATTER at W7) | N-FORMATTER wave: resequenced W7→W8. N-TIER-MANAGER inserted at W7 between N-VERIFIER and N-FORMATTER. | "[Wave 8 (final-stage convergence + conditional continuity): [N-FORMATTER]]" §4.1 | false |
| FD-11 | P1 brief | P3 original (v1 N-PERSISTER at W8) | N-PERSISTER resequenced W8→W9. Required by N-FORMATTER moving to W8. | "[Wave 9 (terminal): [N-PERSISTER]]" §4.1 | false |
| FD-12 | P1 brief | P3 original (v1 E-18: N-REFINER→N-FORMATTER) | E-18 retarget: N-REFINER→N-VERIFIER (not N-FORMATTER). New pipeline order: N-REFINER→N-VERIFIER→N-TIER-MANAGER→N-FORMATTER. | "E-18: N-REFINER → N-VERIFIER (required)" §4.1 | false |
| FD-13 | P1 brief | P3 original (v1 E-19: N-VERIFIER→N-FORMATTER) | E-19 retarget: N-VERIFIER→N-TIER-MANAGER on verify_pass==true. | "E-19: N-VERIFIER → N-TIER-MANAGER (gate-open; verify_pass==true)" §4.1 | false |
| FD-14 | P1 brief | P3 original (N-CONTINUITY-MARKER not present) | N-CONTINUITY-MARKER as standalone W8 node (not inlined into N-FORMATTER). Brief §5.2 explicitly names it as the 20th canonical node. AP-V29 compliance: forward-conditional E-23 must be a declared graph edge. | "N-CONTINUITY-MARKER" in §5.2 named entities | false |
| FD-15 | P1 brief + P4 default ([NO-EXTERNAL-TOOLS]) | Brief §1.5 literal ("Use API count_tokens endpoint") | [API-TOKEN-COUNT] ambiguity resolution. "API count_tokens endpoint" maps to Claude Code's internal token counting capability, NOT an external REST call. Preserves [NO-EXTERNAL-TOOLS] constraint 11. | "Use API count_tokens endpoint for accurate measurement" §1.5; "No external tools or APIs." constraint 11 | false |
| FD-16 | P1 brief | P3 original (v1 8-SC battery) | SC battery 8→13. [VERIFIER-13-SC] constraint 37 is an explicit P1 mandate. SC-9..SC-13 defined in brief §4.2. | "[VERIFIER-13-SC] SC battery extended to 13" constraint 37 | false |
| FD-17 | P1 brief | P3 original (v1 static_spawns=2) | 3rd spawn added: N-TIER-MANAGER. Brief §4.1: "Static spawns: 3". | "Static spawns: 3 (N-AGGREGATION W4, N-REFINER W5, N-TIER-MANAGER W7)" §4.1 | false |
| FD-18 | P1 brief | P3 original (v1 ad-hoc scoring) | R(msg) formula. Brief §1.1 specifies exact formula: R(msg)=0.3*recency+0.3*semantic_similarity+0.2*graph_centrality+0.2*user_importance. | "R(msg) = 0.3 * recency + 0.3 * semantic_similarity(current_turn) + 0.2 * graph_centrality + 0.2 * user_importance" §1.1 | false |
| FD-19 | P1 brief | N-CONTEXT-ANALYZE (N-FORMATTER inlining continuity marker as fallback) | N-CONTINUITY-MARKER handling. N-CONTEXT-ANALYZE RC-05 suggested inlining into N-FORMATTER if budget tightens. Brief §5.2 explicit: N-CONTINUITY-MARKER is canonical node 20. No inlining allowed. | "N-CONTINUITY-MARKER" listed as one of exactly 20 canonical node names in §5.2 | false |
| FD-20 | P1 brief | N-CONTEXT-ANALYZE (N-TIER-MANAGER at W2 as a "tier assignment" node) | N-TIER-MANAGER role clarification. N-CONTEXT-ANALYZE envisioned N-TIER-MANAGER as an early-pipeline tier-labeler at W2. Brief §4.2 specifies N-TIER-MANAGER as the 4-phase eviction executor at W7. These are categorically different roles. | "N-TIER-MANAGER [NEW v2] / (hot/warm/cold tier assignment; 4-phase eviction)" §4.1 W7 placement | false |

## decomposition_tasks

### Node tasks (DT-01 through DT-20)

| task_id | category | target_item_id | authority | regression_risk | wave_target |
|---|---|---|---|---|---|
| DT-01 | preserve | N-ANALYZER-CORRECTIONS | P3 original | null | 3 |
| DT-02 | upgrade | N-INGEST | P1 brief | low | 1 |
| DT-03 | upgrade | N-PREFLIGHT | P1 brief | medium | 1 |
| DT-04 | upgrade | N-GENERATOR | P1 brief | medium | 2 |
| DT-05 | upgrade | N-CLASSIFIER | P1 brief | low | 2 |
| DT-06 | upgrade | N-FILTER | P1 brief | low | 2 |
| DT-07 | upgrade | N-SCORER-TECHNICAL | P1 brief | low | 3 |
| DT-08 | upgrade | N-SCORER-CREATIVE | P1 brief | low | 3 |
| DT-09 | upgrade | N-ANALYZER-TOPIC-SWITCH | P1 brief | low | 3 |
| DT-10 | upgrade | N-AGGREGATION | P1 brief | medium | 4 |
| DT-11 | upgrade | N-REFINER | P1 brief | medium | 5 |
| DT-12 | upgrade | N-VERIFIER | P1 brief | low | 6 |
| DT-13 | upgrade | N-RECOVERY | P1 brief | low | 7 |
| DT-14 | upgrade | N-FORMATTER | P1 brief | medium | 8 |
| DT-15 | add | N-TRIGGER-EVAL | P1 brief | low | 1 |
| DT-16 | add | N-FILE-CACHE | P1 brief | low | 2 |
| DT-17 | add | N-SEMANTIC-CLUSTER | P1 brief | low | 3 |
| DT-18 | add | N-TIER-MANAGER | P1 brief | low | 7 |
| DT-19 | add | N-CONTINUITY-MARKER | P1 brief | low | 8 |
| DT-20 | resequence | N-PERSISTER | P1 brief | low | 9 |

### Edge tasks (DT-21 through DT-59)

| task_id | category | target_item_id | authority | regression_risk |
|---|---|---|---|---|
| DT-21 | preserve | E-01 | P3 original | null |
| DT-22 | preserve | E-02 | P3 original | null |
| DT-23 | preserve | E-05b | P3 original | null |
| DT-24 | preserve | E-06 | P3 original | null |
| DT-25 | preserve | E-07 | P3 original | null |
| DT-26 | preserve | E-08 | P3 original | null |
| DT-27 | preserve | E-08b | P3 original | null |
| DT-28 | preserve | E-09 | P3 original | null |
| DT-29 | preserve | E-10 | P3 original | null |
| DT-30 | preserve | E-11 | P3 original | null |
| DT-31 | preserve | E-12 | P3 original | null |
| DT-32 | preserve | E-13 | P3 original | null |
| DT-33 | preserve | E-14 | P3 original | null |
| DT-34 | preserve | E-15 | P3 original | null |
| DT-35 | preserve | E-16 | P3 original | null |
| DT-36 | preserve | E-16b | P3 original | null |
| DT-37 | preserve | E-20 | P3 original | null |
| DT-38 | preserve | E-21 | P3 original | null |
| DT-39 | recontract | E-03 | P1 brief | low |
| DT-40 | recontract | E-04 | P1 brief | low |
| DT-41 | recontract | E-05 | P1 brief | low |
| DT-42 | recontract | E-17 | P1 brief | low |
| DT-43 | recontract | E-18 | P1 brief | medium |
| DT-44 | recontract | E-19 | P1 brief | medium |
| DT-45 | recontract | E-22 | P1 brief | medium |
| DT-46 | recontract | E-23 | P1 brief | low |
| DT-47 | add | E-02b | P1 brief | low |
| DT-48 | add | E-05c | P1 brief | low |
| DT-49 | add | E-08c | P1 brief | low |
| DT-50 | add | E-08d | P1 brief | low |
| DT-51 | add | E-13b | P1 brief | low |
| DT-52 | add | E-14b | P1 brief | low |
| DT-53 | add | E-15b | P1 brief | low |
| DT-54 | add | E-15c | P1 brief | low |
| DT-55 | add | E-17b | P1 brief | low |
| DT-56 | add | E-19b | P1 brief | low |
| DT-57 | add | E-24 | P1 brief | low |
| DT-58 | add | E-24b | P1 brief | low |
| DT-59 | add | E-25 | P1 brief | low |

## fusion_constraints_applied

| fc_id | constraint | status | notes |
|---|---|---|---|
| FC-01 | Every divergence from original MUST be documented in `fusion_decisions[]` | SATISFIED | N-FUSION-ANALYZE delta_matrix documents all 20 nodes and 35 edges with resolved_action, authority, and rationale. All 5 name reconciliation conflicts (CN-01..CN-03 + node count implications) explicitly resolved. |
| FC-02 | If brief is silent on a design question, prefer spec over original skill | SATISFIED (N/A) | No `--context-spec` was supplied; P2 slot is empty. All brief-silent decisions fell to P3 (original skill) or P4 (GOTSCS defaults), as required. |
| FC-03 | If brief contradicts both spec and original, brief wins — but MUST include `risk_acknowledgment` in `fusion_task_trace` row | SATISFIED | Multiple brief-vs-original conflicts resolved: OPT-07 (TOKEN-BUDGET-50K re-scoping), N-TIER-MANAGER wave placement (W2→W7), N-FORMATTER resequence (W7→W8). All documented with explicit rationale. |
| FC-04 | INVENTORY items inherited as candidates, not mandates, EXCEPT external-contract items per briefing-appendix-contract §EC-FC04 | SATISFIED | EC-FC04-1 (skill name): locked. EC-FC04-2 (output schema): locked; 11 v1 fields preserved; 2 additive. EC-FC04-3 (HC-02 caps): locked. EC-FC04-4 (signal names): locked; all 15 v1 signals preserved; 8 new signals additive. EC-FC04-5 (sinks): locked. No external-contract item was removed or renamed. |
| FC-05 | Backward compatibility advisory for internal details, MANDATORY for external behavior unless `--strict` OR `contract_override` | SATISFIED | All EC-FC04 external items preserved. Internal changes (wave positions, node additions, 8-stream aggregation, new edges) are all additive or recontractive with rationale. No external behavior regressed. |
| FC-06 | Optimization for final utility is the primary objective | SATISFIED | All optimization opportunities (OPT-01..OPT-07) evaluated and applied. N-CRITICAL-PATH merged into N-GENERATOR; N-CONTINUITY-MARKER kept standalone for AP-V29 compliance; N-TIER-MANAGER correctly placed at W7. |
| FC-07 | When replacing a node, the new node MUST satisfy all functional contracts of the old node unless brief explicitly redefines them | SATISFIED | N-FORMATTER functional contract analysis confirms: AP-4 convergence preserved, downshiftable=false preserved, 5-section body is a strict subset of v2 6-7-section body, E-17 long-carry unchanged, MINIMAL-mode N-TIER-MANAGER always executes (not skipped). |
| FC-08 | Every redesign MUST have a corresponding regression test in the smoke-test battery | AT-RISK (partial) | v1 TC-01..TC-10 cover carry-forward behavior. v2 adds TC-11..TC-18 per brief success criteria 3. N-EMIT has bootstrapped these test cases in REGRESSION.md. AP-V34/V35/V36/V37 each have dedicated regression entries. |
| FC-09 | `--evolve-aggressive` requires `waiver_justification` ≥50 chars | SATISFIED (N/A) | This run uses `evolution_mode=evolve` (not `evolve-aggressive`). FC-09 waiver requirement does not apply. |
