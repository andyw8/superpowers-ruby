# Superpowers for OpenCode

Complete guide for using Superpowers with [OpenCode](https://opencode.ai) **2.x**.

> **OpenCode 2 is required.** Superpowers uses the OpenCode 2 plugin API (`Plugin.define`, domain transforms, and session hooks). It does not load on OpenCode 1. See [Migrate from V1](https://opencode.ai/v2/docs/migrate-v1) if you are upgrading OpenCode itself.

## Requirements

- OpenCode 2 (`opencode --version` reports `2.x` or newer)
- Git on your `PATH`

## Installation

Install with the OpenCode CLI:

```bash
opencode plugin add 'superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git'
```

Or edit `opencode.json(c)` directly (global at `~/.config/opencode/`, or project-level):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": ["superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git"]
}
```

Restart OpenCode. OpenCode installs the plugin and the plugin registers all bundled skills — no symlinks and no `skills` config entry required.

Verify:

```bash
opencode plugin list          # superpowers-ruby should be listed
opencode api get /api/skill   # brainstorming, handoff, using-superpowers, ...
```

Then ask: "Tell me about your superpowers".

### Migrating from OpenCode 1 or an old symlink install

This plugin replaces both the V1 plugin and the old `git clone` + symlink setup:

```bash
# Remove old symlinks or cloned plugin files
rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers-ruby
rm -rf ~/.config/opencode/superpowers-ruby

# Remove the old "plugin" entry from opencode.json(c), then install as above.
```

The V1 `skills.paths` config is not used by OpenCode. Use the `skills` array instead; Superpowers does not need an entry there because the plugin registers its own skills.

## Usage

### Finding skills

Use OpenCode's native `skill` tool:

```
use the skill tool to list skills
```

### Loading a skill

Use the skill's **bare ID**:

```
use the skill tool to load brainstorming
use the skill tool to load handoff
```

Or mention it directly:

```
@brainstorming help me design this feature
```

Skill IDs are derived from the directory name. On OpenCode they are `brainstorming`, `handoff`, `using-superpowers`, and so on — not `superpowers-ruby/brainstorming` or `superpowers-ruby:brainstorming`.

### Personal skills

Create your own skills in `~/.config/opencode/skills/`:

```bash
mkdir -p ~/.config/opencode/skills/my-skill
```

Create `~/.config/opencode/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Use when [condition] - [what it does]
---

# My Skill

[Your skill content here]
```

### Project skills

Create project-specific skills in `.opencode/skills/` inside the project:

```text
.opencode/skills/my-project-skill/SKILL.md
```

### Skill priority

Project skills override personal skills, which override the skills bundled with Superpowers:

```text
.opencode/skills/<id>/SKILL.md              (highest)
~/.config/opencode/skills/<id>/SKILL.md
skills bundled by superpowers-ruby          (lowest)
```

OpenCode selects skills by ID, so a project copy of `brainstorming` replaces the bundled `brainstorming` for that project.

## Updating

OpenCode checks unpinned Git plugins for updates at startup. To update explicitly:

```bash
opencode plugin update superpowers-ruby
opencode reload
```

To pin a release, append its tag or commit hash to the Git spec:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugins": [
    "superpowers-ruby@git+https://github.com/lucianghinda/superpowers-ruby.git#<tag-or-commit>"
  ]
}
```

## How It Works

The plugin is a native OpenCode plugin (`Plugin.define({ id: "superpowers-ruby", setup(ctx) })`). It does four things:

1. **Registers bundled skills** with `ctx.skill.transform`, including frontmatter names, descriptions, and bodies. Skills with `disable-model-invocation: true` are registered with `autoinvoke: false`.
2. **Loads `using-superpowers` once per session** through the `prompt` session hook. It checks the session's history first, so the bootstrap is not duplicated on later prompts or after a restart.
3. **Captures a handoff document** before compaction with the `compaction` session hook (`hooks/handoff-create`).
4. **Restores the handoff after compaction** by subscribing to `session.compaction.ended`, running `hooks/handoff-restore`, and adding the restored document to the system prompt for that session.

All of the above use the V2 plugin API. There is no `config` hook, no `skills.paths` mutation, and no V1 experimental hook names.

### Tool Mapping

Skills written for Claude Code are adapted for OpenCode:

| Skill references | OpenCode |
|---|---|
| `TodoWrite` | `todowrite` — enable with `{"experimental": {"todo": true}}`; todos are off by default |
| `Task` tool with subagents | OpenCode's subagent system |
| `Skill` tool | OpenCode's native `skill` tool, using the bare skill ID |
| `Read`, `Write`, `Edit` | Native OpenCode file tools |
| `Bash` | Native OpenCode shell tool |

See [`../skills/using-superpowers/references/opencode-tools.md`](../skills/using-superpowers/references/opencode-tools.md) for details.

## Troubleshooting

### Plugin not loading

1. Confirm OpenCode 2 is installed:
   ```bash
   opencode --version
   ```
2. Check the plugin list:
   ```bash
   opencode plugin list
   ```
3. Read the server log:
   ```bash
   grep 'role=server' ~/.local/share/opencode/log/opencode.log | grep -i superpowers
   ```
4. Verify the `plugins` entry in `opencode.json(c)`, then restart:
   ```bash
   opencode service restart
   ```

`opencode run --print-logs` still works, but server logs require `--standalone`.

### Skills not found

1. Use OpenCode's `skill` tool to list available skills, or query the API:
   ```bash
   opencode api get /api/skill
   ```
2. Confirm the plugin is active (see above).
3. Each skill needs a `SKILL.md` with valid YAML frontmatter containing a `description`.

### Bootstrap not appearing

1. Confirm `using-superpowers` is in the skill list.
2. Start a new session. The bootstrap is attached to the first prompt of each session, not added to every request.
3. Restart OpenCode after changing the plugin.

## Getting Help

- Report issues: https://github.com/lucianghinda/superpowers-ruby/issues
- Main documentation: https://github.com/lucianghinda/superpowers-ruby
- OpenCode docs: https://opencode.ai/v2/docs/
