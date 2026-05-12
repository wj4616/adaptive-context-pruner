---
node_id: N-SCORER-CREATIVE
node_type: SCORER
hat: scorer
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 3000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: graph_structure
    format: json
    signal_field: graph_structure
    required: true
  - port: domain_gate
    format: json
    signal_field: domain_gate
    required: false
output_ports:
  - port: creative_scores
    format: json
    signal_field: creative_scores
raises_signals: [creative_scores]
required_output_sections: []
---

## INPUT ports
- graph_structure: json (signal_field: graph_structure) — from N-GENERATOR via E-07
- domain_gate: json (signal_field: domain_gate) — from N-CLASSIFIER via E-10 forward-conditional; absent if E-10 did not fire

## OUTPUT ports
- creative_scores: json (signal_field: creative_scores) — dict {turn_id: R_score} with creative domain modifiers; null-signal when E-10 gate is false

## AI advantages exploited
- consistency_at_scale  # Applying the R(msg) formula with creative-specific modifiers uniformly to every turn, detecting brainstorm-thread value signals that require full-corpus comparison to score accurately.

## Protocol

### Step 1 — Check domain gate
Check whether E-10 fired (domain_gate is present and evaluates to true for creative domain). If the gate did not fire (N-CLASSIFIER determined creative domain probability < 0.4 and domain_label != "creative-brainstorming"), emit `creative_scores: null` immediately and return. N-AGGREGATION accepts null as a null-tolerant stream.

### Step 2 — Apply R(msg) formula to all turns
For each turn in `graph_structure.nodes`, compute:
```
R(msg) = 0.3 × recency + 0.3 × semantic_similarity + 0.2 × graph_centrality + 0.2 × user_importance
```

**recency**: normalized decay score = `turn_index / max_turn_index` (linear; turn 0 scores 0.0, most recent turn scores 1.0)

**semantic_similarity**: compute token-level overlap between this turn's content and the content of the most recent user-role turn. Normalize to [0.0, 1.0] by dividing shared token count by the smaller turn's token count.

**graph_centrality**: `(in_degree + out_degree) / max_degree_in_graph` where degree counts edges in `graph_structure.edges`. Normalize to [0.0, 1.0].

**user_importance**: presence of any of: (a) user explicitly affirms or extends this turn's idea in a subsequent turn, (b) this turn introduces a concept referenced by ≥2 subsequent turns, (c) this turn contains a direct response to a user creative prompt. Score 1.0 if any condition met, 0.5 if one condition partially met, 0.0 otherwise.

### Step 3 — Compute creative-domain modifiers
For each turn, compute a domain modifier and apply it multiplicatively to R(msg):

**Boost factors** (multiply R(msg) by 1.2, capped at 1.0):
- Turn contains brainstorming or idea-generation content (novel concepts, "what if" framings, design proposals)
- Turn contains concept-development or exploratory reasoning
- Turn introduces an idea that is explicitly built upon in ≥1 later turn (forward reference)
- Turn contains an exploratory question that opens a new creative thread

**Penalty factors** (multiply R(msg) by 0.7):
- Turn content is only a low-engagement acknowledgment ("OK", "Sure", "Got it") with no creative contribution
- Turn contains administrative or meta-discussion (scheduling, format preferences) unrelated to the creative work

### Step 4 — Emit creative_scores
Emit `creative_scores: {turn_id: R_score_with_modifier}` for all turns in graph_structure. Each score is clamped to [0.0, 1.0].

## Scale gates
- tokens: 3000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit partial creative_scores for the first 50% of turns processed; annotate with `partial_flag: true`
- malformed output: if R(msg) arithmetic fails for any turn, assign default score of 0.5 for that turn
- missing input: HALT "N-SCORER-CREATIVE: graph_structure missing" if graph_structure signal absent
- format-mismatch on Edge: re-read graph_structure from N-GENERATOR stage output directly
