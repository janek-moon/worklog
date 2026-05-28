# Source: claude-code

Reads `~/.claude/projects/<encoded-cwd>/` session files.

## Procedure

1. List subdirectories.
2. For each session file (.jsonl) with mtime in window:
   - `meta`: turn count, first user prompt (first 200 chars), file paths mentioned (deduped).
   - `summary`: meta + 1–2 sentence Claude summary.
   - `full`: include up to 5 longest turns verbatim — must pipe through `scripts/pii_mask.sh` first.
3. Group by project dir (decoded original cwd).

## Status mapping

| Condition | status |
|----|----|
| `~/.claude/projects/` exists and readable | ok |
| Exists, no sessions in window | ok |
| Not exists | skipped |
| Permission denied | failed |
