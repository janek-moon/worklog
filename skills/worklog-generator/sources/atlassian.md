# Source: atlassian

Triggered only when `config.sources.mcp.atlassian.enabled = true`.

## Procedure

1. MCP `atlassianUserInfo` → user's `accountId`. Fail → `status: failed`, stop.
2. MCP `getAccessibleAtlassianResources` → cloudId (first, or config-pinned).
3. For each `projectKeys[]`:
   - JQL: `assignee = currentUser() AND project = "<KEY>" AND updated >= "SINCE" AND updated < "UNTIL"`.
   - MCP `searchJiraIssuesUsingJql` with fields `summary,status,resolution,updated,issuetype`.
   - Build timeline entry `{type:"jira", key, summary, status, updated, url}`.

## Status mapping

| Condition | status |
|----|----|
| All projects ok | ok |
| userInfo fails | failed |
| Some project queries fail | degraded |
| projectKeys empty | skipped |
