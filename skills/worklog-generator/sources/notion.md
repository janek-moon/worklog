# Source: notion

Triggered only when `config.sources.mcp.notion.enabled = true`.

## Procedure

1. For each `databaseIds[]`:
   - MCP `notion-fetch` filtered by `last_edited_time >= SINCE`.
   - Client-side filter `< UNTIL`.
   - Extract `title`, `url`, `last_edited_time`, summary `properties`.
   - Build timeline entry `{type:"notion", id, title, url, lastEdited, db}`.

## Status mapping

| Condition | status |
|----|----|
| All ok | ok |
| `databaseIds` empty | skipped |
| Some fail | degraded |
| All fail | failed |

## Notes

- Title property: search `type == "title"`, join `rich_text[]`.
- Paginate until `has_more = false` or 100 entries per database.
