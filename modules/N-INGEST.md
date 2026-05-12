---
node_id: N-INGEST
node_type: INGEST
hat: extractor
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: conversation_history
    format: text
    signal_field: conversation_history
    required: false
  - port: session_metadata
    format: json
    signal_field: session_metadata
    required: true
  - port: turn_delta
    format: text
    signal_field: turn_delta
    required: false
  - port: current_token_count
    format: json
    signal_field: current_token_count
    required: false
  - port: current_graph_state
    format: json
    signal_field: current_graph_state
    required: false
  - port: pending_tool_calls
    format: json
    signal_field: pending_tool_calls
    required: false
output_ports:
  - port: ingest_record
    format: json
    signal_field: ingest_record
  - port: turn_records
    format: json
    signal_field: turn_records
  - port: corpus_stats
    format: json
    signal_field: corpus_stats
raises_signals: [ingest_record]
required_output_sections: []
---

## INPUT ports
- conversation_history: text (signal_field: conversation_history) — MANUAL mode: full conversation text
- session_metadata: json (signal_field: session_metadata) — required; contains mode field (MANUAL|AUTOMATIC)
- turn_delta: text (signal_field: turn_delta) — AUTOMATIC mode: incremental turn record
- current_token_count: json (signal_field: current_token_count) — AUTOMATIC mode: live token count
- current_graph_state: json (signal_field: current_graph_state) — AUTOMATIC mode: current dependency graph
- pending_tool_calls: json (signal_field: pending_tool_calls) — AUTOMATIC mode: pending tool call list

## OUTPUT ports
- ingest_record: json (signal_field: ingest_record)
- turn_records: json (signal_field: turn_records)
- corpus_stats: json (signal_field: corpus_stats)

## AI advantages exploited
- consistency_at_scale  # Applying the same turn normalization schema deterministically across arbitrarily large conversation corpora regardless of history length.

## Protocol

### Step 1 — Detect invocation mode
Read `session_metadata.mode`. Accept values: `MANUAL` or `AUTOMATIC`. If the `mode` field is absent or contains an unrecognized value, HALT immediately with signal `malformed_input: mode field absent or invalid`.

### Step 2 — Parse input per mode
**MANUAL mode:** Parse `conversation_history` (raw text or structured input) into a list of turn records. Each record must be assigned a sequential `turn_index`. If `conversation_history` is null or empty, HALT with `malformed_input: empty conversation_history in MANUAL mode`.

**AUTOMATIC mode:** Parse `turn_delta` as a single incremental turn record. Read `current_token_count` (integer), `current_graph_state` (JSON), and `pending_tool_calls` (list) from the auto-mode payload. Validate: `current_token_count > 0`; `current_graph_state` non-null. If either fails, HALT with `malformed_input: invalid auto-mode payload`.

### Step 3 — Normalize turn_records schema
Produce a uniform `turn_records` list. Each entry has the following fields:
- `id`: string — unique turn identifier (e.g., `turn_0`, `turn_1`, ...)
- `role`: string — `user`, `assistant`, `system`, or `tool`
- `content`: string — raw text content
- `tool_use`: list|null — tool call objects if present
- `tool_result`: list|null — tool result objects if present
- `token_count`: int — token count for this turn (estimated if not provided)
- `turn_index`: int — 0-based position in the conversation

For AUTOMATIC mode, append the `turn_delta` record to `current_graph_state.turn_records` (if graph state carries prior records) or create a single-entry list.

### Step 4 — Compute corpus_stats and emit ingest_record
Compute `corpus_stats`:
- `total_turns`: count of entries in `turn_records`
- `total_tokens`: sum of `token_count` across all turns
- `pending_tool_calls_count`: count of `turn_records` entries where `tool_use` is non-null and no matching `tool_result` exists
- `mode`: echoed from `session_metadata.mode`

Assemble `ingest_record`: `{session_metadata, turn_records, corpus_stats}`. Emit `ingest_record` (combined output signal), `turn_records`, and `corpus_stats` on their respective output ports.

## Scale gates
- tokens: 2000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); if second attempt exceeds 120s, emit partial ingest_record with `timeout_flag: true` and proceed
- malformed output: if turn_records list is empty after parsing, re-attempt parse with looser delimiter heuristics once; HALT if still empty
- missing input: HALT "N-INGEST: session_metadata missing" if session_metadata absent; HALT "N-INGEST: mode field missing" if mode field absent
- format-mismatch on Edge: re-read session_metadata directly from invocation payload; do not infer mode from content heuristics
