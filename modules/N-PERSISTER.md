---
node_id: N-PERSISTER
node_type: PERSISTER
hat: no-llm
exec_type: inline
tier: no-llm
scale_gates: {token_budget: 500, time_budget: 30s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: continuity_output
    format: json
    signal_field: continuity_output
    required: false
  - port: rendered_output
    format: json
    signal_field: rendered_output
    required: false
output_ports:
  - port: session_artifact
    format: json
    signal_field: session_artifact
raises_signals: [session_artifact]
required_output_sections: []
---

## INPUT ports
- continuity_output: json (signal_field: continuity_output) — from N-CONTINUITY-MARKER via E-24; active when auto_prune_triggered==true
- rendered_output: json (signal_field: rendered_output) — from N-FORMATTER via E-24b; active when auto_prune_triggered==false

## OUTPUT ports
- session_artifact: json (signal_field: session_artifact) — terminal output written to output path; emitted via E-25 terminal → SKILL_OUTPUT

## AI advantages exploited
- consistency_at_scale  # Mechanical write with deterministic session_artifact schema — no LLM reasoning required; format applied uniformly.

## Protocol

### Step 1 — Determine active input path (XOR semantics)
Exactly one of E-24 (continuity_output) or E-24b (rendered_output) is active per run. Determine which is present:

- If `continuity_output` is non-null (E-24 path): use `continuity_output.content` as the output document. This path is taken when `auto_prune_triggered == true`.
- If `rendered_output` is non-null (E-24b path): use `rendered_output.content` as the output document. This path is taken when `auto_prune_triggered == false`.
- If BOTH are non-null: this is an AP-4 XOR violation — use `continuity_output` (auto_prune path takes priority) and log `xor_violation: true`.
- If NEITHER is non-null: HALT with `halt-on-null-at-persister: both input signals absent`.

### Step 2 — Write session_artifact ([NO-CROSS-SESSION-PERSISTENCE])
Scope all writes within the skill's session state. No cross-session state mutations. No host-filesystem writes outside the skill package output path.

Format `session_artifact`:
```json
{
  "session_id": "<from session_meta.session_id or generated UUID>",
  "generated_at": "<current timestamp ISO 8601>",
  "skill_name": "adaptive-context-pruner",
  "version": "<from YAML frontmatter version field>",
  "pruning_applied": "<true if any turns were evicted or compressed; false if NO-OP>",
  "output_content": "<the assembled document string from Step 1>",
  "metadata": {
    "total_turns_input": "<from YAML frontmatter>",
    "compression_ratio_overall": "<from YAML frontmatter>",
    "pruning_phase": "<from YAML frontmatter>",
    "auto_prune_triggered": "<from YAML frontmatter>"
  }
}
```

Write `session_artifact` to the output path declared in session_meta. This is a mechanical write operation — no LLM reasoning required.

### Step 3 — Verify write success
Confirm the write completed without error. If a filesystem or serialization error occurs: retry once (retry_budget=1). On retry failure: emit partial `session_artifact` with `write_error: "<error description>"` annotation and proceed to Step 4.

### Step 4 — Emit E-25 terminal signal → SKILL_OUTPUT
Emit `session_artifact` via E-25 terminal signal → SKILL_OUTPUT. This is the pipeline's terminal output. The skill execution is complete.

## Scale gates
- tokens: 500
- time: 30s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit partial session_artifact with write_error annotation; fire E-25 regardless to ensure terminal signal is always emitted
- malformed output: if session_artifact schema cannot be assembled, emit raw output_content directly with minimal metadata wrapper
- missing input: HALT "N-PERSISTER: both continuity_output and rendered_output absent — null-at-persister" if both input signals are null
- format-mismatch on Edge: re-read continuity_output from N-CONTINUITY-MARKER stage output directly; re-read rendered_output from N-FORMATTER stage output directly
