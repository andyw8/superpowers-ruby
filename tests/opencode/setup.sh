#!/usr/bin/env bash
# Setup script for OpenCode plugin tests
# Creates isolated test projects that load the plugin from this working tree.
set -euo pipefail

# Get the repository root (two levels up from tests/opencode/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Create a temp directory for isolated test projects. The OpenCode service
# still uses the current user's home so integration tests can reuse the shared
# background service.
export TEST_HOME
TEST_HOME=$(mktemp -d)

export TEST_PROJECT="$TEST_HOME/project"
export PRIORITY_PROJECT="$TEST_HOME/priority-project"

install_plugin_fixture() {
    local target="$1"

    mkdir -p "$target/.opencode/plugins"
    cp "$REPO_ROOT/.opencode/plugins/superpowers.js" "$target/.opencode/plugins/superpowers.js"
    cp -R "$REPO_ROOT/skills" "$target/skills"
    cp -R "$REPO_ROOT/hooks" "$target/hooks"

    cat > "$target/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json"
}
EOF
}

install_plugin_fixture "$TEST_PROJECT"
install_plugin_fixture "$PRIORITY_PROJECT"

# Project test skill
mkdir -p "$TEST_PROJECT/.opencode/skills/project-test"
cat > "$TEST_PROJECT/.opencode/skills/project-test/SKILL.md" <<'EOF'
---
name: project-test
description: Test project skill for verification
---
# Project Test Skill

PROJECT_SKILL_MARKER_67890
EOF

# Project skill that overrides a bundled skill ID
mkdir -p "$PRIORITY_PROJECT/.opencode/skills/brainstorming"
cat > "$PRIORITY_PROJECT/.opencode/skills/brainstorming/SKILL.md" <<'EOF'
---
name: brainstorming
description: PROJECT OVERRIDE
---
# Project Brainstorming Override

PROJECT_OVERRIDE_MARKER
EOF

# Refresh the shared-service discovery file. `opencode api` updates it with the
# current URL and password; a stale file would point at a stopped server.
if command -v opencode &> /dev/null; then
    timeout 60 opencode api get /api/info >/dev/null 2>&1 || true
fi

# Query the shared OpenCode service directly. `opencode api` truncates large
# responses (the skill list is several hundred KB), so use curl with the
# service password to get the complete JSON document.
oc_api_get() {
    local path="$1"
    local project="$2"
    local service_file="${OPENCODE_SERVICE_FILE:-$HOME/.local/state/opencode/service.json}"

    if [ ! -f "$service_file" ]; then
        timeout 60 opencode api get /api/info >/dev/null 2>&1 || true
    fi
    if [ ! -f "$service_file" ]; then
        return 1
    fi

    local password url
    password=$(jq -r '.password' "$service_file")
    url=$(jq -r '.url' "$service_file")

    curl -sS --max-time 60 -u "opencode:$password" \
        --get --data-urlencode "location[directory]=$project" \
        "$url$path"
}

echo "Setup complete: $TEST_HOME"
echo "Plugin project: $TEST_PROJECT"
echo "Priority project: $PRIORITY_PROJECT"

# Helper function for cleanup (call from tests or trap)
cleanup_test_env() {
    if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
        rm -rf "$TEST_HOME"
    fi
}

export -f cleanup_test_env
export REPO_ROOT
