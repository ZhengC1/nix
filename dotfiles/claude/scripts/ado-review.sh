#!/usr/bin/env bash
# Azure DevOps helper for the /review-open-prs routine -- reviewing OTHER people's PRs.
#
# Companion to ado-pr.sh, which handles PRs I authored. This one only ever posts
# findings, never fixes; it has no push, no resolve-my-own-thread, no worktree.
#
# Read subcommands are safe to run freely:
#   ado-review.sh review-prs [--include-drafts]  active PRs where I am a reviewer
#   ado-review.sh about <pr>               author, description, reviewers + votes, iterations
#   ado-review.sh iterations <pr>          iteration list with source commit ids
#   ado-review.sh files <pr> [iteration]   paths changed, per the server
#   ado-review.sh my-threads <pr> [--all]  threads I opened; --all includes resolved
#   ado-review.sh needs-me <pr>            my threads where someone else spoke last
#   ado-review.sh whoami                   the identity `az` is authenticated as
#
# Write subcommands (gated by the routine and by env, see below):
#   ado-review.sh comment <pr> <file> [--path <p> --line <n> [--end-line <n>]]
#                                          [--iteration <n>] [--status <s>]
#                                          open a new thread; refuses a duplicate body
#   ado-review.sh vote <pr> <approve|approve-with-suggestions|wait-for-author|reject|reset>
#
# Verification subcommands. Exit 0 = check PASSED, 1 = check FAILED (the claim is
# false), 2 = the check could not be run. Callers must treat 2 as a failure:
#   ado-review.sh posted <pr> <threadId>         the thread exists and its root is mine
#   ado-review.sh anchored <pr> <threadId> <path>[:<line>]   it points where I claim
#   ado-review.sh line-in-diff <pr> <path> <line>  that line is actually in the PR diff
#   ado-review.sh vote-status <pr> [expected]    read my vote back
#   ado-review.sh review-audit <pr> [--json]     every thread I opened + a verdict
#
# Override the target with ADO_ORG / ADO_PROJECT / ADO_REPO if needed.
# ADO_REVIEW_DRY_RUN=1     comment/vote print what they would send and write nothing.
# ADO_REVIEW_ALLOW_VOTE=1  required by `vote` at all; a vote speaks in my name.
# ADO_REVIEW_ALLOW_REJECT=1  additionally required for `reject`.
#
# `ado-review.sh help` prints this header.

set -euo pipefail

ORG="${ADO_ORG:-unitherdevops}"
PROJECT="${ADO_PROJECT:-UTIE-2.0}"
REPO="${ADO_REPO:-UTIE-2.0}"

ADO_RESOURCE=499b84ac-1321-427f-aa17-267ca6975798
BASE="https://dev.azure.com/${ORG}/${PROJECT}/_apis/git/repositories/${REPO}"
API="api-version=7.1"

# The usage text is the header comment block, so the two cannot drift.
usage() { sed -n '2,/^$/p' "$0" | sed -e 's/^# \{0,1\}//'; }

die()  { echo "ado-review.sh: $*" >&2; exit 2; }
fail() { echo "FAIL: $*" >&2; exit 1; }

req() { # req METHOD URL [BODY]
    local method=$1 url=$2 body=${3:-}
    if [[ -n $body ]]; then
        az rest --resource "$ADO_RESOURCE" --method "$method" --url "$url" \
            --headers "Content-Type=application/json" --body "$body" -o json
    else
        az rest --resource "$ADO_RESOURCE" --method "$method" --url "$url" -o json
    fi
}

whoami_id() {
    req GET "https://dev.azure.com/${ORG}/_apis/connectionData?api-version=7.1-preview" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["authenticatedUser"]["id"])'
}

cmd_whoami() {
    req GET "https://dev.azure.com/${ORG}/_apis/connectionData?api-version=7.1-preview" \
        | python3 -c '
import sys, json
u = json.load(sys.stdin)["authenticatedUser"]
print(json.dumps({"id": u["id"], "displayName": u.get("providerDisplayName")}, indent=2))'
}

VOTE_NAMES='{10: "approved", 5: "approved-with-suggestions", 0: "no-vote", -5: "waiting-for-author", -10: "rejected"}'

# PRs where I am on the reviewer list. A PR I created is dropped even if I am
# also listed as a reviewer -- that one belongs to /review-my-open-prs, not here.
cmd_review_prs() {
    local include_drafts=0
    [[ ${1:-} == --include-drafts ]] && include_drafts=1
    local me; me=$(whoami_id)
    req GET "${BASE}/pullRequests?searchCriteria.reviewerId=${me}&searchCriteria.status=active&\$top=100&${API}" \
        | python3 -c '
import sys, json
me, include_drafts = sys.argv[1], sys.argv[2] == "1"
VOTES = '"$VOTE_NAMES"'
out = []
for p in json.load(sys.stdin)["value"]:
    if p["createdBy"]["id"] == me:
        continue
    if p.get("isDraft") and not include_drafts:
        continue
    mine = next((r for r in p.get("reviewers", []) if r["id"] == me), None)
    out.append({
        "id": p["pullRequestId"],
        "title": p["title"],
        "author": p["createdBy"]["displayName"],
        "isDraft": p.get("isDraft", False),
        "sourceBranch": p["sourceRefName"].removeprefix("refs/heads/"),
        "targetBranch": p["targetRefName"].removeprefix("refs/heads/"),
        "myVote": VOTES.get((mine or {}).get("vote", 0), "unknown"),
        "isRequired": bool((mine or {}).get("isRequired", False)),
    })
print(json.dumps(out, indent=2))' "$me" "$include_drafts"
}

cmd_about() {
    local pr=${1:?pr id required} me; me=$(whoami_id)
    local iters
    iters=$(req GET "${BASE}/pullRequests/${pr}/iterations?${API}" \
        | python3 -c 'import sys,json; print(len(json.load(sys.stdin)["value"]))')
    req GET "${BASE}/pullRequests/${pr}?${API}" | python3 -c '
import sys, json
me, iters = sys.argv[1], int(sys.argv[2])
VOTES = '"$VOTE_NAMES"'
p = json.load(sys.stdin)
mine = next((r for r in p.get("reviewers", []) if r["id"] == me), None)
print(json.dumps({
    "id": p["pullRequestId"],
    "title": p["title"],
    "author": p["createdBy"]["displayName"],
    "authorIsMe": p["createdBy"]["id"] == me,
    "status": p["status"],
    "isDraft": p.get("isDraft", False),
    "sourceBranch": p["sourceRefName"].removeprefix("refs/heads/"),
    "targetBranch": p["targetRefName"].removeprefix("refs/heads/"),
    "mergeStatus": p.get("mergeStatus"),
    "lastMergeSourceCommit": (p.get("lastMergeSourceCommit") or {}).get("commitId"),
    "iterations": iters,
    "iAmReviewer": mine is not None,
    "myVote": VOTES.get((mine or {}).get("vote", 0), "unknown"),
    "reviewers": [{"name": r["displayName"], "vote": VOTES.get(r.get("vote", 0), "unknown"),
                   "required": bool(r.get("isRequired", False))} for r in p.get("reviewers", [])],
    "description": p.get("description") or "",
}, indent=2))' "$me" "$iters"
}

cmd_iterations() {
    local pr=${1:?pr id required}
    req GET "${BASE}/pullRequests/${pr}/iterations?${API}" | python3 -c '
import sys, json
print(json.dumps([{
    "iteration": it["id"],
    "createdDate": it.get("createdDate"),
    "sourceCommit": (it.get("sourceRefCommit") or {}).get("commitId"),
    "targetCommit": (it.get("targetRefCommit") or {}).get("commitId"),
    "commonRefCommit": (it.get("commonRefCommit") or {}).get("commitId"),
} for it in json.load(sys.stdin)["value"]], indent=2))'
}

cmd_files() {
    local pr=${1:?pr id required} it=${2:-}
    if [[ -z $it ]]; then
        it=$(req GET "${BASE}/pullRequests/${pr}/iterations?${API}" \
            | python3 -c 'import sys,json; v=json.load(sys.stdin)["value"]; print(v[-1]["id"] if v else "")')
        [[ -n $it ]] || die "PR $pr has no iterations"
    fi
    req GET "${BASE}/pullRequests/${pr}/iterations/${it}/changes?${API}" | python3 -c '
import sys, json
out = []
for c in json.load(sys.stdin).get("changeEntries", []):
    item = c.get("item") or {}
    if item.get("isFolder"):
        continue
    out.append({"path": item.get("path"), "changeType": c.get("changeType")})
print(json.dumps({"iteration": int(sys.argv[1]), "files": out}, indent=2))' "$it"
}

# Threads whose ROOT comment is mine -- the findings I raised, not the ones I
# happened to reply to.
cmd_my_threads() {
    local pr=${1:?pr id required} scope=${2:-unresolved}
    local all=0
    [[ $scope == --all || $scope == all ]] && all=1
    local me; me=$(whoami_id)
    req GET "${BASE}/pullRequests/${pr}/threads?${API}" | python3 -c '
import sys, json
me, show_all = sys.argv[1], sys.argv[2] == "1"
out = []
for t in json.load(sys.stdin)["value"]:
    if t.get("isDeleted"):
        continue
    comments = [c for c in t.get("comments", [])
                if c.get("commentType") != "system" and not c.get("isDeleted")]
    if not comments or comments[0]["author"]["id"] != me:
        continue
    if not show_all and t.get("status") not in ("active", "pending"):
        continue
    ctx = t.get("threadContext") or {}
    out.append({
        "threadId": t["id"],
        "status": t["status"],
        "file": ctx.get("filePath"),
        "line": (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line"),
        "replies": len(comments) - 1,
        "lastAuthor": comments[-1]["author"]["displayName"],
        "lastIsMe": comments[-1]["author"]["id"] == me,
        "comments": [{"id": c["id"], "author": c["author"]["displayName"],
                      "published": c.get("publishedDate"), "content": c.get("content", "")}
                     for c in comments],
    })
print(json.dumps(out, indent=2))' "$me" "$all"
}

# My open findings where the author (or anyone else) has spoken last: my turn.
cmd_needs_me() {
    local pr=${1:?pr id required}
    cmd_my_threads "$pr" | python3 -c '
import sys, json
rows = [t for t in json.load(sys.stdin) if not t["lastIsMe"]]
print(json.dumps(rows, indent=2))
sys.exit(1 if rows else 0)'
}

# Finding text comes from a file so Markdown, quotes, and newlines survive.
cmd_comment() {
    local pr=${1:?pr id required} file=${2:?finding file required}
    shift 2
    local path="" line="" endline="" iteration="" status="active"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --path)      path=${2:?--path needs a value}; shift 2 ;;
            --line)      line=${2:?--line needs a value}; shift 2 ;;
            --end-line)  endline=${2:?--end-line needs a value}; shift 2 ;;
            --iteration) iteration=${2:?--iteration needs a value}; shift 2 ;;
            --status)    status=${2:?--status needs a value}; shift 2 ;;
            *) die "unknown option '$1'" ;;
        esac
    done
    [[ -f $file ]] || die "finding file not found: $file"
    [[ -s $file ]] || die "finding file is empty: $file"
    case $status in active|pending|closed) ;; *) die "invalid status '$status' (active|pending|closed)" ;; esac
    [[ -n $line && -z $path ]] && die "--line needs --path"
    [[ -n $path && $path != /* ]] && path="/$path"

    # A finding that names no file is a PR-level thread; that is allowed, but a
    # line number that is not in the PR's own diff points the author at code
    # they did not write, so prove the anchor before posting.
    if [[ -n $path && -n $line ]]; then
        local why
        # A subshell, because line-in-diff exits rather than returns on a failed
        # check; without it the exit would escape this refusal entirely.
        why=$( ( cmd_line_in_diff "$pr" "$path" "$line" ) 2>&1 >/dev/null ) \
            || die "refusing to post at $path:$line -- ${why:-the anchor could not be proven}"
    fi

    if [[ ${ADO_REVIEW_DRY_RUN:-} == 1 ]]; then
        echo "DRY RUN: would open a thread on PR $pr at ${path:-(PR-level)}${line:+:$line} (status $status):"
        sed -e 's/^/  | /' "$file"
        return 0
    fi

    # Re-run safety: an identical body already posted by me is refused rather
    # than duplicated, whatever it is anchored to.
    local dup
    dup=$(req GET "${BASE}/pullRequests/${pr}/threads?${API}" | python3 -c '
import sys, json, re
def norm(x): return re.sub(r"\s+", " ", x or "").strip()
me, body = sys.argv[1], norm(open(sys.argv[2], encoding="utf-8").read())
for t in json.load(sys.stdin)["value"]:
    if t.get("isDeleted"):
        continue
    for c in t.get("comments", []):
        if c.get("isDeleted") or c.get("commentType") == "system":
            continue
        if c["author"]["id"] == me and norm(c.get("content")) == body:
            print("%s" % t["id"])
            raise SystemExit(0)
print("")' "$(whoami_id)" "$file")
    [[ -z $dup ]] || die "this exact finding is already thread $dup on PR $pr; nothing posted"

    local body
    body=$(python3 -c '
import json, sys
content, status, path, line, endline, iteration = sys.argv[1:7]
t = {"comments": [{"parentCommentId": 0, "commentType": 1,
                   "content": open(content, encoding="utf-8").read()}],
     "status": status}
if path:
    ctx = {"filePath": path}
    if line:
        ln, end = int(line), int(endline or line)
        ctx["rightFileStart"] = {"line": ln, "offset": 1}
        ctx["rightFileEnd"] = {"line": end, "offset": 1}
    t["threadContext"] = ctx
if iteration:
    n = int(iteration)
    t["pullRequestThreadContext"] = {"iterationContext":
        {"firstComparingIteration": n, "secondComparingIteration": n}}
print(json.dumps(t))' "$file" "$status" "$path" "$line" "$endline" "$iteration")

    local created me
    created=$(req POST "${BASE}/pullRequests/${pr}/threads?${API}" "$body" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    [[ -n $created ]] || fail "thread POST returned no id on PR $pr"

    # A 200 from POST is not proof the thread is on the PR. Read it back.
    me=$(whoami_id)
    req GET "${BASE}/pullRequests/${pr}/threads/${created}?${API}" | python3 -c '
import sys, json
me = sys.argv[1]
t = json.load(sys.stdin)
comments = [c for c in t.get("comments", [])
            if c.get("commentType") != "system" and not c.get("isDeleted")]
if not comments:
    print("FAIL: thread %s has no comment after POST" % t["id"], file=sys.stderr); sys.exit(1)
if comments[0]["author"]["id"] != me:
    print("FAIL: thread %s root comment is not yours" % t["id"], file=sys.stderr); sys.exit(1)
ctx = t.get("threadContext") or {}
loc = ctx.get("filePath") or "(PR-level)"
ln = (ctx.get("rightFileStart") or {}).get("line")
print("posted: thread %s at %s%s status %s (confirmed on readback)"
      % (t["id"], loc, ":%s" % ln if ln else "", t.get("status")))' "$me"
}

# A vote speaks in my name to the whole team, so it is doubly gated and never
# implied by having posted findings.
cmd_vote() {
    local pr=${1:?pr id required} want=${2:?vote required}
    local n
    case $want in
        approve)                  n=10 ;;
        approve-with-suggestions) n=5 ;;
        reset|no-vote)            n=0 ;;
        wait-for-author)          n=-5 ;;
        reject)                   n=-10 ;;
        *) die "invalid vote '$want' (approve|approve-with-suggestions|wait-for-author|reject|reset)" ;;
    esac
    [[ ${ADO_REVIEW_ALLOW_VOTE:-} == 1 ]] || die \
        "voting speaks in your name -- set ADO_REVIEW_ALLOW_VOTE=1 only after the user approves this specific vote"
    if [[ $want == reject ]]; then
        [[ ${ADO_REVIEW_ALLOW_REJECT:-} == 1 ]] || die \
            "'reject' additionally requires ADO_REVIEW_ALLOW_REJECT=1"
    fi

    if [[ ${ADO_REVIEW_DRY_RUN:-} == 1 ]]; then
        echo "DRY RUN: would set my vote on PR $pr to '$want' ($n)"
        return 0
    fi

    local me; me=$(whoami_id)
    req PUT "${BASE}/pullRequests/${pr}/reviewers/${me}?${API}" "{\"vote\":${n}}" >/dev/null
    cmd_vote_status "$pr" "$want"
}

# ---------------------------------------------------------------------------
# Verification. Exit 0 = passed, 1 = the claim is false, 2 = could not check.

cmd_posted() {
    local pr=${1:?pr id required} tid=${2:?thread id required} me; me=$(whoami_id)
    req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json
me = sys.argv[1]
t = json.load(sys.stdin)
if t.get("isDeleted"):
    print("FAIL: thread %s is deleted" % t["id"], file=sys.stderr); sys.exit(1)
comments = [c for c in t.get("comments", [])
            if c.get("commentType") != "system" and not c.get("isDeleted")]
if not comments:
    print("FAIL: thread %s has no live comment" % t["id"], file=sys.stderr); sys.exit(1)
if comments[0]["author"]["id"] != me:
    print("FAIL: thread %s root comment is %s'"'"'s, not yours"
          % (t["id"], comments[0]["author"]["displayName"]), file=sys.stderr); sys.exit(1)
print("thread %s is yours, status %s, %d comment(s)" % (t["id"], t.get("status"), len(comments)))' "$me"
}

cmd_anchored() {
    local pr=${1:?pr id required} tid=${2:?thread id required} want=${3:?path[:line] required}
    req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json
want = sys.argv[1]
wpath, _, wline = want.partition(":")
if not wpath.startswith("/"):
    wpath = "/" + wpath
t = json.load(sys.stdin)
ctx = t.get("threadContext") or {}
path = ctx.get("filePath")
line = (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line")
if path != wpath:
    print("FAIL: thread %s anchors on %s, not %s" % (t["id"], path, wpath), file=sys.stderr)
    sys.exit(1)
if wline and str(line) != wline:
    print("FAIL: thread %s anchors on line %s, not %s" % (t["id"], line, wline), file=sys.stderr)
    sys.exit(1)
print("thread %s anchors on %s%s" % (t["id"], path, ":%s" % line if line else ""))' "$want"
}

# The single most common way a review comment is wrong: it points at a line the
# PR never touched. Ask the server which lines this PR added or changed.
cmd_line_in_diff() {
    local pr=${1:?pr id required} path=${2:?path required} line=${3:?line required}
    [[ $path != /* ]] && path="/$path"
    local it commits base head
    IFS=$'\t' read -r base head <<<"$(
        req GET "${BASE}/pullRequests/${pr}/iterations?${API}" | python3 -c '
import sys, json
v = json.load(sys.stdin)["value"]
if not v:
    raise SystemExit(2)
it = v[-1]
print("%s\t%s" % ((it.get("commonRefCommit") or {}).get("commitId"),
                  (it.get("sourceRefCommit") or {}).get("commitId")))')" || die "cannot read iterations for PR $pr"
    [[ -n $base && -n $head ]] || die "PR $pr iteration has no commit ids"

    # Server-side diff of the file, so this works without a local checkout.
    local url="https://dev.azure.com/${ORG}/${PROJECT}/_apis/git/repositories/${REPO}"
    local blobs
    blobs=$(req GET "${url}/diffs/commits?baseVersion=${base}&baseVersionType=commit&targetVersion=${head}&targetVersionType=commit&\$top=2000&${API}" \
        | python3 -c '
import sys, json
path = sys.argv[1]
for c in json.load(sys.stdin).get("changes", []):
    item = c.get("item") or {}
    if item.get("path") == path:
        print(c.get("changeType", ""))
        raise SystemExit(0)
print("")' "$path")
    if [[ -z $blobs ]]; then
        echo "FAIL: PR $pr does not change $path" >&2; exit 1
    fi
    if [[ $blobs == *delete* ]]; then
        echo "FAIL: $path is deleted by PR $pr; there is no right-side line $line" >&2; exit 1
    fi
    # The right-side file must at least be long enough to contain the line.
    # The items endpoint hands back the raw file, not JSON, so count the lines
    # off the byte stream rather than parsing a response envelope.
    local len
    len=$(az rest --resource "$ADO_RESOURCE" --method GET \
            --url "${url}/items?path=${path}&versionDescriptor.version=${head}&versionDescriptor.versionType=commit&includeContent=true&${API}" \
            -o tsv 2>/dev/null \
        | python3 -c 'import sys; print(len(sys.stdin.buffer.read().splitlines()))' 2>/dev/null) \
        || die "cannot read $path at $head"
    if [[ -z $len || $len -eq 0 ]]; then
        die "cannot read $path at $head (empty or binary)"
    fi
    if (( line < 1 || line > len )); then
        echo "FAIL: $path has $len lines at the PR head; line $line does not exist" >&2; exit 1
    fi
    echo "$path is changed by PR $pr ($blobs) and has $len lines at head; line $line exists"
}

cmd_vote_status() {
    local pr=${1:?pr id required} expected=${2:-} me; me=$(whoami_id)
    req GET "${BASE}/pullRequests/${pr}?${API}" | python3 -c '
import sys, json
me, expected = sys.argv[1], sys.argv[2]
VOTES = '"$VOTE_NAMES"'
NAME = {"approve": "approved", "approve-with-suggestions": "approved-with-suggestions",
        "reset": "no-vote", "no-vote": "no-vote",
        "wait-for-author": "waiting-for-author", "reject": "rejected"}
p = json.load(sys.stdin)
mine = next((r for r in p.get("reviewers", []) if r["id"] == me), None)
if mine is None:
    print("FAIL: you are not a reviewer on PR %s" % p["pullRequestId"], file=sys.stderr); sys.exit(1)
actual = VOTES.get(mine.get("vote", 0), "unknown")
print("PR %s: my vote is %s" % (p["pullRequestId"], actual), flush=True)
if expected and actual != NAME.get(expected, expected):
    print("FAIL: expected %s" % NAME.get(expected, expected), file=sys.stderr); sys.exit(1)' "$me" "$expected"
}

# Read back what is actually true on the server, so the run report is not built
# from memory. Exit 1 when any thread of mine still needs something from me.
cmd_review_audit() {
    local pr=${1:?pr id required} fmt=${2:-}
    local json; json=$(cmd_my_threads "$pr" --all)
    if [[ $fmt == --json ]]; then
        printf '%s\n' "$json"
        printf '%s' "$json" | python3 -c '
import sys, json
rows = json.load(sys.stdin)
sys.exit(1 if any(not r["lastIsMe"] and r["status"] in ("active", "pending") for r in rows) else 0)'
        return
    fi
    printf '%s' "$json" | python3 -c '
import sys, json
rows = json.load(sys.stdin)
if not rows:
    print("no threads opened by you on this PR")
    raise SystemExit(0)
print("%7s  %-9s %-8s %-24s %s" % ("thread", "status", "replies", "verdict", "location"))
need = 0
for r in rows:
    open_ = r["status"] in ("active", "pending")
    if not open_:
        verdict = "closed by %s" % ("you" if r["lastIsMe"] else "the author")
    elif not r["lastIsMe"]:
        verdict = "OPEN author replied"
        need += 1
    elif r["replies"] == 0:
        verdict = "open awaiting author"
    else:
        verdict = "open you spoke last"
    loc = r["file"] or "(PR-level)"
    if r["line"]:
        loc = "%s:%s" % (loc, r["line"])
    print("%7s  %-9s %-8s %-24s %s" % (r["threadId"], r["status"], r["replies"], verdict, loc))
print()
print("%d thread(s) opened by you; %d waiting on your response" % (len(rows), need))
sys.exit(1 if need else 0)'
}

case ${1:-} in
    review-prs)    shift; cmd_review_prs "$@" ;;
    about)         shift; cmd_about "$@" ;;
    iterations)    shift; cmd_iterations "$@" ;;
    files)         shift; cmd_files "$@" ;;
    my-threads)    shift; cmd_my_threads "$@" ;;
    needs-me)      shift; cmd_needs_me "$@" ;;
    whoami)        shift; cmd_whoami "$@" ;;
    comment)       shift; cmd_comment "$@" ;;
    vote)          shift; cmd_vote "$@" ;;
    posted)        shift; cmd_posted "$@" ;;
    anchored)      shift; cmd_anchored "$@" ;;
    line-in-diff)  shift; cmd_line_in_diff "$@" ;;
    vote-status)   shift; cmd_vote_status "$@" ;;
    review-audit)  shift; cmd_review_audit "$@" ;;
    help|-h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
