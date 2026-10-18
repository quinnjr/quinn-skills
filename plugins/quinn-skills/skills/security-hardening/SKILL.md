---
name: security-hardening
description: >-
  Run 10 parallel paranoid security review agents to harden a repository.
  Covers OWASP Top 10, supply chain, SSRF, data privacy, runtime safety,
  CVE detection, and more. Use when auditing code for vulnerabilities,
  preparing for a security review, or hardening a codebase.
user-invocable: true
disable-model-invocation: true
allowed-tools: Agent Bash(git *) Bash(npm audit*) Bash(pip audit*) Bash(cargo audit*) Bash(go list*) Bash(bundle audit*) Bash(osv-scanner*) Read Grep Glob WebSearch
argument-hint: "[scope: all | deps | secrets | injection | auth | crypto | config | ssrf | privacy | supply-chain | runtime]"
---

# Security Hardening — Paranoid Multi-Agent Review

You are orchestrating a **paranoid, comprehensive security audit** of this
repository using 10 parallel review agents. Each agent is a specialist in a
distinct security domain and has been instructed to assume the worst about every
line of code. Trust nothing. Verify everything.

## Inputs

- `$ARGUMENTS` — optional scope filter. Defaults to `all`.
  Accepted values: `all`, `deps`, `secrets`, `injection`, `auth`, `crypto`,
  `config`, `ssrf`, `privacy`, `supply-chain`, `runtime`.
  Comma-separated values are supported (e.g., `deps,secrets,injection,ssrf`).

## Preparation

Before launching agents, gather baseline context that every agent will need:

1. Detect the project's language(s) and framework(s):

```!
git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

2. Get the repository file tree:

```!
git ls-files | head -750
```

3. Check for existing security tooling and configuration:

```!
ls -1 .snyk .trivyignore .gitleaksignore .bandit .semgrepignore .eslintrc* .safety* tox.ini pyproject.toml package.json Cargo.toml go.sum Gemfile.lock composer.json pom.xml build.gradle .github/workflows/* .gitlab-ci.yml Dockerfile* docker-compose* k8s/ kubernetes/ terraform/ .terraform* Jenkinsfile .circleci/ 2>/dev/null || echo "none detected"
```

4. **Run available dependency audit tools** to get CVE data for agents:

```!
if [ -f package-lock.json ] || [ -f package.json ]; then npm audit --json 2>/dev/null | head -200 || echo "npm audit not available"; fi
```

```!
if [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f Pipfile ]; then pip audit --format=json 2>/dev/null | head -200 || pip-audit --format=json 2>/dev/null | head -200 || echo "pip audit not available"; fi
```

```!
if [ -f Cargo.toml ]; then cargo audit --json 2>/dev/null | head -200 || echo "cargo audit not available"; fi
```

```!
if [ -f go.mod ]; then go list -json -m all 2>/dev/null | head -200 || echo "go list not available"; fi
```

```!
if [ -f Gemfile.lock ]; then bundle audit check 2>/dev/null | head -100 || echo "bundle audit not available"; fi
```

Store ALL of this context — languages, frameworks, file tree, security tooling,
and CVE audit results. You will pass them to each agent.

## Agent Dispatch

Parse `$ARGUMENTS` (default `all`) to determine which agents to launch.
Launch the selected agents **in parallel** using the Agent tool. Each agent
prompt MUST include the baseline context gathered above so agents can work
without re-scanning.

Read the corresponding agent prompt file from `${CLAUDE_SKILL_DIR}/agents/` and
use it as the agent's prompt, prepending the baseline context block.

| Scope key      | Agent prompt file                                  | Description                                  |
| -------------- | -------------------------------------------------- | -------------------------------------------- |
| `deps`         | `${CLAUDE_SKILL_DIR}/agents/dependency-audit.md`   | Dependency vulns, CVEs, supply-chain risks   |
| `secrets`      | `${CLAUDE_SKILL_DIR}/agents/secrets-scan.md`       | Hardcoded secrets, credential leaks          |
| `injection`    | `${CLAUDE_SKILL_DIR}/agents/injection-review.md`   | SQLi, XSS, command injection, SSTI, XXE      |
| `auth`         | `${CLAUDE_SKILL_DIR}/agents/auth-review.md`        | Authentication, authorization, sessions      |
| `crypto`       | `${CLAUDE_SKILL_DIR}/agents/crypto-review.md`      | Cryptographic practices, TLS, key management |
| `config`       | `${CLAUDE_SKILL_DIR}/agents/config-review.md`      | Configuration, Docker, CI/CD, cloud infra    |
| `ssrf`         | `${CLAUDE_SKILL_DIR}/agents/ssrf-network.md`       | SSRF, DNS rebinding, network boundary        |
| `privacy`      | `${CLAUDE_SKILL_DIR}/agents/data-privacy.md`       | PII exposure, data leakage, compliance       |
| `supply-chain` | `${CLAUDE_SKILL_DIR}/agents/supply-chain.md`       | Build integrity, artifact provenance         |
| `runtime`      | `${CLAUDE_SKILL_DIR}/agents/runtime-safety.md`     | ReDoS, race conditions, prototype pollution  |

When `all` is selected, launch **all 10 agents in parallel** in a single
message containing 10 Agent tool calls.

For each agent:
- Set `subagent_type` to `"Explore"` (read-only, no edits).
- Prefix the agent prompt with a context block:

```
## Repository Context
- **Languages/Frameworks**: <detected>
- **File tree**: <from git ls-files>
- **Existing security tooling**: <detected>
- **CVE audit results**: <from npm audit / pip audit / cargo audit / etc.>

## Instructions
Examine this repository with MAXIMUM paranoia. You are not looking for obvious
bugs — you are looking for the subtle, the overlooked, the "it'll never happen"
scenarios that end up on the front page of Hacker News. Check everything.
Assume hostile input everywhere. Assume the network is compromised. Assume
dependencies are backdoored. Report anything suspicious, even if you're only
60% confident — label it "Needs Manual Review" and explain your concern.
```

## CVE-Specific Instructions for Dependency Agent

The dependency audit agent MUST additionally:

1. **Cross-reference installed versions against CVE databases**: Use the audit
   tool output provided in context, plus search the web for recent CVEs for
   every major dependency found in the manifest files.

2. **Recommend specific safe versions**: For every vulnerable dependency found,
   specify the exact minimum safe version to upgrade to. Format:
   `Upgrade <package> from <current> to >= <safe-version> (fixes CVE-XXXX-XXXXX)`

3. **Check for zero-day advisories**: Use WebSearch to look up
   `"<package-name>" CVE 2025 2026` for the top 20 most critical dependencies.
   Report any findings even if the audit tools didn't catch them.

4. **Generate an upgrade plan**: At the end of findings, produce a
   prioritized upgrade table:
   ```
   | Package | Current | Safe Version | CVE(s) | Severity | Breaking? |
   |---------|---------|-------------|--------|----------|-----------|
   ```

## Aggregation

After all agents return, compile a unified **Security Hardening Report**.

### Paranoia Score

Assign a **Paranoia Score** from 0-100 based on overall findings:
- **90-100**: Fortress — minimal findings, strong security posture
- **70-89**: Solid — some issues but fundamentally sound
- **50-69**: Concerning — significant gaps that need attention
- **30-49**: Alarming — multiple serious vulnerabilities
- **0-29**: On Fire — critical vulnerabilities, likely already compromised

### Report Structure

```markdown
# Security Hardening Report

**Repository**: <repo name>
**Date**: <today>
**Scope**: <which agents ran>
**Paranoia Score**: <0-100> / 100 — <rating>

## Executive Summary
<3-5 sentence overview. Be blunt. If the codebase has serious issues, say so
plainly. Mention total findings by severity and the most critical issues.>

## Threat Model Summary
<Brief description of the attack surface: What does this application do? What
are the most valuable targets? What are the likely attack vectors?>

## Critical & High Findings — Act Immediately
<Deduplicated, prioritized list of CRITICAL and HIGH findings across all
domains. Each finding appears once, with cross-references to the domain report.>

## Dependency Upgrade Plan
<Table of all dependencies that need upgrading, with current version, safe
version, CVE references, and whether the upgrade is breaking.>

## All Findings by Severity

### Critical
<findings rated CRITICAL, sorted by exploitability>

### High
<findings rated HIGH>

### Medium
<findings rated MEDIUM>

### Low / Informational
<findings rated LOW or INFO>

## Domain Reports

### 1. Dependency Audit & CVEs
<agent findings + upgrade plan>

### 2. Secrets & Credentials
<agent findings>

### 3. Injection Vulnerabilities
<agent findings>

### 4. Authentication & Authorization
<agent findings>

### 5. Cryptographic Practices
<agent findings>

### 6. Configuration & Infrastructure
<agent findings>

### 7. SSRF & Network Security
<agent findings>

### 8. Data Privacy & PII
<agent findings>

### 9. Supply Chain & Build Integrity
<agent findings>

### 10. Runtime & Memory Safety
<agent findings>

## Recommended Remediation Plan
<Prioritized list of fixes, ordered by: severity → exploitability → effort.
Group into:
- **Immediate (today)**: Critical/high findings with known exploits
- **This week**: High/medium findings that are straightforward to fix
- **This sprint**: Medium findings requiring design changes
- **Backlog**: Low/informational improvements

Each item includes: file path, line number, what to fix, suggested fix, and
estimated effort (trivial/small/medium/large).>

## Positive Findings
<List things the codebase does WELL. This builds trust in the report and
highlights practices to maintain.>

## Summary Statistics
| Severity | Count |
|----------|-------|
| Critical | N     |
| High     | N     |
| Medium   | N     |
| Low/Info | N     |
| **Total**| **N** |

| Domain | Critical | High | Medium | Low |
|--------|----------|------|--------|-----|
| Dependencies & CVEs | N | N | N | N |
| Secrets | N | N | N | N |
| Injection | N | N | N | N |
| Auth & AuthZ | N | N | N | N |
| Cryptography | N | N | N | N |
| Configuration | N | N | N | N |
| SSRF & Network | N | N | N | N |
| Data Privacy | N | N | N | N |
| Supply Chain | N | N | N | N |
| Runtime Safety | N | N | N | N |
```

## Important Guidelines

- **Read-only audit**: Do NOT modify any files. This is a review, not a fix.
- **Paranoid but precise**: Report everything suspicious, but clearly label
  confidence levels. A "Needs Manual Review" finding is better than a miss.
- **Include evidence**: Every finding MUST reference a specific file and line.
- **Be actionable**: Every finding MUST include a concrete remediation with
  enough detail that a developer can implement it without further research.
- **Deduplicate**: If multiple agents report the same issue, consolidate it
  in the final report with cross-references.
- **Cross-domain correlation**: Look for findings that combine across domains
  to create a more severe vulnerability chain (e.g., SSRF + cloud metadata +
  hardcoded internal URLs = full cloud account takeover).
- Consult `${CLAUDE_SKILL_DIR}/reference/owasp-top-10.md` if you need to
  classify findings by OWASP category.
