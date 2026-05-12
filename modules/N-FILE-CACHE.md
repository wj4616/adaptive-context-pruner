---
node_id: N-FILE-CACHE
node_type: IO
hat: cache
exec_type: inline
tier: model-small
scale_gates: {token_budget: 1500, time_budget: 120s, spawn_budget: 0, retry_budget: 0}
mode_inactive: MINIMAL
input_ports:
  - port: session_meta
    format: json
    signal_field: session_meta
    required: true
  - port: avoid_cache_hint
    format: json
    signal_field: avoid_cache_hint
    required: false
output_ports:
  - port: file_cache_map
    format: json
    signal_field: file_cache_map
raises_signals: [file_cache_map]
required_output_sections: []
---

## INPUT ports
- session_meta: json (signal_field: session_meta)
- avoid_cache_hint: json (signal_field: avoid_cache_hint) — list of file paths to exclude from caching (from N-FILTER via E-15b)

## OUTPUT ports
- file_cache_map: json (signal_field: file_cache_map) — dict mapping file paths to cache entries; emitted via E-15c (→N-REFINER, optional)

## AI advantages exploited
- super_human_recall  # Tracking exact SHA-256 fingerprints of every file version seen across the session, enabling precise delta detection without re-reading full file contents.

## Protocol

### Step 1 — Check mode and scan turn_records for file references
Check `session_meta.mode` context: if running in MINIMAL mode, this node is inactive — emit an empty `file_cache_map` and return immediately (E-15c carries null-signal to N-REFINER, which accepts it as optional).

Read `turn_records` from `session_meta.ingest_record_ref`. Scan all turns for file read events: turns containing tool_use calls of type `read_file`, `cat`, or similar file-reading tool names, or turns whose `content` embeds a recognized file path pattern followed by file content.

Collect the set of unique file paths referenced across all turns. Exclude any paths listed in `avoid_cache_hint` (always-retain files that must never be replaced with FileRef tokens).

### Step 2 — SHA-256 comparison against cache state
For each unique file path not in `avoid_cache_hint`:
- Retrieve the current file content as it appears in the most recent turn that references this path.
- Compute SHA-256 of the current content string.
- Compare against the persisted cache dict `file_cache[path]`: `{sha256, compressed_content, last_read_turn}`.
  - If `file_cache[path]` exists and SHA-256 matches: the file is unchanged.
  - If `file_cache[path]` does not exist or SHA-256 differs: the file is new or changed.

### Step 3 — Pre-check SC-12 FileRef token count
Before emitting FileRefs, count the number of files that would receive `type: "fileref"` (unchanged files). Verify this count < 20 (SC-12 pre-check: FileRef token count must stay below 20). If the count would meet or exceed 20, prioritize FileRef assignment by most-recently-accessed turns first until the count drops below 20; remaining unchanged files are demoted to `type: "full"` (retain full content).

### Step 4 — Build and emit file_cache_map
For each file path in scope:
- **Unchanged (SHA-256 match):** emit entry with `type: "fileref"`, `content: "[FileRef: <path>]"` (~15 tokens), `sha256: <sha256>`, `token_count: 15`
- **Changed (SHA-256 mismatch):** emit entry with `type: "diff"`, `content: <unified_diff>`, `sha256: <new_sha256>`, `token_count: <diff_token_count>`
- **First encounter:** emit entry with `type: "full"`, `content: <full_content>`, `sha256: <sha256>`, `token_count: <full_token_count>`

Update the session file_cache dict with new SHA-256 values and last_read_turn for all processed files.

Emit `file_cache_map` via E-15c → N-REFINER (optional; N-REFINER proceeds without it if absent in MINIMAL mode).

## Scale gates
- tokens: 1500
- time: 120s
- spawns: 0
- retries: 0

## Failure modes
- timeout: no retry (retry_budget=0); skip FileRef computation; pass null file_cache_map to N-REFINER; SC-12 not applicable for this run
- malformed output: if SHA-256 computation fails for any file, skip that file; retain full content as fallback
- missing input: if avoid_cache_hint absent, proceed with empty exclusion list (all files eligible for caching)
- format-mismatch on Edge: re-read session_meta from N-TRIGGER-EVAL stage output directly
