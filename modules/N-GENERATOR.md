---
node_id: N-GENERATOR
node_type: GENERATOR
hat: generator
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 4000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
    required: true
output_ports:
  - port: graph_structure
    format: json
    signal_field: graph_structure
  - port: dependency_graph
    format: json
    signal_field: dependency_graph
  - port: critical_path_set
    format: json
    signal_field: critical_path_set
  - port: boundary_candidates
    format: json
    signal_field: boundary_candidates
raises_signals: [graph_structure, dependency_graph, critical_path_set]
required_output_sections: [dependency_graph, critical_path]
---

## INPUT ports
- session_meta: json (signal_field: session_meta)

## OUTPUT ports
- graph_structure: json (signal_field: graph_structure) — full dependency DAG
- dependency_graph: json (signal_field: dependency_graph) — DAG with critical=True flags
- critical_path_set: json (signal_field: critical_path_set) — list of turn IDs on critical path
- boundary_candidates: json (signal_field: boundary_candidates) — list of turn IDs at topic/domain boundaries

## AI advantages exploited
- topology_aware_reasoning  # Explicitly modeling the conversation as a directed acyclic graph and reasoning over dependency edges, not just scanning turns sequentially.

## Protocol

### Step 1 — Build dependency DAG
Read `turn_records` from `session_meta.ingest_record_ref`. Build the dependency DAG with the following edge classes:
- **Sequential edges**: A→B where B directly follows A (baseline chain)
- **Reference edges**: B quotes or explicitly references A's content (keyword/entity overlap detection)
- **Correction edges**: B overrides or negates A (detect correction openers: "Actually...", "I meant...", "Disregard...", "Never mind...")
- **Tool-use→tool-result pairs**: each `tool_use` turn is linked to its corresponding `tool_result` turn by tool_call_id
- **File-read provenance**: turns that reference a file path create a provenance edge from the file-read turn
- **User-query→assistant-response causality**: each assistant turn is linked to the most recent prior user turn

Represent the DAG as `{nodes: [{id, role, turn_index, critical}], edges: [{source, target, edge_class}]}`.

### Step 2 — Identify pending_tool_calls
Scan `turn_records` for turns with `tool_use` that have no matching `tool_result` by `tool_call_id`. These are pending tool calls. Mark their `turn_index` values as the pending_tool_call_roots.

OPT-09 exception: if `pending_tool_calls_count == 0` and token budget is near exhaustion (>3500 tokens consumed), skip full backward BFS in Step 3; emit empty `critical_path_set` with `advisory: "critical_path_skipped_OPT09"`.

### Step 3 — Compute critical_path_set via backward BFS
Starting from all `pending_tool_call_roots`, perform backward BFS on the dependency DAG (follow edges in reverse). Set `critical = True` on every ancestor node reached. The `critical_path_set` is the complete list of turn IDs with `critical == True`.

### Step 4 — Compute boundary_candidates and emit
Scan consecutive turn pairs. Mark turn index `i` as a boundary candidate if:
- The turn at index `i+1` introduces vocabulary not present in the prior 5 turns (computed as token-level overlap < 20%), OR
- There is a detectable explicit reorientation phrase in turn `i+1` (e.g., "Let's switch to...", "Moving on to...", "New topic:")

Emit:
- `graph_structure`: full DAG JSON with all edge classes — broadcast via E-06 (→N-SCORER-TECHNICAL), E-07 (→N-SCORER-CREATIVE), E-08 (→N-ANALYZER-TOPIC-SWITCH), E-08b (→N-ANALYZER-CORRECTIONS)
- `dependency_graph`: same DAG with `critical` flags applied to nodes — broadcast via E-08d (→N-AGGREGATION, required unconditional stream) and E-08c (→N-SEMANTIC-CLUSTER, optional, gate: enable_semantic_clustering==true)
- `critical_path_set`: list of turn IDs where `critical == True`
- `boundary_candidates`: list of turn IDs at boundary positions — consumed by N-SEMANTIC-CLUSTER via E-08c

Write `dependency_graph` and `critical_path` required output sections.

## Scale gates
- tokens: 4000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, apply OPT-09: emit partial graph_structure with available turns; SC-9 advisory-degraded flag set
- malformed output: if DAG construction fails (cycle detected), emit linear chain fallback (sequential edges only) with `advisory: "dag_cycle_detected_linear_fallback"`
- missing input: HALT "N-GENERATOR: session_meta missing" if session_meta signal absent
- format-mismatch on Edge: re-read session_meta from N-TRIGGER-EVAL stage output directly
