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
2. Bump `version` in both `plugins/quinn-skills/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json` (installed copies only update when the version changes).
3. Validate: `claude plugin validate .`

## Adding a plugin

Create `plugins/<plugin-name>/.claude-plugin/plugin.json` plus its `skills/`, `commands/`, `agents/` or `hooks/` directories, then add an entry to the `plugins` array in `.claude-plugin/marketplace.json`.
