---
node_id: N-TRIGGER-EVAL
node_type: GATE
hat: gate
exec_type: inline
tier: model-small
scale_gates: {token_budget: 1000, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
input_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
    required: true
output_ports:
  - port: trigger_signal
    format: json
    signal_field: trigger_signal
  - port: trigger_phase
    format: json
    signal_field: trigger_phase
  - port: trigger_noop
    format: json
    signal_field: trigger_noop
raises_signals: [trigger_signal, trigger_phase]
required_output_sections: [trigger_evaluation]
---

## INPUT ports
- session_meta: json (signal_field: session_meta)

## OUTPUT ports
- trigger_signal: json (signal_field: trigger_signal) — bool; true if pipeline should proceed
- trigger_phase: json (signal_field: trigger_phase) — str; one of {manual, yellow, orange, red}
- trigger_noop: json (signal_field: trigger_noop) — bool; true if E-02b NO-OP terminal fires

## AI advantages exploited
- consistency_at_scale  # Applying the same threshold arithmetic uniformly to every auto-mode invocation without drift in boundary conditions.

## Protocol

### Step 1 — MANUAL mode fast path
Read `session_meta.mode`. If `mode == MANUAL`: set `trigger_signal = true`, `trigger_phase = "manual"`, `trigger_noop = false`. Fire fan-out edges E-04 (→N-CLASSIFIER), E-05 (→N-FILTER), E-05c (→N-GENERATOR) immediately. Write trigger_evaluation section and halt this node. Do not proceed to Step 2.

### Step 2 — AUTOMATIC mode threshold computation
Read `current_token_count` and `context_window_size` from `session_meta.ingest_record_ref.session_metadata`. Compute:
```
utilization = current_token_count / context_window_size
```
If `context_window_size` is absent or zero, treat utilization as 1.0 (fail-open: assume Red threshold to avoid missing a needed prune).

### Step 3 — Classify utilization and check interval
Apply threshold classification:
- `utilization < 0.70` → below Yellow
- `0.70 ≤ utilization < 0.85` → Yellow phase
- `0.85 ≤ utilization < 0.95` → Orange phase
- `utilization ≥ 0.95` → Red phase

Also check scheduled interval: if `session_meta.ingest_record_ref.corpus_stats.total_turns % 15 == 0` AND `total_turns > 0`, the scheduled interval is met.

### Step 4 — Emit trigger decision
**No trigger condition:** if utilization is below Yellow threshold AND the scheduled interval has NOT been met → set `trigger_signal = false`, `trigger_noop = true`. Fire E-02b forward-conditional to NO-OP-TERMINAL. Do not fire E-04/E-05/E-05c.

**Trigger condition:** if utilization ≥ Yellow threshold OR scheduled interval met → set `trigger_signal = true`, `trigger_noop = false`. Assign `trigger_phase` from the utilization classification (yellow/orange/red). Fire fan-out edges E-04 (→N-CLASSIFIER), E-05 (→N-FILTER), E-05c (→N-GENERATOR).

Write `trigger_evaluation` output section:
```
trigger_evaluation:
  mode: <mode>
  trigger_signal: <bool>
  trigger_phase: <phase>
  utilization: <float>
  threshold_used: <float>
  interval_check: <bool>
  routing: <"fan-out E04/E05/E05c" | "E-02b NO-OP">
```

## Scale gates
- tokens: 1000
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); treat as trigger==true with trigger_phase="orange" (fail-open for safety); fire fan-out E-04/E-05/E-05c
- malformed output: if trigger_phase cannot be determined, default to "orange" and proceed with trigger_signal=true
- missing input: HALT "N-TRIGGER-EVAL: session_meta missing" if session_meta signal absent
- format-mismatch on Edge: re-read session_meta from N-PREFLIGHT stage output directly
