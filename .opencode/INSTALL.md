# Installing Superpowers for OpenCode

## Prerequisites

- **OpenCode 2** (`opencode --version` reports `2.x` or newer). OpenCode 1 is not supported: Superpowers uses the OpenCode 2 plugin API and will not load on V1.
- Git available on your `PATH` (the plugin and its skills are installed from this repository).

## Installation

Install the plugin with the OpenCode CLI:

```bash
opencode plugin add 'superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git'
```

Or add it to the `plugins` array in `opencode.json(c)` (global or project-level):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git"]
}
```

Restart OpenCode. The plugin installs and registers all bundled skills automatically — no symlinks and no `skills` config entry required.

Verify the install:

```bash
opencode plugin list          # superpowers-ruby should be listed
opencode api get /api/skill   # bundled skills such as brainstorming and handoff
```

Then ask: "Tell me about your superpowers".

## Migrating from OpenCode 1 or an old symlink install

This plugin replaces the V1 plugin and the old `git clone` + symlink setup. If you used either, remove the old pieces before installing:

```bash
# Remove old symlinks or cloned plugin files
rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers-ruby
rm -rf ~/.config/opencode/superpowers-ruby

# Remove the V1 plugin entry from opencode.json(c), then install as above.
```

The old `skills.paths` config is also V1-only. OpenCode uses a `skills` array instead, and you do not need it for Superpowers.

## Usage

Skills are loaded with OpenCode's native `skill` tool using their **bare ID**:

```
use the skill tool to load brainstorming
use the skill tool to load handoff
```

You can also mention a skill directly in a prompt:

```
@brainstorming help me design this feature
```

Skill IDs are path-derived: `brainstorming`, `handoff`, `using-superpowers` — not `superpowers-ruby/brainstorming` or `superpowers-ruby:brainstorming`.

**Skill priority:** project skills (`.opencode/skills/`) override personal skills (`~/.config/opencode/skills/`), which override the skills bundled with Superpowers.

## Updating

OpenCode checks unpinned Git plugins for updates at startup. To update explicitly:

```bash
opencode plugin update superpowers-ruby
opencode reload
```

To pin a specific release, append its tag or commit hash:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    "superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git#<tag-or-commit>"
  ]
}
```

## Troubleshooting

### Plugin not loading

1. Confirm OpenCode 2 is installed:
   ```bash
   opencode --version
   ```
2. Check that the plugin is listed and active:
   ```bash
   opencode plugin list
   ```
3. Read the server logs:
   ```bash
   grep 'role=server' ~/.local/share/opencode/log/opencode.log | grep -i superpowers
   ```
4. Verify the `plugins` entry in `opencode.json(c)`, then restart:
   ```bash
   opencode service restart
   ```

If you use `opencode run --print-logs`, add `--standalone` to see server logs.

### Skills not found

1. List the skills OpenCode discovered:
   ```bash
   opencode api get /api/skill
   ```
2. Confirm the plugin is active (see above).
3. A skill with the same ID in `.opencode/skills/` or `~/.config/opencode/skills/` overrides the bundled copy.

### Tool mapping

When skills reference Claude Code tools:

- `TodoWrite` → `todowrite`. Todos are **off by default** in OpenCode; enable them with `{"experimental": {"todo": true}}`.
- `Task` with subagents → OpenCode's subagent system.
- `Skill` tool → OpenCode's native `skill` tool, using the bare skill ID.
- `Read`, `Write`, `Edit`, `Bash` → your native OpenCode tools.

See [`skills/using-superpowers/references/opencode-tools.md`](../skills/using-superpowers/references/opencode-tools.md) for the full mapping.

## Getting Help

- Report issues: https://github.com/lucianghinda/superpowers-ruby/issues
- Full documentation: https://github.com/lucianghinda/superpowers-ruby/blob/main/docs/README.opencode.md
- OpenCode docs: https://opencode.ai/v2/docs/
