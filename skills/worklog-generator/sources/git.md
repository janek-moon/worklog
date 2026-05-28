# Source: git

## Procedure

1. Resolve repos:
   - If `config.sources.git.repos[]` non-empty: use them.
   - Else if cwd is a git repo: use cwd.
   - Else: `status = skipped`.
2. `scripts/collect_git.sh --since SINCE --until UNTIL --repos <joined>`.
3. Parse NDJSON: `{type:"commit", sha, date, subject, author, repo, files}`.
4. PR/Issue:
   - Derive `owner/name` from `git -C <repo> remote get-url origin` (parse).
   - `scripts/fetchers/pr/<prFetcher>.sh --since SINCE --until UNTIL --repos OWNERS`.

## Status mapping

| collect_git.sh | gh.sh | status |
|----|----|----|
| 0, has output | 0 | ok |
| 0, empty | 0 | ok (no activity) |
| 0 | 1 (gh missing) | degraded |
| 0 | 2 (auth) | degraded |
| 3 (no repo) | - | skipped |
| other | - | failed |
