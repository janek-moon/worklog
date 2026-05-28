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
