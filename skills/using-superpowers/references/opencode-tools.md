# OpenCode Tool Mapping

This mapping targets OpenCode 2, which Superpowers requires.

Skills use Claude Code tool names. When you encounter these in a skill, use your OpenCode equivalent:

| Skill references | OpenCode equivalent |
|---|---|
| `Skill` tool (invoke a skill) | OpenCode's native `skill` tool, using the bare skill ID |
| `Task` tool (dispatch subagent) | OpenCode's subagent system |
| `TodoWrite` (task tracking) | `todowrite` — only available when `experimental.todo` is enabled |
| `Read`, `Write`, `Edit` (files) | Native OpenCode file tools |
| `Bash` (run commands) | Native OpenCode shell tool |

## Skill IDs

OpenCode derives a skill's ID from its directory or file name. Bundled Superpowers skills therefore use bare IDs:

- `brainstorming`
- `handoff`
- `using-superpowers`

Do **not** prefix them with `superpowers-ruby` (neither `superpowers-ruby:brainstorming` nor `superpowers-ruby/brainstorming`). Load a skill with the `skill` tool and its exact ID, or mention it in a prompt as `@brainstorming`.

When another skill says to invoke `superpowers-ruby:<slug>` or `superpowers:<slug>`, load `<slug>` instead.

Project skills (`.opencode/skills/`) and personal skills (`~/.config/opencode/skills/`) take precedence over the bundled copies when both define the same ID.

## Todos

OpenCode has todos **off by default**. If a skill asks you to create todos and the `todowrite` tool is unavailable, either:

- enable it in `opencode.json(c)`:

  ```jsonc
  {
    "$schema": "https://opencode.ai/config.json",
    "experimental": { "todo": true }
  }
  ```

- or track the checklist in your response without a dedicated tool.

## Subagents

OpenCode dispatches subagents through its own agent system. `subagent_depth` defaults to `1`, so a subagent cannot start another subagent unless you raise it:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "experimental": { "subagent_depth": 2 }
}
```

When a skill references a named agent type such as `superpowers-ruby:code-reviewer`, use the prompt from `agents/code-reviewer.md` with an OpenCode subagent instead.

## Background service

OpenCode runs a shared background server. If the plugin or skills stop updating, restart it:

```bash
opencode service restart
```

Logs live at `~/.local/share/opencode/log/opencode.log`. Filter `role=server` for plugin and skill activity.
