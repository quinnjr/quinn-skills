# quinn-skills

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) of personal skills.

## Install

```sh
# From GitHub
/plugin marketplace add quinnjr/quinn-skills
# Or from a local clone
/plugin marketplace add /path/to/quinn-skills

/plugin install quinn-skills@quinn-skills
```

Run `/plugin marketplace update quinn-skills` to pull new versions.

## Kiro

`install-kiro.sh` copies the plugin's skills and agents into a Kiro home (needs `jq`):

```sh
./install-kiro.sh                          # $KIRO_HOME, or ~/.kiro
./install-kiro.sh --home ~/.kiro --home /mnt/c/Users/me/.kiro   # several homes
./install-kiro.sh --dry-run                # show what would change
./install-kiro.sh --uninstall              # remove what it installed
```

- The home is chosen the same way kiro-cli chooses it: `--home` flags first, then `KIRO_HOME` (only if it is an absolute path, since kiro-cli ignores a relative one), then `~/.kiro`.
- Skills go to `<home>/skills/`, with `${CLAUDE_SKILL_DIR}` rewritten to the installed path.
- Agents are converted to `<home>/agents/<name>.json`, with the prompt in `<home>/prompts/<name>.md`.
- Anything already in the home that this installer did not create is skipped. `--force` replaces it after backing it up to `<home>/.quinn-skills/backup/`.
- If the global setting `chat.defaultAgent` names a custom agent that does not load `<home>/skills`, the installer tells you which `resources` entry to add.
- Re-run after pulling to update. Skills dropped from the plugin are removed.

Tests: `tests/install-kiro.test.sh`

## OpenCode

`install-opencode.sh` copies the plugin's skills and agents into an OpenCode config directory (needs `jq` and `perl`):

```sh
./install-opencode.sh                          # $OPENCODE_CONFIG_DIR, or ${XDG_CONFIG_HOME:-~/.config}/opencode
./install-opencode.sh --config-dir ~/oc-a --config-dir ~/oc-b   # several directories
./install-opencode.sh --dry-run                # show what would change
./install-opencode.sh --uninstall              # remove what it installed
```

- The directory is chosen the same way opencode chooses it: `--config-dir` flags first, then `OPENCODE_CONFIG_DIR`, then `${XDG_CONFIG_HOME:-~/.config}/opencode`. opencode resolves a relative value against the directory it is launched from, so the installer warns and uses the current directory.
- Skills go to `<dir>/skills/`, with `${CLAUDE_SKILL_DIR}` rewritten to the installed path. They keep `disable-model-invocation: true`, which opencode honors: you invoke them from the `/skills` picker, and the model doesn't trigger them on its own.
- Agents become subagents at `<dir>/agents/<name>.md`.
- Ownership, `--force` backups and stale-file removal work the same as in the Kiro installer.
- After installing, it reads the global config (`<dir>/opencode.json`, `<dir>/opencode.jsonc`, and `$OPENCODE_CONFIG` when no `--config-dir` is given). It warns about any installed agent that is disabled there, and any skill or agent that a `skill` or `task` permission rule denies. Both the legacy (`agent`, `permission`, `tools`) and current (`agents`, `permissions`) formats are checked.

Tests: `tests/install-opencode.test.sh`

## Layout

```
.claude-plugin/marketplace.json      # marketplace catalog
plugins/
  quinn-skills/
    .claude-plugin/plugin.json       # plugin manifest
    skills/<skill-name>/SKILL.md     # one directory per skill
    agents/<agent-name>.md           # one file per subagent
```

## Adding a skill

1. Create `plugins/quinn-skills/skills/<skill-name>/SKILL.md` with `name` and `description` frontmatter.
2. Keep it working in Claude Code, Kiro and OpenCode: copy the "Harness compatibility" section from an existing skill, describe steps by capability ("ask the user to choose", "launch read-only subagents") rather than by Claude tool name, and use ordinary `bash` blocks for commands, not ` ```! ` blocks, which only Claude Code runs.
3. Bump `version` in both `plugins/quinn-skills/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json` (installed copies only update when the version changes).
4. Validate: `claude plugin validate .`

## Adding a plugin

Create `plugins/<plugin-name>/.claude-plugin/plugin.json` plus its `skills/`, `commands/`, `agents/` or `hooks/` directories, then add an entry to the `plugins` array in `.claude-plugin/marketplace.json`.

## License

MIT. See [LICENSE](LICENSE).
