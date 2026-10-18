#!/usr/bin/env bash
# Install the quinn-skills plugin's skills and agents into one or more OpenCode
# config directories.
#
# Config directory resolution (mirrors opencode):
#   1. --config-dir DIR (repeatable) — install into each listed directory
#   2. $OPENCODE_CONFIG_DIR
#   3. ${XDG_CONFIG_HOME:-~/.config}/opencode
#
# Skills are copied to <dir>/skills/<name>/. Agents are converted from Claude
# Code markdown to OpenCode subagents at <dir>/agents/<name>.md.
#
# After installing, the global config (<dir>/opencode.json[c], plus
# $OPENCODE_CONFIG for the default directory) is checked for settings that
# would hide what was installed: disabled agents and denied skill/task rules.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_NAME="OpenCode"
TARGET_LABEL="config dir"
TARGET_FLAG="--config-dir"
TARGET_HELP="OpenCode config directory to install into (repeatable). Defaults to
               \$OPENCODE_CONFIG_DIR, or \${XDG_CONFIG_HOME:-~/.config}/opencode."
# shellcheck source=lib/install-common.sh
. "${REPO_DIR}/lib/install-common.sh"

parse_args "$@"

# opencode resolves relative paths against the directory it is launched from,
# so a relative value has no single meaning. Resolve it against $PWD and say so.
resolve_env_dir() {
  local var="$1" value="$2"
  case "$value" in
    /*) printf '%s\n' "$value" ;;
    *)
      echo "WARN  ${var}='${value}' is relative; opencode resolves it per launch directory, using ${PWD}/${value}" >&2
      printf '%s\n' "${PWD}/${value}" ;;
  esac
}

USE_ENV_CONFIG=0
if [ ${#TARGETS[@]} -eq 0 ]; then
  USE_ENV_CONFIG=1
  if [ -n "${OPENCODE_CONFIG_DIR:-}" ]; then
    TARGETS=("$(resolve_env_dir OPENCODE_CONFIG_DIR "$OPENCODE_CONFIG_DIR")")
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
    TARGETS=("$(resolve_env_dir XDG_CONFIG_HOME "$XDG_CONFIG_HOME")/opencode")
  else
    TARGETS=("${HOME}/.config/opencode")
  fi
fi

write_agent_md() {
  local src="$1" dest="$2"
  {
    echo "---"
    printf 'description: %s\n' "$(agent_description "$src" | jq -R .)"
    echo "mode: subagent"
    echo "---"
    agent_body "$src"
  } > "$dest"
}

# --- global settings check --------------------------------------------------

# Parse JSON or JSONC (comments, trailing commas) to plain JSON on stdout.
read_config() {
  perl -0pe 's{/\*.*?\*/}{}gs; s{(^|[^:"\\])//[^\n]*}{$1}g; s{,(\s*[\]\}])}{$1}g' "$1" | jq -c . 2>/dev/null
}

# Permission rules from a config, in opencode's order: legacy `tools`, legacy
# `permission`, then `permissions`. Output: action<TAB>resource<TAB>effect.
config_rules() {
  jq -r '
    [ (.tools // {} | to_entries[] | {action: .key, resource: "*", effect: (if .value then "allow" else "deny" end)}),
      (.permission // empty
        | if type == "string" then {action: "*", resource: "*", effect: .}
          else to_entries[]
            | if (.value | type) == "string" then {action: .key, resource: "*", effect: .value}
              else .key as $a | .value | to_entries[] | {action: $a, resource: .key, effect: .value} end
          end),
      (.permissions // [])[]
    ] | .[] | [.action, (.resource // "*"), .effect] | @tsv'
}

# Last matching rule wins, as in opencode.
effect_for() {
  local action="$1" name="$2" rules="$3" a r e effect=""
  while IFS="$(printf '\t')" read -r a r e; do
    [ -n "$a" ] || continue
    # shellcheck disable=SC2053 # rule resources are glob patterns
    if { [ "$a" = "$action" ] || [ "$a" = "*" ]; } && [[ "$name" == $r ]]; then
      effect="$e"
    fi
  done <<< "$rules"
  printf '%s\n' "$effect"
}

check_global_settings() {
  local files=() f json rules="" disabled_agents="" src name
  for f in "${TARGET}/opencode.json" "${TARGET}/opencode.jsonc"; do
    [ -f "$f" ] && files+=("$f")
  done
  if [ "$USE_ENV_CONFIG" -eq 1 ] && [ -n "${OPENCODE_CONFIG:-}" ] && [ -f "$OPENCODE_CONFIG" ]; then
    files+=("$OPENCODE_CONFIG")
  fi
  [ ${#files[@]} -gt 0 ] || return 0

  for f in "${files[@]}"; do
    if ! json="$(read_config "$f")" || [ -z "$json" ]; then
      echo "NOTE  could not parse ${f}; skipped its settings check"
      continue
    fi
    rules+="$(printf '%s' "$json" | config_rules)"$'\n'
    disabled_agents+="$(printf '%s' "$json" | jq -r '
      ((.agent // {}) | to_entries[] | select(.value.disable == true) | .key),
      ((.agents // {}) | to_entries[] | select(.value.disabled == true) | .key)')"$'\n'
  done

  for src in "${PLUGIN_DIR}"/skills/*/SKILL.md; do
    [ -f "$src" ] || continue
    name="$(basename "$(dirname "$src")")"
    if [ "$(effect_for skill "$name" "$rules")" = "deny" ]; then
      echo "WARN  skill '${name}' is denied by a skill permission rule in your global config"
    fi
  done
  for src in "${PLUGIN_DIR}"/agents/*.md; do
    [ -f "$src" ] || continue
    name="$(basename "$src" .md)"
    if printf '%s\n' "$disabled_agents" | grep -qxF "$name"; then
      echo "WARN  agent '${name}' is disabled in your global config"
    elif [ "$(effect_for task "$name" "$rules")" = "deny" ]; then
      echo "WARN  agent '${name}' is denied by a task permission rule in your global config"
    fi
  done
}

install_target() {
  local src name rel
  begin_install
  install_skills skills
  run mkdir -p "${TARGET}/agents"

  for src in "${PLUGIN_DIR}"/agents/*.md; do
    [ -f "$src" ] || continue
    name="$(basename "$src" .md)"
    rel="agents/${name}.md"
    claim "$rel" || continue
    echo "AGENT ${name}"
    if [ "$DRY_RUN" -eq 0 ]; then
      write_agent_md "$src" "${TARGET}/${rel}.quinn-tmp"
      mv "${TARGET}/${rel}.quinn-tmp" "${TARGET}/${rel}"
    fi
    record "$rel"
  done

  finish_install
  check_global_settings
}

main_loop
