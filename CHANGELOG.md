# Changelog

## 1.0.0 — 2026-10-18

First release.

### Added
- Claude Code plugin marketplace (`.claude-plugin/marketplace.json`) with one plugin, `quinn-skills`.
- Skills:
  - `indepth-code-review`: seven parallel specialist reviewers of a diff.
  - `complexity-audit`: Big O audit of every function.
  - `optimize`: multi-domain performance audit, with optional profiling.
  - `security-hardening`: ten parallel security reviewers.
- Agents: `critical-reviewer`, `code-smell-detector`.
- `install-kiro.sh`: installs the skills and converted agents into Kiro homes (`--home`, `KIRO_HOME`, `~/.kiro`). Warns when the global `chat.defaultAgent` won't load them.
- `install-opencode.sh`: installs into OpenCode config directories (`--config-dir`, `OPENCODE_CONFIG_DIR`, `XDG_CONFIG_HOME`). Warns about disabled agents and denied skill or task rules in the global config.
- Every skill runs in Claude Code, Kiro and OpenCode. Each `SKILL.md` has a harness compatibility table.
- MIT license.
