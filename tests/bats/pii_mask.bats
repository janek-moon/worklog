#!/usr/bin/env bats

@test "masks AWS access key" {
    run "${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh" < "${BATS_TEST_DIRNAME}/../fixtures/secrets.txt"
    [ "$status" -eq 0 ]
    [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "masks email" {
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'reach: alice@example.com'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"alice@example.com"* ]]
}

@test "masks Korean RRN" {
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< '901231-1234567'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"901231-1234567"* ]]
}

@test "whitelists email via env" {
    run bash -c "WORKLOG_PII_ALLOW='alice@example.com' '${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'alice@example.com'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"alice@example.com"* ]]
}

@test "reports masked count to stderr" {
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' < '${BATS_TEST_DIRNAME}/../fixtures/secrets.txt' 2>&1 1>/dev/null"
    [[ "$output" == *"masked"* ]]
}

@test "mixed allowed email + AWS key on same line — only email kept" {
    run bash -c "WORKLOG_PII_ALLOW='alice@example.com' '${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'alice@example.com AKIAIOSFODNN7EXAMPLE'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"alice@example.com"* ]]
    [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "custom regex containing | is interpreted literally by awk" {
    run bash -c "WORKLOG_PII_CUSTOM='trace-[a-z]+|debug-[a-z]+' '${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'trace-foo and debug-bar'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"trace-foo"* ]]
    [[ "$output" != *"debug-bar"* ]]
}

@test "Bearer and gh_ tokens masked" {
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'Bearer ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"ghp_"* ]]
}

@test "phone regex does not false-positive on build/PR IDs" {
    # "123-4567-8901" — not a KR phone (no 01x or 0[2-6] prefix)
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'Build 123-4567-8901 done'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"123-4567-8901"* ]]
}

@test "exact masked count reported" {
    run bash -c "'${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'AKIAIOSFODNN7EXAMPLE alice@example.com' 2>&1 1>/dev/null"
    [[ "$output" == *"masked: 2"* ]]
}

@test "zero-width custom regex does not hang" {
    run timeout 3 bash -c "WORKLOG_PII_CUSTOM='x*' '${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'aaa'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaa"* ]]
}

@test "anchor-only custom regex does not hang" {
    run timeout 3 bash -c "WORKLOG_PII_CUSTOM='^' '${BATS_TEST_DIRNAME}/../../scripts/pii_mask.sh' <<< 'word'"
    [ "$status" -eq 0 ]
}
