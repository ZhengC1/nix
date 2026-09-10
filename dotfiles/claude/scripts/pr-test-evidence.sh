#!/usr/bin/env bash
# Test-evidence recorder for the /review-my-open-prs routine.
#
# Turns "the tests passed" into a durable artifact that a later step -- or an
# independent verifier -- can re-read. Pass counts quoted in a pull-request
# reply come from `summary`, never from an agent's recollection of scrollback.
#
#   pr-test-evidence.sh run <label> [--filter <vstest-expr>] [--no-build]
#       Build and test in Release per STANDARDS.md, then record logs, a trx,
#       exit codes, the four test counts, and exactly which tree was tested.
#
#   pr-test-evidence.sh summary <label>      one reply-ready evidence line
#   pr-test-evidence.sh show <label>         the full evidence JSON
#   pr-test-evidence.sh check <label>        the working tree is still what was tested
#   pr-test-evidence.sh bind <label> <sha>   the tested tree IS that commit, clean
#
#   pr-test-evidence.sh regression-check <base-sha> --filter <expr>
#       Run the named test against the code BEFORE the fix and require it to
#       fail or not exist. Proves the test is not tautological. Expensive
#       (a second Release build) -- reserve it for [P0]/[P1] findings.
#
# Exit 0 = pass, 1 = the run or the check failed, 2 = could not run.
# Artifacts land in $PR_EVIDENCE_DIR (default: $TMPDIR/pr-triage-evidence).
#
# `pr-test-evidence.sh help` prints this header.

set -euo pipefail

EVID_DIR="${PR_EVIDENCE_DIR:-${TMPDIR:-/tmp}/pr-triage-evidence}"

# The usage text is the header comment block, so the two cannot drift.
usage() { sed -n '2,/^$/p' "$0" | sed -e 's/^# \{0,1\}//'; }

die()  { echo "pr-test-evidence.sh: $*" >&2; exit 2; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# STANDARDS.md -> Definition of Done: the canonical .NET verification commands
# are Release-configured and target the test project explicitly.
SOLUTION="UTIE.GenAI.sln"
TEST_PROJECT="UTIE.GenAI.Tests/UTIE.GenAI.Tests.csproj"

app_dir() {
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
    [[ -d $top/app ]] || die "no app/ directory under $top"
    printf '%s\n' "$top/app"
}

# Identifies the exact code under test: the commit plus a digest of everything
# not yet committed. Any later edit changes the digest, so evidence cannot be
# silently carried over to a different tree.
tree_state() { # -> head<TAB>branch<TAB>dirtyDigest<TAB>clean
    local head branch digest porcelain
    head=$(git rev-parse HEAD)
    branch=$(git rev-parse --abbrev-ref HEAD)
    porcelain=$(git status --porcelain)
    digest=$( { printf '%s\n' "$porcelain"; git diff HEAD; } | shasum -a 256 | cut -d' ' -f1)
    printf '%s\t%s\t%s\t%s\n' "$head" "$branch" "$digest" \
        "$([[ -z $porcelain ]] && echo clean || echo dirty)"
}

evid_file() { printf '%s/%s.json' "$EVID_DIR" "$1"; }

require_evidence() {
    local f; f=$(evid_file "$1")
    [[ -f $f ]] || die "no evidence recorded under label '$1' (looked in $EVID_DIR)"
    printf '%s\n' "$f"
}

cmd_run() {
    local label=${1:?label required}; shift
    local filter="" build=1
    while [[ $# -gt 0 ]]; do
        case $1 in
            --filter) filter=${2:?filter expression required}; shift 2 ;;
            --no-build) build=0; shift ;;
            *) die "unknown option: $1" ;;
        esac
    done

    local app; app=$(app_dir)
    mkdir -p "$EVID_DIR"

    local head branch digest clean
    IFS=$'\t' read -r head branch digest clean <<<"$(tree_state)"

    local build_log="$EVID_DIR/$label.build.log"
    local test_log="$EVID_DIR/$label.test.log"
    local build_rc=0 test_rc=0

    if (( build )); then
        echo "building Release (log: $build_log)"
        # --no-incremental so warning counts reflect a real compile, not an
        # up-to-date no-op. Redirect rather than pipe: a pipe would hand back
        # tee's exit code instead of dotnet's.
        ( cd "$app" && dotnet build "$SOLUTION" --configuration Release --no-incremental --nologo ) \
            > "$build_log" 2>&1 || build_rc=$?
    else
        echo "(build skipped)" > "$build_log"
    fi

    local trx="$label.trx"
    if (( build_rc == 0 )); then
        echo "testing Release${filter:+ (filter: $filter)} (log: $test_log)"
        if [[ -n $filter ]]; then
            ( cd "$app" && dotnet test "$TEST_PROJECT" --configuration Release --nologo \
                --filter "$filter" --logger "trx;LogFileName=$trx" \
                --results-directory "$EVID_DIR" ) > "$test_log" 2>&1 || test_rc=$?
        else
            ( cd "$app" && dotnet test "$TEST_PROJECT" --configuration Release --nologo \
                --logger "trx;LogFileName=$trx" \
                --results-directory "$EVID_DIR" ) > "$test_log" 2>&1 || test_rc=$?
        fi
    else
        echo "(tests not run: build failed)" > "$test_log"
        test_rc=-1
    fi

    python3 - "$label" "$(evid_file "$label")" "$build_log" "$test_log" \
        "$build_rc" "$test_rc" "$head" "$branch" "$digest" "$clean" "$filter" "$EVID_DIR/$trx" <<'PY'
import json, os, re, sys

(label, out, build_log, test_log, build_rc, test_rc,
 head, branch, digest, clean, filt, trx) = sys.argv[1:13]

def tail(path, n=40):
    try:
        with open(path, errors="replace") as f:
            return f.read().splitlines()[-n:]
    except OSError:
        return []

test_lines = tail(test_log, 400)

# Verified VSTest summary shape, always the last such line:
#   Passed!  - Failed:     0, Passed:  3108, Skipped:   366, Total:  3474, Duration: 15 s
counts, verdict, summary_line = None, None, None
pat = re.compile(r"^(Passed|Failed)!\s+-\s+Failed:\s*(\d+),\s*Passed:\s*(\d+),"
                 r"\s*Skipped:\s*(\d+),\s*Total:\s*(\d+)")
for line in test_lines:
    m = pat.match(line.strip())
    if m:
        verdict = m.group(1)
        counts = dict(zip(("failed", "passed", "skipped", "total"),
                          (int(m.group(i)) for i in range(2, 6))))
        summary_line = line.strip()

warnings = errors = None
for line in tail(build_log, 60):
    w = re.match(r"^\s*(\d+) Warning\(s\)", line)
    e = re.match(r"^\s*(\d+) Error\(s\)", line)
    if w: warnings = int(w.group(1))
    if e: errors = int(e.group(1))

ev = {
    "label": label,
    "testedCommit": head,
    "testedBranch": branch,
    "treeDigest": digest,
    "treeClean": clean == "clean",
    "filter": filt or None,
    "buildExitCode": int(build_rc),
    "testExitCode": int(test_rc),
    "buildWarnings": warnings,
    "buildErrors": errors,
    "verdict": verdict,
    "counts": counts,
    "summaryLine": summary_line,
    "buildLog": build_log,
    "testLog": test_log,
    "trx": trx if os.path.exists(trx) else None,
}
with open(out, "w") as f:
    json.dump(ev, f, indent=2)

problems = []
if int(build_rc) != 0:
    problems.append("build exited %s" % build_rc)
if int(test_rc) != 0:
    problems.append("test exited %s" % test_rc)
if counts is None:
    problems.append("no parseable test summary line in %s" % test_log)
elif counts["failed"] or verdict != "Passed":
    problems.append("%s: %s failed" % (verdict, counts["failed"]))

print(json.dumps(ev, indent=2))
if problems:
    print("\nFAIL: " + "; ".join(problems), file=sys.stderr)
    sys.exit(1)
print("\nrecorded: %s" % out)
PY
}

# The reply-ready line. STANDARDS.md's example omits skips; this repo skips
# hundreds of tests, so the skipped count is stated rather than hidden.
cmd_summary() {
    local f; f=$(require_evidence "${1:?label required}")
    python3 -c '
import json, sys
ev = json.load(open(sys.argv[1]))
c = ev.get("counts")
if not c:
    print("no parseable counts in evidence %s" % ev["label"], file=sys.stderr)
    sys.exit(1)
scope = "focused suite (%s)" % ev["filter"] if ev.get("filter") else "full Release suite"
tail = ", %d skipped" % c["skipped"] if c["skipped"] else ""
print("%s: %d/%d passed%s (Release, commit %s)"
      % (scope, c["passed"], c["total"], tail, ev["testedCommit"][:8]))' "$f"
}

cmd_show() { cat "$(require_evidence "${1:?label required}")"; }

# Proves the evidence still describes the code in front of you: an edit made
# after the run changes the digest and invalidates the numbers.
cmd_check() {
    local label=${1:?label required}
    local f; f=$(require_evidence "$label")
    local head branch digest clean
    IFS=$'\t' read -r head branch digest clean <<<"$(tree_state)"
    python3 -c '
import json, sys
ev = json.load(open(sys.argv[1]))
head, digest = sys.argv[2], sys.argv[3]
bad = []
if ev["testedCommit"] != head:
    bad.append("tested commit %s, tree is now at %s" % (ev["testedCommit"][:8], head[:8]))
if ev["treeDigest"] != digest:
    bad.append("working tree changed since the run")
if bad:
    print("FAIL: evidence %s is stale -- %s" % (ev["label"], "; ".join(bad)), file=sys.stderr)
    sys.exit(1)
print("ok: evidence %s still describes the current tree (%s)" % (ev["label"], head[:8]))' \
        "$f" "$head" "$digest"
}

# The linchpin: the tests ran against a clean tree AT the commit that was
# pushed. Without this the counts could describe any tree at all.
cmd_bind() {
    local label=${1:?label required} sha=${2:?commit sha required}
    local f; f=$(require_evidence "$label")
    local full
    full=$(git rev-parse "$sha^{commit}" 2>/dev/null) || fail "unknown commit: $sha"
    python3 -c '
import json, sys
ev = json.load(open(sys.argv[1]))
sha = sys.argv[2]
bad = []
if not ev.get("treeClean"):
    bad.append("the tested tree had uncommitted changes")
if ev["testedCommit"] != sha:
    bad.append("evidence is for commit %s, not %s" % (ev["testedCommit"][:8], sha[:8]))
if bad:
    print("FAIL: evidence %s does not describe %s -- %s"
          % (ev["label"], sha[:8], "; ".join(bad)), file=sys.stderr)
    sys.exit(1)
print("ok: evidence %s was recorded against clean commit %s" % (ev["label"], sha[:8]))' \
        "$f" "$full"
}

# The anti-tautology check: run the same filter against the code BEFORE the fix
# and require it NOT to pass. A test that passes with and without the change
# proves nothing, and this is the only way to tell the difference. Uses a
# detached worktree so the current tree is never touched.
cmd_regression_check() {
    local base=${1:?base commit required}; shift
    local filter=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --filter) filter=${2:?filter expression required}; shift 2 ;;
            *) die "unknown option: $1" ;;
        esac
    done
    [[ -n $filter ]] || die "--filter is required: name the test that is supposed to prove the fix"

    local base_sha top wt
    base_sha=$(git rev-parse "$base^{commit}" 2>/dev/null) || die "unknown commit: $base"
    top=$(git rev-parse --show-toplevel) || die "not inside a git repository"
    mkdir -p "$EVID_DIR"
    wt="$EVID_DIR/regression-worktree"

    cleanup() { git -C "$top" worktree remove --force "$wt" >/dev/null 2>&1 || true; }
    trap cleanup EXIT
    cleanup
    git -C "$top" worktree add --detach --quiet "$wt" "$base_sha" \
        || die "could not create a worktree at $base_sha"

    local log="$EVID_DIR/regression.log" rc=0
    echo "running '$filter' against pre-fix code ${base_sha:0:8} (log: $log)"
    ( cd "$wt/app" && dotnet test "$TEST_PROJECT" --configuration Release --nologo \
        --filter "$filter" ) > "$log" 2>&1 || rc=$?

    if (( rc == 0 )); then
        # It passed without the fix, so it does not test the fix.
        grep -E '^(Passed|Failed)!' "$log" | tail -1 >&2 || true
        fail "'$filter' PASSES against pre-fix code ${base_sha:0:8} -- the test does not exercise the fix"
    fi

    local why="failed"
    grep -qiE 'No test (is available|matches the given testcase filter)' "$log" && why="did not exist"
    echo "ok: '$filter' $why against pre-fix code ${base_sha:0:8} -- the test is sensitive to the change"
    grep -E '^(Passed|Failed)!|No test' "$log" | tail -1 || true
}

case ${1:-} in
    run)     shift; cmd_run "$@" ;;
    regression-check) shift; cmd_regression_check "$@" ;;
    summary) shift; cmd_summary "$@" ;;
    show)    shift; cmd_show "$@" ;;
    check)   shift; cmd_check "$@" ;;
    bind)    shift; cmd_bind "$@" ;;
    help|-h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
