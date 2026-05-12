---
node_id: N-TIER-MANAGER
node_type: AGGREGATION
hat: aggregator
exec_type: spawn
tier: model-large
scale_gates: {token_budget: 6000, time_budget: 480s, spawn_budget: 1, retry_budget: 1}
aggregation_policy: "AND-join (verify_pass_signal + tier inputs required); 4-phase Algorithm A eviction synthesis; branch_budget_cap=4; MINIMAL mode: exec_type=inline, tier=model-medium (always executes)"
input_ports:
  - port: verify_pass_signal
    format: json
    signal_field: verify_pass_signal
    required: false
  - port: recovery_pass_signal
    format: json
    signal_field: recovery_pass_signal
    required: false
  - port: protected_node_set
    format: json
    signal_field: protected_node_set
    required: true
  - port: dependency_graph
    format: json
    signal_field: dependency_graph
    required: true
output_ports:
  - port: tier_state
    format: json
    signal_field: tier_state
  - port: tier_state_final
    format: json
    signal_field: tier_state_final
  - port: pruning_phase
    format: json
    signal_field: pruning_phase
raises_signals: [tier_state, tier_state_final, pruning_phase]
required_output_sections: []
---

## INPUT ports
- verify_pass_signal: json (signal_field: verify_pass_signal) — from N-VERIFIER via E-19 gate-open; fires when verify_pass==true
- recovery_pass_signal: json (signal_field: recovery_pass_signal) — from N-RECOVERY via E-19b gate-open; fires when recovery_complete==true (alternate entry)
- protected_node_set: json (signal_field: protected_node_set) — from N-FILTER via E-17 long-carry (W2→W7); required
- dependency_graph: json (signal_field: dependency_graph) — from N-GENERATOR via E-08d long-carry; required

## OUTPUT ports
- tier_state: json (signal_field: tier_state) — intermediate tier assignment summary; emitted via E-17b to N-FORMATTER
- tier_state_final: json (signal_field: tier_state_final) — finalized eviction manifest; emitted via E-22 to N-FORMATTER
- pruning_phase: json (signal_field: pruning_phase) — one of {none, yellow, orange, red}; emitted alongside tier_state_final

## AI advantages exploited
- topology_aware_reasoning  # Executing Algorithm A using the dependency graph's critical-path topology as a hard constraint layer that cannot be overridden by score-based eviction phases.
- parallel_artifact_processing  # Processing tier assignments for all turns simultaneously across 4 eviction phases, using the dependency graph and protected_node_set as joint exclusion constraints.

## AGGREGATION POLICY
> "Aggregation is the defining unlock. It lets multiple independent thought branches merge into a single richer node — something no human-cognition model can do simultaneously. This is the machine advantage you need to design around."

- Decomposition tree: 4 input streams (verify_pass or recovery_pass + protected_node_set + dependency_graph + refined_context) → 4-phase Algorithm A synthesis → tier_state + tier_state_final
- Synthesis strategy: 4-phase Algorithm A eviction with hard exclusion of protected_node_set and critical_path_set from all eviction phases
- Join semantics: AND
- Activation condition: exactly one of verify_pass_signal (E-19) or recovery_pass_signal (E-19b) must be present; plus protected_node_set and dependency_graph
- Branch-budget cap: 4
- MINIMAL mode override: exec_type=inline, tier=model-medium (always executes — never skipped)

## Protocol

### Step 1 — Determine entry path and read inputs
Check which gate fired: E-19 (verify_pass path) or E-19b (recovery_complete path). Read the `refined_context` from the verify/recovery pass chain (carried through the pipeline). Read `protected_node_set` (E-17 long-carry). Read `dependency_graph` (E-08d long-carry).

If recovery path (E-19b): the `refined_context` already incorporates `recovery_overrides` from N-RECOVERY (applied by N-REFINER on the second pass). Proceed directly to Phase 1.

In MINIMAL mode: execute this node inline as model-medium (never skip — CR-02 TRIZ Dynamics resolution: always-execute invariant).

### Step 2 — Phase 1: Detach completed tool chains
Identify all `tool_result` turns in `refined_context` where: (a) the corresponding `tool_use` turn is no longer in `pending_tool_calls`, and (b) no other turn in the dependency graph has this tool_result as a dependency. These are completed tool-chain result turns with no pending dependents. Assign these to `cold` tier with action `archive`. Exclude any turns in `protected_node_set` from this phase unconditionally.

### Step 3 — Phase 2: Archive leaf cold nodes
Identify leaf nodes in the dependency DAG: turns with no outgoing edges (no other turn depends on them) AND `R(msg) < TierConfig.cold_threshold` (default 0.3). Assign `cold` tier with action `archive`. Exclude protected_node_set and critical_path_set turns unconditionally.

### Step 4 — Phase 3: Compress warm nodes
Identify warm-candidate turns: turns with R(msg) in the warm band [TierConfig.warm_low .. TierConfig.warm_high] (default 0.3–0.6) that are not in `protected_node_set`, not `critical == True`, and not already assigned in Phases 1-2. Apply [COMPRESS-NOT-DROP] rule: compress these turns to tier summary entries using 1-2 sentence summaries. Assign `warm` tier with action `compress`.

### Step 5 — Phase 4: Emergency evict if over budget
After Phases 1-3, compute remaining token sum for all `hot` and `warm` tier turns. If `sum > TierConfig.window_size`: emergency eviction needed.

Sort remaining eligible turns (not in protected_node_set, not `critical == True`) by ascending R(msg) score. Evict from lowest-score upward until `sum ≤ TierConfig.window_size`. **NEVER evict a turn where `critical == True` in dependency_graph.** If budget cannot be met without evicting a critical turn: proceed at current budget and set `budget_violation_flag: true` (emit for SC-13 re-check).

### Step 6 — Emit tier_state, tier_state_final, pruning_phase
Emit `tier_state`: intermediate summary `{turn_id: tier}` for N-FORMATTER's conditional 6th section assembly.

Emit `tier_state_final`: finalized manifest `{turn_id: {tier, action, eviction_rationale}}`.

Emit `pruning_phase`: read from `trigger_phase` in session_meta → map to {none, yellow, orange, red}.

All `protected_node_set` turns receive `tier: hot` regardless of R(msg) score.

Fire E-17b (tier_state → N-FORMATTER) and E-22 (tier_state_final → N-FORMATTER).

## Scale gates
- tokens: 6000
- time: 480s
- spawns: 1
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit tier_state_final using protected_node_set → hot, remainder → cold; annotate with `emergency_tier_flag: true`
- malformed output: if Algorithm A Phase 4 cannot reduce to budget without evicting critical turns, emit with `budget_violation_flag: true`
- missing input: HALT "N-TIER-MANAGER: protected_node_set missing" if protected_node_set absent; HALT "N-TIER-MANAGER: dependency_graph missing" if dependency_graph absent
- format-mismatch on Edge: re-read protected_node_set from N-FILTER stage output directly; re-read dependency_graph from N-GENERATOR stage output directly
