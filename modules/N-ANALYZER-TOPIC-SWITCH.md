---
node_id: N-ANALYZER-TOPIC-SWITCH
node_type: ANALYZER
hat: analyzer
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2500, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: graph_structure
    format: json
    signal_field: graph_structure
    required: true
output_ports:
  - port: topic_signal
    format: json
    signal_field: topic_signal
  - port: topic_switch_map
    format: json
    signal_field: topic_switch_map
  - port: episode_boundaries
    format: json
    signal_field: episode_boundaries
raises_signals: [topic_signal, topic_switch_map, episode_boundaries]
required_output_sections: []
---

## INPUT ports
- graph_structure: json (signal_field: graph_structure) — from N-GENERATOR via E-08

## OUTPUT ports
- topic_signal: json (signal_field: topic_signal) — includes active_topic_thread and topic_switch_count; emitted via E-13 to N-AGGREGATION
- topic_switch_map: json (signal_field: topic_switch_map) — dict {turn_index: {previous_topic, new_topic, switch_confidence}}
- episode_boundaries: json (signal_field: episode_boundaries) — list of turn indices at significant transitions; emitted via E-13b optional to N-SEMANTIC-CLUSTER

## AI advantages exploited
- cross_document_pattern_recognition  # Detecting vocabulary-shift patterns across the full turn sequence simultaneously, tracking topic thread continuity that spans many turns and is not visible from a local window.

## Protocol

### Step 1 — Scan for vocabulary-shift patterns
Read `turn_records` from graph_structure. For each turn at index `i` (starting from turn 5 to allow a prior-context window), compute vocabulary overlap between turn `i` and the prior-5 turns window:
```
prior_vocab = union of all tokens in turns [i-5 .. i-1]
current_vocab = tokens in turn[i]
overlap_ratio = |current_vocab ∩ prior_vocab| / max(|current_vocab|, 1)
```

A vocabulary-shift is detected when `overlap_ratio < 0.20` (less than 20% token overlap with the prior window). Apply additional checks:
- Entity-reference shift: the primary named entities (proper nouns, technical terms) in turn `i` are absent from turns `[i-5..i-1]`
- Question-domain shift: the domain indicators in turn `i` differ from the dominant domain in turns `[i-5..i-1]`

An explicit reorientation phrase in turn `i` (e.g., "Let's switch to...", "Moving on to...", "New topic:", "Separate question:") confirms a topic switch regardless of vocabulary overlap.

### Step 2 — Identify active topic thread
The active topic thread is the topic most recently discussed with active user engagement (the topic covering the last turn where the user asked a question or gave a directive). Mark the active topic thread as always-retained: turns constituting the active thread should never be pruned. Record the `active_topic_thread` as a label string describing the current topic domain.

### Step 3 — Build topic_switch_map
For each detected topic switch at turn index `i`:
```json
{
  "turn_index": i,
  "previous_topic": "<descriptive label>",
  "new_topic": "<descriptive label>",
  "switch_confidence": 0.0–1.0
}
```
`switch_confidence` is 1.0 for explicit reorientation phrase, 0.8 for high vocabulary shift + entity shift, 0.5 for vocabulary shift only.

### Step 4 — Compute episode_boundaries and emit
`episode_boundaries`: list of turn indices where a topic switch was detected (switch_confidence ≥ 0.5) OR where a tool-chain completion occurred (a tool_result turn that resolves the last pending tool_use in a chain). These boundaries segment the conversation into episodes for N-SEMANTIC-CLUSTER.

Emit:
- `topic_signal`: `{active_topic_thread: "<label>", topic_switch_count: N, active_thread_turn_ids: ["<turn_id>", ...]}`
- `topic_switch_map`: dict of switch events
- `episode_boundaries`: list of turn indices

## Scale gates
- tokens: 2500
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit topic_signal with active_topic_thread derived from the last 5 turns only; emit empty topic_switch_map; emit episode_boundaries as empty list
- malformed output: if graph_structure node list is missing turn content, use turn roles as fallback for topic inference
- missing input: HALT "N-ANALYZER-TOPIC-SWITCH: graph_structure missing" if graph_structure signal absent
- format-mismatch on Edge: re-read graph_structure from N-GENERATOR stage output directly
