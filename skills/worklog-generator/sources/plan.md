# Source: plan

Reads local planning documents (e.g. `PLAN.md`, `SPEC.md`) so the retro can
contrast **what was planned** against **what was actually done** (git diff).
These docs typically live in the repo working tree but may be gitignored as
local design artifacts.

## Procedure

1. Resolve plan-doc paths:
   - Use `config.sources.plan.paths[]` if non-empty; else default `["PLAN.md", "SPEC.md"]`.
   - Resolve each path relative to every repo in `config.sources.git.repos[]`
     (or cwd if a git repo). Expand `~`.
2. For each resolved path that exists and is readable: capture its text.
   - Skip nonexistent paths quietly.
3. Note recency: for each plan doc inside a git repo, record whether it was
   touched in the window (`git -C <repo> log --since SINCE --until UNTIL -- <path>`
   has output). This flags plans that were actively edited during the period.
4. Provide the (PII-masked) plan-doc text as the "planned intent" context for
   synthesis. Synthesis compares this against the git activity to surface
   delivered-vs-planned gaps in KPT.

## Status mapping

| condition | status |
|----|----|
| `enabled: false` | disabled |
| ≥1 plan doc found and read | ok |
| enabled, but no plan doc exists at any resolved path | none |
| a configured path exists but is unreadable | degraded |
