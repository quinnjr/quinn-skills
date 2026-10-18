# Shared helpers for the non-Claude installers (install-kiro.sh, install-opencode.sh).
# Source after setting REPO_DIR. Callers set TARGET_FLAG and TOOL_NAME, call
# parse_args "$@", then for each target: set_target DIR, then install or uninstall.
#
# Installed paths are recorded in <target>/.quinn-skills/manifest. Paths that
# exist but are not in the manifest belong to the user and are skipped unless
# --force is given, in which case they are backed up first.

PLUGIN_DIR="${REPO_DIR}/plugins/quinn-skills"
VERSION="$(jq -r .version "${PLUGIN_DIR}/.claude-plugin/plugin.json" 2>/dev/null || echo unknown)"
STAMP="$(date +%Y%m%d-%H%M%S)"

TARGETS=()
FORCE=0
UNINSTALL=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [${TARGET_FLAG} DIR]... [--force] [--uninstall] [--dry-run]

  ${TARGET_FLAG} DIR  ${TARGET_HELP}
  --force      Replace skills/agents that this installer does not own,
               backing them up to <dir>/.quinn-skills/backup/<timestamp>/.
  --uninstall  Remove everything this installer put in each directory.
  --dry-run    Print what would change without touching anything.
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      "$TARGET_FLAG")
        [ $# -ge 2 ] || { echo "${TARGET_FLAG} needs a directory" >&2; exit 2; }
        TARGETS+=("$2"); shift 2 ;;
      "$TARGET_FLAG"=*) TARGETS+=("${1#*=}"); shift ;;
      --force) FORCE=1; shift ;;
      --uninstall) UNINSTALL=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
  done
  command -v jq >/dev/null 2>&1 || { echo "jq is required (https://jqlang.org)" >&2; exit 1; }
}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "${1%/}" ;;
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "${HOME}/${1#\~/}" ;;
    *) printf '%s\n' "${PWD}/${1%/}" ;;
  esac
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "      (dry-run) $*"
  else
    "$@"
  fi
}

set_target() {
  TARGET="$(abs_path "$1")"
  STATE_DIR="${TARGET}/.quinn-skills"
  MANIFEST="${STATE_DIR}/manifest"
}

# --- Claude agent markdown --------------------------------------------------

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

# Claude tool names from the agent's `tools:` line, one per line.
agent_claude_tools() {
  frontmatter "$1" | sed -n 's/^tools:[[:space:]]*//p' | tr -d '[]"' | tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true
}

# --- manifest ---------------------------------------------------------------

owned() { [ -f "$MANIFEST" ] && grep -qxF "$1" "$MANIFEST"; }

# Ensure a path relative to $TARGET is safe to (re)write. Returns 1 to skip.
claim() {
  local rel="$1" path="${TARGET}/$1"
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

begin_install() {
  NEW_MANIFEST="$(mktemp)"
  run mkdir -p "$STATE_DIR"
}

record() { printf '%s\n' "$@" >> "$NEW_MANIFEST"; }

# Copy every plugin skill to <target>/<subdir>/<name>/.
install_skills() {
  local subdir="$1" src name rel dest tmp
  run mkdir -p "${TARGET}/${subdir}"
  for src in "${PLUGIN_DIR}"/skills/*/SKILL.md; do
    [ -f "$src" ] || continue
    src="$(dirname "$src")"
    name="$(basename "$src")"
    rel="${subdir}/${name}"
    claim "$rel" || continue
    dest="${TARGET}/${rel}"
    echo "SKILL ${name}"
    if [ "$DRY_RUN" -eq 0 ]; then
      tmp="${dest}.quinn-tmp"
      rm -rf "$tmp"
      cp -R "$src" "$tmp"
      # Only Claude Code expands ${CLAUDE_SKILL_DIR}; point it at the installed copy.
      find "$tmp" -type f -name '*.md' | while read -r md; do
        if grep -q 'CLAUDE_SKILL_DIR' "$md"; then
          sed "s#\${CLAUDE_SKILL_DIR}#${dest}#g" "$md" > "${md}.quinn-sed" && mv "${md}.quinn-sed" "$md"
        fi
      done
      rm -rf "$dest"
      mv "$tmp" "$dest"
    fi
    record "$rel"
  done
}

# Remove what a previous install owned but this one did not, then save the manifest.
finish_install() {
  local rel
  if [ -f "$MANIFEST" ]; then
    while read -r rel; do
      [ -n "$rel" ] || continue
      if ! grep -qxF "$rel" "$NEW_MANIFEST"; then
        echo "REMOVE ${rel} — no longer in quinn-skills"
        run rm -rf "${TARGET:?}/${rel}"
      fi
    done < "$MANIFEST"
  fi
  if [ "$DRY_RUN" -eq 0 ]; then
    mv "$NEW_MANIFEST" "$MANIFEST"
    echo "$VERSION" > "${STATE_DIR}/version"
  else
    rm -f "$NEW_MANIFEST"
  fi
}

uninstall_target() {
  local rel
  if [ ! -f "$MANIFEST" ]; then
    echo "Nothing installed by quinn-skills here."
    return 0
  fi
  while read -r rel; do
    [ -n "$rel" ] || continue
    echo "REMOVE ${rel}"
    run rm -rf "${TARGET:?}/${rel}"
  done < "$MANIFEST"
  run rm -f "$MANIFEST" "${STATE_DIR}/version"
}

# Run install_target (defined by the caller) or uninstall for every target.
main_loop() {
  local raw
  echo "quinn-skills ${VERSION} — ${TOOL_NAME} installer"
  for raw in "${TARGETS[@]}"; do
    set_target "$raw"
    echo ""
    echo "${TOOL_NAME} ${TARGET_LABEL}: ${TARGET}"
    if [ "$UNINSTALL" -eq 1 ]; then
      uninstall_target
    else
      install_target
    fi
  done
}
