# worklog

[![CI](https://github.com/YOUR_ORG/worklog/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/worklog/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

A Claude Code plugin for **personal work retrospectives + agent rule learning**. Generate a daily / weekly / monthly retrospective from your activity, then turn the patterns into rules your agent actually follows.

```
/worklog                            # auto-detect latest working day
/worklog 25년 5월                    # or natural language
/worklog apply worklog-2025-05.md   # promote learnings to CLAUDE.md / learnings.md
```

## Two commands, one feedback loop

1. `/worklog [period]` collects facts from git, GitHub PRs, Claude Code sessions, optional Atlassian and Notion, and your previous retros — then writes a markdown + HTML retrospective with **Activities**, **Prior Try**, **KPT**, and **Rule Candidates**.

2. `/worklog apply <retro-file>` walks you through each Rule Candidate (accept / edit / skip), backs up your target rule files (`./CLAUDE.md`, `./AGENTS.md`, `learnings.md`), and appends the approved rules. Your next retro reads the current rules and won't propose duplicates.

## Install

This is a Claude Code plugin. Installation flow varies by host — see Claude Code docs for adding a plugin from a local directory. Once linked, the `/worklog` command and both skills are available.

### Dependencies

| Tool | Required | Purpose |
|------|----------|---------|
| `git` | ✅ | Commit collection |
| `jq` | ✅ | JSON processing |
| `bash` ≥ 4.4 | ✅ | Scripts |
| `gh` CLI | recommended | PR/Issue collection |
| `node` + `ajv-cli` | dev only | Schema validation |
| `bats-core`, `shellcheck` | dev only | Tests + lint |

```bash
# macOS
brew install bash jq gh bats-core shellcheck
```

## Configure

Copy `config.example.json` to `~/.config/worklog/config.json` and edit. Defaults if no file: git + Claude Code sources enabled, MCP off, learnings extracted but no auto-apply targets.

### Enable Atlassian (Jira)

```json
"atlassian": { "enabled": true, "projectKeys": ["MYPROJ"] }
```

Requires the Atlassian MCP. worklog auto-detects your Jira accountId via `atlassianUserInfo`.

### Enable Notion

```json
"notion": { "enabled": true, "databaseIds": ["abc123...", "def456..."] }
```

Requires the Notion MCP. List the databases to scan for recent edits.

### Learnings (rule auto-curation)

```json
"learnings": {
  "extraction": { "enabled": true, "maxCandidates": 5 },
  "apply": {
    "targets": [
      { "path": "./CLAUDE.md", "section": "## Auto-curated Learnings", "ifAbsent": "skip" },
      { "path": "~/.local/share/worklog/learnings.md", "section": null, "ifAbsent": "create" }
    ],
    "requireApproval": true,
    "backupSuffix": ".bak"
  }
}
```

- `extraction.enabled: false` to skip Rule Candidates entirely.
- `apply.targets[].section: null` appends at end of file; a heading string locates the section to append within.
- `ifAbsent`: `skip` (default), `create` (make the file), `error` (abort).
- `requireApproval: true` (default) prompts per candidate per target. `false` applies all silently — discouraged.

### PII handling

Common patterns (AWS keys, GitHub tokens, emails, phones, Korean RRN) are masked as `[REDACTED]`. Your own email (from `git config user.email`) is auto-allowlisted.

Add more:

```json
"pii": {
  "allowedEmails": ["teammate@company.com"],
  "customPatterns": ["PATIENT-[0-9]{6}"]
}
```

## Use

```
/worklog                              # latest working day
/worklog 2025-05-27                   # specific day
/worklog 2025-W21                     # ISO week
/worklog 2025-05                      # specific month
/worklog 2025-05-20..2025-05-27       # range
/worklog 25년 5월                      # NL Korean
/worklog last week                    # NL English

/worklog apply worklog-2025-05-27.md             # interactive
/worklog apply worklog-2025-05-27.md --dry-run   # preview diff
/worklog apply worklog-2025-05-27.md --target ./CLAUDE.md  # one target
```

Output:

```
~/.local/share/worklog/
├── worklog-2025-05-27.md
├── worklog-2025-W21.md
├── learnings.md
└── html/worklog-2025-05-27.html
```

Re-running on the same period rotates the old file to `*.md.bak` once before overwriting.

## Extending

### Add a PR fetcher (e.g., GitLab MCP)

Match the [PullRequestFetcher contract](./scripts/fetchers/pr/README.md), drop into `scripts/fetchers/pr/`, set `sources.git.prFetcher`.

### Add an MCP source

Add `skills/worklog-generator/sources/<name>.md`, extend `schemas/config.schema.json` and `SKILL.md`.

## Develop

```bash
bats tests/bats/
shellcheck scripts/**/*.sh
npx ajv-cli validate -s schemas/config.schema.json -d config.example.json
```

## License

MIT — see [LICENSE](./LICENSE). © 2025 worklog contributors.
