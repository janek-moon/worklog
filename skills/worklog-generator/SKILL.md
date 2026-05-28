---
name: worklog-generator
description: Generates a daily/weekly/monthly/range work retrospective by collecting activity from git, GitHub PRs, Claude Code sessions, optional MCP sources (Atlassian, Notion), the prior retro, and currently active rule files. Synthesizes a KPT-formatted markdown report with HTML mirror, and extracts a Rule Candidates section for later application via /worklog apply.
---

# worklog Generator

You generate a work retrospective for the user. Be deterministic: rely on scripts for fact collection and use Claude only for synthesis. Rule Candidates extraction is part of synthesis.

## Inputs

- Optional positional arg: a period spec or natural language (`2025-05-27`, `2025-W21`, `2025-05`, `2025-05-20..2025-05-27`, `25년 5월`, `last week`, `어제`, `yesterday`).
- If no arg: auto-detect the latest working day.

## Procedure

### Step 1. Load config

1. Resolve config path: `$XDG_CONFIG_HOME/worklog/config.json` or `~/.config/worklog/config.json`.
2. If file exists, read it; else use defaults.
3. Resolve `output.dir` (expand `~` and `$XDG_DATA_HOME`).
4. Identify enabled sources from `sources.*.enabled`.

### Step 2. Determine time window

If user provided a period arg:
1. Normalize to ISO form.
2. Infer `type`.
3. If ambiguous, ask once.

If no arg:
1. `scripts/collect_git.sh --since <today-30> --until <tomorrow>`.
2. Pick the most recent date with any activity. That date = daily target.
3. If 0 activity in 30 days: emit "No activity in the last 30 days" and graceful exit.

Compute `SINCE`/`UNTIL` boundaries in user's TZ (`config.tz` or system TZ).

### Step 3. Collect (in parallel — single message, multiple tool calls)

Issue these in one batch:

- `scripts/collect_git.sh --since SINCE --until UNTIL --repos REPOS`
  - `REPOS` from `config.sources.git.repos` if non-empty; else cwd if a git repo; else skip.
- `scripts/fetchers/pr/<prFetcher>.sh --since SINCE --until UNTIL --repos OWNER_NAMES`
  - `OWNER_NAMES` derived from `git remote get-url origin` of each repo (parse `owner/name`).
  - Skip if no remote URLs.
- Read `~/.claude/projects/`: metadata per session in window (depth per `sources.claudeCode.depth`).
- Prior retro: list `$output.dir/worklog-*.md` of same `type`, pick most recent before SINCE. Extract `### Try` items. Compute `gapDays`.
- Current rule files (`sources.currentRules.enabled`):
  - Read `./CLAUDE.md`, `./AGENTS.md`, `~/.claude/CLAUDE.md`, accumulated `learnings.md` (from output.dir), and `extraPaths[]`.
  - Concatenate. Skip nonexistent files quietly.
- MCP (only enabled):
  - Atlassian: `atlassianUserInfo` → JQL `assignee = currentUser() AND project = <KEY> AND updated >= SINCE AND updated < UNTIL`.
  - Notion: `notion-fetch` for each `databaseIds[]` with `last_edited_time >= SINCE`, client-side filter `< UNTIL`.

Record per-source `status`: `ok` | `disabled` | `skipped` | `failed` | `degraded` | `none` | `corrupted`.

### Step 4. Synthesize

1. Build chronological merged timeline.
2. Pipe all text through `scripts/pii_mask.sh` (env: `WORKLOG_PII_ALLOW=<emails>`, `WORKLOG_PII_CUSTOM=<patterns>`).
3. Determine language (auto cache in `${configDir}/state.json`).
4. KPT draft (English headings, narrative in resolved language):
   - **Keep**, **Problem**, **Try**.
5. Rule Candidates extraction (only if `learnings.extraction.enabled`):
   - Inspect the activity timeline + KPT.Problem patterns.
   - Generalize patterns that recur or have clear cause-effect into rule candidates.
   - Drop any candidate that overlaps with an existing rule in the currentRules concatenation (lexical similarity > 70% or same imperative core verb on same noun phrase).
   - Cap at `learnings.extraction.maxCandidates`.
   - For each candidate: `{ rule, rationale, evidence: [activity refs], suggestedTargets }` per SPEC § Appendix E.

### Step 5. Write outputs

1. Build frontmatter per `schemas/frontmatter.schema.json`. Include `learnings.candidatesCount` and `learnings.applied: []`.
2. Build markdown body per SPEC § 4.4 (Activities / Prior Try / KPT / Rule Candidates).
3. Filename: `worklog-{period}.md` (rules per SPEC § 4.1).
4. If destination exists: rotate to `.md.bak` once, then overwrite.
5. Write markdown (0644).
6. If `output.htmlMirror`: load `templates/worklog.html`, convert markdown → inline HTML, inject into `<!-- CONTENT -->`, set `<title>`, write `output.dir/html/worklog-{period}.html`.

### Step 6. Report (stdout)

```
worklog: PERIOD (TYPE)
  → DIR/worklog-PERIOD.md
  → DIR/html/worklog-PERIOD.html
  PII masked: N
  Sources: git=ok, claudeCode=ok, ...
  Rule Candidates: M (apply with: /worklog apply worklog-PERIOD.md)
```

## Error Handling (SPEC § 5.1.1)

- `git` absent → abort exit 1.
- `gh` absent → mark `git.status: degraded`, continue.
- MCP failure → source `failed`, record reason, continue.
- 0 activity (user-specified window) → suggest closest active day; abort if declined.
- currentRules all missing → `currentRules.status: skipped`, continue.

## Source Procedure References

- [git](./sources/git.md)
- [claude-code](./sources/claude-code.md)
- [atlassian](./sources/atlassian.md)
- [notion](./sources/notion.md)
- [prior-retros](./sources/prior-retros.md)
- [current-rules](./sources/current-rules.md)
