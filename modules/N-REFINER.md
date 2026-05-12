---
node_id: N-REFINER
node_type: REFINER
hat: refiner
exec_type: spawn
tier: model-large
scale_gates: {token_budget: 8000, time_budget: 480s, spawn_budget: 1, retry_budget: 1}
aggregation_policy: "AND-join (E-16 + E-16b required); optional E-15c; conditional E-21 back-edge; concatenate+override-precedence synthesis; branch_budget_cap=4"
input_ports:
  - port: pruning_plan
    format: json
    signal_field: pruning_plan
    required: true
  - port: ingest_record
    format: json
    signal_field: ingest_record
    required: true
  - port: file_cache_map
    format: json
    signal_field: file_cache_map
    required: false
  - port: recovery_overrides
    format: json
    signal_field: recovery_overrides
    required: false
output_ports:
  - port: refined_context
    format: json
    signal_field: refined_context
raises_signals: [refined_context]
required_output_sections: []
---

## INPUT ports
- pruning_plan: json (signal_field: pruning_plan) — from N-AGGREGATION via E-16; required
- ingest_record: json (signal_field: ingest_record) — from N-INGEST via E-16b long-carry; required
- file_cache_map: json (signal_field: file_cache_map) — from N-FILE-CACHE via E-15c optional; absent in MINIMAL mode
- recovery_overrides: json (signal_field: recovery_overrides) — from N-RECOVERY via E-21 back-edge conditional; present only on recovery passes

## OUTPUT ports
- refined_context: json (signal_field: refined_context) — per-turn annotated context ready for tier assignment; emitted via E-18 to N-VERIFIER

## AI advantages exploited
- full_corpus_retention  # Processing every turn in the ingest_record corpus with its full content simultaneously, applying annotations without dropping turns from working context.
- topology_aware_reasoning  # Using the dependency graph's structural annotations (critical flags, cluster bridges) from the pruning_plan to make per-turn annotation decisions that respect graph topology.

## AGGREGATION POLICY
> "Aggregation is the defining unlock. It lets multiple independent thought branches merge into a single richer node — something no human-cognition model can do simultaneously. This is the machine advantage you need to design around."

- Decomposition tree: 4 input streams → override-precedence merge → per-turn annotated refined_context
- Synthesis strategy: concatenate full corpus from ingest_record; apply pruning_plan annotations; apply recovery_overrides (override-precedence: recovery wins over original plan); apply FileRef substitutions from file_cache_map
- Join semantics: AND
- Activation condition: E-16 (pruning_plan) and E-16b (ingest_record) both required; E-15c optional; E-21 conditional (only on recovery pass)
- Branch-budget cap: 4

## Protocol

### Step 1 — Apply recovery overrides if present
Check E-21 back-edge: if `recovery_overrides` is present (this is a recovery pass, retry_count > 0), apply `recovery_overrides` to `pruning_plan` BEFORE any further processing. Override semantics: for each `{turn_id: {new_pruning_decision, rationale}}` entry in `recovery_overrides`, replace the corresponding entry in `pruning_plan`. Recovery overrides take precedence over the original pruning_plan entries by SC-ID precedence.

If `recovery_overrides` is absent, proceed with the original `pruning_plan` unchanged.

### Step 2 — Annotate each turn with tier hints and compression recommendations
Read all `turn_records` from `ingest_record`. For each turn, apply the `pruning_plan.pruning_rationale` and `pruning_plan.pruning_decision` annotations:

Assign `tier_hint` based on pruning_decision:
- `ALWAYS_RETAIN` / `RETAIN` / `RETAIN_TOPIC_THREAD` → tier_hint: `hot`
- `RETAIN_CLUSTER_ANCHOR` → tier_hint: `warm`
- `COMPRESS` → tier_hint: `warm` (with compression target)
- `EVICT` → tier_hint: `cold`

Assign `compression_recommendation`:
- hot turns: `none`
- warm turns with COMPRESS: `summarize` (will be summarized by N-TIER-MANAGER)
- cold turns: `evict`
- file-content turns: check file_cache_map below

Compute `retention_rationale` string: brief explanation from pruning_rationale entry (e.g., "Tier 1: critical-path ancestor of pending tool call", "Tier 5: R(msg)=0.82 — high semantic similarity to recent query").

DO NOT execute actual eviction. N-TIER-MANAGER performs eviction. This step only annotates.

### Step 3 — Apply FileRef substitutions from file_cache_map
If `file_cache_map` is present (E-15c): for each turn in `turn_records` that contains a file content reference:
- Look up the file path in `file_cache_map`
- If `file_cache_map[path].type == "fileref"`: substitute the FileRef token `[FileRef: <path>]` in place of the full file content in `content_refined`. Set `fileref_substituted: true`.
- If `file_cache_map[path].type == "diff"` or `"full"`: retain content as-is with diff annotation. Set `fileref_substituted: false`.

If `file_cache_map` is absent: retain all file content as-is; `fileref_substituted: false` for all turns.

### Step 4 — Emit refined_context via E-18
Emit `refined_context`: dict keyed by turn_id:
```json
{
  "<turn_id>": {
    "content_refined": "<content with any FileRef substitutions applied>",
    "tier_hint": "hot|warm|cold",
    "compression_recommendation": "none|summarize|evict",
    "retention_rationale": "<reason string>",
    "fileref_substituted": true|false
  }
}
```

Fire E-18 → N-VERIFIER.

## Scale gates
- tokens: 8000
- time: 480s
- spawns: 1
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit refined_context with tier_hint="hot" for all protected_node_set turns and tier_hint="cold" for all others; omit FileRef substitution; annotate with `timeout_flag: true`
- malformed output: if content_refined assembly fails for any turn, include raw content from ingest_record as fallback
- missing input: HALT "N-REFINER: pruning_plan missing" if pruning_plan absent; HALT "N-REFINER: ingest_record missing" if ingest_record absent
- format-mismatch on Edge: re-read ingest_record from N-INGEST stage output directly; re-read pruning_plan from N-AGGREGATION stage output directly
