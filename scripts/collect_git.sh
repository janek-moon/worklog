#!/usr/bin/env bash
set -euo pipefail

SINCE=""; UNTIL=""
REPOS=()

usage() { echo "Usage: $0 --since YYYY-MM-DD --until YYYY-MM-DD [--repos PATH]... (repeat --repos for multiple)" >&2; exit 3; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        --until) UNTIL="${2:-}"; shift 2 ;;
        --repos) REPOS+=("${2:-}"); shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 3 ;;
    esac
done

[[ -z "$SINCE" || -z "$UNTIL" ]] && usage

date_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
[[ "$SINCE" =~ $date_re ]] || { echo "Invalid --since: $SINCE (expected YYYY-MM-DD)" >&2; exit 3; }
[[ "$UNTIL" =~ $date_re ]] || { echo "Invalid --until: $UNTIL (expected YYYY-MM-DD)" >&2; exit 3; }

command -v jq >/dev/null 2>&1 || { echo "missing dependency: jq" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "missing dependency: git" >&2; exit 1; }

if [[ ${#REPOS[@]} -eq 0 ]]; then
    REPOS=(".")
fi

for repo in "${REPOS[@]}"; do
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "warn: not a git repo, skipping: $repo" >&2
        continue
    fi
    repo_name=$(basename "$(git -C "$repo" rev-parse --show-toplevel)")
    git -C "$repo" log --since="$SINCE" --until="$UNTIL" --no-merges \
        --pretty='%H%x1F%aI%x1F%s%x1F%ae' \
    | while IFS=$'\x1F' read -r sha date subject author; do
        files_json=$(
            git -C "$repo" show --name-only --pretty=format: "$sha" \
                | awk 'NF' | jq -R . | jq -s .
        )
        jq -nc \
            --arg sha "$sha" --arg date "$date" --arg subject "$subject" \
            --arg author "$author" --arg repo "$repo_name" \
            --argjson files "$files_json" \
            '{type:"commit", sha:$sha, date:$date, subject:$subject, author:$author, repo:$repo, files:$files}'
    done
done
