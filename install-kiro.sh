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
#
# Installed paths are recorded in <home>/.quinn-skills/manifest. Paths that
# exist but are not in the manifest belong to the user and are skipped unless
# --force is given, in which case they are backed up first.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${REPO_DIR}/plugins/quinn-skills"
VERSION="$(jq -r .version "${PLUGIN_DIR}/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--home DIR]... [--force] [--uninstall] [--dry-run]

  --home DIR   Kiro home to install into (repeatable). Defaults to \$KIRO_HOME,
               or ~/.kiro when KIRO_HOME is unset or not an absolute path.
  --force      Replace skills/agents that this installer does not own,
               backing them up to <home>/.quinn-skills/backup/<timestamp>/.
  --uninstall  Remove everything this installer put in each home.
  --dry-run    Print what would change without touching anything.
EOF
}

HOMES=()
FORCE=0
UNINSTALL=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --home)
      [ $# -ge 2 ] || { echo "--home needs a directory" >&2; exit 2; }
      HOMES+=("$2"); shift 2 ;;
    --home=*) HOMES+=("${1#--home=}"); shift ;;
    --force) FORCE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq is required (https://jqlang.org)" >&2; exit 1; }

abs_path() {
  case "$1" in
    /*) printf '%s\n' "${1%/}" ;;
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "${HOME}/${1#\~/}" ;;
    *) printf '%s\n' "${PWD}/${1%/}" ;;
  esac
}

if [ ${#HOMES[@]} -eq 0 ]; then
  if [ -n "${KIRO_HOME:-}" ]; then
    case "$KIRO_HOME" in
      /*) HOMES=("$KIRO_HOME") ;;
      *)
        echo "WARN  KIRO_HOME='${KIRO_HOME}' is not absolute; kiro-cli ignores it, using ~/.kiro" >&2
        HOMES=("${HOME}/.kiro") ;;
    esac
  else
    HOMES=("${HOME}/.kiro")
  fi
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "      (dry-run) $*"
  else
    "$@"
  fi
}

# --- Claude agent markdown -> Kiro pieces ----------------------------------

# Frontmatter body (between the first two '---' lines).
frontmatter() { awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$1"; }

# Prompt body (everything after the frontmatter).
agent_body() { awk 'NR==1 && $0=="---"{f=1; next} f==1 && $0=="---"{f=2; next} f==2{print}' "$1"; }

# First paragraph of the description, without the trailing "Examples:".
agent_description() {
  frontmatter "$1" | awk '
    /^description:/ { sub(/^description:[ \t]*\|?[ \t]*/, ""); if (length) { out = $0; done = 1 }; grab = 1; next }
    grab && /^[^ \t]/ { exit }
    grab && !done {
      line = $0; sub(/^[ \t]+/, "", line)
      if (line == "") { if (out != "") done = 1; next }
      out = (out == "" ? line : out " " line)
    }
    END { sub(/[ \t]*Examples:[ \t]*$/, "", out); print out }'
}

# Claude tool names -> Kiro tool names, as a JSON array.
agent_tools() {
  frontmatter "$1" | sed -n 's/^tools:[[:space:]]*//p' | tr -d '[]"' | tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
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
  local src="$1" home="$2" dest="$3" name tools
  name="$(basename "$src" .md)"
  tools="$(agent_tools "$src")"
  [ "$tools" != "[]" ] || tools='["read","grep","glob"]'
  jq -n \
    --arg name "$name" \
    --arg description "$(agent_description "$src")" \
    --arg prompt "file://${home}/prompts/${name}.md" \
    --arg home "$home" \
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

# --- manifest ---------------------------------------------------------------

owned() { [ -f "$MANIFEST" ] && grep -qxF "$1" "$MANIFEST"; }

# Ensure a relative path under $KH is safe to (re)write. Returns 1 to skip.
claim() {
  local rel="$1" path="${KH}/$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then return 0; fi
  if owned "$rel"; then return 0; fi
  if [ "$FORCE" -eq 1 ]; then
    local backup="${STATE_DIR}/backup/${STAMP}/${rel}"
    echo "BACKUP ${rel} -> ${backup}"
    run mkdir -p "$(dirname "$backup")"
    run mv "$path" "$backup"
    return 0
  fi
  echo "SKIP  ${rel} — already exists and was not installed by quinn-skills (use --force to replace)"
  return 1
}

# --- per-home install -------------------------------------------------------

check_default_agent() {
  local settings="${KH}/settings/cli.json" agent agent_file
  [ -f "$settings" ] || return 0
  agent="$(jq -r '."chat.defaultAgent" // empty' "$settings" 2>/dev/null || true)"
  case "$agent" in ""|kiro_*) return 0 ;; esac
  agent_file="${KH}/agents/${agent}.json"
  if [ ! -f "$agent_file" ]; then
    echo "NOTE  default agent '${agent}' (from ${settings}) is not in ${KH}/agents; make sure it loads skill://${KH}/skills/*/SKILL.md"
    return 0
  fi
  if ! jq -e --arg h "$KH" '
      [.resources[]? | if type == "string" then . else (.source? // .path? // "") end
       | select(startswith("skill://\($h)/skills/") or startswith("skill://~/.kiro/skills/"))]
      | length > 0' "$agent_file" >/dev/null 2>&1; then
    echo "WARN  default agent '${agent}' does not load skills from ${KH}/skills;"
    echo "      add \"skill://${KH}/skills/*/SKILL.md\" to \"resources\" in ${agent_file}"
  fi
}

install_home() {
  local new_manifest rel name src dest tmp
  new_manifest="$(mktemp)"
  run mkdir -p "${KH}/skills" "${KH}/agents" "${KH}/prompts" "$STATE_DIR"

  for src in "${PLUGIN_DIR}"/skills/*/SKILL.md; do
    [ -f "$src" ] || continue
    src="$(dirname "$src")"
    name="$(basename "$src")"
    rel="skills/${name}"
    claim "$rel" || continue
    dest="${KH}/${rel}"
    echo "SKILL ${name}"
    if [ "$DRY_RUN" -eq 0 ]; then
      tmp="${dest}.quinn-tmp"
      rm -rf "$tmp"
      cp -R "$src" "$tmp"
      # Kiro does not expand ${CLAUDE_SKILL_DIR}; point it at the installed copy.
      find "$tmp" -type f -name '*.md' | while read -r md; do
        if grep -q 'CLAUDE_SKILL_DIR' "$md"; then
          sed "s#\${CLAUDE_SKILL_DIR}#${dest}#g" "$md" > "${md}.quinn-sed" && mv "${md}.quinn-sed" "$md"
        fi
      done
      rm -rf "$dest"
      mv "$tmp" "$dest"
    fi
    echo "$rel" >> "$new_manifest"
  done

  for src in "${PLUGIN_DIR}"/agents/*.md; do
    [ -f "$src" ] || continue
    name="$(basename "$src" .md)"
    # The JSON config and its prompt are one unit: skip both if either is foreign.
    claim "agents/${name}.json" || continue
    claim "prompts/${name}.md" || continue
    echo "AGENT ${name}"
    if [ "$DRY_RUN" -eq 0 ]; then
      agent_body "$src" > "${KH}/prompts/${name}.md"
      write_agent_json "$src" "$KH" "${KH}/agents/${name}.json.quinn-tmp"
      mv "${KH}/agents/${name}.json.quinn-tmp" "${KH}/agents/${name}.json"
    fi
    printf '%s\n' "agents/${name}.json" "prompts/${name}.md" >> "$new_manifest"
  done

  # Remove things a previous install owned that the plugin no longer ships.
  if [ -f "$MANIFEST" ]; then
    while read -r rel; do
      [ -n "$rel" ] || continue
      if ! grep -qxF "$rel" "$new_manifest"; then
        echo "REMOVE ${rel} — no longer in quinn-skills"
        run rm -rf "${KH:?}/${rel}"
      fi
    done < "$MANIFEST"
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    mv "$new_manifest" "$MANIFEST"
    echo "$VERSION" > "${STATE_DIR}/version"
  else
    rm -f "$new_manifest"
  fi

  check_default_agent
}

uninstall_home() {
  if [ ! -f "$MANIFEST" ]; then
    echo "Nothing installed by quinn-skills here."
    return 0
  fi
  while read -r rel; do
    [ -n "$rel" ] || continue
    echo "REMOVE ${rel}"
    run rm -rf "${KH:?}/${rel}"
  done < "$MANIFEST"
  run rm -f "$MANIFEST" "${STATE_DIR}/version"
}

STAMP="$(date +%Y%m%d-%H%M%S)"
echo "quinn-skills ${VERSION} — Kiro installer"

for raw in "${HOMES[@]}"; do
  KH="$(abs_path "$raw")"
  STATE_DIR="${KH}/.quinn-skills"
  MANIFEST="${STATE_DIR}/manifest"
  echo ""
  echo "Kiro home: ${KH}"
  if [ "$UNINSTALL" -eq 1 ]; then
    uninstall_home
  else
    install_home
  fi
done
