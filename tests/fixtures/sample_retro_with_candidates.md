---
period: 2025-05-27
type: daily
generated: 2025-05-28T10:30:00+09:00
tz: Asia/Seoul
sources:
  git: { status: ok }
framework: KPT
language: ko
pii: { maskedCount: 0 }
learnings:
  candidatesCount: 2
  applied: []
---

# Worklog — 2025-05-27 (Tue)

## Activities

### Commits & PRs
- 09:24 commit one

## KPT

### Keep
- nothing

### Problem
- duplicated work

### Try
- check status first

## Rule Candidates

### Candidate 1: Run git status before any new task
- **Rule**: Always run `git status` at the start of a new task to verify working tree cleanliness.
- **Rationale**: Today's lint conflict originated from a leftover modification not committed.
- **Evidence**: #1351, #1352, lint failure at 11:14.
- **Suggested target(s)**: project, learnings

### Candidate 2: Self-review PR before opening
- **Rule**: Read your full PR diff once before clicking "Create PR".
- **Rationale**: Two PRs today had typos catchable by self-review.
- **Evidence**: #1349 typo, #1350 typo.
- **Suggested target(s)**: project
