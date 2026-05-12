---
node_id: N-FORMATTER
node_type: FORMATTER
hat: formatter
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 6000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: protected_node_set
    format: json
    signal_field: protected_node_set
    required: true
  - port: tier_state
    format: json
    signal_field: tier_state
    required: true
  - port: tier_state_final
    format: json
    signal_field: tier_state_final
    required: true
output_ports:
  - port: formatted_output
    format: json
    signal_field: formatted_output
  - port: rendered_output
    format: json
    signal_field: rendered_output
raises_signals: [formatted_output, rendered_output, auto_prune_triggered]
required_output_sections: [skill_output_yaml, skill_output_body]
---

## INPUT ports
- protected_node_set: json (signal_field: protected_node_set) — from N-FILTER via E-17 long-carry (W2→W8, 6-wave skip)
- tier_state: json (signal_field: tier_state) — from N-TIER-MANAGER via E-17b
- tier_state_final: json (signal_field: tier_state_final) — from N-TIER-MANAGER via E-22

## OUTPUT ports
- formatted_output: json (signal_field: formatted_output) — assembled output including YAML frontmatter + 5-section body; includes conditional 6th section trigger; emitted via E-23 forward-conditional when auto_prune_triggered==true
- rendered_output: json (signal_field: rendered_output) — final rendered output for direct persistence; emitted via E-24b when auto_prune_triggered==false

## AI advantages exploited
- consistency_at_scale  # Assembling the 13-field YAML frontmatter and 5-section body with identical structure across all runs, ensuring no field is silently omitted regardless of which pipeline path was taken.

## Protocol

### Step 1 — Assemble YAML frontmatter (13 fields)
Produce the YAML frontmatter block. All 13 fields must be populated; no field may be null without explicit N/A rationale:

```yaml
skill_name: adaptive-context-pruner
version: <from TierConfig or session_meta>
generated_at: <current timestamp ISO 8601>
domain: <from domain_label emitted by N-CLASSIFIER>
retention_ruleset_applied: <from tier_state.ruleset_summary>
total_turns_input: <from corpus_stats.total_turns>
compression_ratio_overall: <retained_tokens / total_tokens, computed from tier_state_final>
topic_switch_count: <from topic_switch_map.count — carried via session state>
supersession_count: <count of entries in supersession_map — carried via session state>
verify_pass: <from verify_pass_signal.verify_pass or degraded_flag status>
conflict_annotations: <from supersession_map.conflict_annotations — null if none>
auto_prune_triggered: <true if mode==AUTOMATIC and trigger_signal==true; false otherwise>
pruning_phase: <from tier_state_final.pruning_phase — one of none/yellow/orange/red>
```

Verify all 13 fields are populated before proceeding. If any field value is unavailable, substitute `"N/A: <reason>"` rather than null.

### Step 2 — Build 5-section body
Assemble the 5 body sections using `tier_state_final` and `protected_node_set`:

**Section 1 — Effective Instructions:** All turns in `protected_node_set` with `role: system` or instruction-type user turns. Emit verbatim content. Label: `## Effective Instructions`.

**Section 2 — Superseded Instructions:** All turns in `supersession_map` (superseded_turn_id entries) with their `supersession_rationale`. Emit original content with strikethrough notation and superseding reference. Label: `## Superseded Instructions (Archived)`.

**Section 3 — Compressed Conversation:** All turns with `tier: hot` or `tier: warm` from `tier_state_final`, in turn_index order. Apply FileRef substitutions for any `fileref_substituted: true` turns. Warm turns emit their compressed summary rather than full content. Label: `## Conversation Context`.

**Section 4 — Relevance Graph Summary:** Summarize the dependency graph topology. Bounded to ≤200 turns before triggering self-summarization ([GRAPH-SUMMARY-BOUNDED] rule): if `total_turns_input > 200`, emit a meta-summary of the graph structure (edge counts, critical-path summary, top-3 hub turns by degree) rather than a full node enumeration. Label: `## Dependency Graph Summary`.

**Section 5 — Active Topic Thread:** Emit the current `active_topic_thread` label and the turn IDs constituting the active thread. This provides context-continuity for the next conversation turn. Label: `## Active Topic Thread`.

### Step 3 — Route based on auto_prune_triggered
If `auto_prune_triggered == true`:
- Prepare `formatted_output` with all 5 sections assembled but leave a placeholder for the 6th continuity section
- Fire E-23 forward-conditional gate → N-CONTINUITY-MARKER
- Do NOT emit rendered_output yet; N-CONTINUITY-MARKER will append and then route to N-PERSISTER

If `auto_prune_triggered == false`:
- Set `rendered_output` = the complete assembled document (frontmatter + 5 sections)
- Emit `rendered_output`
- Fire E-24b → N-PERSISTER directly

### Step 4 — Verify YAML frontmatter completeness
Before emitting, verify all 13 frontmatter fields are non-null and non-empty-string. Confirm `skill_output_yaml` and `skill_output_body` required sections are present.

## Scale gates
- tokens: 6000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit minimal rendered_output with frontmatter only (no body sections); set `truncated_output: true`
- malformed output: if any of the 3 required inputs produces schema errors, emit partial output with the sections that could be assembled; note missing fields in frontmatter
- missing input: HALT "N-FORMATTER: tier_state_final missing" if tier_state_final absent (E-22 is required per graph spec — should never be absent)
- format-mismatch on Edge: re-read protected_node_set from N-FILTER stage output directly; re-read tier_state_final from N-TIER-MANAGER stage output directly
