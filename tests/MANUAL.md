# Manual Smoke Test Checklist

Run before release / merge of significant changes. CI does not cover Claude-driven synthesis or interactive apply.

Setup: have a local git repo with recent commits, `gh auth status` showing logged in.

## Generate flow

### Smoke 1: Auto-detect default

```
/worklog
```

Expect:
- `~/.local/share/worklog/worklog-YYYY-MM-DD.md` created for the latest working day.
- HTML mirror opens; dark mode toggle works.
- `## Activities`, `## KPT`, `## Rule Candidates` all present.

### Smoke 2: Specific day

```
/worklog 2025-05-27
```

Expect: frontmatter `period: 2025-05-27`, `type: daily`.

### Smoke 3: Natural language (Korean)

```
/worklog 25년 5월
```

Expect: normalizes to `2025-05`, type `monthly`. If ambiguous, asks once.

### Smoke 4: MCP disabled

Fresh shell, no config.json:

```
/worklog 2025-05-27
```

Expect: frontmatter `atlassian: {status: disabled}`, `notion: {status: disabled}`. No errors.

### Smoke 5: MCP enabled

Configure `atlassian.enabled = true` with real `projectKeys`:

```
/worklog 2025-05-27
```

Expect: frontmatter `atlassian: {status: ok}`, body has `### Jira` subsection.

### Smoke 6: Re-run same period

Run Smoke 2 twice. Expect `.md.bak` appears.

### Smoke 7: PII masking

Add a commit with fake AWS key `AKIAIOSFODNN7TESTING` in the message. Run worklog covering that day. Expect commit subject shows `[REDACTED]`; frontmatter `pii.maskedCount` ≥ 1.

### Smoke 8: Prior Try carry-over

Edit yesterday's worklog file to add an unchecked Try item. Run today's worklog. Expect today's report includes `## Prior Try` with that item as `- [ ]`.

### Smoke 9: Rule Candidates appear

Run any generate flow. Expect `## Rule Candidates` section with at least one `### Candidate N:` entry (if extraction enabled and activity exists). Frontmatter `learnings.candidatesCount > 0`.

## Apply flow

### Smoke 10: Apply with interactive approval

After Smoke 9:

```
/worklog apply ~/.local/share/worklog/worklog-YYYY-MM-DD.md
```

Expect: prompts per candidate. Choose `a` for candidate 1, `s` for candidate 2.
- `./CLAUDE.md` gets candidate 1 appended under `## Auto-curated Learnings`.
- `learnings.md` gets candidate 1 appended at end.
- `.bak` files appear next to modified targets.
- Retro frontmatter `learnings.applied[]` has 2 entries (one per target).

### Smoke 11: Apply --dry-run

```
/worklog apply <retro> --dry-run
```

Expect: unified diff output, no file changes, no `.bak` created, frontmatter unchanged.

### Smoke 12: Apply --target

```
/worklog apply <retro> --target ./CLAUDE.md
```

Expect: only `./CLAUDE.md` touched. `learnings.md` unchanged.

### Smoke 13: Apply with ifAbsent: create

Remove `learnings.md`, configure target with `"ifAbsent": "create"`, run apply with that target. Expect file created.

### Smoke 14: Apply skips duplicate next time

After Smoke 10, run a new `/worklog` for an overlapping period. Expect: in the new report, the previously applied rule does NOT reappear in `## Rule Candidates`.

---

Attach at least one retro's frontmatter to the PR as evidence.
