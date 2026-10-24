#!/usr/bin/env bash
# Test: Plugin structure for OpenCode
# Verifies the plugin entrypoint and the files it needs at runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Plugin Loading ==="

source "$SCRIPT_DIR/setup.sh"
trap cleanup_test_env EXIT

plugin_file="$TEST_PROJECT/.opencode/plugins/superpowers.js"

echo "Test 1: Checking plugin entrypoint..."
if [ -f "$plugin_file" ]; then
    echo "  [PASS] Plugin entrypoint exists"
else
    echo "  [FAIL] Plugin entrypoint not found at $plugin_file"
    exit 1
fi

echo "Test 2: Checking V2 plugin definition..."
if grep -q "id: 'superpowers-ruby'" "$plugin_file" && grep -q "async setup(ctx)" "$plugin_file"; then
    echo "  [PASS] Plugin exports a V2 definition with an id and setup()"
else
    echo "  [FAIL] Plugin does not look like an OpenCode plugin definition"
    exit 1
fi

echo "Test 3: Checking JavaScript syntax..."
if node --check "$plugin_file" 2>/dev/null; then
    echo "  [PASS] Plugin JavaScript syntax is valid"
else
    echo "  [FAIL] Plugin has JavaScript syntax errors"
    exit 1
fi

echo "Test 4: Checking bundled skills..."
skill_count=$(find "$TEST_PROJECT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
if [ "$skill_count" -gt 0 ]; then
    echo "  [PASS] Found $skill_count bundled skills"
else
    echo "  [FAIL] No bundled skills found"
    exit 1
fi

if [ -f "$TEST_PROJECT/skills/using-superpowers/SKILL.md" ]; then
    echo "  [PASS] using-superpowers skill exists (required for bootstrap)"
else
    echo "  [FAIL] using-superpowers skill not found (required for bootstrap)"
    exit 1
fi

echo "Test 5: Checking handoff hook scripts..."
for hook in handoff-create handoff-restore; do
    if [ -f "$TEST_PROJECT/hooks/$hook" ]; then
        echo "  [PASS] hooks/$hook exists"
    else
        echo "  [FAIL] hooks/$hook not found"
        exit 1
    fi
done

echo ""
echo "=== All plugin loading tests passed ==="
