#!/usr/bin/env bash
# Test: Bundled skill registration (integration)
# Requires OpenCode 2 to be installed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Skill Registration ==="

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

wait_for() {
    local pattern="$1"
    local project="$2"
    local output=""

    for _ in $(seq 1 15); do
        output=$(api_get /api/skill "$project")
        if echo "$output" | grep -q "$pattern"; then
            echo "$output"
            return 0
        fi
        sleep 1
    done

    echo "$output"
    return 1
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

echo "Test 2: Plugin is active..."
plugin_output=""
for _ in $(seq 1 15); do
    plugin_output=$(api_get /api/plugin "$TEST_PROJECT")
    if echo "$plugin_output" | grep -q '"id":"superpowers-ruby"'; then break; fi
    sleep 1
done

if echo "$plugin_output" | grep -q '"id":"superpowers-ruby"'; then
    echo "  [PASS] superpowers-ruby is registered"
else
    echo "  [FAIL] superpowers-ruby is not registered"
    exit 1
fi

if echo "$plugin_output" | grep -q '"status":"active"'; then
    echo "  [PASS] Plugin state is active"
else
    echo "  [FAIL] Plugin state is not active"
    exit 1
fi

echo "Test 3: Every bundled skill is registered..."
if ! skills_output=$(wait_for '"id":"project-test"' "$TEST_PROJECT"); then
    echo "  [FAIL] Timed out waiting for project skills to register"
    exit 1
fi

missing=0
for skill_file in "$TEST_PROJECT"/skills/*/SKILL.md; do
    skill_id=$(basename "$(dirname "$skill_file")")
    if echo "$skills_output" | grep -q "\"id\":\"$skill_id\""; then
        :
    else
        echo "  [FAIL] Missing skill: $skill_id"
        missing=$((missing + 1))
    fi
done

if [ "$missing" -eq 0 ]; then
    echo "  [PASS] All bundled skills are registered with bare IDs"
else
    echo "  [FAIL] $missing bundled skills are missing"
    exit 1
fi

echo "Test 4: Project skills are registered..."
if echo "$skills_output" | grep -q '"id":"project-test"'; then
    echo "  [PASS] project-test is registered"
else
    echo "  [FAIL] project-test is not registered"
    exit 1
fi

echo "Test 5: disable-model-invocation maps to autoinvoke: false..."
compound_refresh=$(echo "$skills_output" | grep -o '"id":"compound-refresh"[^}]*' || true)
if echo "$compound_refresh" | grep -q '"autoinvoke":false'; then
    echo "  [PASS] compound-refresh is hidden from the model but still loadable"
else
    echo "  [FAIL] compound-refresh autoinvoke mapping is missing"
    exit 1
fi

echo ""
echo "=== All skill registration tests passed ==="
