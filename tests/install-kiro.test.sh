#!/usr/bin/env bash
# Tests for install-kiro.sh. Runs against throwaway HOME/KIRO_HOME directories.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_DIR}/install-kiro.sh"
REAL_HOME="$HOME"
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
  unset KIRO_HOME
}

install() { (cd "$WORK/case" && "$INSTALLER" "$@") > "$WORK/case/out" 2>&1; }

# --- default home is ~/.kiro ---
fresh
install
check "default: installs skills into ~/.kiro" test -f "$HOME/.kiro/skills/indepth-code-review/SKILL.md"
check "default: installs agent JSON" test -f "$HOME/.kiro/agents/critical-reviewer.json"
check "default: installs agent prompt" test -f "$HOME/.kiro/prompts/critical-reviewer.md"
check "default: writes manifest" grep -qx "skills/optimize" "$HOME/.kiro/.quinn-skills/manifest"

# --- agent conversion ---
J="$HOME/.kiro/agents/critical-reviewer.json"
check "agent: name" jq -e '.name == "critical-reviewer"' "$J"
check "agent: description has no examples" jq -e '(.description | test("Examples|<example>") | not) and (.description | length > 20)' "$J"
check "agent: prompt points at this home" jq -e --arg p "file://$HOME/.kiro/prompts/critical-reviewer.md" '.prompt == $p' "$J"
check "agent: tools mapped" jq -e '.tools == ["read","write","grep","glob","shell"]' "$J"
check "agent: only read-only tools pre-approved" jq -e '.allowedTools == ["read","grep","glob"]' "$J"
check "agent: loads skills from this home" jq -e --arg s "skill://$HOME/.kiro/skills/*/SKILL.md" '.resources | index($s)' "$J"
check "agent: prompt has no frontmatter" bash -c "! head -1 '$HOME/.kiro/prompts/critical-reviewer.md' | grep -qx -- '---'"

# --- CLAUDE_SKILL_DIR substitution ---
check "skill: CLAUDE_SKILL_DIR rewritten" bash -c "! grep -rq CLAUDE_SKILL_DIR '$HOME/.kiro/skills'"
check "skill: points at installed dir" grep -q "$HOME/.kiro/skills/optimize/agents/" "$HOME/.kiro/skills/optimize/SKILL.md"

# --- KIRO_HOME (absolute) is respected ---
fresh
export KIRO_HOME="$WORK/case/custom-kiro"
install
check "KIRO_HOME: installs there" test -f "$KIRO_HOME/skills/security-hardening/SKILL.md"
check "KIRO_HOME: leaves ~/.kiro alone" test ! -e "$HOME/.kiro"
check "KIRO_HOME: agent paths use KIRO_HOME" jq -e --arg h "$KIRO_HOME" '.prompt | startswith("file://\($h)/")' "$KIRO_HOME/agents/code-smell-detector.json"

# --- relative KIRO_HOME is ignored, like kiro-cli ---
fresh
export KIRO_HOME="relative-kiro"
install
check "relative KIRO_HOME: falls back to ~/.kiro" test -f "$HOME/.kiro/skills/optimize/SKILL.md"
check "relative KIRO_HOME: warns" grep -q "not absolute" "$WORK/case/out"
check "relative KIRO_HOME: does not create it" test ! -e "$WORK/case/relative-kiro"

# --- multiple --home flags override KIRO_HOME ---
fresh
export KIRO_HOME="$WORK/case/ignored"
install --home "$WORK/case/a" --home "$WORK/case/b"
check "--home: installs into first" test -f "$WORK/case/a/skills/optimize/SKILL.md"
check "--home: installs into second" test -f "$WORK/case/b/skills/optimize/SKILL.md"
check "--home: overrides KIRO_HOME" test ! -e "$KIRO_HOME"

# --- user-owned files are not clobbered ---
fresh
mkdir -p "$HOME/.kiro/skills/optimize" "$HOME/.kiro/agents"
echo mine > "$HOME/.kiro/skills/optimize/SKILL.md"
echo '{"name":"critical-reviewer"}' > "$HOME/.kiro/agents/critical-reviewer.json"
install
check "foreign skill: kept" grep -qx mine "$HOME/.kiro/skills/optimize/SKILL.md"
check "foreign skill: reported" grep -q "SKIP  skills/optimize" "$WORK/case/out"
check "foreign agent: kept" jq -e '. == {"name":"critical-reviewer"}' "$HOME/.kiro/agents/critical-reviewer.json"
check "foreign agent: prompt not written" test ! -e "$HOME/.kiro/prompts/critical-reviewer.md"
check "foreign skill: not in manifest" bash -c "! grep -qx skills/optimize '$HOME/.kiro/.quinn-skills/manifest'"

# --- --force backs up then replaces ---
install --force
check "--force: replaces skill" bash -c "! grep -qx mine '$HOME/.kiro/skills/optimize/SKILL.md'"
check "--force: backs up skill" bash -c "grep -rqx mine '$HOME/.kiro/.quinn-skills/backup'"

# --- reinstall is idempotent and updates owned files ---
fresh
install
echo stale > "$HOME/.kiro/skills/optimize/SKILL.md"
install
check "reinstall: overwrites owned files" bash -c "! grep -qx stale '$HOME/.kiro/skills/optimize/SKILL.md'"
check "reinstall: no SKIP for owned files" bash -c "! grep -q SKIP '$WORK/case/out'"

# --- stale owned entries are removed ---
echo "skills/retired-skill" >> "$HOME/.kiro/.quinn-skills/manifest"
mkdir -p "$HOME/.kiro/skills/retired-skill"
install
check "stale: removed" test ! -e "$HOME/.kiro/skills/retired-skill"

# --- global settings: default agent check ---
fresh
mkdir -p "$HOME/.kiro/settings" "$HOME/.kiro/agents"
echo '{"chat.defaultAgent":"work"}' > "$HOME/.kiro/settings/cli.json"
echo '{"name":"work","resources":["file://AGENTS.md"]}' > "$HOME/.kiro/agents/work.json"
install
check "settings: warns when default agent misses skills" grep -q "default agent 'work' does not load skills" "$WORK/case/out"
echo "{\"name\":\"work\",\"resources\":[\"skill://$HOME/.kiro/skills/*/SKILL.md\"]}" > "$HOME/.kiro/agents/work.json"
install
check "settings: quiet when default agent loads skills" bash -c "! grep -q \"default agent 'work'\" '$WORK/case/out'"
echo '{"chat.defaultAgent":"kiro_default"}' > "$HOME/.kiro/settings/cli.json"
install
check "settings: built-in default agent is fine" bash -c "! grep -q 'default agent' '$WORK/case/out'"

# --- dry run touches nothing ---
fresh
install --dry-run
check "dry-run: creates nothing" test ! -e "$HOME/.kiro"

# --- uninstall removes only what it installed ---
fresh
mkdir -p "$HOME/.kiro/skills/user-skill"
install
install --uninstall
check "uninstall: removes skills" test ! -e "$HOME/.kiro/skills/optimize"
check "uninstall: removes agents" test ! -e "$HOME/.kiro/agents/critical-reviewer.json"
check "uninstall: removes manifest" test ! -e "$HOME/.kiro/.quinn-skills/manifest"
check "uninstall: keeps user skills" test -d "$HOME/.kiro/skills/user-skill"

# --- generated agents pass kiro-cli validation, when available ---
if command -v kiro-cli >/dev/null 2>&1; then
  fresh
  install
  for j in "$HOME"/.kiro/agents/*.json; do
    # kiro-cli needs the real HOME for its own data dir.
    check "kiro-cli validates $(basename "$j")" env HOME="$REAL_HOME" kiro-cli agent validate --path "$j"
  done
fi

echo ""
echo "${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
