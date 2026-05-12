---
node_id: N-ANALYZER-CORRECTIONS
node_type: ANALYZER
hat: analyzer
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: graph_structure
    format: json
    signal_field: graph_structure
    required: true
output_ports:
  - port: supersession_map
    format: json
    signal_field: supersession_map
raises_signals: [supersession_map, conflict_signal]
required_output_sections: []
---

## INPUT ports
- graph_structure: json (signal_field: graph_structure) — from N-GENERATOR via E-08b

## OUTPUT ports
- supersession_map: json (signal_field: supersession_map) — dict {superseded_turn_id: {superseding_turn_id, supersession_type, confidence, conflict_annotation?}}; emitted via declared edge E-14 to N-AGGREGATION (AP-V29 compliance)

## AI advantages exploited
- cross_document_pattern_recognition  # Scanning the entire conversation corpus to trace supersession chains and detect contradiction patterns spanning turns that are far apart in the sequence, without losing earlier instructions from memory.

## Protocol

### Step 1 — Scan for correction patterns
Read `turn_records` from graph_structure. Scan all turns for the following correction and supersession patterns:

**Explicit correction openers** (high confidence, 0.9):
- "Actually, ...", "I meant ...", "Disregard that ...", "Never mind ...", "Correction: ...", "To clarify, ..."
- "Let me rephrase ...", "I was wrong ...", "Forget what I said about ..."

**Imperative override patterns** (high confidence, 0.85):
- A later turn contains a new directive using "always", "never", "you must", "from now on", "instead" that contradicts an active directive in an earlier turn

**Mind-change patterns** (medium confidence, 0.6):
- A later turn asks to reverse a prior decision ("Actually use X instead of Y", "Let's go back to A approach")
- A later turn's stated preference directly conflicts with an earlier stated preference on the same subject

For each detected correction, identify the `superseding_turn_id` (the later turn) and the `superseded_turn_id` (the earlier turn being overridden).

### Step 2 — Apply latest-explicit-instruction-wins canonicalization
Build the `supersession_map` by chaining corrections: if turn A is superseded by turn B, and turn B is subsequently superseded by turn C, then turn A and turn B are both superseded by turn C. Apply transitive closure: the most recent override in a chain wins.

For each entry in the supersession_map, record:
- `superseded_turn_id`: the turn being overridden
- `superseding_turn_id`: the most recent authoritative override
- `supersession_type`: one of `explicit_correction`, `imperative_override`, `mind_change`
- `confidence`: float 0.0–1.0

### Step 3 — Detect unresolvable contradictions (AP-V7 guard)
Scan for cases where two active instructions (not yet superseded) cannot coexist. Examples:
- "Use Python" (turn 5, not superseded) AND "Use JavaScript" (turn 12, not superseded by any explicit override)
- "Always format output as JSON" (turn 3) AND "Format output as plain text" (turn 20, ambiguous — could be scoped or a mind-change)

For each detected contradiction: emit a `conflict_signal` annotation (AP-V7 guard: no silent deferral allowed). Include `{conflict_id, turn_ids_in_conflict, conflict_description, resolution_advisory}` in the `conflict_annotations` list embedded within `supersession_map`.

### Step 4 — Emit supersession_map via E-14
Emit `supersession_map` containing:
- All supersession entries (key: superseded_turn_id)
- `conflict_annotations` list (may be empty if no contradictions detected)

Fire E-14 declared edge to N-AGGREGATION. AP-V29 compliance: this edge is explicitly declared in the edge table and must carry the full supersession_map including any conflict_annotations.

## Scale gates
- tokens: 2000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit supersession_map with only high-confidence (≥0.85) corrections; omit conflict detection; annotate with `partial_flag: true`
- malformed output: if supersession chain transitive closure computation fails (cycle in supersession graph), break the cycle at the lowest-confidence link and annotate with `cycle_break_flag: true`
- missing input: HALT "N-ANALYZER-CORRECTIONS: graph_structure missing" if graph_structure signal absent
- format-mismatch on Edge: re-read graph_structure from N-GENERATOR stage output directly
