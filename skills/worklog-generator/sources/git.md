# Source: git

## Procedure

1. Resolve repos:
   - If `config.sources.git.repos[]` non-empty: use them.
   - Else if cwd is a git repo: use cwd.
   - Else: `status = skipped`.
2. `scripts/collect_git.sh --since SINCE --until UNTIL --repos <joined>`.
3. Parse NDJSON: `{type:"commit", sha, date, subject, author, repo, files}`.

## Status mapping

| collect_git.sh | status |
|----|----|
| 0, has output | ok |
| 0, empty | ok (no activity) |
| 3 (no repo) | skipped |
| other | failed |
