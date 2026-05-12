# RATIONALE.md — Design rationale and architectural decisions

evolution_mode: evolve
gotscs_version: 4.3.0
timestamp: 2026-05-12T00:00:00Z
skill: adaptive-context-pruner
version: 2.0.0
evolved_from: 1.0.0

This file documents the design rationale for v2.0.0: TRIZ contradiction resolutions, anti-pattern guards, architectural decisions, and fusion redesign justifications. It is documentation-only; runtime behavior is fully determined by SKILL.md, graph.json, and modules/.

---

## 1. TRIZ Contradiction Resolutions

### C1 — Wave Fan-Out Breadth vs. Aggregation Depth

**Conflict:** W3 is a 5-way fan-out (HC-23 required) while N-AGGREGATION must tolerate 8 input streams. Maximizing parallelism (H.7 advantage) creates wider null-path surface at the AND-join.

**Resolution (Segmentation + Partial/Excess Action):** Stratify the 8 streams into unconditional and conditional tiers. Null-tolerance is mandated only for conditional streams; unconditional streams block the AND-join if absent.

- Unconditional (5): E-08d dependency_graph, E-13 topic_signal, E-14 supersession_map, E-15 protected_node_set, E-05b ingest_record
- Conditional/null-tolerant (3): E-11 technical_scores (domain-gated), E-12 creative_scores (domain-gated), E-14b cluster_summaries (enable_semantic_clustering-gated)

**Guard:** AP-V20 (N-AGGREGATION 8-stream null-tolerance).

---

### C2 — N-TIER-MANAGER Wave Position vs. MINIMAL-Mode Fallback

**Conflict (FC-07):** N-TIER-MANAGER is a W7 spawn required by N-FORMATTER (W8) for tier_state input. In MINIMAL mode N-TIER-MANAGER downgrades to model-medium inline. If N-TIER-MANAGER were skipped, N-FORMATTER's required input E-22 (tier_state_final) would be missing.

**Resolution (Dynamics / Parameter Change):** N-TIER-MANAGER ALWAYS executes. MINIMAL mode changes exec_type and tier only (spawn → inline model-medium), not activation. The 4-phase Algorithm A runs at reduced fidelity but still fires and emits tier_state.

- STANDARD / DEEP: N-VERIFIER→E-19→N-TIER-MANAGER(spawn)→E-22→N-FORMATTER
- MINIMAL: N-VERIFIER→E-19→N-TIER-MANAGER(inline model-medium)→E-22→N-FORMATTER

**FC-07 status: RESOLVED.** N-FORMATTER's E-22 input is always satisfied because N-TIER-MANAGER always executes.

---

### C3 — W7 Mutual Exclusion (N-RECOVERY vs. N-TIER-MANAGER)

**Conflict (RISK-02 HIGH):** W7 contains both N-RECOVERY (conditional on E-20, verify_pass==false) and N-TIER-MANAGER (conditional on E-19, verify_pass==true). Two-pass recovery scenario creates potential for both nodes to fire.

**Resolution (Prior Action + Transition to Another Dimension):** W7 is time-multiplexed (not spatially parallel).

- **W7-pass-1 (first-pass):** Exactly one of {N-RECOVERY, N-TIER-MANAGER} dispatched based on initial E-20/E-19 gate.
- **W7-pass-2 (recovery-path only):** If E-20 fired → N-RECOVERY → E-21 back-edge → N-REFINER → N-VERIFIER second pass → if verify_pass==true → E-19b → N-TIER-MANAGER only.

**GoT Controller STEP 7 invariant:**
1. Read E-20 and E-19 gate outputs from N-VERIFIER (W6).
2. IF E-20 fired (verify_pass==false AND retry_count_artifact<1): dispatch N-RECOVERY only; N-TIER-MANAGER SKIPPED for this pass. After back-edge chain completes, if second-pass verify_pass==true: dispatch N-TIER-MANAGER via E-19b. If second-pass verify_pass==false: retry_count==1 → cap exceeded → proceed to N-TIER-MANAGER in degraded mode (recovery_override_final flag set).
3. IF E-19 fired (verify_pass==true, first pass): dispatch N-TIER-MANAGER directly; N-RECOVERY SKIPPED entirely.
4. NEVER dispatch both N-RECOVERY and N-TIER-MANAGER in the same pass.

**E-19b** carries recovery_pass_signal; gate_condition: recovery_complete==true.

---

### C4 — N-FORMATTER Input Reconstruction (E-17b vs. E-22 apparent duplication)

**Conflict:** N-FORMATTER (W8) has two inputs from N-TIER-MANAGER: E-17b (tier_state) and E-22 (tier_state_final). Is this duplication?

**Resolution:** These carry distinct payloads emitted at different points in N-TIER-MANAGER's 4-phase execution:
- **E-17b** (tier_state): intermediate tier assignment summary (for conditional 6th section rendering)
- **E-22** (tier_state_final): finalized eviction manifest (for YAML frontmatter pruning_phase field)

Both required. AP-4 convergence consumes all three inputs (protected_node_set via E-17, tier_state via E-17b, tier_state_final via E-22).

---

### C5 — N-SEMANTIC-CLUSTER Conditional Gate (MINIMAL-mode skip)

**Conflict:** E-13b (N-ANALYZER-TOPIC-SWITCH→N-SEMANTIC-CLUSTER) was typed `required` in N-DECOMPOSE, but N-SEMANTIC-CLUSTER is inactive in MINIMAL mode. A required edge to an inactive node stalls the AND-join.

**Resolution (Skipping / Prior Counteraction):** Retype E-13b to `optional` with gate_condition `enable_semantic_clustering==true AND mode!=MINIMAL`. The `required` designation in N-DECOMPOSE meant "required when N-SEMANTIC-CLUSTER is active" (not unconditionally required). When N-SEMANTIC-CLUSTER is inactive: E-08c not fired, E-13b not fired, E-14b emits null-signal to N-AGGREGATION (null-tolerant stream).

---

## 2. Key Design Decisions

### DD-01: N-CRITICAL-PATH absorbed into N-GENERATOR (OPT-01 / FD-02)

N-CONTEXT-ANALYZE proposed a standalone N-CRITICAL-PATH node. Brief §4.2 explicitly states "Extend N-GENERATOR to build full dependency DAG." P1 brief wins (FD-02). N-GENERATOR emits dependency_graph + critical_path_set + boundary_candidates as output ports. This preserves the 20-node budget.

### DD-02: N-TIER-MANAGER at W7 not W2 (FD-04)

N-CONTEXT-ANALYZE placed N-TIER-MANAGER at W2 for early tier labeling. Brief §4.1 places it at W7 for post-verify 4-phase eviction. W2 placement is architecturally incorrect: tier eviction requires verified refined_context (AP-V31 runtime-sequencing constraint). P1 brief wins.

### DD-03: N-CONTINUITY-MARKER as standalone node (FD-14, FD-19)

N-CONTEXT-ANALYZE RC-05 suggested inlining N-CONTINUITY-MARKER into N-FORMATTER as a budget-tightening fallback. Brief §5.2 lists N-CONTINUITY-MARKER as canonical node 20. AP-V29 compliance requires E-23 (N-FORMATTER→N-CONTINUITY-MARKER) to be a declared graph edge — this is only possible if N-CONTINUITY-MARKER is a standalone node. No inlining allowed.

### DD-04: E-22 ID repurposed (RISK-05)

v1 E-22 was N-FORMATTER→N-PERSISTER. v2 E-22 is N-TIER-MANAGER→N-FORMATTER (tier_state_final). The v1 render→persist path becomes E-24b (N-FORMATTER→N-PERSISTER direct, when auto_prune_triggered==false). Any tooling hard-coding E-22 as the render→persist edge must be updated.

### DD-05: N-REFINER scope boundary (RISK-04)

v1 N-REFINER was the eviction actuator. v2 N-REFINER produces compression recommendations only; eviction is N-TIER-MANAGER's responsibility. This scope change is required by [HOT-WARM-COLD-TIERS] and the Algorithm A 4-phase design. v1 TC-01..TC-10 tests that checked eviction-applied output at N-REFINER stage must be updated to expect annotation-only output.

### DD-06: R(msg) formula explicit (FD-18)

v1 used ad-hoc scoring weights. v2 mandates the explicit formula from brief §1.1:
`R(msg) = 0.3 * recency + 0.3 * semantic_similarity(current_turn) + 0.2 * graph_centrality + 0.2 * user_importance`

Applied in both N-SCORER-TECHNICAL and N-SCORER-CREATIVE. graph_centrality is sourced from the dependency_graph computed by N-GENERATOR.

### DD-07: [API-TOKEN-COUNT] ambiguity resolution (FD-15)

Brief §1.5 says "Use API count_tokens endpoint." Brief constraint 11 says "No external tools or APIs." These appear contradictory. Resolution: "API count_tokens endpoint" maps to Claude Code's internal token counting capability, NOT an external REST call. Preserves [NO-EXTERNAL-TOOLS].

### DD-08: N-FORMATTER downshiftable=false preserved (FC-07)

v1 N-FORMATTER had downshiftable=false. This constraint carries forward to v2. N-TIER-MANAGER executes in MINIMAL mode as inline model-medium (not skipped), ensuring N-FORMATTER always receives tier_state_final via E-22 regardless of mode. No MINIMAL-mode fallback that bypasses N-TIER-MANAGER.

---

## 3. Anti-Pattern Guards

### HIGH risk guards (13)

| ap_id | node(s) | guard |
|---|---|---|
| AP-T1 | N-FORMATTER | YAML frontmatter fields must all be consumed by downstream; no orphan fields |
| AP-V4 | graph.json | Declares all 39 v2 edges; any edge used by a module must appear in graph.json |
| AP-V6 | all 20 nodes | Graceful-degradation path documented in every node |
| AP-V7 | N-ANALYZER-CORRECTIONS | No-silent-deferral: must emit conflict_signal on unresolvable contradiction; AP-V7 preserved verbatim |
| AP-V8 | graph.json | static_spawns == 3 (N-AGGREGATION W4, N-REFINER W5, N-TIER-MANAGER W7) |
| AP-V19 | SKILL.md | v2.0.0 content delta present; must not be byte-identical to v1.0.0 |
| AP-V23 | N-FORMATTER | Relevance Graph Summary section bounded; no unbounded graph dumps |
| AP-V27 | SKILL.md + graph.json | Signal field names consistent across all 20 nodes; SKILL.md matches graph.json |
| AP-V29 | graph.json | All 12 named long-carry/provenance/conditional edges declared: E-05b, E-16b, E-17, E-17b, E-08c, E-13b, E-14b, E-15b, E-15c, E-19b, E-20, E-21 |
| AP-V31 | N-CLASSIFIER + N-VERIFIER | Runtime sequencing: N-CLASSIFIER W2→N-SCORER W3; N-VERIFIER W6→N-TIER-MANAGER W7 (not direct to N-FORMATTER) |
| AP-V32 | N-TIER-MANAGER | Critical-path nodes (critical=True in dependency_graph) NEVER placed in cold tier; NEVER evicted |
| AP-V33 | N-GENERATOR | Emits critical=True flags on all transitive ancestors of pending_tool_calls |
| AP-V37 | N-CONTINUITY-MARKER | MUST NOT fire if auto_prune_triggered==false; forward-conditional gate E-23 mandatory |

### MEDIUM risk guards (8)

| ap_id | node(s) | guard |
|---|---|---|
| AP-V5 | N-REFINER + N-TIER-MANAGER | Scoring drives behavior, not warnings only |
| AP-V9 | all 20 nodes | signal_field names consistent across all module specs |
| AP-V15 | N-VERIFIER (SC-9) | Testable tier_consistency metric: verify protected_node_set excluded from eviction |
| AP-V20 | N-AGGREGATION | 8-stream null-tolerance; cluster_summaries and dependency_graph accepted as null-signal in MINIMAL mode |
| AP-V25 | N-PERSISTER | Session-scoped writes only; no cross-session persistence |
| AP-V34 | N-VERIFIER (SC-11) | N-TRIGGER-EVAL micro-cycle frequency cap enforced via SC-11 |
| AP-V35 | N-VERIFIER (SC-12) | N-FILE-CACHE FileRef representation < 20 tokens verified via SC-12 |
| AP-V36 | N-VERIFIER (SC-13) | N-TIER-MANAGER tier budget sum ≤ window_size verified via SC-13 |

---

## 4. Fusion Redesign Justifications (Divergence Summary)

Derived from divergence_map. Items with origin ∈ {replaced, removed, recontract} + medium/high regression_risk receive detailed justification.

### N-PREFLIGHT (upgrade, medium risk)

**Why:** [DUAL-INVOCATION-MODE] constraint 27 mandates two mutually exclusive runtime modes. N-PREFLIGHT is the entry point; it must branch on `mode` field and apply per-mode validation. v1 validated manual input only.

**Risk:** If mode detection fails (mode field absent), PREFLIGHT may route auto-mode traffic to the manual validation path — fail-fast is correct but could produce false-negative refusals on well-formed auto-mode inputs.

**Mitigation:** N-PREFLIGHT emits structured error with `mode` field name on validation failure. TC-12 covers dual-mode preflight routing.

---

### N-GENERATOR (upgrade, medium risk)

**Why:** [DEPENDENCY-GRAPH-CRITICAL-PATH] constraint 47 mandates a full dependency DAG with tool-use→tool-result, file_read provenance, and user_query→assistant_response causality edges. N-CRITICAL-PATH absorbed per OPT-01 / FD-02.

**Risk:** Dependency-DAG computation is O(N × D) where N=turns and D=max dependency depth. For 200+ turn conversations with deep tool-call chains, this may push N-GENERATOR toward its 4000-token ceiling.

**Mitigation:** OPT-09 — if latency exceeds 120s, gate dependency_graph computation on pending_tool_calls>0. token_budget set at ceiling (4000); RISK-09 documented.

---

### N-AGGREGATION (upgrade, medium risk)

**Why:** AND-join must accommodate 8 streams (up from 6) to handle the 5-tier priority merge including dependency_graph (critical-path protection) and cluster_summaries (semantic compression). branch_budget_cap raised 5→8; token_budget raised 6000→8000.

**Risk:** 2 new conditional streams (E-08d dependency_graph, E-14b cluster_summaries via E-14b null-tolerant) expand null-tolerance surface. v1 TC-01..TC-10 tested 6-stream AND-join behavior.

**Mitigation:** AP-V20 guard extended to 8-stream AND-join. TC-07 (upgraded) covers 8-stream behavior. AP-1 stratifies unconditional vs. conditional streams.

---

### N-REFINER (upgrade, medium risk)

**Why:** v2 separates the "score and annotate for compression" role (N-REFINER) from the "execute eviction" role (N-TIER-MANAGER). This separation is required by [HOT-WARM-COLD-TIERS] and the 4-phase Algorithm A design. N-REFINER's scope now ends at producing refined_context with per-turn annotations and FileRef substitutions. N-TIER-MANAGER handles the actual tier eviction.

**Risk:** Any v1 TC-01..TC-10 test that expected eviction-applied output at N-REFINER stage will fail.

**Mitigation:** N-REFINER module spec explicitly states scope boundary. TC-08 (upgraded) verifies compression-recommendation-only behavior. v1 tests checking eviction at N-REFINER must be re-targeted to N-TIER-MANAGER.

---

### N-FORMATTER (upgrade + resequence, medium risk)

**Why:** Wave resequenced W7→W8 to accommodate N-TIER-MANAGER insertion at W7. N-FORMATTER's input contract changes: was directly from N-VERIFIER (E-19); now receives tier_state_final from N-TIER-MANAGER (E-22). New YAML fields auto_prune_triggered and pruning_phase added per brief §2.2. 4th input (tier_state via E-17b) added.

**Risk:** v1 callers or tests expecting N-FORMATTER at W7 or directly fed by N-VERIFIER will fail. E-22 semantics change (RISK-05).

**Mitigation:** REGRESSION.md documents E-22 repurpose. N-TIER-MANAGER runs inline in MINIMAL mode (not skipped), so E-22 always delivered. TC-09 (upgraded) covers new YAML field presence.

---

### E-18 (recontract, medium risk)

**Why:** v1 E-18 was N-REFINER→N-FORMATTER directly. v2 inserts N-VERIFIER between N-REFINER and N-FORMATTER: N-REFINER→N-VERIFIER (E-18) → N-TIER-MANAGER (E-19) → N-FORMATTER (E-22). The SC battery must validate the refined_context before tier eviction.

**Risk (RISK-01):** v1 N-REFINER→N-FORMATTER direct path callers see routing mismatch. Tier eviction could discard nodes that N-FORMATTER would have preserved via protected_node_set (E-17).

**Mitigation:** SC-9 checks that N-TIER-MANAGER's AP-3 policy includes protected_node_set as an eviction exclusion list.

---

### E-19 (recontract, medium risk)

**Why:** v1 E-19 was N-VERIFIER→N-FORMATTER gate-open. v2 E-19 is N-VERIFIER→N-TIER-MANAGER gate-open. verify_pass now gates tier assignment, not final formatting. Architectural correctness: tier eviction must happen after verification.

**Risk (RISK-02):** v1 callers expecting N-VERIFIER→N-FORMATTER gate see empty formatter input on verify_pass.

**Mitigation:** W7 mutual-exclusion (N-RECOVERY vs. N-TIER-MANAGER) enforced by GoT controller per C3 resolution. SC-9..SC-13 battery added to N-VERIFIER to provide fuller coverage before tier eviction.

---

### E-22 (recontract, medium risk)

**Why:** v1 E-22 was N-FORMATTER→N-PERSISTER. v2 E-22 is N-TIER-MANAGER→N-FORMATTER (tier_state_final). ID repurposed per brief §4.1 canonical edge table. The v1 render→persist path becomes E-24b.

**Risk (RISK-05):** Any tooling hard-coding E-22 as the render→persist edge will break silently. REGRESSION.md required (FC-08 partial compliance note).

**Mitigation:** REGRESSION.md documents E-22 recontract. TODO: smoke-test assertion checking E-22 source == N-TIER-MANAGER (see FC-08 compliance gate in REGRESSION.md).

---

### spawn_count (upgrade, medium risk)

**Why:** 3rd spawn N-TIER-MANAGER required per [SPAWN-BUDGET-3] constraint 59 and brief §4.1 "Static spawns: 3". AP-V8 enforces spawn_node_count == 3 in graph.json.

**Risk:** v1 orchestration harnesses expecting 2 static spawns will need updating.

**Mitigation:** TC-15 behavioral test covers N-TIER-MANAGER spawning behavior.

---

### SC_battery (upgrade, medium risk)

**Why:** [VERIFIER-13-SC] constraint 51 is an explicit P1 mandate. SC-9 through SC-13 cover tier-specific verification: SC-9 (tier_consistency), SC-10 (continuity_marker_present), SC-11 (micro-cycle frequency cap), SC-12 (FileRef token count), SC-13 (tier budget sum).

**Risk:** 5 new SC checks unevaluated in v1 test suites.

**Mitigation:** S09 smoke-test checks SC battery count. TC-06 (upgraded) covers SC-9..SC-13 trigger scenarios.

---

## 5. Constraints Summary

### Hard constraints (HC-01..HC-25)

All 62 inventory items preserved or additive. Key hard constraints:
- HC-02: nodes ≤ 30, waves ≤ 15, edges ≤ 100 — v2: 20 nodes, 9 waves, 39 edges — PASS
- HC-23: single-response parallel dispatch required at W2 (4-node fan-out) and W3 (5-node fan-out)
- Back-edge caps: E-20 cap=1 STANDARD/0 MINIMAL/2 DEEP; E-21 same caps

### v2 new constraints (44-62)

| constraint_id | description | primary_node |
|---|---|---|
| [DUAL-INVOCATION-MODE] | Two mutually exclusive modes: MANUAL full pipeline, AUTOMATIC background micro-cycle | N-INGEST, N-PREFLIGHT, N-TRIGGER-EVAL |
| [AUTO-PRUNE-THRESHOLDS] | Yellow ≥0.70, Orange ≥0.85, Red ≥0.95 utilization thresholds + every-15-turns scheduled | N-TRIGGER-EVAL |
| [HOT-WARM-COLD-TIERS] | Hot/warm/cold/meta tier architecture with TierConfig YAML | N-TIER-MANAGER |
| [DEPENDENCY-GRAPH-CRITICAL-PATH] | Full dependency DAG; critical-path nodes never evicted | N-GENERATOR, N-TIER-MANAGER |
| [SEMANTIC-CLUSTERING] | Episode-level clustering conditional on enable_semantic_clustering | N-SEMANTIC-CLUSTER |
| [DELTA-FILE-CACHE] | SHA-256 FileRef substitution; >50% token reduction on unchanged file re-reads | N-FILE-CACHE |
| [CONTINUITY-MARKER] | Standalone W8 node; fires only when auto_prune_triggered==true | N-CONTINUITY-MARKER |
| [VERIFIER-13-SC] | SC battery extended 8→13; SC-9..SC-13 defined | N-VERIFIER, N-RECOVERY |
| [MICRO-CYCLE-5S] | Auto-mode micro-cycle budget ≤15K tokens; latency ≤5s | N-CONTINUITY-MARKER |
| [API-TOKEN-COUNT] | Internal token counting only; no external REST calls | all nodes |
| [TIER-CONFIG-YAML] | All tunable tier parameters in TierConfig YAML block; no hardcoded values | N-TIER-MANAGER |
| [SKILL-NAME-V2] | Canonical skill name unchanged: adaptive-context-pruner; version bumps to 2.0.0 | SKILL.md |
