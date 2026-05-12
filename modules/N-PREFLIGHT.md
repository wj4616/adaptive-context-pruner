---
node_id: N-PREFLIGHT
node_type: PREFLIGHT
hat: gate
exec_type: inline
tier: model-small
scale_gates: {token_budget: 1500, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
input_ports:
  - port: ingest_record
    format: json
    signal_field: ingest_record
    required: true
output_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
  - port: refuse_signal
    format: json
    signal_field: refuse_signal
raises_signals: [preflight_pass, refuse_signal]
required_output_sections: [preflight_result]
---

## INPUT ports
- ingest_record: json (signal_field: ingest_record)

## OUTPUT ports
- session_meta: json (signal_field: session_meta) — emitted via E-03 gate-open on validation pass
- refuse_signal: json (signal_field: refuse_signal) — emitted via E-02 terminal on validation failure

## AI advantages exploited
- consistency_at_scale  # Applying the same validation ruleset uniformly to every invocation regardless of input size or structure.

## Protocol

### Step 1 — Read and unpack ingest_record
Read `ingest_record`. Verify the following top-level fields are present and non-null: `session_metadata`, `turn_records`, `corpus_stats`. If any top-level field is absent, immediately emit `refuse_signal` with `failure_reason: "ingest_record schema incomplete"` and fire E-02 terminal. Do not proceed.

### Step 2 — Mode-specific validation
Read `ingest_record.session_metadata.mode`.

**MANUAL mode validation:**
- `conversation_history` reference must be non-null in session_metadata
- `turn_records` list must contain at least 1 entry
- `corpus_stats.total_turns` must be ≥ 1

**AUTOMATIC mode validation:**
- `corpus_stats.total_tokens` (i.e., `current_token_count`) must be > 0
- `current_graph_state` in session_metadata must be non-null
- `turn_records` must contain at least 1 entry (the turn_delta record)

If any mode-specific check fails, emit `refuse_signal` with `failure_reason` naming the specific failed check, and fire E-02 terminal.

### Step 3 — Emit refuse_signal on failure
If any check in Steps 1 or 2 failed: emit `refuse_signal: {failure_reason: "<specific reason>", mode: "<mode if determinable>", timestamp: "<now>"}`. Fire E-02 terminal to REFUSE_OUTPUT. Do not proceed past this step.

### Step 4 — Emit session_meta on pass
All checks passed. Assemble `session_meta`: `{mode: <from session_metadata.mode>, ingest_record_ref: <ingest_record passthrough>, corpus_stats: <corpus_stats>}`. Emit `session_meta`. Fire E-03 gate-open to N-TRIGGER-EVAL. Write `preflight_result` section to output.

**preflight_result output section:**
```
preflight_result:
  status: PASS
  mode: <mode>
  total_turns: <corpus_stats.total_turns>
  total_tokens: <corpus_stats.total_tokens>
  checks_run: [schema_complete, mode_field_valid, corpus_non_empty, mode_specific_payload_valid]
  all_passed: true
```

## Scale gates
- tokens: 1500
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); emit refuse_signal with `failure_reason: "preflight_timeout"` and fire E-02 terminal
- malformed output: if session_meta cannot be assembled (unexpected schema error), emit refuse_signal and halt
- missing input: HALT "N-PREFLIGHT: ingest_record missing" if ingest_record signal absent
- format-mismatch on Edge: re-read ingest_record directly from N-INGEST stage output
