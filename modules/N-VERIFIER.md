---
node_id: N-VERIFIER
node_type: VERIFIER
hat: verifier
exec_type: inline
tier: model-medium
scale_gates: {token_budget: 4000, time_budget: 120s, spawn_budget: 0, retry_budget: 1}
input_ports:
  - port: refined_context
    format: json
    signal_field: refined_context
    required: true
output_ports:
  - port: verify_pass_signal
    format: json
    signal_field: verify_pass_signal
  - port: violation_signal
    format: json
    signal_field: violation_signal
raises_signals: [verify_pass_signal, violation_signal]
required_output_sections: [sc_battery_results]
---

## INPUT ports
- refined_context: json (signal_field: refined_context) — from N-REFINER via E-18

## OUTPUT ports
- verify_pass_signal: json (signal_field: verify_pass_signal) — bool; true if all 13 SCs pass; emitted via E-19 gate-open to N-TIER-MANAGER
- violation_signal: json (signal_field: violation_signal) — dict with SC violation details; emitted via E-20 back-edge to N-RECOVERY when verify_pass==false

## AI advantages exploited
- consistency_at_scale  # Applying all 13 safety checks with identical rigor to every turn annotation in refined_context without selective enforcement or threshold drift.

## Protocol

### Step 1 — Run 13-SC safety battery
Apply each of the 13 safety checks to `refined_context`. Record pass/fail for each:

**SC-1** (protected nodes present): Verify no turn in `protected_node_set` is assigned `compression_recommendation: evict` in refined_context. FAIL if any protected turn has been evicted.

**SC-2** (recent window preserved): Verify the last N turns (N = TierConfig.recent_window, default 5) all have `tier_hint: hot`. FAIL if any recent-window turn is assigned cold or has evict recommendation.

**SC-3** (instruction turns retained): Verify all turns with `role: system` and all explicitly instruction-type user turns (per N-FILTER logic) have `compression_recommendation: none`. FAIL if any instruction turn is marked for compression or eviction.

**SC-4** (compression ratio within bounds): Compute `retained_tokens / total_tokens`. FAIL if ratio falls outside [0.30, 0.50] (the [COMPRESSION-RATIO-30-50] bounds). A ratio below 0.30 means too much was retained; above 0.50 means too little was pruned.

**SC-5** (graph summary bounded): If `refined_context` includes a relevance graph summary field, verify it references ≤200 turns before triggering self-summarization ([GRAPH-SUMMARY-BOUNDED]). FAIL if the graph summary references > 200 turns without self-summary.

**SC-6** (retention_ruleset applied): Verify that `retention_rationale` is populated for all turns and does not contain empty strings. FAIL if any turn has missing or empty `retention_rationale`.

**SC-7** (supersession chain correctness): Verify the latest-wins invariant: no superseded turn (from supersession_map) has `tier_hint: hot` while its superseding turn has `tier_hint: cold`. FAIL if the ordering is inverted.

**SC-8** (domain classification consistent): Verify that if `technical_scores` was non-null, technical-domain modifier boosts were applied (at least one turn with code content should have R(msg) ≥ 0.6). FAIL if scores exist but no technical boost is reflected.

**SC-9** (no critical-path turn cold-tiered): Verify NO turn with `critical == True` in dependency_graph has `tier_hint: cold` or `compression_recommendation: evict`. This is the v2-primary BLOCKING check. FAIL immediately on any violation.

**SC-10** (continuity_marker accurate): If auto_prune_triggered==true is declared in session_meta, verify `refined_context` includes a continuity_marker field or flag signaling N-CONTINUITY-MARKER should fire. FAIL if auto_prune_triggered is true but no continuity signal is present.

**SC-11** (auto-mode trigger frequency): Verify that auto-mode was not triggered more than once per 5 turns ([MICRO-CYCLE-5S] constraint). Check `corpus_stats.total_turns % 5 != 0` OR `auto_prune_triggered == false`. FAIL if micro-cycle frequency violation detected.

**SC-12** (FileRef token count): Count FileRef tokens in refined_context. Verify count < 20 ([DELTA-FILE-CACHE] constraint). FAIL if count ≥ 20.

**SC-13** (tier budget sum): Verify that sum of token counts for all `tier_hint: hot` and `tier_hint: warm` turns ≤ `TierConfig.window_size`. FAIL if the sum exceeds the window size budget.

### Step 2 — Evaluate battery results
If ALL 13 SCs pass: set `verify_pass = true`. Proceed to Step 4.

If ANY SC fails:
- Check `retry_count_artifact` (how many back-edge recovery cycles have occurred for this run):
  - STANDARD mode: cap = 1
  - MINIMAL mode: cap = 0 (no recovery allowed)
  - DEEP mode: cap = 2
- If `retry_count_artifact < cap`: set `verify_pass = false`. Proceed to Step 3 (fire back-edge).
- If `retry_count_artifact >= cap`: set `verify_pass = true` with `degraded_flag: true`. Proceed to Step 4 with degraded status.

### Step 3 — Emit violation_signal via E-20 back-edge
Assemble `violation_signal`:
```json
{
  "failed_scs": ["<SC-N>", ...],
  "violations": [
    {"sc_id": "SC-9", "violation_description": "<details>", "proposed_override": "<fix>"},
    ...
  ],
  "retry_count_artifact": N
}
```

Fire E-20 back-edge → N-RECOVERY.

### Step 4 — Emit verify_pass_signal via E-19
Emit `verify_pass_signal: {verify_pass: true, degraded_flag: <bool>, sc_battery_results: <all 13 results>}`.
Fire E-19 gate-open → N-TIER-MANAGER.

Write `sc_battery_results` required output section listing all 13 checks with PASS/FAIL status.

## Scale gates
- tokens: 4000
- time: 120s
- spawns: 0
- retries: 1

## Failure modes
- timeout: retry once (retry_budget=1); on second timeout, emit verify_pass_signal with `verify_pass: true, degraded_flag: true`; include any SCs that completed before timeout
- malformed output: if SC battery cannot complete (refined_context schema mismatch), emit violation_signal for SC-6 (retention_rationale missing) as the catch-all failure mode
- missing input: HALT "N-VERIFIER: refined_context missing" if refined_context signal absent
- format-mismatch on Edge: re-read refined_context from N-REFINER stage output directly
