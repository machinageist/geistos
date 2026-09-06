#!/usr/bin/env bash
# Author: Jeff
# Date: 2026-09-05
# Description: End-to-end test of the one live cross-application path
# Notes: Both sides of this pipe were already covered by unit tests built from
#        hand-authored fixtures, which agree with each other by construction.
#        Nothing ran the real binaries into each other, and the shell script
#        that does it in production had no test at all. This closes both gaps
set -euo pipefail

# Opt in, like the per-application database suites, because this creates and
# drops real databases
if [[ "${GEIST_RUN_SUITE_TESTS:-}" != "1" ]]; then
    printf 'skipped: set GEIST_RUN_SUITE_TESTS=1 to run the suite pipe test\n'
    exit 0
fi

geistos="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
suite="${GEIST_ROOT:-${geistos}/mg-suite}"
sync_script="${GEIST_SYNC_SCRIPT:-${HOME}/dotfiles/scripts/geist-sync-todo-projection}"

# Defaults, not overrides: a caller must be able to point this at other builds,
# which is also how the test proves it can detect a broken pipe
export MG_REMINDR_BIN="${MG_REMINDR_BIN:-${suite}/mg-remindr/target/debug/mg-remindr}"
export MG_CALR_BIN="${MG_CALR_BIN:-${suite}/mg-calr/target/debug/mg-calr}"

# A database name no human would pick for real data, so cleanup is unambiguous
TEST_DB="mg_remindr_pipe_test"

failures=0
checks=0

# Compare one value against an expectation
check() {
    local label="$1" expected="$2" actual="$3"
    checks=$((checks + 1))
    if [[ "$expected" == "$actual" ]]; then
        printf '  ok    %s\n' "$label"
    else
        printf '  FAIL  %s\n        expected: %s\n        actual:   %s\n' \
            "$label" "$expected" "$actual"
        failures=$((failures + 1))
    fi
}

# Assert a command fails and names a reason
check_refuses() {
    local label="$1" needle="$2"
    shift 2
    checks=$((checks + 1))
    local output
    if output="$("$@" 2>&1)"; then
        printf '  FAIL  %s\n        expected refusal, got success: %s\n' "$label" "$output"
        failures=$((failures + 1))
    elif [[ "$output" != *"$needle"* ]]; then
        printf '  FAIL  %s\n        refused without naming %s: %s\n' "$label" "$needle" "$output"
        failures=$((failures + 1))
    else
        printf '  ok    %s\n' "$label"
    fi
}

for binary in "$MG_REMINDR_BIN" "$MG_CALR_BIN"; do
    [[ -x "$binary" ]] || { printf 'missing build artifact: %s\n' "$binary" >&2; exit 69; }
done
[[ -x "$sync_script" ]] || { printf 'missing sync script: %s\n' "$sync_script" >&2; exit 69; }

work="$(mktemp -d)"
started_cluster="no"
cleanup() {
    rm -rf -- "$work"
    [[ -n "${socket:-}" ]] && dropdb -h "$socket" --if-exists "$TEST_DB" >/dev/null 2>&1
    # Leave the cluster as this test found it
    [[ "$started_cluster" == "yes" ]] && "${geistos}/bin/geist-db" stop >/dev/null 2>&1
    return 0
}
trap cleanup EXIT

# Always the private cluster: this test creates and drops databases, and a
# system cluster's role may not hold CREATEDB — nor should a test assume it may
export GEIST_SYSTEM_PGSOCKET=/nonexistent-by-design
if ! "${geistos}/bin/geist-db" status >/dev/null 2>&1; then
    "${geistos}/bin/geist-db" start >/dev/null || {
        printf 'could not start the private cluster\n' >&2; exit 69; }
    started_cluster="yes"
fi
socket="$("${geistos}/bin/geist-db" socket)"

printf 'suite pipe test\n'

# Section: a real producer database

dropdb -h "$socket" --if-exists "$TEST_DB" >/dev/null 2>&1 || true
createdb -h "$socket" "$TEST_DB"
export MG_REMINDR_DATABASE_URL="postgresql:///${TEST_DB}?host=${socket}"
"$MG_REMINDR_BIN" migration apply >/dev/null

due="$(date -I)"
"$MG_REMINDR_BIN" add "pipe test reminder" --due "$due" --timezone UTC >/dev/null
check "producer holds one open reminder" "1" \
    "$("$MG_REMINDR_BIN" ls --json 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null || echo unknown)"

# Section: the production glue, running both real binaries

store="${work}/todo-projection.json"
MG_CALR_TODO_PROJECTION="$store" "$sync_script" >/dev/null

check "sync wrote a projection" "yes" "$([[ -s "$store" ]] && echo yes || echo no)"
check "projection names the real producer" "mg-remindr" \
    "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["producer"]["app"])' "$store")"
check "projection carries the reminder" "1" \
    "$(python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
titles = [r["payload"].get("title") for r in doc["records"] if r["payload"].get("title")]
print(sum(1 for t in titles if t == "pipe test reminder"))' "$store")"

# The digest must be stable across exports of unchanged data, which is the
# property the old test checked by grepping for Sha256::digest in the source
first="$("$MG_REMINDR_BIN" interop export | python3 -c 'import json,sys; print(json.load(sys.stdin)["source_revision"])')"
second="$("$MG_REMINDR_BIN" interop export | python3 -c 'import json,sys; print(json.load(sys.stdin)["source_revision"])')"
check "export identity is deterministic for unchanged data" "$first" "$second"

# And it must move when the data moves
"$MG_REMINDR_BIN" add "second reminder" --due "$due" --timezone UTC >/dev/null
third="$("$MG_REMINDR_BIN" interop export | python3 -c 'import json,sys; print(json.load(sys.stdin)["source_revision"])')"
check "export identity changes when the data does" "different" \
    "$([[ "$first" != "$third" ]] && echo different || echo same)"

# Section: the consumer refuses what it should

snapshot="${work}/snapshot.json"
"$MG_REMINDR_BIN" interop export > "$snapshot"

foreign="${work}/foreign.json"
python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
doc["producer"]["app"] = "not-mg-remindr"
json.dump(doc, open(sys.argv[2], "w"))' "$snapshot" "$foreign"
check_refuses "import refuses a foreign producer" "producer" \
    "$MG_CALR_BIN" --json --no-input interop import-todo --input "$foreign" --store "${work}/rejected.json"

truncated="${work}/truncated.json"
python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
doc["records"] = doc["records"][:1]
json.dump(doc, open(sys.argv[2], "w"))' "$snapshot" "$truncated"
check_refuses "import refuses a record count that disagrees with completeness" "" \
    "$MG_CALR_BIN" --json --no-input interop import-todo --input "$truncated" --store "${work}/rejected.json"

check "a refused import leaves no store behind" "no" \
    "$([[ -e "${work}/rejected.json" ]] && echo yes || echo no)"

printf '%d checks, %d failures\n' "$checks" "$failures"
[[ "$failures" -eq 0 ]]
