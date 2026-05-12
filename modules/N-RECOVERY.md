---
node_id: N-RECOVERY
node_type: RECOVERY
hat: recovery
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2000, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
input_ports:
  - port: violation_signal
    format: json
    signal_field: violation_signal
    required: true
output_ports:
  - port: recovery_overrides
    format: json
    signal_field: recovery_overrides
  - port: recovery_pass_signal
    format: json
    signal_field: recovery_pass_signal
raises_signals: [recovery_overrides, recovery_pass_signal]
required_output_sections: []
---

## INPUT ports
- violation_signal: json (signal_field: violation_signal) — from N-VERIFIER via E-20 back-edge; node activates only when verify_pass==false

## OUTPUT ports
- recovery_overrides: json (signal_field: recovery_overrides) — targeted correction dict; emitted via E-21 back-edge to N-REFINER
- recovery_pass_signal: json (signal_field: recovery_pass_signal) — bool; fires E-19b gate-open to N-TIER-MANAGER after recovery_overrides dispatched

## AI advantages exploited
- multi_perspective_simulation  # Evaluating each failed SC through its specific override procedure, applying distinct resolution strategies per SC-ID rather than a single generic recovery heuristic.

## Protocol

### Step 1 — Read violation_signal and identify failed SCs
Read `violation_signal` from N-VERIFIER. Extract `failed_scs` list and `violations` array. Identify each SC-ID that failed. Increment `retry_count_artifact` by 1 (tracked in session state).

Log recovery entry: `{retry_count: N, failed_scs: [...], timestamp: <now>}`.

### Step 2 — Apply per-SC-ID override procedures
For each failed SC, apply the targeted override procedure:

**SC-9 (critical-path turn cold-tiered):** For every turn with `critical == True` in dependency_graph that was assigned cold tier or evict recommendation: emit override `{turn_id: {new_tier_hint: "hot", new_compression_recommendation: "none", override_rationale: "SC-9: critical-path ancestor of pending tool call"}}`. This is the highest-priority override.

**SC-10 (continuity_marker missing):** Emit override `{continuity_marker_required: true, auto_prune_triggered: true}` to ensure N-FORMATTER fires E-23 → N-CONTINUITY-MARKER.

**SC-11 (micro-cycle frequency):** Emit override `{rate_limit_constraint: "no_auto_trigger_within_5_turns", last_auto_trigger_turn: <N>}` as a session constraint added to recovery_overrides.

**SC-12 (FileRef count ≥ 20):** Emit override listing the lowest-priority FileRef entries (oldest last_read_turn) to revert from "fileref" type back to "full" content type until count drops below 20: `{revert_filerefs: ["<path1>", "<path2>", ...]}`.

**SC-13 (tier budget sum > window_size):** Compute the excess token count (`sum_hot_warm_tokens - window_size`). Emit override: `{tier_threshold_adjustment: {warm_to_cold_candidates: ["<turn_ids with lowest R(msg) in warm tier>"], token_deficit: N}}`. Turns listed are candidates to demote from warm to cold to reduce the budget.

**SC-1..SC-8 violations:** For each SC-1..SC-8 failure, emit targeted refinements to the pruning_plan aspects that caused the failure:
- SC-1: re-protect any missing protected_node turns
- SC-2: restore recent-window turns to hot tier
- SC-3: restore instruction turns to non-compress status
- SC-4: adjust compression ratio by identifying additional low-R turns for eviction (if under-pruned) or upgrading cold turns to warm (if over-pruned)
- SC-5..SC-8: targeted schema corrections as described in violation_description

### Step 3 — Emit recovery_overrides via E-21
Assemble `recovery_overrides`: dict of all per-SC override directives. Emit via E-21 back-edge → N-REFINER for a corrective second pass.

### Step 4 — Emit recovery_pass_signal via E-19b
After dispatching `recovery_overrides`, emit `recovery_pass_signal: {recovery_complete: true, retry_count: N, scs_addressed: ["<SC-IDs>"]}`. Fire E-19b gate-open → N-TIER-MANAGER (the recovery-complete path bypasses the need for verify_pass==true from N-VERIFIER to proceed).

## Scale gates
- tokens: 2000
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); emit partial recovery_overrides covering only SC-9 (highest priority); fire recovery_pass_signal regardless
- malformed output: if override assembly fails, emit minimal override containing only protected_node_set re-enforcement
- missing input: HALT "N-RECOVERY: violation_signal missing" if violation_signal signal absent
- format-mismatch on Edge: re-read violation_signal from N-VERIFIER stage output directly
