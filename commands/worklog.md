---
name: worklog
description: Generate a work retrospective for a given period (auto-detected if no arg), or apply Rule Candidates from a retro file to target agent rule files.
---

# /worklog

Single entry point for two flows:

- **Generate**: `/worklog [period]` — creates a retro markdown + HTML and extracts Rule Candidates.
- **Apply**: `/worklog apply <retro-file>` — interactively appends accepted Rule Candidates to target rule files.

## Dispatch

Look at the first positional token:

- If first token is `apply` → invoke `worklog-applier` skill with the remaining args (`<retro-file>` plus any flags like `--dry-run`, `--target <path>`).
- Otherwise → invoke `worklog-generator` skill with the full arg string as the period spec.

## Usage

```
/worklog                                  # auto: latest working day
/worklog 2025-05-27                       # specific day
/worklog 2025-W21                         # ISO week
/worklog 2025-05                          # specific month
/worklog 2025-05-20..2025-05-27           # range
/worklog 25년 5월                          # NL (Korean)
/worklog last week                        # NL (English)
/worklog 어제                              # NL (Korean)

/worklog apply <retro-file>               # apply Rule Candidates interactively
/worklog apply <retro-file> --dry-run     # diff preview only
/worklog apply <retro-file> --target PATH # restrict to one target
```

## What `generate` does

See [worklog-generator SKILL.md](../skills/worklog-generator/SKILL.md).

## What `apply` does

See [worklog-applier SKILL.md](../skills/worklog-applier/SKILL.md).
