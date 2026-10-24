#!/usr/bin/env bash
# Test: Skill priority resolution (integration)
# Project skills must override bundled skills with the same ID.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Skill Priority ==="

if ! command -v opencode &> /dev/null; then
    echo "  [SKIP] OpenCode not installed - skipping integration test"
    echo "  Install OpenCode 2: https://opencode.ai"
    exit 0
fi

if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null; then
    echo "  [SKIP] jq and curl are required for integration tests"
    exit 0
fi

source "$SCRIPT_DIR/setup.sh"
trap cleanup_test_env EXIT

api_get() {
    oc_api_get "$1" "$2" 2>&1 || true
}

echo "Test 1: OpenCode version..."
version=$(opencode --version 2>/dev/null | head -1)
case "$version" in
    *v2.*|2.*)
        echo "  [PASS] $version is OpenCode 2"
        ;;
    *)
        echo "  [FAIL] OpenCode 2 is required (got: $version)"
        exit 1
        ;;
esac

echo "Test 2: Loading skills for the priority project..."
skills_output=""
for _ in $(seq 1 15); do
    skills_output=$(api_get /api/skill "$PRIORITY_PROJECT")
    if echo "$skills_output" | grep -q '"description":"PROJECT OVERRIDE"'; then break; fi
    sleep 1
done

if echo "$skills_output" | grep -q '"id":"brainstorming"'; then
    echo "  [PASS] brainstorming is registered"
else
    echo "  [FAIL] brainstorming is not registered"
    exit 1
fi

echo "Test 3: The project skill overrides the bundled skill..."
override=$(echo "$skills_output" | grep -o '"id":"brainstorming"[^}]*' || true)
if echo "$override" | grep -q '"description":"PROJECT OVERRIDE"'; then
    echo "  [PASS] Project brainstorming overrides the bundled copy"
else
    echo "  [FAIL] Bundled brainstorming won over the project copy"
    echo "        $override"
    exit 1
fi

if echo "$override" | grep -q "\"path\":\"$PRIORITY_PROJECT/.opencode/skills/brainstorming/SKILL.md\""; then
    echo "  [PASS] Loaded path points at the project skill"
else
    echo "  [FAIL] Loaded path does not point at the project skill"
    echo "        $override"
    exit 1
fi

echo "Test 4: Bundled skills remain available under other IDs..."
for skill_id in handoff using-superpowers; do
    if echo "$skills_output" | grep -q "\"id\":\"$skill_id\""; then
        echo "  [PASS] $skill_id is still registered"
    else
        echo "  [FAIL] $skill_id missing"
        exit 1
    fi
done

echo ""
echo "=== All skill priority tests passed ==="
