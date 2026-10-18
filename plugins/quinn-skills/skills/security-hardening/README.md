# security-hardening

A Claude Code skill that runs **10 parallel paranoid security review agents** to
audit a repository for vulnerabilities, misconfigurations, and security
anti-patterns. Includes active CVE detection and dependency upgrade planning.

## What It Does

When invoked, the skill:

1. Detects languages, frameworks, and existing security tooling
2. Runs available dependency audit tools (`npm audit`, `pip audit`, `cargo audit`, etc.)
3. Launches up to **10 specialized agents in parallel**, each a domain expert
4. Agents search for recent CVEs via web search for installed dependencies
5. Aggregates findings into a unified **Security Hardening Report** with a Paranoia Score,
   severity ratings, OWASP/CWE classifications, and a prioritized remediation plan

### Review Agents

| # | Agent | What It Checks |
|---|-------|----------------|
| 1 | **Dependency Audit** | Known CVEs, active CVE search, version upgrade plan, supply-chain risks, typosquatting, dependency confusion, abandoned packages |
| 2 | **Secrets Scan** | 50+ credential patterns (AWS, GCP, Azure, Stripe, GitHub, etc.), high-entropy strings, base64-encoded secrets, sneaky hiding spots, Terraform state, Jupyter notebooks |
| 3 | **Injection Review** | SQLi, NoSQLi, XSS (reflected/stored/DOM), SSTI, command injection, path traversal, XXE, LDAP injection, deserialization, mass assignment, GraphQL injection |
| 4 | **Auth Review** | Password hashing strength, JWT algorithm confusion, session fixation, IDOR, privilege escalation, OAuth/SAML flaws, MFA bypass, brute force, account enumeration |
| 5 | **Crypto Review** | Weak algorithms, nonce reuse, key management, TLS/mTLS config, certificate validation, CSPRNG usage, timing attacks, padding oracle, post-quantum readiness |
| 6 | **Config Review** | CSP/CORS/HSTS headers, debug mode, Docker escape vectors, Kubernetes security contexts, CI/CD injection, cloud IAM, rate limiting, error information leakage |
| 7 | **SSRF & Network** | Direct/blind SSRF, cloud metadata access, DNS rebinding, internal network exposure, URL parser differentials, WebSocket security, GraphQL SSRF |
| 8 | **Data Privacy** | PII in logs/errors/APIs, GDPR/CCPA surface area, third-party data sharing, data retention gaps, cache leaks, export over-exposure, consent tracking |
| 9 | **Supply Chain** | Lock file integrity, CI/CD script injection, unpinned Actions, dependency confusion, typosquatting, artifact signing, SBOM, SRI hashes, build reproducibility |
| 10 | **Runtime Safety** | Prototype pollution, ReDoS, race conditions/TOCTOU, algorithmic DoS, resource exhaustion, memory safety, timing attacks, unsafe eval/deserialization |

All agents are **read-only** — they analyze but never modify code.

## Installation

Ships in the `quinn-skills` plugin:

```
/plugin marketplace add quinnjr/quinn-skills
/plugin install quinn-skills@quinn-skills
```

## Usage

```
# Run full audit (all 10 agents in parallel)
/security-hardening

# Run specific domains only
/security-hardening deps
/security-hardening secrets,injection,ssrf
/security-hardening auth,crypto,config
/security-hardening supply-chain,runtime,privacy
```

### Scope Options

| Scope | Agent |
|-------|-------|
| `all` | All 10 agents (default) |
| `deps` | Dependency audit + CVE search |
| `secrets` | Secrets & credentials scan |
| `injection` | Injection vulnerability review |
| `auth` | Authentication & authorization |
| `crypto` | Cryptographic practices |
| `config` | Configuration & infrastructure |
| `ssrf` | SSRF & network security |
| `privacy` | Data privacy & PII exposure |
| `supply-chain` | Supply chain & build integrity |
| `runtime` | Runtime & memory safety |

## Output

The skill produces a structured Markdown report including:

- **Paranoia Score** (0-100) — overall security posture rating
- **Threat Model Summary** — attack surface description
- **Critical & High Findings** — deduplicated, prioritized urgent issues
- **Dependency Upgrade Plan** — table of packages to upgrade with safe versions and CVEs
- **All Findings by Severity** — CRITICAL / HIGH / MEDIUM / LOW
- **10 Domain Reports** — detailed findings from each agent
- **Remediation Plan** — prioritized into Immediate / This Week / This Sprint / Backlog
- **Positive Findings** — what the codebase does well
- **Summary Statistics** — finding counts by severity and domain

Every finding includes:
- File path and line number
- OWASP Top 10 + CWE classification
- Attack scenario describing exploitation
- Specific, implementable remediation

## Customization

Agent prompts in `agents/` are standalone Markdown files. You can:

- Edit an agent to add project-specific patterns or ignore rules
- Remove agents you don't need
- Add new agents by creating a `.md` file in `agents/` and adding it to the dispatch table in `SKILL.md`
- Adjust the OWASP reference in `reference/owasp-top-10.md`

## Optional: Install Audit Tools for Better CVE Detection

The skill runs available audit tools automatically. Install them for richer results:

```bash
# Node.js (built into npm)
npm audit

# Python
pip install pip-audit

# Rust
cargo install cargo-audit

# Ruby
gem install bundler-audit

# Multi-ecosystem
pip install osv-scanner  # or install from GitHub releases
```

## Requirements

- Claude Code CLI or IDE extension
- A git repository to audit
- (Optional) Language-specific audit tools for CVE detection

## License

MIT
