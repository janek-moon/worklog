# worklog

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

A Claude Code plugin for **personal work retrospectives + agent rule learning**. Generate a daily / weekly / monthly retrospective from your activity, then turn the patterns into rules your agent actually follows.

```
/worklog                            # auto-detect latest working day
/worklog 25년 5월                    # or natural language
/worklog apply worklog-2025-05.md   # promote learnings to CLAUDE.md / learnings.md
```

## Two commands, one feedback loop

1. `/worklog [period]` collects facts from git and your local planning docs (`PLAN.md` / `SPEC.md`), contrasts planned intent against the delivered git diff, then writes a markdown + HTML retrospective with **Activities**, **KPT**, and **Rule Candidates**.

2. `/worklog apply <retro-file>` walks you through each Rule Candidate (accept / edit / skip), backs up your target rule files (`./CLAUDE.md`, `./AGENTS.md`, `learnings.md`), and appends the approved rules. Per-candidate approval gates every write.

## Install

This repo is a Claude Code plugin marketplace. Add it, then install (requires Claude Code v2.1.140+):

```
/plugin marketplace add janek-moon/worklog
/plugin install worklog@worklog
```

Once installed, the `/worklog` command and both skills (`worklog-generator`, `worklog-applier`) are available. For development, point the marketplace at a local clone instead: `/plugin marketplace add ./worklog`.

### Dependencies

| Tool | Required | Purpose |
|------|----------|---------|
| `git` | ✅ | Commit collection |
| `jq` | ✅ | JSON processing |
| `bash` ≥ 4.4 | ✅ | Scripts |
| `node` + `ajv-cli` | dev only | Schema validation |
| `bats-core`, `shellcheck` | dev only | Tests + lint |

```bash
# macOS
brew install bash jq bats-core shellcheck
```

## Configure

Copy `config.example.json` to `~/.config/worklog/config.json` and edit. Defaults if no file: git + plan sources enabled, learnings extracted but no auto-apply targets.

### Plan docs

```json
"plan": { "enabled": true, "paths": ["PLAN.md", "SPEC.md"] }
```

Paths resolve relative to each git repo (or cwd). worklog reads these planning docs as "planned intent" and contrasts them against the delivered git diff. Missing paths are skipped quietly — handy when the docs are kept local (gitignored).

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

### Add a source

Add `skills/worklog-generator/sources/<name>.md` (procedure + status mapping, mirroring `git.md` / `plan.md`), then extend `schemas/config.schema.json` and the collect step in `SKILL.md`.

## Develop

```bash
bats tests/bats/
shellcheck scripts/**/*.sh
npx ajv-cli validate -s schemas/config.schema.json -d config.example.json
```

## License

MIT — see [LICENSE](./LICENSE). © 2025 worklog contributors.
