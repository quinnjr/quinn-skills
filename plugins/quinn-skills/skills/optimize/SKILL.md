---
name: optimize
description: >-
  Orchestrate parallel optimization agents across runtime performance,
  database queries, bundle/build, memory/resource use, and general
  performance (I/O, caching, async). Auto-detects which domains actually
  apply to the repository (e.g. skips the database agent when no ORM,
  driver, or SQL/migration signal is found) unless domains are explicitly
  requested. Reports tiered findings with concrete optimizations and offers
  to implement them. Optional dynamic profiling via --profile for runtime
  and memory agents. Use when auditing performance, hunting wasted CPU/RAM,
  or preparing a service for scale.
user-invocable: true
disable-model-invocation: true
allowed-tools: Agent Bash(git *) Bash(cat *) Bash(ls *) Bash(rg *) Bash(npm *) Bash(pnpm *) Bash(node *) Bash(cargo *) Bash(go *) Bash(python *) Bash(python3 *) Bash(pytest *) Bash(uv *) Bash(poetry *) Bash(time *) Read Grep Glob Edit AskUserQuestion
argument-hint: "[domains: all | runtime | db | bundle | memory | general] [path] [--profile] [--threshold critical|warning|info]"
---

# Optimize — Multi-Domain Performance Audit

You are orchestrating a **comprehensive performance optimization audit** of this
repository using up to 5 parallel specialist agents — runtime, database
queries, bundle/build, memory/resource, and general performance. Which
agents actually launch depends on what the repository contains: `db` and
`bundle` only run when Phase 1.4 detects a signal for them (skip a database
audit on a repo with no data layer). Each launched agent owns one domain and
reports findings in severity tiers with concrete, behavior-preserving
optimizations. After the report you offer to implement fixes.

This skill is related to `/complexity-audit` but broader: `/complexity-audit`
scores Big O for every function; `/optimize` hunts runtime hot paths, DB
anti-patterns, bundle bloat, memory waste, and cross-cutting performance
issues that Big O alone won't catch.

## Inputs

`$ARGUMENTS` is free-form. Parse it for:

- **Domains**: comma-separated subset of `runtime`, `db`, `bundle`, `memory`,
  `general`, or `all` (default). Example: `runtime,db`. When left at the
  default `all`, `db` and `bundle` are only launched if Phase 1.4 detects
  a signal for them — see there for the detection rule. An explicit,
  non-`all` domain list is always honored as-is, never auto-filtered.
- **Path**: any non-flag, non-domain token is treated as a directory/file
  scope. Default: repository root.
- **`--profile`**: enables dynamic analysis for the `runtime` and `memory`
  agents. Other agents ignore this flag. Default: off.
- **`--threshold <tier>`**: minimum tier to display. Values:
  - `critical` — critical only
  - `warning` — critical + warning
  - `info` — critical + warning + info (default)

Parse into:
- `DOMAINS` — list of domain keys as requested, or `all` (default)
- `SCOPE_PATH` — directory/file, or `.`
- `PROFILE_MODE` — boolean
- `THRESHOLD` — one of `critical`, `warning`, `info`

`DOMAINS` is resolved into `EFFECTIVE_DOMAINS` in Phase 1.4 — `all` is
narrowed to whichever domains have a detected signal; an explicit list
passes through unchanged.

Examples:
- `/optimize` → auto-detected domains (always runtime/memory/general, plus
  db/bundle if detected), `.`, static, `info`
- `/optimize --profile` → auto-detected domains, `.`, dynamic-where-applicable, `info`
- `/optimize runtime,db` → exactly those two domains, no auto-detection
- `/optimize src/services/` → auto-detected domains, scoped path
- `/optimize --profile runtime src/api/` → runtime agent only, dynamic mode,
  scoped to `src/api/`
- `/optimize --threshold warning` → hide info-tier findings

## Phase 1: Preparation

Before launching agents, gather baseline context that every agent will need.
Parse `$ARGUMENTS` first (see Inputs above). Every command below substitutes
the parsed `SCOPE_PATH` as a literal string — do not pre-execute any of them
before argument parsing, or the path scope is silently ignored.

Run the following with the Bash tool (not as pre-execution `!`-blocks — those
run at skill invocation, before `$ARGUMENTS` is parsed, and would ignore the
requested scope path entirely):

### 1.1 Detect languages and manifests

```bash
git ls-files -- "<SCOPE_PATH>" | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

```bash
ls -1 package.json pnpm-lock.yaml yarn.lock Cargo.toml go.mod pyproject.toml requirements.txt Pipfile Gemfile composer.json build.gradle pom.xml 2>/dev/null || echo "no manifests in root"
```

### 1.2 Get the code file tree

```bash
git ls-files -- "<SCOPE_PATH>" | grep -vE '(\.md$|\.txt$|\.json$|\.ya?ml$|\.toml$|\.lock$|\.csv$|\.svg$|\.png$|\.jpg$|\.gif$|\.ico$|\.woff|\.eot$|\.ttf$|\.map$|\.min\.|node_modules/|vendor/|dist/|build/|\.git/|__pycache__|\.pytest_cache|\.next/|\.nuxt/|target/|\.idea/|\.vscode/)' | head -1000
```

Store as `CODE_FILES`.

Also get the full tree including configs for cross-reference:

```bash
git ls-files -- "<SCOPE_PATH>" | head -750
```

Store as `FULL_TREE`.

### 1.3 Detect ORM and framework signals

```bash
rg -l --max-count=1 "from prisma|@prisma/client|PrismaClient|TypeOrmModule|mongoose|sequelize|sqlalchemy|django\.db|diesel::|sqlx::|gorm\.Model|ActiveRecord" -g '!node_modules' -g '!target' -g '!dist' "<SCOPE_PATH>" 2>/dev/null | head -20 || echo "no ORM detected"
```

```bash
rg -l --max-count=1 "express|fastify|nestjs|@nestjs|angular|react|vue|svelte|next|nuxt|remix|axum|actix|gin-gonic|flask|django|fastapi|rails" -g '!node_modules' -g '!target' -g '!dist' "<SCOPE_PATH>" 2>/dev/null | head -20 || echo "no framework detected"
```

Store detected signals as `ORM_FRAMEWORKS`.

### 1.4 Determine which domains actually apply

`runtime`, `memory`, and `general` apply to any codebase — always include
them. `db` and `bundle` are conditional: launching a database-query agent on
a repo with no data layer, or a bundle agent on a repo with no frontend
build, produces nothing but noise. Detect applicability before dispatch:

```bash
# DB signal: ORM/driver usage, raw SQL, or a migration/schema layer
rg -l --max-count=1 "from prisma|@prisma/client|PrismaClient|TypeOrmModule|mongoose|sequelize|sqlalchemy|django\.db|diesel::|sqlx::|gorm\.Model|ActiveRecord|database/sql|psycopg2|mysql2|pg\.Pool|redis\.|SELECT .* FROM|INSERT INTO|CREATE TABLE" -g '!node_modules' -g '!target' -g '!dist' "<SCOPE_PATH>" 2>/dev/null | head -5
git ls-files -- "<SCOPE_PATH>" | grep -iE '(migrations?/|schema\.(prisma|sql)$|\.sql$)' | head -5
```

```bash
# Bundle signal: a frontend framework plus an actual bundler/build config
rg -l --max-count=1 "react|vue|svelte|angular|next|nuxt|remix" -g '!node_modules' -g '!target' -g '!dist' "<SCOPE_PATH>" 2>/dev/null | head -5
ls -1 webpack.config.* vite.config.* rollup.config.* next.config.* angular.json esbuild.config.* parcel.config.* 2>/dev/null
```

Set:
- `DB_APPLICABLE` — true if either DB-signal command returned any output
- `BUNDLE_APPLICABLE` — true if either bundle-signal command returned any
  output

If `DOMAINS` was explicitly requested by the user (anything other than the
default `all`), **honor it as-is** — do not filter an explicit request, even
if a domain looks inapplicable; just note in the report if a requested
domain found nothing to analyze.

If `DOMAINS` is the default `all`, compute `EFFECTIVE_DOMAINS`:
- Always: `runtime`, `memory`, `general`
- `db` — only if `DB_APPLICABLE`
- `bundle` — only if `BUNDLE_APPLICABLE`

Record which domains were auto-excluded and why (e.g., `db: no ORM, driver,
or SQL/migration signal found`) — this appears in the final report so the
user can see the audit didn't just silently skip a domain.

## Phase 2: Agent Dispatch

Launch only the agents in `EFFECTIVE_DOMAINS` **in parallel**, in a single
message containing multiple Agent tool calls. Use `subagent_type: "Explore"`
for each (read-only except for the optional profiling step — see below).

If a domain was auto-excluded, do not launch it and do not fabricate
findings for it — Phase 3 reports it as skipped instead.

Each agent prompt is assembled from a shared context block plus the
domain-specific prompt file:

| Domain key | Prompt file                                             | Dynamic-capable? |
| ---------- | ------------------------------------------------------- | ---------------- |
| `runtime`  | `${CLAUDE_SKILL_DIR}/agents/runtime-performance.md`     | yes              |
| `db`       | `${CLAUDE_SKILL_DIR}/agents/database-query.md`          | no               |
| `bundle`   | `${CLAUDE_SKILL_DIR}/agents/bundle-build.md`            | no               |
| `memory`   | `${CLAUDE_SKILL_DIR}/agents/memory-resource.md`         | yes              |
| `general`  | `${CLAUDE_SKILL_DIR}/agents/general-performance.md`     | no               |

Prefix every agent prompt with this context block:

```
## Repository Context
- **Languages**: <from 1.1>
- **Manifests**: <from 1.1>
- **ORM/Framework signals**: <from 1.3>
- **Scope path**: <SCOPE_PATH>
- **File tree (code only)**: <CODE_FILES>
- **Full tree**: <FULL_TREE>
- **Profile mode**: <PROFILE_MODE>
- **Threshold**: <THRESHOLD>

## Output Contract
Return findings in the exact format specified in your prompt. Every finding
must include: severity tier, file:line, what the problem is, why it's slow,
and a concrete optimization with expected impact. No hand-wavy "consider
improving performance" findings — every entry must be actionable.

Tiers:
- **Critical**: measurable production impact (seconds per request, GB of
  memory, queries-per-page exceeding a reasonable bound, bundle size blowouts)
- **Warning**: real but bounded cost — noticeable under load or at scale
- **Info**: minor improvement, worth noting but not urgent
```

**Dynamic mode rule (runtime and memory agents only):**

When `PROFILE_MODE` is true, the `runtime` and `memory` agents follow these
extra steps:

1. Detect the project's test or benchmark entry point from the manifests and
   `FULL_TREE`.
2. Propose a concrete profiler command (see
   `${CLAUDE_SKILL_DIR}/reference/profiling-commands.md`).
3. **Stop and ask the user for explicit confirmation** before running
   anything — use `AskUserQuestion`. Never run a profiler without approval.
4. If approved, run the command, parse output, and cross-reference hot
   functions against the static findings. Upgrade severity when real data
   confirms a suspicion.
5. If the user declines, or the project is not runnable (no test target,
   missing deps, build broken), fall back to static analysis and note
   `Fallback: static-only — <reason>` in the agent's report.

All other agents stay static regardless of `PROFILE_MODE`.

## Phase 3: Report Assembly

After all agents return, compile a unified report. Print it inline to the
terminal (do NOT write it to a file).

### 3.1 Deduplicate cross-domain findings

If two agents report the same underlying problem (e.g., `runtime` and
`general` both flagging an N+1-like loop that the `db` agent already
classified as N+1), consolidate to the most specific domain and drop the
duplicate. Never repeat the same `file:line` across domains.

### 3.2 Apply threshold

Filter findings per `THRESHOLD`:
- `critical` — keep Critical only
- `warning` — keep Critical + Warning
- `info` (default) — keep all three tiers

### 3.3 Print the report

```markdown
# Optimize Report — {project or scope path}

Scope: {SCOPE_PATH}
Languages: {detected}
Domains run: {EFFECTIVE_DOMAINS}
Domains skipped (no signal detected): {domain: reason, ... — omit line if none}
Mode: {static | dynamic (profiled) | dynamic (fallback to static)}
Threshold: {THRESHOLD}

> **Note**: This is static analysis by Claude (plus optional profiler data in
> dynamic mode). Suggestions are best-effort and must be validated by tests
> before merging.

## Summary

Only domains in `EFFECTIVE_DOMAINS` get a row; a domain skipped by
auto-detection is omitted from the table entirely, not shown with zeros.

| Domain | Critical | Warning | Info |
|--------|----------|---------|------|
| Runtime Performance | N | N | N |
| Database & Queries  | N | N | N |
| Bundle & Build      | N | N | N |
| Memory & Resources  | N | N | N |
| General Performance | N | N | N |
| **Total**           | **N** | **N** | **N** |

(Database & Queries and Bundle & Build rows appear only when `db`/`bundle`
are in `EFFECTIVE_DOMAINS`.)

## Critical Findings

### Runtime Performance — {count}
<findings>

### Database & Queries — {count}
<findings>

...one section per domain that has Critical findings...

## Warning Findings
(same structure, only if THRESHOLD includes warning)

## Info Findings
(same structure, only if THRESHOLD includes info)
```

Each finding looks like:

```markdown
#### `path/to/file.ext:142` — short title

- **Cause**: what makes this slow (one sentence)
- **Evidence**: the offending snippet (3-8 lines, fenced)
- **Fix**: concrete optimization with expected impact (one-two sentences)
- **Behavior-preserving?**: yes | no — if no, explain the semantic change
- **Profiled** (dynamic mode only): hot-path share, e.g., "34% of total runtime"
```

If a domain or tier has no findings, write "No findings." rather than an
empty table.

## Phase 4: Optimization Offer

After printing the report, if there is at least one Critical or Warning
finding, use `AskUserQuestion` to present implementation options:

> "I found **{X} critical** and **{Y} warning** findings that could be
> optimized. Want me to implement the fixes?"

Options:

1. **All** — every Critical + Warning finding
2. **Critical only** — just the top tier
3. **Behavior-preserving only** — skip anything marked `Behavior-preserving?: no`
4. **Pick** — list findings with numbers and let the user select a subset
5. **None** — keep the report as-is

### If the user chooses to implement

1. Collect the selected findings.
2. Group them by file.
3. Launch parallel agents — one per file (or small group of files in the
   same directory, capped at 6 concurrent). Each agent receives:
   - The file path(s) to modify
   - The specific findings with their suggested fixes
   - Instructions to `Read` each file, then `Edit` with the optimization
   - Instructions to preserve function signatures and public APIs — if a
     signature change is unavoidable, skip the finding and flag it

4. After all implementation agents return, run the project's test command
   (detect via manifest: `pnpm test`, `cargo test`, `pytest`, `go test ./...`).
   If tests fail, **do not commit**. Print the failure and list which
   optimizations were applied so the user can decide whether to revert.

5. On success, print a summary:

```markdown
## Optimizations Applied

| Finding | Location | Domain | Technique |
|---------|----------|--------|-----------|
| <title> | file:line | runtime | replaced nested scan with Map |
```

6. If any fixes were skipped (signature change required, semantics unclear,
   agent bailed), list them under "Skipped — Needs Manual Review" with the
   reason each one was skipped.

### Safety rails

- **Behavior-preserving only** by default. If a fix would change observable
  behavior (sync → async, reordered side effects, error-type changes, loss
  of ordering guarantees), the agent MUST either skip the finding or flag
  it explicitly in the report — never silently change semantics.
- **One commit per fix** when applying multiple optimizations, matching the
  repo's existing discipline. Each commit gets a subject like
  `perf(<domain>): <finding title>`.
- **Never run the profiler without explicit user consent** — see Phase 2.
- **Never modify files** during Phases 1-3. Phases 1-3 are read-only.

## Important Guidelines

- **Read-only through Phase 3**: No file writes until the user picks an
  optimization option in Phase 4.
- **No redundant findings**: Deduplicate across domains. If `general` and
  `runtime` both see the same hot loop, the one with the more specific
  fix wins.
- **Every finding is actionable**: If a finding does not have a concrete
  fix and an expected impact, drop it. No "consider refactoring" filler.
- **Cite evidence**: Every finding has a `file:line` reference. A finding
  without a location is a bug in the report.
- **Respect the scope**: If `SCOPE_PATH` is a subdirectory, agents must not
  report findings outside it. Cross-directory impact notes are fine, but
  the finding itself lives where the fix is applied.
