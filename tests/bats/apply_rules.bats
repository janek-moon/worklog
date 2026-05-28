#!/usr/bin/env bats

setup() {
    WORK="${BATS_TMPDIR}/apply-test-$$"
    mkdir -p "$WORK"
    cp "${BATS_TEST_DIRNAME}/../fixtures/sample_retro_with_candidates.md" "$WORK/retro.md"
    cp "${BATS_TEST_DIRNAME}/../fixtures/sample_claude_md.md" "$WORK/CLAUDE.md"
}

teardown() { rm -rf "$WORK"; }

@test "apply --dry-run --auto-accept produces diff but does not modify file" {
    pre_hash=$(shasum "$WORK/CLAUDE.md" | cut -d' ' -f1)
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --dry-run --auto-accept \
        --target "$WORK/CLAUDE.md" \
        --section "## Auto-curated Learnings" \
        --if-absent skip \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"---"* ]]
    [[ "$output" == *"+++"* ]]
    post_hash=$(shasum "$WORK/CLAUDE.md" | cut -d' ' -f1)
    [ "$pre_hash" = "$post_hash" ]
}

@test "apply with --auto-accept appends to existing section" {
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept \
        --target "$WORK/CLAUDE.md" \
        --section "## Auto-curated Learnings" \
        --if-absent skip \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    grep -q "Always run .git status" "$WORK/CLAUDE.md"
    [ -f "$WORK/CLAUDE.md.bak" ]
    diff "$WORK/CLAUDE.md.bak" "${BATS_TEST_DIRNAME}/../fixtures/sample_claude_md.md"
}

@test "apply with ifAbsent=create makes file" {
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept \
        --target "$WORK/learnings.md" \
        --if-absent create \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    [ -f "$WORK/learnings.md" ]
    grep -q "Always run" "$WORK/learnings.md"
}

@test "apply with ifAbsent=skip warns and exits 0 when target missing" {
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept \
        --target "$WORK/AGENTS.md" \
        --if-absent skip \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    [ ! -f "$WORK/AGENTS.md" ]
}

@test "apply with ifAbsent=error exits 1 when target missing" {
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept \
        --target "$WORK/MISSING.md" \
        --if-absent error \
        "$WORK/retro.md"
    [ "$status" -eq 1 ]
}

@test "apply --parse-only handles CRLF retro file without breaking jq" {
    crlf_retro="${BATS_TMPDIR}/crlf-retro-$$.md"
    sed 's/$/\r/' "${BATS_TEST_DIRNAME}/../fixtures/sample_retro_with_candidates.md" > "$crlf_retro"
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" --parse-only "$crlf_retro"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e 'length == 2' >/dev/null
    echo "$output" | jq -e '.[0].rule | startswith("Always run")' >/dev/null
    rm -f "$crlf_retro"
}

@test "apply twice preserves original-state backup (backup-once)" {
    # First apply
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept --target "$WORK/CLAUDE.md" \
        --section "## Auto-curated Learnings" --if-absent skip \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    first_bak_hash=$(shasum "$WORK/CLAUDE.md.bak" | cut -d' ' -f1)

    # Second apply on the same target
    run "${BATS_TEST_DIRNAME}/../../scripts/apply_rules.sh" \
        --auto-accept --target "$WORK/CLAUDE.md" \
        --section "## Auto-curated Learnings" --if-absent skip \
        "$WORK/retro.md"
    [ "$status" -eq 0 ]
    second_bak_hash=$(shasum "$WORK/CLAUDE.md.bak" | cut -d' ' -f1)

    # Backup must still hash to the original pristine file
    [ "$first_bak_hash" = "$second_bak_hash" ]
    diff "$WORK/CLAUDE.md.bak" "${BATS_TEST_DIRNAME}/../fixtures/sample_claude_md.md"
}
