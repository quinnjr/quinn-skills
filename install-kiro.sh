#!/usr/bin/env bash
# Install the quinn-skills plugin's skills and agents into one or more Kiro homes.
#
# Kiro home resolution (mirrors kiro-cli):
#   1. --home DIR (repeatable) — install into each listed home
#   2. $KIRO_HOME, when it is an absolute path (kiro-cli ignores a relative one)
#   3. ~/.kiro
#
# Skills are copied to <home>/skills/<name>/. Agents are converted from Claude
# Code markdown to Kiro JSON at <home>/agents/<name>.json with their prompt at
# <home>/prompts/<name>.md. Everything is copied, not symlinked: kiro-cli's
# auto-upgrade rewrites agent configs in place, which would edit this repo.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_NAME="Kiro"
TARGET_LABEL="home"
TARGET_FLAG="--home"
TARGET_HELP="Kiro home to install into (repeatable). Defaults to \$KIRO_HOME,
               or ~/.kiro when KIRO_HOME is unset or not an absolute path."
# shellcheck source=lib/install-common.sh
. "${REPO_DIR}/lib/install-common.sh"

parse_args "$@"

if [ ${#TARGETS[@]} -eq 0 ]; then
  if [ -n "${KIRO_HOME:-}" ]; then
    case "$KIRO_HOME" in
      /*) TARGETS=("$KIRO_HOME") ;;
      *)
        echo "WARN  KIRO_HOME='${KIRO_HOME}' is not absolute; kiro-cli ignores it, using ~/.kiro" >&2
        TARGETS=("${HOME}/.kiro") ;;
    esac
  else
    TARGETS=("${HOME}/.kiro")
  fi
fi

# Claude tool names -> Kiro tool names, as a JSON array.
kiro_tools() {
  agent_claude_tools "$1" |
    while read -r tool; do
      case "$tool" in
        Read) echo read ;;
        Write|Edit|MultiEdit) echo write ;;
        Grep) echo grep ;;
        Glob) echo glob ;;
        Bash) echo shell ;;
        WebFetch|WebSearch) echo web_fetch ;;
      esac
    done | awk '!seen[$0]++' | jq -R . | jq -cs .
}

write_agent_json() {
  local src="$1" dest="$2" name tools
  name="$(basename "$src" .md)"
  tools="$(kiro_tools "$src")"
  [ "$tools" != "[]" ] || tools='["read","grep","glob"]'
  jq -n \
    --arg name "$name" \
    --arg description "$(agent_description "$src")" \
    --arg prompt "file://${TARGET}/prompts/${name}.md" \
    --arg home "$TARGET" \
    --argjson tools "$tools" \
    '{
      name: $name,
      description: $description,
      prompt: $prompt,
      tools: $tools,
      allowedTools: [$tools[] | select(. == "read" or . == "grep" or . == "glob")],
      resources: [
        "file://.kiro/steering/**/*.md",
        "file://\($home)/steering/**/*.md",
        "skill://.kiro/skills/*/SKILL.md",
        "skill://\($home)/skills/*/SKILL.md"
      ]
    }' > "$dest"
}

check_default_agent() {
  local settings="${TARGET}/settings/cli.json" agent agent_file
  [ -f "$settings" ] || return 0
  agent="$(jq -r '."chat.defaultAgent" // empty' "$settings" 2>/dev/null || true)"
  case "$agent" in ""|kiro_*) return 0 ;; esac
  agent_file="${TARGET}/agents/${agent}.json"
  if [ ! -f "$agent_file" ]; then
    echo "NOTE  default agent '${agent}' (from ${settings}) is not in ${TARGET}/agents; make sure it loads skill://${TARGET}/skills/*/SKILL.md"
    return 0
  fi
  if ! jq -e --arg h "$TARGET" '
      [.resources[]? | if type == "string" then . else (.source? // .path? // "") end
       | select(startswith("skill://\($h)/skills/") or startswith("skill://~/.kiro/skills/"))]
      | length > 0' "$agent_file" >/dev/null 2>&1; then
    echo "WARN  default agent '${agent}' does not load skills from ${TARGET}/skills;"
    echo "      add \"skill://${TARGET}/skills/*/SKILL.md\" to \"resources\" in ${agent_file}"
  fi
}

install_target() {
  local src name
  begin_install
  install_skills skills
  run mkdir -p "${TARGET}/agents" "${TARGET}/prompts"

  for src in "${PLUGIN_DIR}"/agents/*.md; do
    [ -f "$src" ] || continue
    name="$(basename "$src" .md)"
    # The JSON config and its prompt are one unit: skip both if either is foreign.
    claim "agents/${name}.json" || continue
    claim "prompts/${name}.md" || continue
    echo "AGENT ${name}"
    if [ "$DRY_RUN" -eq 0 ]; then
      agent_body "$src" > "${TARGET}/prompts/${name}.md"
      write_agent_json "$src" "${TARGET}/agents/${name}.json.quinn-tmp"
      mv "${TARGET}/agents/${name}.json.quinn-tmp" "${TARGET}/agents/${name}.json"
    fi
    record "agents/${name}.json" "prompts/${name}.md"
  done

  finish_install
  check_default_agent
}

main_loop
