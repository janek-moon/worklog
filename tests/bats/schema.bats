#!/usr/bin/env bats

setup() {
    cd "${BATS_TEST_DIRNAME}/../.." || exit 1
}

@test "config.example.json validates against config.schema.json" {
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/config.schema.json -d config.example.json
    [ "$status" -eq 0 ]
}

@test "sample frontmatter validates against frontmatter.schema.json" {
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/frontmatter.schema.json -d tests/fixtures/sample_frontmatter.json
    [ "$status" -eq 0 ]
}

@test "frontmatter missing required period fails" {
    cat > "${BATS_TMPDIR}/bad.json" <<'JSON'
{ "type": "daily" }
JSON
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/frontmatter.schema.json -d "${BATS_TMPDIR}/bad.json"
    [ "$status" -ne 0 ]
}

@test "frontmatter with unknown source status fails" {
    cat > "${BATS_TMPDIR}/bad_status.json" <<'JSON'
{
  "period": "2025-05-27",
  "type": "daily",
  "generated": "2025-05-28T10:30:00+09:00",
  "tz": "Asia/Seoul",
  "sources": { "git": { "status": "weird" } },
  "framework": "KPT",
  "language": "ko"
}
JSON
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/frontmatter.schema.json -d "${BATS_TMPDIR}/bad_status.json"
    [ "$status" -ne 0 ]
}

@test "config with learnings.apply.targets validates" {
    cat > "${BATS_TMPDIR}/cfg.json" <<'JSON'
{
  "learnings": {
    "extraction": { "enabled": true, "maxCandidates": 3 },
    "apply": {
      "targets": [
        { "path": "./CLAUDE.md", "section": "## L", "ifAbsent": "skip" }
      ],
      "requireApproval": true,
      "dryRun": false,
      "backupSuffix": ".bak"
    }
  }
}
JSON
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/config.schema.json -d "${BATS_TMPDIR}/cfg.json"
    [ "$status" -eq 0 ]
}

@test "config with invalid claudeCode.depth fails" {
    cat > "${BATS_TMPDIR}/bad_depth.json" <<'JSON'
{ "sources": { "claudeCode": { "depth": "bogus" } } }
JSON
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/config.schema.json -d "${BATS_TMPDIR}/bad_depth.json"
    [ "$status" -ne 0 ]
}

@test "config with invalid learnings.apply.targets[].ifAbsent fails" {
    cat > "${BATS_TMPDIR}/bad_ifabsent.json" <<'JSON'
{ "learnings": { "apply": { "targets": [ { "path": "./X.md", "ifAbsent": "nope" } ] } } }
JSON
    run npx --yes ajv-cli validate --spec=draft7 --allow-union-types -s schemas/config.schema.json -d "${BATS_TMPDIR}/bad_ifabsent.json"
    [ "$status" -ne 0 ]
}

@test "config.example.json has all SPEC top-level keys" {
    for key in output sources learnings framework language tz pii; do
        run jq -e "has(\"$key\")" config.example.json
        [ "$status" -eq 0 ]
        [ "$output" = "true" ]
    done
}
