#!/usr/bin/env bats

setup() {
    MOCK_DIR="${BATS_TMPDIR}/gh-mock-$$"
    mkdir -p "$MOCK_DIR"
    cat > "$MOCK_DIR/gh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "list" ]]; then
    cat <<'JSON'
[{"number":1352,"title":"[OF-2744] cleanup","state":"MERGED","url":"https://github.com/o/r/pull/1352","createdAt":"2025-05-27T09:24:00Z","mergedAt":"2025-05-27T10:11:00Z","labels":[{"name":"test"}]}]
JSON
elif [[ "$1" == "issue" && "$2" == "list" ]]; then
    echo "[]"
else
    exit 1
fi
MOCK
    chmod +x "$MOCK_DIR/gh"
    export PATH="$MOCK_DIR:$PATH"
}

teardown() { rm -rf "$MOCK_DIR"; }

@test "gh.sh emits NDJSON" {
    run "${BATS_TEST_DIRNAME}/../../scripts/fetchers/pr/gh.sh" \
        --since 2025-05-27 --until 2025-05-28 --repos o/r
    [ "$status" -eq 0 ]
    echo "$output" | head -1 | jq -e '.type == "pr"'
    echo "$output" | head -1 | jq -e '.number == 1352'
}

@test "gh.sh exits 3 on missing --repos" {
    run "${BATS_TEST_DIRNAME}/../../scripts/fetchers/pr/gh.sh" --since 2025-05-27 --until 2025-05-28
    [ "$status" -eq 3 ]
}

@test "gh.sh exits 1 when gh absent" {
    PATH="/usr/bin:/bin" run "${BATS_TEST_DIRNAME}/../../scripts/fetchers/pr/gh.sh" \
        --since 2025-05-27 --until 2025-05-28 --repos o/r
    [ "$status" -eq 1 ]
}

@test "gh.sh warns on --limit 200 saturation" {
    MOCK_DIR="${BATS_TMPDIR}/gh-mock-sat-$$"
    mkdir -p "$MOCK_DIR"
    # Generate a 200-element JSON array via jq
    cat > "$MOCK_DIR/gh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "pr" && "$2" == "list" ]]; then
    jq -n '[range(200)] | map({number:(. + 1),title:"PR \(.)",state:"MERGED",url:"https://github.com/o/r/pull/\(.+1)",createdAt:"2025-05-27T00:00:00Z",mergedAt:"2025-05-27T01:00:00Z",closedAt:null,labels:[]})'
elif [[ "$1" == "issue" && "$2" == "list" ]]; then
    echo "[]"
else
    exit 1
fi
MOCK
    chmod +x "$MOCK_DIR/gh"
    PATH="$MOCK_DIR:$PATH" run "${BATS_TEST_DIRNAME}/../../scripts/fetchers/pr/gh.sh" \
        --since 2025-05-27 --until 2025-05-28 --repos o/r
    [ "$status" -eq 0 ]
    [[ "$output" == *"hit --limit 200 cap"* ]]
    rm -rf "$MOCK_DIR"
}
