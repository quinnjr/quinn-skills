#!/usr/bin/env bash
# Tests for install-opencode.sh. Runs against throwaway HOME/config directories.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_DIR}/install-opencode.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }
check() { local desc="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi; }

fresh() {
  rm -rf "$WORK/case"
  mkdir -p "$WORK/case/home"
  export HOME="$WORK/case/home"
  unset OPENCODE_CONFIG_DIR XDG_CONFIG_HOME OPENCODE_CONFIG
  OC="$HOME/.config/opencode"
}

install() { (cd "$WORK/case" && "$INSTALLER" "$@") > "$WORK/case/out" 2>&1; }

# --- default is ~/.config/opencode ---
fresh
install
check "default: installs skills" test -f "$OC/skills/indepth-code-review/SKILL.md"
check "default: installs agents" test -f "$OC/agents/critical-reviewer.md"
check "default: writes manifest" grep -qx "agents/code-smell-detector.md" "$OC/.quinn-skills/manifest"

# --- agent conversion ---
A="$OC/agents/critical-reviewer.md"
check "agent: is a subagent" grep -qx "mode: subagent" "$A"
check "agent: description is one JSON-quoted line" bash -c "grep '^description: \"Use this agent' '$A' | grep -qv Examples"
check "agent: drops Claude-only frontmatter" bash -c "! grep -qE '^(name|model|color|tools):' '$A'"
check "agent: keeps prompt body" grep -q "## Step 1: Determine the Diff" "$A"
check "agent: exactly one frontmatter block" bash -c "[ \$(grep -cx -- '---' '$A') -ge 2 ] && head -1 '$A' | grep -qx -- '---'"

# --- CLAUDE_SKILL_DIR substitution ---
check "skill: CLAUDE_SKILL_DIR rewritten" bash -c "! grep -rq CLAUDE_SKILL_DIR '$OC/skills'"
check "skill: points at installed dir" grep -q "$OC/skills/optimize/agents/" "$OC/skills/optimize/SKILL.md"

# --- XDG_CONFIG_HOME is respected ---
fresh
export XDG_CONFIG_HOME="$WORK/case/xdg"
install
check "XDG_CONFIG_HOME: installs there" test -f "$XDG_CONFIG_HOME/opencode/skills/optimize/SKILL.md"
check "XDG_CONFIG_HOME: leaves ~/.config alone" test ! -e "$HOME/.config"

# --- OPENCODE_CONFIG_DIR beats XDG_CONFIG_HOME ---
fresh
export XDG_CONFIG_HOME="$WORK/case/xdg"
export OPENCODE_CONFIG_DIR="$WORK/case/occ"
install
check "OPENCODE_CONFIG_DIR: installs there" test -f "$OPENCODE_CONFIG_DIR/agents/critical-reviewer.md"
check "OPENCODE_CONFIG_DIR: beats XDG_CONFIG_HOME" test ! -e "$XDG_CONFIG_HOME"

# --- relative OPENCODE_CONFIG_DIR resolves against $PWD with a warning ---
fresh
export OPENCODE_CONFIG_DIR="rel-oc"
install
check "relative dir: resolved against PWD" test -f "$WORK/case/rel-oc/skills/optimize/SKILL.md"
check "relative dir: warns" grep -q "is relative" "$WORK/case/out"

# --- multiple --config-dir flags override env ---
fresh
export OPENCODE_CONFIG_DIR="$WORK/case/ignored"
install --config-dir "$WORK/case/a" --config-dir "$WORK/case/b"
check "--config-dir: first" test -f "$WORK/case/a/skills/optimize/SKILL.md"
check "--config-dir: second" test -f "$WORK/case/b/agents/critical-reviewer.md"
check "--config-dir: overrides env" test ! -e "$OPENCODE_CONFIG_DIR"

# --- user-owned files are not clobbered; --force backs up ---
fresh
mkdir -p "$OC/skills/optimize" "$OC/agents"
echo mine > "$OC/skills/optimize/SKILL.md"
echo mine > "$OC/agents/critical-reviewer.md"
install
check "foreign skill: kept" grep -qx mine "$OC/skills/optimize/SKILL.md"
check "foreign agent: kept" grep -qx mine "$OC/agents/critical-reviewer.md"
check "foreign: reported" grep -q "SKIP  agents/critical-reviewer.md" "$WORK/case/out"
install --force
check "--force: replaces agent" grep -qx "mode: subagent" "$OC/agents/critical-reviewer.md"
check "--force: backs up agent" bash -c "grep -rqx mine '$OC/.quinn-skills/backup'"

# --- global settings checks ---
fresh
mkdir -p "$OC"
cat > "$OC/opencode.jsonc" <<'EOF'
{
  // legacy-style settings
  "agent": { "code-smell-detector": { "disable": true } },
  "permission": { "skill": { "optimize": "deny", "*": "allow" } },
  /* block comment */
  "$schema": "https://opencode.ai/config.json",
}
EOF
install
check "settings: JSONC parsed" bash -c "! grep -q 'could not parse' '$WORK/case/out'"
check "settings: legacy disabled agent" grep -q "agent 'code-smell-detector' is disabled" "$WORK/case/out"
check "settings: last matching rule wins (allow after deny)" bash -c "! grep -q \"skill 'optimize' is denied\" '$WORK/case/out'"

echo '{"permissions":[{"action":"skill","resource":"*","effect":"allow"},{"action":"skill","resource":"security-*","effect":"deny"}],"agents":{"critical-reviewer":{"disabled":true}}}' > "$OC/opencode.json"
rm "$OC/opencode.jsonc"
install
check "settings: v2 skill deny by glob" grep -q "skill 'security-hardening' is denied" "$WORK/case/out"
check "settings: v2 deny is scoped" bash -c "! grep -q \"skill 'optimize' is denied\" '$WORK/case/out'"
check "settings: v2 disabled agent" grep -q "agent 'critical-reviewer' is disabled" "$WORK/case/out"

echo '{"tools":{"task":false}}' > "$OC/opencode.json"
install
check "settings: legacy tools.task=false denies agents" grep -q "agent 'critical-reviewer' is denied by a task permission" "$WORK/case/out"

echo '{}' > "$OC/opencode.json"
echo '{"permission":"deny"}' > "$WORK/case/extra.json"
export OPENCODE_CONFIG="$WORK/case/extra.json"
install
check "settings: OPENCODE_CONFIG is checked" grep -q "skill 'optimize' is denied" "$WORK/case/out"
install --config-dir "$OC"
check "settings: OPENCODE_CONFIG ignored for explicit --config-dir" bash -c "! grep -q denied '$WORK/case/out'"
unset OPENCODE_CONFIG

echo '{ not json' > "$OC/opencode.json"
install
check "settings: unparseable config is reported, not fatal" grep -q "could not parse" "$WORK/case/out"

# --- reinstall / stale / dry-run / uninstall ---
fresh
install
echo "skills/retired-skill" >> "$OC/.quinn-skills/manifest"
mkdir -p "$OC/skills/retired-skill"
install
check "reinstall: no SKIP for owned files" bash -c "! grep -q SKIP '$WORK/case/out'"
check "stale: removed" test ! -e "$OC/skills/retired-skill"

fresh
install --dry-run
check "dry-run: creates nothing" test ! -e "$OC"

fresh
mkdir -p "$OC/skills/user-skill"
install
install --uninstall
check "uninstall: removes skills" test ! -e "$OC/skills/optimize"
check "uninstall: removes agents" test ! -e "$OC/agents/critical-reviewer.md"
check "uninstall: keeps user skills" test -d "$OC/skills/user-skill"

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
