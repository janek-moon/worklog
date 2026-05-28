#!/usr/bin/env bash
set -euo pipefail

SINCE=""; UNTIL=""; REPOS_RAW=""

usage() { echo "Usage: $0 --since DATE --until DATE --repos owner/name,..." >&2; exit 3; }

is_iso_date() {
    [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        --until) UNTIL="${2:-}"; shift 2 ;;
        --repos) REPOS_RAW="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 3 ;;
    esac
done

[[ -z "$SINCE" || -z "$UNTIL" || -z "$REPOS_RAW" ]] && usage

if ! is_iso_date "$SINCE"; then
    echo "Invalid --since date (expected YYYY-MM-DD): $SINCE" >&2; exit 3
fi
if ! is_iso_date "$UNTIL"; then
    echo "Invalid --until date (expected YYYY-MM-DD): $UNTIL" >&2; exit 3
fi

command -v gh  >/dev/null 2>&1 || { echo "gh not found" >&2; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

IFS=',' read -ra REPOS <<< "$REPOS_RAW"

for repo in "${REPOS[@]}"; do
    prs=$(gh pr list --repo "$repo" --state all \
        --search "updated:${SINCE}..${UNTIL}" --limit 200 \
        --json number,title,state,url,createdAt,mergedAt,closedAt,labels 2>/dev/null) || {
            ec=$?
            if [[ $ec -eq 4 ]]; then echo "auth failed for $repo" >&2; exit 2; fi
            echo "Warning: gh pr list failed for $repo (exit $ec)" >&2
            continue
        }
    echo "$prs" | jq -c --arg repo "$repo" '.[] | {
        type:"pr", number:.number, title:.title, state:(.state | ascii_downcase),
        repo:$repo, url:.url, createdAt:.createdAt, mergedAt:.mergedAt,
        closedAt:.closedAt, labels:([.labels[]?.name])
    }'
    issues=$(gh issue list --repo "$repo" --state all \
        --search "updated:${SINCE}..${UNTIL}" --limit 200 \
        --json number,title,state,url,createdAt,closedAt,labels 2>/dev/null) || {
            echo "Warning: gh issue list failed for $repo" >&2
            continue
        }
    echo "$issues" | jq -c --arg repo "$repo" '.[] | {
        type:"issue", number:.number, title:.title, state:(.state | ascii_downcase),
        repo:$repo, url:.url, createdAt:.createdAt, closedAt:.closedAt,
        labels:([.labels[]?.name])
    }'
done
