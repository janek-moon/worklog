#!/usr/bin/env bash
# pii_mask.sh — Read stdin, mask common secret/PII patterns, write to stdout.
# Prints "masked: N" to stderr.
# Env:
#   WORKLOG_PII_ALLOW   comma-separated literal strings to keep verbatim
#   WORKLOG_PII_CUSTOM  comma-separated additional ERE patterns to mask

set -euo pipefail

ALLOW_RAW="${WORKLOG_PII_ALLOW:-}"
CUSTOM_RAW="${WORKLOG_PII_CUSTOM:-}"

# Build awk allowlist as a "|sep|" string for exact-token match.
ALLOW_LIST=""
if [[ -n "$ALLOW_RAW" ]]; then
    ALLOW_LIST="|$(echo "$ALLOW_RAW" | tr ',' '|')|"
fi

# Auto-add git config user.email to allowlist if available (per SPEC § 5.2).
if user_email=$(git config user.email 2>/dev/null) && [[ -n "$user_email" ]]; then
    if [[ -z "$ALLOW_LIST" ]]; then
        ALLOW_LIST="|${user_email}|"
    else
        ALLOW_LIST="${ALLOW_LIST}${user_email}|"
    fi
fi

# Custom patterns: comma-separated -> newline-separated, passed via env var
# (awk reads ENVIRON["CUSTOM_PATS"] to avoid multiline -v limitation on BSD awk).
export CUSTOM_PATS=""
if [[ -n "$CUSTOM_RAW" ]]; then
    CUSTOM_PATS=$(echo "$CUSTOM_RAW" | tr ',' '\n')
fi

# Single awk pass: standard patterns are embedded in BEGIN; custom patterns loaded
# from ENVIRON["CUSTOM_PATS"]. For each line, for each pattern, walk matches with
# RSTART/RLENGTH. Allowed values (exact match) are kept; everything else -> [REDACTED].
masked_output=$(
    awk -v allow="$ALLOW_LIST" '
        BEGIN {
            # Standard patterns — POSIX ERE. Order: more specific first.
            parr[1]  = "AKIA[0-9A-Z]{16}"
            parr[2]  = "gh[oprsu]_[A-Za-z0-9]{36}"
            parr[3]  = "Bearer +[A-Za-z0-9._~+/-]{20,}"
            parr[4]  = "sk-[A-Za-z0-9]{20,}"
            parr[5]  = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
            parr[6]  = "(01[016789]|0[2-6][0-9]?)-[0-9]{3,4}-[0-9]{4}"
            parr[7]  = "[0-9]{6}-[1-4][0-9]{6}"
            n = 7

            # Append custom patterns from environment (newline-separated).
            custom = ENVIRON["CUSTOM_PATS"]
            if (custom != "") {
                m = split(custom, carr, "\n")
                for (j = 1; j <= m; j++) {
                    if (carr[j] != "") {
                        n++
                        parr[n] = carr[j]
                    }
                }
            }
            count = 0
        }
        {
            line = $0
            # Process each pattern in sequence; rebuild line by scanning matches.
            for (i = 1; i <= n; i++) {
                pat = parr[i]
                out = ""
                rest = line
                while (match(rest, pat)) {
                    before  = substr(rest, 1, RSTART - 1)
                    matched = substr(rest, RSTART, RLENGTH)
                    rest    = substr(rest, RSTART + RLENGTH)
                    # Allowlist check: exact match enclosed in "|...|" markers.
                    if (allow != "" && index(allow, "|" matched "|") > 0) {
                        out = out before matched
                    } else {
                        out = out before "[REDACTED]"
                        count++
                    }
                }
                line = out rest
            }
            print line
        }
        END {
            print "masked: " count > "/dev/stderr"
        }
    '
)

printf '%s\n' "$masked_output"
