#!/usr/bin/env bash
set -euo pipefail

SINCE=""; UNTIL=""; REPOS_RAW=""

usage() { echo "Usage: $0 --since YYYY-MM-DD --until YYYY-MM-DD [--repos path1,path2,...]" >&2; exit 3; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --since) SINCE="${2:-}"; shift 2 ;;
        --until) UNTIL="${2:-}"; shift 2 ;;
        --repos) REPOS_RAW="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 3 ;;
    esac
done

[[ -z "$SINCE" || -z "$UNTIL" ]] && usage

if [[ -z "$REPOS_RAW" ]]; then
    REPOS=(".")
else
    IFS=',' read -ra REPOS <<< "$REPOS_RAW"
fi

for repo in "${REPOS[@]}"; do
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        continue
    fi
    repo_name=$(basename "$(git -C "$repo" rev-parse --show-toplevel)")
    git -C "$repo" log --since="$SINCE" --until="$UNTIL" --no-merges \
        --pretty='%H%x1F%aI%x1F%s%x1F%ae' | \
    while IFS=$'\x1F' read -r sha date subject author; do
        files_json=$(
            git -C "$repo" show --name-only --pretty=format: "$sha" \
                | grep -v '^$' | jq -R . | jq -s .
        )
        jq -nc \
            --arg sha "$sha" --arg date "$date" --arg subject "$subject" \
            --arg author "$author" --arg repo "$repo_name" \
            --argjson files "$files_json" \
            '{type:"commit", sha:$sha, date:$date, subject:$subject, author:$author, repo:$repo, files:$files}'
    done
done
