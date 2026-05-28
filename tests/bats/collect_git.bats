#!/usr/bin/env bats

setup() {
    export TZ=Asia/Seoul
    REPO="${BATS_TMPDIR}/test-repo-$$"
    mkdir -p "$REPO"
    cd "$REPO" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Tester"
    GIT_AUTHOR_DATE="2025-05-27T09:00:00+09:00" \
    GIT_COMMITTER_DATE="2025-05-27T09:00:00+09:00" \
        git commit -q --allow-empty -m "feat: first"
    echo "x" > a.txt
    git add a.txt
    GIT_AUTHOR_DATE="2025-05-27T15:00:00+09:00" \
    GIT_COMMITTER_DATE="2025-05-27T15:00:00+09:00" \
        git commit -q -m "feat: second commit"
}

teardown() { rm -rf "$REPO"; }

@test "collect_git.sh outputs NDJSON with required fields" {
    run "${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh" \
        --since 2025-05-27 --until 2025-05-28 --repos "$REPO"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    echo "$output" | head -1 | jq -e '.type == "commit"'
    echo "$output" | head -1 | jq -e '.sha | length == 40'
}

@test "collect_git.sh skips non-git dir" {
    NONGIT="${BATS_TMPDIR}/not-a-repo-$$"; mkdir -p "$NONGIT"
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh' --since 2025-05-27 --until 2025-05-28 --repos '$NONGIT' 2>/dev/null"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "$NONGIT"
}

@test "collect_git.sh exits 3 on missing --since" {
    run "${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh" --until 2025-05-28
    [ "$status" -eq 3 ]
}

@test "collect_git.sh defaults to cwd if no --repos" {
    cd "$REPO" || exit 1
    run "${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh" \
        --since 2025-05-27 --until 2025-05-28
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "collect_git.sh handles --allow-empty commit at newest end of window" {
    cd "$REPO" || exit 1
    GIT_AUTHOR_DATE="2025-05-27T18:00:00+09:00" \
    GIT_COMMITTER_DATE="2025-05-27T18:00:00+09:00" \
        git commit -q --allow-empty -m "chore: empty bump"
    run "${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh" \
        --since 2025-05-27 --until 2025-05-28 --repos "$REPO"
    [ "$status" -eq 0 ]
    # emits 2 commits in window (boundary commit at 00:00 UTC excluded by --since);
    # newest (the empty bump) must have files: []
    n=$(echo "$output" | wc -l | tr -d ' ')
    [ "$n" -eq 2 ]
    echo "$output" | head -1 | jq -e '.files == []'
}

@test "collect_git.sh exits 3 on missing --until" {
    run "${BATS_TEST_DIRNAME}/../../scripts/collect_git.sh" --since 2025-05-27
    [ "$status" -eq 3 ]
}
