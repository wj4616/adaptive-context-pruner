---
node_id: N-CLASSIFIER
node_type: CLASSIFIER
hat: classifier
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 2000, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
input_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
    required: true
output_ports:
  - port: domain_label
    format: json
    signal_field: domain_label
  - port: domain_probability
    format: json
    signal_field: domain_probability
  - port: domain_gate
    format: json
    signal_field: domain_gate
raises_signals: [domain_label, domain_probability]
required_output_sections: [domain_classification]
---

## INPUT ports
- session_meta: json (signal_field: session_meta)

## OUTPUT ports
- domain_label: json (signal_field: domain_label) — primary domain string
- domain_probability: json (signal_field: domain_probability) — per-domain probability dict
- domain_gate: json (signal_field: domain_gate) — conditional routing signal; fires E-09 (technical) and/or E-10 (creative)

## AI advantages exploited
- multi_perspective_simulation  # Simultaneously evaluating the conversation through five distinct domain frames (technical, creative, research, planning, auto-detect) rather than applying a single classifier pass.

## Protocol

### Step 1 — Scan turn_records for domain indicators
Read `turn_records` from `session_meta.ingest_record_ref`. Scan all turns for the following domain signals:

- **technical-debugging signals**: presence of tool calls (especially `bash`, `read_file`, `edit`), error messages, stack traces, code blocks, compiler output, log lines, debugging language ("exception", "traceback", "segfault", "undefined", "NaN")
- **creative-brainstorming signals**: brainstorming language ("what if", "imagine", "let's explore", "ideas for", "design", "concept"), creative domain vocabulary (art, music, story, persona), open-ended generation requests
- **research signals**: citation language, factual queries, "according to", "research on", "summarize", web search tool calls
- **planning signals**: task lists, step-by-step directives, project structure discussion, milestone language, "implementation plan", "phase"
- **auto-detect**: insufficient signal above — fewer than 3 domain-specific indicators across all turns

### Step 2 — Compute domain_probability dict
Assign probability scores for each domain by counting domain-specific turn indicators and normalizing:
```
domain_probability: {
  technical-debugging: 0.0–1.0,
  creative-brainstorming: 0.0–1.0,
  research: 0.0–1.0,
  planning: 0.0–1.0
}
```
Values are independent probabilities (multi-label: they may sum to > 1.0 for mixed conversations). Each probability represents confidence that this domain is significantly active in the conversation.

### Step 3 — Assign domain_label
Assign `domain_label` as the domain with the highest probability. If the highest probability < 0.4, assign `domain_label = "auto-detect"` (insufficient domain signal).

### Step 4 — Emit domain_gate routing signals
Emit `domain_label` and `domain_probability`.

Fire E-09 (→N-SCORER-TECHNICAL forward-conditional) if:
`domain_label == "technical-debugging"` OR `domain_probability["technical-debugging"] >= 0.4`

Fire E-10 (→N-SCORER-CREATIVE forward-conditional) if:
`domain_label == "creative-brainstorming"` OR `domain_probability["creative-brainstorming"] >= 0.4`

Both E-09 and E-10 may fire simultaneously for ambiguous mixed-domain conversations.

If `domain_label == "auto-detect"` and neither threshold is met: fire BOTH E-09 and E-10 (fail-open — both scorers run; null-tolerant aggregation downstream handles the redundancy).

Emit `domain_gate` signal encoding the routing decisions taken.

Write `domain_classification` required output section.

## Scale gates
- tokens: 2000
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); default to `domain_label="auto-detect"`, fire both E-09 and E-10
- malformed output: if probability dict cannot be computed, default to uniform 0.25 across all 4 domains; fire both E-09 and E-10
- missing input: HALT "N-CLASSIFIER: session_meta missing" if session_meta signal absent
- format-mismatch on Edge: re-read session_meta from N-TRIGGER-EVAL stage output directly
