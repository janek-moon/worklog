#!/usr/bin/env bash
# apply_rules.sh
#   --parse-only <retro>                  : emit candidates as JSON array to stdout
#   --target <path> [--section <heading>] [--if-absent skip|create|error]
#     [--dry-run] [--auto-accept] [--backup-suffix .bak]
#     <retro>                              : interactive-or-auto apply
#
# Interactive mode (without --auto-accept) is not yet shell-driven; the wrapping
# Claude skill (worklog-applier) handles per-candidate prompting and then calls
# this script with --auto-accept for each accepted-or-edited candidate.

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "apply_rules.sh: jq is required" >&2; exit 1; }

PARSE_ONLY=0
DRY_RUN=0
AUTO_ACCEPT=0
TARGET=""
SECTION=""
IF_ABSENT="skip"
BACKUP_SUFFIX=".bak"
RETRO=""

usage() {
    cat >&2 <<USAGE
Usage:
  $0 --parse-only <retro-file>
  $0 --target <path> [--section <heading>] [--if-absent skip|create|error]
     [--dry-run] [--auto-accept] [--backup-suffix .bak] <retro-file>
USAGE
    exit 3
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --parse-only) PARSE_ONLY=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --auto-accept) AUTO_ACCEPT=1; shift ;;
        --target) TARGET="${2:-}"; shift 2 ;;
        --section) SECTION="${2:-}"; shift 2 ;;
        --if-absent) IF_ABSENT="${2:-}"; shift 2 ;;
        --backup-suffix) BACKUP_SUFFIX="${2:-}"; shift 2 ;;
        -h|--help) usage ;;
        --*) echo "Unknown option: $1" >&2; exit 3 ;;
        *) RETRO="$1"; shift ;;
    esac
done

[[ -z "$RETRO" ]] && usage
[[ ! -r "$RETRO" ]] && { echo "Cannot read retro file: $RETRO" >&2; exit 1; }

# --- Parser ---
parse_candidates() {
    awk '
        BEGIN { in_section=0; in_cand=0; idx=0; print "[" }
        /^## Rule Candidates[[:space:]]*$/ { in_section=1; next }
        in_section && /^## / && !/^## Rule Candidates/ { in_section=0 }
        in_section && /^### Candidate / {
            if (in_cand) print_cand()
            in_cand=1; idx++
            title=$0; sub(/^### Candidate [0-9]+: /, "", title)
            rule=""; rationale=""; evidence=""; targets=""
            next
        }
        in_section && in_cand && /^- \*\*Rule\*\*:/ { rule=$0; sub(/^- \*\*Rule\*\*: */, "", rule); next }
        in_section && in_cand && /^- \*\*Rationale\*\*:/ { rationale=$0; sub(/^- \*\*Rationale\*\*: */, "", rationale); next }
        in_section && in_cand && /^- \*\*Evidence\*\*:/ { evidence=$0; sub(/^- \*\*Evidence\*\*: */, "", evidence); next }
        in_section && in_cand && /^- \*\*Suggested target\(s\)\*\*:/ { targets=$0; sub(/^- \*\*Suggested target\(s\)\*\*: */, "", targets); next }
        END { if (in_cand) print_cand(); print "]" }

        function json_escape(s,    r) {
            r = s
            gsub(/\\/, "\\\\", r)
            gsub(/"/, "\\\"", r)
            gsub(/\t/, "\\t", r)
            return r
        }
        function targets_array(s,    arr, i, n, out) {
            n = split(s, arr, /, */)
            out = "["
            for (i=1; i<=n; i++) {
                if (i>1) out = out ","
                out = out "\"" json_escape(arr[i]) "\""
            }
            return out "]"
        }
        function print_cand() {
            if (idx>1) printf(",")
            printf("{\"title\":\"%s\",\"rule\":\"%s\",\"rationale\":\"%s\",\"evidence\":\"%s\",\"suggestedTargets\":%s}",
                json_escape(title), json_escape(rule), json_escape(rationale),
                json_escape(evidence), targets_array(targets))
        }
    ' "$1"
}

if [[ $PARSE_ONLY -eq 1 ]]; then
    parse_candidates "$RETRO" | jq -c '.'
    exit 0
fi

# --- Apply ---
[[ -z "$TARGET" ]] && { echo "--target is required" >&2; exit 3; }

if [[ ! -e "$TARGET" ]]; then
    case "$IF_ABSENT" in
        skip)   echo "skip: target missing: $TARGET" >&2; exit 0 ;;
        create)
            mkdir -p "$(dirname "$TARGET")"
            if [[ -n "$SECTION" ]]; then
                printf '%s\n\n' "$SECTION" > "$TARGET"
            else
                : > "$TARGET"
            fi
            ;;
        error)  echo "error: target missing: $TARGET" >&2; exit 1 ;;
        *)      echo "unknown if-absent: $IF_ABSENT" >&2; exit 3 ;;
    esac
fi

candidates=$(parse_candidates "$RETRO" | jq -c '.')
n=$(echo "$candidates" | jq 'length')
if [[ "$n" -eq 0 ]]; then
    echo "no candidates in $RETRO" >&2
    exit 0
fi

# Build appended block
appended=""
for ((i=0; i<n; i++)); do
    title=$(echo "$candidates" | jq -r ".[$i].title")
    rule=$(echo "$candidates" | jq -r ".[$i].rule")
    appended+="- ${rule}  <!-- from worklog: ${title} -->"$'\n'
done

if [[ $DRY_RUN -eq 1 ]]; then
    tmp=$(mktemp)
    tmp_new=$(mktemp)
    trap 'rm -f "$tmp" "$tmp_new"' EXIT
    cp "$TARGET" "$tmp"
    if [[ -n "$SECTION" ]] && grep -qxF "$SECTION" "$tmp"; then
        WORKLOG_APPEND="$appended" awk -v sec="$SECTION" '
            BEGIN { in_sec=0; added=0; add=ENVIRON["WORKLOG_APPEND"] }
            in_sec && !added && /^## / && $0 != sec {
                printf("%s", add); added=1; in_sec=0
            }
            { print }
            $0==sec && !added { in_sec=1 }
            END { if (in_sec && !added) printf("%s", add) }
        ' "$tmp" > "$tmp_new"
    else
        cat "$tmp" > "$tmp_new"
        if [[ -n "$SECTION" ]]; then printf '\n%s\n\n' "$SECTION" >> "$tmp_new"; fi
        printf '%s' "$appended" >> "$tmp_new"
    fi
    diff -u "$TARGET" "$tmp_new" || true
    exit 0
fi

if [[ $AUTO_ACCEPT -ne 1 ]]; then
    echo "interactive mode not implemented in shell; called from worklog-applier skill" >&2
    exit 3
fi

# Backup once
[[ -f "$TARGET" ]] && cp "$TARGET" "${TARGET}${BACKUP_SUFFIX}"

if [[ -n "$SECTION" ]] && grep -qxF "$SECTION" "$TARGET"; then
    tmp="$(mktemp)"
    WORKLOG_APPEND="$appended" awk -v sec="$SECTION" '
        BEGIN { in_sec=0; added=0; add=ENVIRON["WORKLOG_APPEND"] }
        in_sec && !added && /^## / && $0 != sec {
            printf("%s", add); added=1; in_sec=0
        }
        { print }
        $0==sec && !added { in_sec=1 }
        END { if (in_sec && !added) printf("%s", add) }
    ' "$TARGET" > "$tmp"
    mv "$tmp" "$TARGET"
else
    if [[ -n "$SECTION" ]]; then printf '\n%s\n\n' "$SECTION" >> "$TARGET"; fi
    printf '%s' "$appended" >> "$TARGET"
fi

echo "applied $n candidate(s) to $TARGET (backup: ${TARGET}${BACKUP_SUFFIX})" >&2
