#!/usr/bin/env bats

@test "apply_rules.sh --parse-only emits JSON array of candidates" {
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --parse-only \
        "${BATS_TEST_DIRNAME}/../fixtures/sample_retro_with_candidates.md"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 2'
    echo "$output" | jq -e '.[0].rule | startswith("Always run")'
    echo "$output" | jq -e '.[0].suggestedTargets | contains(["project"])'
    echo "$output" | jq -e '.[1].rule | startswith("Read your full")'
}

@test "apply_rules.sh --parse-only emits empty array if no candidates section" {
    cat > "${BATS_TMPDIR}/no_cand.md" <<'MD'
---
period: 2025-05-27
type: daily
---
# Worklog
## Activities
## KPT
MD
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" --parse-only "${BATS_TMPDIR}/no_cand.md"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}
