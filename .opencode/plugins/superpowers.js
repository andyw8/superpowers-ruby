/**
 * Superpowers plugin for OpenCode 2
 *
 * Registers the bundled skills with OpenCode's native skill system and loads
 * the using-superpowers skill once per session. Also captures and restores
 * handoff documents around context compaction.
 *
 * Requires OpenCode 2. This file uses the V2 plugin API and does not run on
 * OpenCode 1.
 */

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const PLUGIN_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SKILLS_DIR = path.join(PLUGIN_ROOT, 'skills');
const BOOTSTRAP_SKILL = 'using-superpowers';

/**
 * Parse the small YAML subset used by superpowers skill frontmatter: scalar
 * values, quoted strings, and folded/literal block scalars.
 */
const parseFrontmatter = (source) => {
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { data: {}, content: source };

  const data = {};
  const lines = match[1].split(/\r?\n/);

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const entry = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!entry) continue;

    const key = entry[1];
    let value = entry[2].trim();

    if (/^[>|][+-]?$/.test(value)) {
      const folded = value.startsWith('>');
      const parts = [];
      while (i + 1 < lines.length && (/^\s/.test(lines[i + 1]) || lines[i + 1].trim() === '')) {
        i++;
        parts.push(lines[i].trim());
      }
      value = (folded ? parts.join(' ') : parts.join('\n')).trim();
    } else if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    data[key] = value;
  }

  return { data, content: match[2] };
};

const loadBundledSkills = () => {
  if (!fs.existsSync(SKILLS_DIR)) return [];

  return fs
    .readdirSync(SKILLS_DIR, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => {
      const file = path.join(SKILLS_DIR, entry.name, 'SKILL.md');
      if (!fs.existsSync(file)) return undefined;

      const { data, content } = parseFrontmatter(fs.readFileSync(file, 'utf8'));
      const skill = {
        id: entry.name,
        name: data.name || entry.name,
        path: file,
        content,
      };

      if (data.description) skill.description = data.description;
      if (String(data['disable-model-invocation']).toLowerCase() === 'true') {
        skill.autoinvoke = false;
      }

      return skill;
    })
    .filter(Boolean);
};

const runHook = (scriptName, args, cwd) => {
  const script = path.join(PLUGIN_ROOT, 'hooks', scriptName);
  if (!fs.existsSync(script)) return '';

  try {
    return execFileSync('bash', [script, ...args], {
      cwd,
      encoding: 'utf8',
      timeout: 10_000,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    console.error(`[superpowers-ruby] ${scriptName} failed: ${error.message}`);
    return '';
  }
};

const restoreHandoff = (cwd) => {
  const output = runHook('handoff-restore', [], cwd).trim();
  if (!output) return undefined;

  try {
    const parsed = JSON.parse(output);
    return parsed.additionalContext || parsed.additional_context || parsed.systemMessage;
  } catch (error) {
    console.error(`[superpowers-ruby] could not parse handoff-restore output: ${error.message}`);
    return undefined;
  }
};

export default {
  id: 'superpowers-ruby',
  async setup(ctx) {
    const directory = ctx.location.directory;
    const skills = loadBundledSkills();

    if (skills.length > 0) {
      await ctx.skill.transform((editor) => {
        for (const skill of skills) editor.add(skill);
      });
    }

    const bootstrapped = new Set();
    const restoredHandoffs = new Map();

    // Load using-superpowers once per session, the first time the user prompts.
    await ctx.session.hook('prompt', async (event) => {
      if (bootstrapped.has(event.sessionID)) return;
      bootstrapped.add(event.sessionID);

      try {
        const messages = await ctx.session.context({ sessionID: event.sessionID });
        const alreadyLoaded = messages.some((message) =>
          (message.type === 'skill' && message.skill === BOOTSTRAP_SKILL) ||
          (Array.isArray(message.skills) &&
            message.skills.some((skill) => skill.id === BOOTSTRAP_SKILL)),
        );
        if (alreadyLoaded) return;
      } catch (error) {
        console.error(`[superpowers-ruby] could not read session context: ${error.message}`);
      }

      const selectedSkills = event.prompt.skills ?? [];
      if (selectedSkills.some((skill) => skill.id === BOOTSTRAP_SKILL)) return;

      event.prompt.skills = [...selectedSkills, { id: BOOTSTRAP_SKILL }];
    });

    // Capture a handoff document before the compaction summary is generated.
    await ctx.session.hook('compaction', async () => {
      runHook('handoff-create', ['--trigger', 'compact'], directory);
    });

    // Restore a captured handoff after compaction. The restored document is
    // added to the system prompt of subsequent requests in that session.
    await ctx.session.hook('context', (event) => {
      const handoff = restoredHandoffs.get(event.sessionID);
      if (handoff) event.system.push({ type: 'text', text: handoff });
    });

    const controller = new AbortController();

    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type === 'session.compaction.ended') {
            const eventDirectory = event.location?.directory;
            if (eventDirectory && path.resolve(eventDirectory) !== path.resolve(directory)) continue;

            const sessionID = event.data?.sessionID;
            const handoff = restoreHandoff(eventDirectory || directory);
            if (sessionID && handoff) restoredHandoffs.set(sessionID, handoff);
          } else if (event.type === 'session.deleted') {
            const sessionID = event.data?.sessionID;
            if (sessionID) {
              bootstrapped.delete(sessionID);
              restoredHandoffs.delete(sessionID);
            }
          }
        }
      } catch (error) {
        if (!controller.signal.aborted) {
          console.error(`[superpowers-ruby] event subscription failed: ${error.message}`);
        }
      }
    })();

    return () => controller.abort();
  },
};
