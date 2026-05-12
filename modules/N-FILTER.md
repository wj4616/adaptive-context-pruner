---
node_id: N-FILTER
node_type: FILTER
hat: filter
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2000, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
input_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
    required: true
output_ports:
  - port: protected_node_set
    format: json
    signal_field: protected_node_set
  - port: tiered_node_set_hint
    format: json
    signal_field: tiered_node_set_hint
  - port: avoid_cache_hint
    format: json
    signal_field: avoid_cache_hint
raises_signals: [protected_node_set, tiered_node_set_hint, avoid_cache_hint]
required_output_sections: []
---

## INPUT ports
- session_meta: json (signal_field: session_meta)

## OUTPUT ports
- protected_node_set: json (signal_field: protected_node_set) — list of turn IDs that must never be evicted; emitted via E-15 (→N-AGGREGATION) and E-17 (long-carry W2→W8→N-FORMATTER)
- tiered_node_set_hint: json (signal_field: tiered_node_set_hint) — advisory tier pre-classification hint for N-TIER-MANAGER; maps turn_id → suggested_tier {hot, warm, cold}; not authoritative (N-TIER-MANAGER may override); advisory use only
- avoid_cache_hint: json (signal_field: avoid_cache_hint) — list of file paths for always-retain turns; emitted via E-15b (→N-FILE-CACHE)

## AI advantages exploited
- full_corpus_retention  # Scanning the entire turn corpus simultaneously to identify every always-retain turn, rather than incrementally deciding turn-by-turn with risk of missing early critical instructions.

## Protocol

### Step 1 — Read turn_records and dependency graph
Read `turn_records` from `session_meta.ingest_record_ref`. Read `critical_path_set` from the dependency graph if available via session_meta — if not yet computed (N-GENERATOR runs in parallel), use an empty list as initial input; N-AGGREGATION will reconcile using the full dependency_graph via E-08d.

Read `TierConfig.recent_window` from `session_meta` if present; default to `N = 5` if not specified.

### Step 2 — Build always-retain set
Construct the `protected_node_set` by accumulating turn IDs from three retention categories:

**(a) Instruction-type turns:** All turns with `role == "system"` plus any user-turn that contains explicit directives (detected by imperative language patterns: "always", "never", "you must", "do not", "from now on", "remember that"). Include the full user instruction set regardless of turn age.

**(b) Recent window:** The last `N` turns by `turn_index` (default N=5). These represent the live context the user is actively engaged with.

**(c) Critical-path turns:** All turn IDs in `critical_path_set` (critical=True in dependency_graph). These are transitive ancestors of pending tool calls — evicting any of them would break tool-chain continuity.

Merge all three sets. Deduplicate. The result is `protected_node_set`.

### Step 3 — Compute avoid_cache_hint
Identify all file path references in turns that belong to `protected_node_set`. These files must NOT be replaced with FileRef tokens — since the turns that read them are always-retain, full content must remain available.

`avoid_cache_hint`: list of file paths extracted from `tool_use` or `content` of protected turns.

### Step 4 — Compute tiered_node_set_hint (advisory)
Produce an advisory `tiered_node_set_hint` map for N-TIER-MANAGER. For each turn not already in `protected_node_set`:
- Suggest `hot` for turns within recent_window × 2 OR turns with explicit user-continuation cues ("let's continue", "come back to this")
- Suggest `warm` for turns with tool-use results referenced by turns in the recent_window
- Suggest `cold` for all others (default)

This is advisory only. N-TIER-MANAGER's 4-phase Algorithm A is the authoritative eviction decision.

### Step 5 — Emit signals with fan-out routing
Emit `protected_node_set` via:
- E-15 → N-AGGREGATION (required input stream)
- E-17 long-carry → N-FORMATTER (W2→W8, 6-wave skip; carries always-retain context through the full pipeline)

Emit `tiered_node_set_hint` via:
- advisory channel to N-TIER-MANAGER (carried through N-AGGREGATION as part of pruning_plan metadata)

Emit `avoid_cache_hint` via:
- E-15b → N-FILE-CACHE (instructs cache node to skip these files)

## Scale gates
- tokens: 2000
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); emit protected_node_set containing only instruction-type turns and recent-N turns (skip critical_path dependency); annotate with `timeout_flag: true`
- malformed output: if protected_node_set cannot be assembled, emit the recent-N turns as a minimal safe set
- missing input: HALT "N-FILTER: session_meta missing" if session_meta signal absent
- format-mismatch on Edge: re-read session_meta from N-TRIGGER-EVAL stage output directly
