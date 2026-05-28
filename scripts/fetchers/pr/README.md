# PullRequestFetcher Contract

A fetcher is an executable under `scripts/fetchers/pr/` that emits NDJSON PR/Issue records to stdout.

## Input

```
scripts/fetchers/pr/<name>.sh \
    --since <ISO_DATE> --until <ISO_DATE> \
    --repos <owner/name,owner/name,...>
```

## Output (NDJSON)

```json
{ "type": "pr", "number": 1352, "title": "...", "state": "merged",
  "repo": "owner/name", "url": "https://...", "createdAt": "ISO",
  "mergedAt": "ISO", "labels": ["..."] }
```

Required: type, number, title, state, repo, url, createdAt.
Optional: mergedAt, closedAt, labels.

## Exit codes

| code | meaning |
|------|---------|
| 0 | success |
| 1 | dependency missing |
| 2 | auth/permission failure |
| 3 | argument error |
| ≥4 | other |
