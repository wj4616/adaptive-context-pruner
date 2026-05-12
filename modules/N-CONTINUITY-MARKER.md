---
node_id: N-CONTINUITY-MARKER
node_type: GENERATOR
hat: generator
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 1500, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
activation: "conditional — fires only when auto_prune_triggered==true (E-23 forward-conditional gate)"
input_ports:
  - port: formatted_output
    format: json
    signal_field: formatted_output
    required: true
output_ports:
  - port: continuity_output
    format: json
    signal_field: continuity_output
  - port: continuity_marker
    format: json
    signal_field: continuity_marker
raises_signals: [continuity_marker, continuity_output]
required_output_sections: []
---

## INPUT ports
- formatted_output: json (signal_field: formatted_output) — from N-FORMATTER via E-23 forward-conditional gate; fires only when auto_prune_triggered==true

## OUTPUT ports
- continuity_output: json (signal_field: continuity_output) — formatted_output + appended continuity_marker; emitted via E-24 to N-PERSISTER
- continuity_marker: json (signal_field: continuity_marker) — human-readable pruning summary string (≤500 tokens)

## AI advantages exploited
- super_human_recall  # Generating a precise accounting of what was evicted, compressed, and retained from a full-corpus tier manifest, without needing to re-read the conversation to produce an accurate summary.

## Protocol

### Step 1 — Verify AP-V37 guard (mandatory)
Check: is `auto_prune_triggered == true`? If this node was somehow reached with `auto_prune_triggered == false`: log AP-V37 violation (`"N-CONTINUITY-MARKER reached with auto_prune_triggered==false — AP-V37 guard triggered"`). Return without emitting any output. Do NOT produce or append a continuity marker in this case.

Confirm `formatted_output` is present and non-null before proceeding.

### Step 2 — Read tier_state_final for pruning inventory
Read `tier_state_final` from the context (carried through formatted_output or session state). Identify:
- Turns that were evicted (action: `evict`): count and topic labels
- Turns that were compressed to summaries (action: `compress`): count and which episodes
- FileRef substitutions applied: count and file paths
- Total token reduction: `total_tokens_input - retained_tokens`
- `compression_ratio_overall` from the YAML frontmatter

### Step 3 — Generate continuity_marker (≤500 tokens per [MICRO-CYCLE-5S])
Generate the human-readable continuity marker string. Must be ≤500 tokens to stay within [MICRO-CYCLE-5S] budget. Format:

```markdown
## Auto-Pruning Applied

**What was pruned:** <bulleted list of evicted/compressed items with brief rationale, e.g., "3 completed tool-chain result turns (no pending dependents)", "5 low-relevance turns from prior topic thread 'file parsing'">

**What remains active:** <summary of retained context: e.g., "All system instructions retained verbatim. Current topic thread '<topic>' preserved. 2 pending tool calls and their dependency chains retained.">

**Compression achieved:** <X turns pruned; N turns compressed to summaries; compression_ratio_overall Y%>

**Continuity signal:** <one sentence confirming no critical context was lost, e.g., "No critical-path or instruction-type turns were evicted.">
```

### Step 4 — Append continuity_marker and emit continuity_output
Append `continuity_marker` to `formatted_output` as a new section (Section 6: Auto-Pruning Report). Assemble `continuity_output`: the complete document with all 5 body sections plus the appended continuity marker.

Emit `continuity_marker` (the marker string alone) and `continuity_output` (the full document). Fire E-24 → N-PERSISTER.

## Scale gates
- tokens: 1500
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit minimal continuity_marker ("Auto-pruning applied. See tier_state_final for details.") and append to formatted_output; fire E-24 regardless
- malformed output: if tier_state_final is unavailable, generate continuity_marker from formatted_output metadata only (frontmatter fields: compression_ratio_overall, total_turns_input)
- missing input: HALT "N-CONTINUITY-MARKER: formatted_output missing" if formatted_output signal absent
- format-mismatch on Edge: re-read formatted_output from N-FORMATTER stage output directly
