#!/usr/bin/env bash
# run-behavioral-tests.sh — adaptive-context-pruner v2.0.0 behavioral acceptance tests
# Tests EC2 (minimal), EC4 (contradictory), EC15 (refeed) input paths
# NOTE: Full behavioral acceptance requires live Claude Code skill invocation.
# TODO: tighten assertions after first manual run.

SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE_DIR="$(dirname "$0")"
PASS=0
FAIL=0

pass() { echo "  PASS [$1]: $2"; PASS=$((PASS+1)); }
fail() { echo "  FAIL [$1]: $2"; FAIL=$((FAIL+1)); }

echo "=== adaptive-context-pruner v2.0.0 behavioral tests ==="
echo "SKILL_DIR: $SKILL_DIR"
echo "FIXTURE_DIR: $FIXTURE_DIR"

# EC2: minimal brief — happy path
echo ""
echo "[EC2] Minimal brief (happy path, MANUAL mode)"
echo "  Invocation: /adaptive-context-pruner with EC2-minimal-brief.txt content"
echo "  Expected: SKILL.md loaded; pipeline runs to N-PERSISTER (W9); no error output"

if [[ -f "$FIXTURE_DIR/EC2-minimal-brief.txt" ]]; then
  pass "EC2" "Fixture file EC2-minimal-brief.txt exists"
else
  fail "EC2" "Fixture file EC2-minimal-brief.txt missing"
fi

# EC2 structural assertion: fixture must contain 'mode: manual' for v2
if grep -q 'mode.*manual\|manual.*mode' "$FIXTURE_DIR/EC2-minimal-brief.txt" 2>/dev/null; then
  pass "EC2" "EC2 fixture includes mode indicator (v2 MANUAL mode)"
else
  fail "EC2" "EC2 fixture missing mode indicator — v2 N-PREFLIGHT requires mode field"
fi

# TODO: wire up live invocation
echo "  [TODO] invoke skill with EC2-minimal-brief.txt and assert:"
echo "         - Output YAML frontmatter contains skill_name: adaptive-context-pruner"
echo "         - Output YAML frontmatter contains version: 2.0.0"
echo "         - verify_pass field is true"
echo "         - No REFUSE_OUTPUT triggered"
echo "         - N-PERSISTER (W9) session_artifact produced"

# EC4: contradictory constraints — N-PREFLIGHT / N-ANALYZER-CORRECTIONS handling
echo ""
echo "[EC4] Contradictory brief (contradiction detection)"
echo "  Invocation: /adaptive-context-pruner with EC4-contradictory-brief.txt content"
echo "  Expected: output contains contradiction annotation or structured N-PREFLIGHT refusal"

if [[ -f "$FIXTURE_DIR/EC4-contradictory-brief.txt" ]]; then
  pass "EC4" "Fixture file EC4-contradictory-brief.txt exists"
else
  fail "EC4" "Fixture file EC4-contradictory-brief.txt missing"
fi

# EC4 structural assertion: fixture must have contradictory constraint pair
CONTRA_COUNT=$(grep -c 'enable_semantic_clustering' "$FIXTURE_DIR/EC4-contradictory-brief.txt" 2>/dev/null || echo 0)
if [[ "$CONTRA_COUNT" -ge 2 ]]; then
  pass "EC4" "EC4 fixture contains at least 2 contradictory enable_semantic_clustering references"
else
  fail "EC4" "EC4 fixture missing contradictory constraint pair (found $CONTRA_COUNT enable_semantic_clustering references)"
fi

# TODO: wire up live invocation
echo "  [TODO] invoke skill with EC4-contradictory-brief.txt and assert:"
echo "         - Output contains [CONTRADICTION] or conflict_annotations field"
echo "         - AP-V7 fires: N-ANALYZER-CORRECTIONS emits conflict_signal"
echo "         - verify_pass reflects contradiction-detected state"
echo "         - Pipeline does NOT silently drop the contradiction"

# EC15: refeed — ec-refeed mode, node name preservation
echo ""
echo "[EC15] Refeed (prior skill output as context, ec-skill class)"
echo "  Invocation: /adaptive-context-pruner with EC15-refeed-brief.txt content"
echo "  Expected: v1 node names preserved in output (N-INGEST, N-PREFLIGHT, etc.)"

if [[ -f "$FIXTURE_DIR/EC15-refeed-brief.txt" ]]; then
  pass "EC15" "Fixture file EC15-refeed-brief.txt exists"
else
  fail "EC15" "Fixture file EC15-refeed-brief.txt missing"
fi

# EC15 structural assertion: fixture must have SKILL.md frontmatter
if grep -q 'name: adaptive-context-pruner' "$FIXTURE_DIR/EC15-refeed-brief.txt" 2>/dev/null; then
  pass "EC15" "EC15 fixture has SKILL.md frontmatter (name: adaptive-context-pruner)"
else
  fail "EC15" "EC15 fixture missing SKILL.md frontmatter"
fi

if grep -q 'version:' "$FIXTURE_DIR/EC15-refeed-brief.txt" 2>/dev/null; then
  pass "EC15" "EC15 fixture has version field in frontmatter"
else
  fail "EC15" "EC15 fixture missing version field"
fi

# EC15 v2 node listing check
V1_NODES="N-INGEST\|N-PREFLIGHT\|N-CLASSIFIER\|N-SCORER-TECHNICAL"
if grep -q "$V1_NODES" "$FIXTURE_DIR/EC15-refeed-brief.txt" 2>/dev/null; then
  pass "EC15" "EC15 fixture contains v1 node names (refeed detection target)"
else
  fail "EC15" "EC15 fixture missing v1 node names for refeed detection"
fi

# TODO: wire up live invocation
echo "  [TODO] invoke skill with EC15-refeed-brief.txt and assert:"
echo "         - Skill detects ec-refeed context (auto-detect from SKILL.md frontmatter)"
echo "         - v1 node names (N-INGEST etc.) are treated as context, not constraints"
echo "         - Output schema upgraded to v2.0.0 (20 nodes, 9 waves)"
echo "         - N-PREFLIGHT preserves EC-FC04 external contracts from v1"

echo ""
echo "=== Behavioral results: PASS=$PASS FAIL=$FAIL ==="
echo "NOTE: Structural fixture checks only. Live invocation assertions are TODO."
echo "      Run after installing the skill and verifying with a real Claude session."
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
