#!/usr/bin/env bash
set -euo pipefail

ALLOW_RAW="${WORKLOG_PII_ALLOW:-}"
CUSTOM_RAW="${WORKLOG_PII_CUSTOM:-}"

PATTERNS=(
    'AKIA[0-9A-Z]{16}'
    'gh[oprsu]_[A-Za-z0-9]{36}'
    'Bearer +[A-Za-z0-9._~+/-]{20,}'
    'sk-[A-Za-z0-9]{20,}'
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    '[0-9]{2,3}-[0-9]{3,4}-[0-9]{4}'
    '[0-9]{6}-[1-4][0-9]{6}'
)

if [[ -n "$CUSTOM_RAW" ]]; then
    IFS=',' read -ra CUSTOM <<< "$CUSTOM_RAW"
    PATTERNS+=("${CUSTOM[@]}")
fi

input=$(cat)

if [[ -z "$ALLOW_RAW" ]]; then
    output="$input"
    for p in "${PATTERNS[@]}"; do
        output=$(echo "$output" | sed -E "s|${p}|[REDACTED]|g")
    done
else
    IFS=',' read -ra ALLOW <<< "$ALLOW_RAW"
    output=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        allowed_hit=""
        for a in "${ALLOW[@]}"; do
            if [[ "$line" == *"$a"* ]]; then allowed_hit="$a"; break; fi
        done
        masked_line="$line"
        for p in "${PATTERNS[@]}"; do
            masked_line=$(echo "$masked_line" | sed -E "s|${p}|[REDACTED]|g")
        done
        if [[ -n "$allowed_hit" ]]; then
            masked_line="${masked_line//\[REDACTED\]/$allowed_hit}"
        fi
        output+="$masked_line"$'\n'
    done <<< "$input"
    output="${output%$'\n'}"
fi

count=$(echo "$output" | grep -o '\[REDACTED\]' | wc -l | tr -d ' ' || true)
echo "masked: $count" >&2

printf '%s' "$output"
