---
node_id: N-SEMANTIC-CLUSTER
node_type: ANALYZER
hat: clusterer
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 3000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
mode_inactive: "MINIMAL OR enable_semantic_clustering==false"
input_ports:
  - port: dependency_graph
    format: json
    signal_field: dependency_graph
    required: false
  - port: episode_boundaries
    format: json
    signal_field: episode_boundaries
    required: false
output_ports:
  - port: cluster_summaries
    format: json
    signal_field: cluster_summaries
  - port: episode_map
    format: json
    signal_field: episode_map
raises_signals: [cluster_summaries, episode_map]
required_output_sections: []
---

## INPUT ports
- dependency_graph: json (signal_field: dependency_graph) — from N-GENERATOR via E-08c optional gate; active only when enable_semantic_clustering==true
- episode_boundaries: json (signal_field: episode_boundaries) — from N-ANALYZER-TOPIC-SWITCH via E-13b optional gate; active when enable_semantic_clustering==true AND mode!=MINIMAL

## OUTPUT ports
- cluster_summaries: json (signal_field: cluster_summaries) — list of {episode_id, cluster_id, summary, turn_ids_retained, turn_ids_compressed}; null-signal when gated off
- episode_map: json (signal_field: episode_map) — dict {turn_id → episode_id}; null-signal when gated off

## AI advantages exploited
- cross_document_pattern_recognition  # Detecting semantic cluster structure across all turns simultaneously, identifying coherent sub-episodes by reference-edge density and vocabulary overlap patterns that span many non-adjacent turns.

## Protocol

### Step 1 — Check activation gate
Check: if `enable_semantic_clustering == false` OR mode is MINIMAL, emit `cluster_summaries: null` and `episode_map: null` immediately. Return. N-AGGREGATION accepts null for cluster_summaries (null-tolerant stream E-14b).

### Step 2 — Segment turns into episodes using episode_boundaries
Read `episode_boundaries` from N-ANALYZER-TOPIC-SWITCH (E-13b). Each boundary marks a turn index where a significant topic or tool-chain completion transition occurred.

Segment `dependency_graph.nodes` into episodes: all consecutive turns between two boundary markers form one episode. Assign an `episode_id` (sequential: ep_0, ep_1, ...) to each segment. Build preliminary `episode_map: {turn_id → episode_id}`.

### Step 3 — Detect intra-episode cluster structure
For each episode, analyze internal cluster structure:
- Compute vocabulary overlap between pairs of turns within the episode (shared token ratio)
- Compute reference-edge density within the episode (edges connecting turns inside the same episode vs. crossing episode boundaries)
- High internal overlap AND high reference-edge density → turns form a coherent cluster

Apply intra-cluster summarization to completed, internally-consistent sub-episodes that meet the summarization threshold (all turns in the cluster are non-critical, not in protected_node_set, and have low R(msg) scores based on recency alone). For these clusters: produce one 1-2 sentence summary per [SUMMARIZE-1-2-SENTENCES] rule. Mark constituent turns as `turn_ids_compressed`.

### Step 4 — Apply meta-clustering for large conversations
If `total_turns > 200` (from corpus_stats): apply optional meta-clustering to group related episodes into super-episodes. Episodes with vocabulary overlap > 30% and no intervening boundary-breaker are candidates for merging into a super-episode. This reduces the episode_map cardinality for very long conversations.

### Step 5 — Emit cluster_summaries and episode_map
Emit `cluster_summaries`: list of entries:
```json
{
  "episode_id": "ep_N",
  "cluster_id": "cl_M",
  "summary": "<1-2 sentence summary>",
  "turn_ids_retained": ["<turn_ids kept verbatim>"],
  "turn_ids_compressed": ["<turn_ids replaced by summary>"]
}
```

Emit `episode_map`: `{turn_id: "ep_N"}` for all turns.

## Scale gates
- tokens: 3000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit empty cluster_summaries (no compressions) and a basic linear episode_map (one episode per boundary segment, no intra-cluster summarization)
- malformed output: if episode_boundaries absent, treat every 20-turn block as one episode (fallback segmentation)
- missing input: if dependency_graph absent, skip reference-edge density computation; use vocabulary overlap only for clustering
- format-mismatch on Edge: re-read dependency_graph from N-GENERATOR stage output directly
