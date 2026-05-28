# Source: current-rules

Reads currently active agent rule files to (a) avoid duplicate Rule Candidates, and (b) show the user how many rules are in effect.

## Procedure

1. If `config.sources.currentRules.enabled = false`: `status: disabled`.
2. Build list of candidate paths in order:
   - `./CLAUDE.md`
   - `./AGENTS.md`
   - `~/.claude/CLAUDE.md`
   - `{output.dir}/learnings.md`
   - All `config.sources.currentRules.extraPaths[]`
3. Filter to existing readable files.
4. If empty: `status: skipped`.
5. Concatenate contents (with file-boundary markers) into a single text blob.
6. Output `{status, files:[paths]}` and pass the blob to the synthesis step for de-duplication.

## Status mapping

| Condition | status |
|----|----|
| All listed paths read ok | ok |
| Some paths unreadable but at least one read | degraded |
| All paths missing | skipped |
| Plugin failed to access filesystem | failed |
| `enabled = false` | disabled |

## De-duplication signal

When the synthesis step considers a rule candidate, compare against this blob:
- Same imperative verb + same noun phrase → duplicate, drop.
- Lexical similarity > 70% (e.g., normalized Jaccard) → duplicate, drop.
- Otherwise: keep.
