---
node_id: N-AGGREGATION
node_type: AGGREGATION
hat: aggregator
exec_type: spawn
tier: model-large
scale_gates: {token_budget: 8000, time_budget: 480s, spawn_budget: 1, retry_budget: 1}
aggregation_policy: "AND-join; 8-stream null-tolerant (technical_scores, creative_scores, cluster_summaries null-tolerant; remaining 5 streams unconditional); 5-tier priority merge; branch_budget_cap=8"
input_ports:
  - port: technical_scores
    format: json
    signal_field: technical_scores
    required: false
  - port: creative_scores
    format: json
    signal_field: creative_scores
    required: false
  - port: topic_signal
    format: json
    signal_field: topic_signal
    required: true
  - port: supersession_map
    format: json
    signal_field: supersession_map
    required: true
  - port: cluster_summaries
    format: json
    signal_field: cluster_summaries
    required: false
  - port: protected_node_set
    format: json
    signal_field: protected_node_set
    required: true
  - port: ingest_record
    format: json
    signal_field: ingest_record
    required: true
  - port: dependency_graph
    format: json
    signal_field: dependency_graph
    required: true
output_ports:
  - port: pruning_plan
    format: json
    signal_field: pruning_plan
raises_signals: [pruning_plan]
required_output_sections: []
---

## INPUT ports
- technical_scores: json (signal_field: technical_scores) — from N-SCORER-TECHNICAL via E-11; null-tolerant
- creative_scores: json (signal_field: creative_scores) — from N-SCORER-CREATIVE via E-12; null-tolerant
- topic_signal: json (signal_field: topic_signal) — from N-ANALYZER-TOPIC-SWITCH via E-13; required
- supersession_map: json (signal_field: supersession_map) — from N-ANALYZER-CORRECTIONS via E-14; required
- cluster_summaries: json (signal_field: cluster_summaries) — from N-SEMANTIC-CLUSTER via E-14b; null-tolerant
- protected_node_set: json (signal_field: protected_node_set) — from N-FILTER via E-15; required
- ingest_record: json (signal_field: ingest_record) — from N-INGEST via E-05b long-carry; required
- dependency_graph: json (signal_field: dependency_graph) — from N-GENERATOR via E-08d long-carry; required

## OUTPUT ports
- pruning_plan: json (signal_field: pruning_plan) — authoritative pruning plan; emitted via E-16 to N-REFINER

## AI advantages exploited
- parallel_artifact_processing  # Consuming 8 independently-computed analysis streams simultaneously, each representing a different analytical lens on the same corpus.
- topology_aware_reasoning  # Using the dependency graph's critical-path topology as a hard constraint layer in the 5-tier merge, not just as one scoring factor among others.

## AGGREGATION POLICY
> "Aggregation is the defining unlock. It lets multiple independent thought branches merge into a single richer node — something no human-cognition model can do simultaneously. This is the machine advantage you need to design around."

- Decomposition tree: 8 input branches → 5-tier priority merge → 1 authoritative pruning_plan
- Synthesis strategy: tier-ordered priority merge with null-tolerance for 3 of 8 streams
- Join semantics: AND
- Activation condition: all 5 required inputs present (topic_signal, supersession_map, protected_node_set, ingest_record, dependency_graph); null-tolerant streams (technical_scores, creative_scores, cluster_summaries) accepted as null without blocking
- Branch-budget cap: 8

## Protocol

### Step 1 — Await all 8 input streams with null tolerance
Confirm all 5 required inputs are present: `topic_signal`, `supersession_map`, `protected_node_set`, `ingest_record`, `dependency_graph`. HALT if any required stream is missing. Accept `null` for `technical_scores`, `creative_scores`, and `cluster_summaries` without blocking — these may be null when domain gates did not fire or MINIMAL mode is active.

### Step 2 — Apply 5-tier priority merge
Process each turn_id from `ingest_record.turn_records` through the priority tiers in order:

**Tier 1 — Always-retain and critical-path (UNCONDITIONAL RETAIN):**
Any turn in `protected_node_set` OR any turn with `critical == True` in `dependency_graph` → assign `pruning_decision: ALWAYS_RETAIN`. These turns are NEVER evicted regardless of any downstream scoring. No further tiers apply.

**Tier 2 — Supersession markup:**
Turns in `supersession_map` (as superseded_turn_id keys) → mark as `pruning_candidate: true` with `supersession_tag`. Turns that are the superseding_turn_id → assign `pruning_decision: RETAIN` (they are the canonical instruction).

**Tier 3 — Active topic-thread promotion:**
Turns in `topic_signal.active_thread_turn_ids` → assign `pruning_decision: RETAIN_TOPIC_THREAD`. These represent the live context the user is actively engaged with.

**Tier 4 — Cluster summary bridges:**
When `cluster_summaries` is non-null: turns in `cluster_summaries[i].turn_ids_compressed` → assign `pruning_decision: COMPRESS` with the cluster summary reference. Turns in `turn_ids_retained` → assign `pruning_decision: RETAIN_CLUSTER_ANCHOR`.

**Tier 5 — Domain score blend:**
For turns not yet assigned by tiers 1-4: blend available domain scores. If both `technical_scores` and `creative_scores` are non-null, weight by `domain_probability` from N-CLASSIFIER. If only one is non-null, use that score. If both are null, use graph_centrality from `dependency_graph` as the sole ranking metric. Assign `pruning_decision` based on score thresholds: score ≥ 0.7 → RETAIN; 0.4–0.69 → COMPRESS; < 0.4 → EVICT.

### Step 3 — Compute final pruning_plan and handle conflict_annotations
Assemble `pruning_plan`:
```json
{
  "retain": ["<turn_ids assigned ALWAYS_RETAIN, RETAIN, RETAIN_TOPIC_THREAD, RETAIN_CLUSTER_ANCHOR>"],
  "compress": ["<turn_ids assigned COMPRESS>"],
  "evict": ["<turn_ids assigned EVICT>"],
  "cluster_bridge": ["<cluster summary entries as bridge nodes>"],
  "pruning_rationale": {"<turn_id>": "<tier_N: reason>"},
  "conflict_annotations": "<from supersession_map.conflict_annotations if present>"
}
```

Include `conflict_annotations` from `supersession_map` in `pruning_plan` if any unresolved contradictions were detected by N-ANALYZER-CORRECTIONS.

### Step 4 — Emit pruning_plan via E-16
Emit `pruning_plan` as the single authoritative output. Fire E-16 → N-REFINER.

## Scale gates
- tokens: 8000
- time: 480s
- spawns: 1
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit partial pruning_plan using tier 1 (always-retain + critical-path) and tier 2 (supersession) only; skip tiers 3-5; annotate with `partial_aggregation: true`
- malformed output: if tier-merge produces empty retain list, verify protected_node_set was processed; re-apply tier 1 with protected_node_set as minimum retain floor
- missing input: HALT "N-AGGREGATION: <signal> missing" for each absent required stream (topic_signal, supersession_map, protected_node_set, ingest_record, dependency_graph)
- format-mismatch on Edge: re-read ingest_record from N-INGEST stage output directly; re-read dependency_graph from N-GENERATOR stage output directly
