---
name: complexity-audit
description: >-
  Analyze every function in a project for Big O time and space complexity.
  Reports findings in severity tiers (Critical, Warning, Info) with
  optimization suggestions. Offers to implement optimizations for the
  worst offenders. Use when auditing performance, reviewing algorithmic
  efficiency, or preparing for scale.
user-invocable: true
disable-model-invocation: true
allowed-tools: Agent Bash(git *) Read Grep Glob Edit AskUserQuestion
argument-hint: "[path] [--threshold n1|nlogn|n2|n3]"
---

# Complexity Audit — Big O Analysis

You are orchestrating a **comprehensive Big O complexity audit** of this
project. You will analyze every function for time and space complexity,
classify findings into severity tiers, and offer to optimize the worst
offenders.

## Inputs

- `$ARGUMENTS` — optional. Accepts a directory path to scope the analysis
  and/or a `--threshold` flag to filter output.
  - Path: relative directory to analyze (default: entire project)
  - `--threshold`: minimum complexity tier to display.
    `n1` = show all tiers including OK (most permissive),
    `nlogn` = Info and above,
    `n2` = Warning and above,
    `n3` = Critical only (most restrictive).
    Default: show Critical, Warning, and Info tiers (omit OK).

Parse `$ARGUMENTS` to extract:
- `SCOPE_PATH` — directory path, or `.` if not provided
- `THRESHOLD` — threshold filter, or `nlogn` if not provided

Examples:
- `/complexity-audit` → SCOPE_PATH=`.`, THRESHOLD=`nlogn`
- `/complexity-audit src/services/` → SCOPE_PATH=`src/services/`, THRESHOLD=`nlogn`
- `/complexity-audit --threshold n2` → SCOPE_PATH=`.`, THRESHOLD=`n2`
- `/complexity-audit src/ --threshold n3` → SCOPE_PATH=`src/`, THRESHOLD=`n3`

## Phase 1: Preparation

Before launching agents, gather baseline context.

### 1.1 Detect languages

```!
git ls-files -- "$SCOPE_PATH" | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

### 1.2 Get the code file tree

```!
git ls-files -- "$SCOPE_PATH" | grep -vE '(\.md$|\.txt$|\.json$|\.ya?ml$|\.toml$|\.lock$|\.csv$|\.svg$|\.png$|\.jpg$|\.gif$|\.ico$|\.woff|\.eot$|\.ttf$|\.map$|\.min\.|node_modules/|vendor/|dist/|build/|\.git/|__pycache__|\.pytest_cache|\.next/|\.nuxt/|target/|\.idea/|\.vscode/)' | grep -vE '(test_|_test\.|\.test\.|\.spec\.|__tests__|tests/|spec/)' | head -1000
```

Store this as `CODE_FILES`. This is the list of files agents will analyze.

Also get the full tree (including tests) for cross-reference context:
```!
git ls-files -- "$SCOPE_PATH" | head -750
```

Store this as `FULL_TREE`.

### 1.3 Determine agent count

Count the number of code files in `CODE_FILES` and determine how many
agents to launch:

| Code files | Agents |
|-----------|--------|
| < 50      | 2      |
| 50–150    | 3      |
| 150–300   | 4      |
| 300–500   | 6      |
| 500+      | 8      |

Never exceed 8 agents.

### 1.4 Partition files

Divide `CODE_FILES` into chunks, one per agent. Keep files in the same
directory together when possible — sort the file list by directory path
first, then split into roughly equal chunks by file count. Each chunk
should be a contiguous block of the sorted list.

Store each chunk as `AGENT_N_FILES` (where N is the agent number).

## Phase 2: Parallel Analysis

Launch all agents **in parallel** in a single message containing multiple
Agent tool calls. Each agent is read-only — it reports findings but does
not modify any files.

Set `subagent_type` to `"Explore"` (read-only, no edits) for each agent.

For each agent, use this prompt template (filling in the variables):

```
## Project Context

**Languages detected**: <from step 1.1>
**Full file tree**: <FULL_TREE from step 1.2>
**Threshold filter**: <THRESHOLD>

## Your Assignment

You are Agent {N} of {TOTAL} in a Big O complexity audit. Analyze the
following files for time and space complexity of every function, method,
and named closure.

**Your files:**
<AGENT_N_FILES — one per line>

## Instructions

For each file in your assignment:

1. Read the file using the Read tool.
2. Identify every function, method, class method, and named closure.
3. For each function, determine:
   - **Time complexity**: Big O notation for the worst case
   - **Space complexity**: Big O notation (report O(1) when the function
     uses constant extra space)
   - **Complexity driver**: What causes the complexity — nested loops,
     recursive calls, sort-inside-loop, repeated concatenation, hidden
     costs from library calls (e.g., `array.includes()` inside a loop
     is O(n²), `.sort()` is O(n log n)), etc.

4. Classify each function into a tier:
   - **Critical**: O(n³) or worse — likely performance problems at any
     scale
   - **Warning**: O(n²) — problematic at scale, should be reviewed
   - **Info**: O(n log n) — generally acceptable but worth noting
   - **OK**: O(n), O(log n), O(1) — no action needed

5. For every Critical and Warning function, provide a **concrete
   optimization suggestion**: what algorithm, data structure, or
   approach would lower the complexity, and what the new Big O would be.
   Be specific — name the technique (e.g., "use a hash set for O(1)
   lookup instead of linear scan", "replace bubble sort with built-in
   sort", "precompute the index outside the loop").

## Output Format

Return your findings as structured text in EXACTLY this format. Do not
deviate from this format:

### Agent {N} Results

**Files analyzed**: {count}
**Functions analyzed**: {count}

#### Critical — O(n³)+
| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| funcName | path/to/file.ext:42 | O(n³) | O(n²) | description |

**funcName** (path/to/file.ext:42): <optimization suggestion with expected new Big O>

#### Warning — O(n²)
| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| funcName | path/to/file.ext:99 | O(n²) | O(n) | description |

**funcName** (path/to/file.ext:99): <optimization suggestion with expected new Big O>

#### Info — O(n log n)
| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| funcName | path/to/file.ext:15 | O(n log n) | O(n) | description |

#### Summary
- Critical: {count}
- Warning: {count}
- Info: {count}
- OK: {count}

If a tier has no findings, include the header but write "None found."
under the table header.

## Important

- Analyze EVERY function, not just the ones that look complex. Hidden
  complexity in seemingly simple functions (e.g., a one-liner calling
  `.filter().map().sort()`) is exactly what this audit exists to catch.
- Consider the FULL call chain when a function calls other functions
  defined in the same file. If `processItems()` calls `findMatch()`
  in a loop, and `findMatch()` is O(n), then `processItems()` is O(n²).
- For recursive functions, identify the recurrence relation and solve it.
- Library/built-in operations have costs: `.sort()` is O(n log n),
  `.includes()` / `.indexOf()` / `in` on a list is O(n), hash
  map/set lookup is O(1) amortized, tree map lookup is O(log n).
- If you are uncertain about a function's complexity, report your best
  estimate and note the uncertainty.
- Do NOT modify any files. This is a read-only analysis phase.
```

## Phase 3: Report Assembly

After all agents return, compile a unified report. Print it inline to the
terminal (do NOT write it to a file).

### 3.1 Merge and deduplicate

Combine all agent results. If multiple agents analyzed the same function
(unlikely given the partitioning, but possible with re-exports), keep the
more detailed analysis.

### 3.2 Apply threshold filter

If `THRESHOLD` is set, filter the output:
- `n1`: show all tiers including OK (most permissive)
- `nlogn`: show Critical, Warning, and Info tiers
- `n2`: show Critical and Warning tiers only
- `n3`: show Critical tier only (most restrictive)
- Default (no flag): same as `nlogn` — Critical, Warning, and Info tiers

### 3.3 Print the report

```markdown
# Complexity Audit — {project/directory name}

Analyzed {N} files across {M} functions.
Languages: {detected languages}
Agents used: {count}

> **Note**: This is static analysis by Claude, not formal verification.
> Complexity estimates are best-effort based on code structure and may
> not account for all runtime behaviors, input distributions, or
> framework-specific optimizations.

## Critical — O(n³)+

| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| ... | ... | ... | ... | ... |

**Optimization suggestions:**
- **funcName** (file:line): suggestion → expected new Big O

## Warning — O(n²)

| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| ... | ... | ... | ... | ... |

**Optimization suggestions:**
- **funcName** (file:line): suggestion → expected new Big O

## Info — O(n log n)

| Function | Location | Time | Space | Driver |
|----------|----------|------|-------|--------|
| ... | ... | ... | ... | ... |

## Summary

| Tier | Count |
|------|-------|
| Critical (O(n³)+) | N |
| Warning (O(n²)) | N |
| Info (O(n log n)) | N |
| OK | N |
| **Total functions** | **N** |
```

If a tier has no findings, print "No functions found in this tier."
instead of an empty table.

## Phase 4: Optimization Offer

After printing the report, if there are any Critical or Warning findings,
use AskUserQuestion to present the optimization options:

> "I found **{X} functions** in the Critical/Warning tiers that could be
> optimized. Would you like me to implement the optimizations?"

Options:
1. **All** — optimize all Critical and Warning functions
2. **Critical only** — just the worst offenders (O(n³)+)
3. **Pick** — list each function and let the user choose
4. **None** — keep the report as-is

### If the user chooses to optimize:

1. Collect the selected functions and their optimization suggestions.
2. Group them by file.
3. Launch parallel agents — one per file (or small group of files in the
   same directory). Each agent receives:
   - The file path(s) to modify
   - The specific functions to optimize with the suggested approach
   - Instructions to use `Read` to read the current file, then `Edit`
     to apply the optimization
   - Instructions to preserve function signatures and public APIs — if
     a signature change is unavoidable, flag it in the output
4. After all optimization agents return, print a summary:

```markdown
## Optimizations Applied

| Function | Location | Before | After | Technique |
|----------|----------|--------|-------|-----------|
| funcName | file:42 | O(n³) | O(n²) | replaced nested scan with hash map |
```

If any optimization agent reports that it could not safely optimize a
function (e.g., signature change required, unclear semantics), list those
separately under a "Skipped — Needs Manual Review" section.

### If there are no Critical or Warning findings:

Skip the optimization offer. Instead, print:

> "No functions at O(n²) or worse were found. The codebase looks
> algorithmically sound."

