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

## Layout

```
.claude-plugin/marketplace.json      # marketplace catalog
plugins/
  quinn-skills/
    .claude-plugin/plugin.json       # plugin manifest
    skills/<skill-name>/SKILL.md     # one directory per skill
```

## Adding a skill

1. Create `plugins/quinn-skills/skills/<skill-name>/SKILL.md` with `name` and `description` frontmatter.
2. Bump `version` in both `plugins/quinn-skills/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json` (installed copies only update when the version changes).
3. Validate: `claude plugin validate .`

## Adding a plugin

Create `plugins/<plugin-name>/.claude-plugin/plugin.json` plus its `skills/`, `commands/`, `agents/` or `hooks/` directories, then add an entry to the `plugins` array in `.claude-plugin/marketplace.json`.
