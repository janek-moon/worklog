# Source: prior-retros

Reads the most recent prior retro of the same `type` from `output.dir`.

## Procedure

1. List `worklog-*.md` in `output.dir`.
2. Parse each frontmatter; filter by `type == <current type>`.
3. Sort by `period` desc. Pick first with `period < SINCE`.
4. None → `status: none`.
5. Read `## KPT` → `### Try` items:
   - `- [x]` → done
   - `- [ ]` → pending
6. `gapDays` = days between picked `period` and current SINCE.
7. Output `{status:"ok", found, gapDays, tries:[{text, done}, ...]}`.

## Status mapping

| Condition | status |
|----|----|
| Match found, frontmatter valid | ok |
| No match | none |
| Match but invalid frontmatter / KPT missing | corrupted |
| range type | skipped |
