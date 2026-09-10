#!/usr/bin/env bash
# Azure DevOps pull-request helper for the /review-my-open-prs routine.
#
# Wraps the ADO REST API behind the already-authenticated `az` CLI so the routine
# never has to hand-assemble URLs or JSON bodies.
#
# Read subcommands are safe to run freely:
#   ado-pr.sh my-prs                       list active PRs created by the current identity
#   ado-pr.sh info <pr>                    id/title/branches/status for one PR
#   ado-pr.sh threads <pr> [--all]         comment threads; --all includes resolved ones
#   ado-pr.sh thread <pr> <threadId>       one thread with every comment in full
#   ado-pr.sh whoami                       the identity `az` is authenticated as
#
# Write subcommands (gated by the routine itself):
#   ado-pr.sh reply <pr> <threadId> <file> post the contents of <file> as a reply
#   ado-pr.sh resolve <pr> <threadId> [status]   set thread status (default: fixed)
#   ado-pr.sh reply-and-resolve <pr> <threadId> <file> [status]
#                                          reply then resolve, so a failed reply
#                                          can never be followed by a resolve
#
# Verification subcommands. Exit 0 = check PASSED, 1 = check FAILED (the claim is
# false), 2 = the check could not be run. Callers must treat 2 as a failure:
#   ado-pr.sh replied <pr> <threadId>            a reply of mine postdates the reviewer
#   ado-pr.sh thread-status <pr> <threadId> [expected]   read status back
#   ado-pr.sh sha-on-branch <sha> <branch>       the commit really is on the remote branch
#   ado-pr.sh touched <commit|range> <path>...   those paths really changed there
#   ado-pr.sh audit <pr> [--json]                every thread + a verdict per thread
#   ado-pr.sh policy-status <pr>                 Azure DevOps' own build/comment verdicts
#
# Override the target with ADO_ORG / ADO_PROJECT / ADO_REPO if needed.
# ADO_PR_DRY_RUN=1        reply/resolve print what they would send and write nothing.
# ADO_PR_ALLOW_DECLINE=1  required for the wontFix / byDesign / closed statuses.
#
# `ado-pr.sh help` prints this header.

set -euo pipefail

ORG="${ADO_ORG:-unitherdevops}"
PROJECT="${ADO_PROJECT:-UTIE-2.0}"
REPO="${ADO_REPO:-UTIE-2.0}"

# Well-known Azure DevOps resource id; `az rest` needs it to mint the right token.
ADO_RESOURCE=499b84ac-1321-427f-aa17-267ca6975798
BASE="https://dev.azure.com/${ORG}/${PROJECT}/_apis/git/repositories/${REPO}"
API="api-version=7.1"

# Python 3.11 rejects a backslash inside an f-string expression, so the embedded
# snippets below use %-formatting rather than f"{d[\"key\"]}".
# The usage text is the header comment block, so the two cannot drift.
usage() { sed -n '2,/^$/p' "$0" | sed -e 's/^# \{0,1\}//'; }

die() { echo "ado-pr.sh: $*" >&2; exit 2; }
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

cmd_my_prs() {
    local me; me=$(whoami_id)
    req GET "${BASE}/pullRequests?searchCriteria.creatorId=${me}&searchCriteria.status=active&\$top=100&${API}" \
        | python3 -c '
import sys, json
prs = json.load(sys.stdin)["value"]
print(json.dumps([{
    "id": p["pullRequestId"],
    "title": p["title"],
    "isDraft": p.get("isDraft", False),
    "sourceBranch": p["sourceRefName"].removeprefix("refs/heads/"),
    "targetBranch": p["targetRefName"].removeprefix("refs/heads/"),
    "mergeStatus": p.get("mergeStatus"),
} for p in prs], indent=2))'
}

cmd_info() {
    local pr=${1:?pr id required}
    req GET "${BASE}/pullRequests/${pr}?${API}" | python3 -c '
import sys, json
p = json.load(sys.stdin)
print(json.dumps({
    "id": p["pullRequestId"],
    "title": p["title"],
    "status": p["status"],
    "isDraft": p.get("isDraft", False),
    "sourceBranch": p["sourceRefName"].removeprefix("refs/heads/"),
    "targetBranch": p["targetRefName"].removeprefix("refs/heads/"),
    "mergeStatus": p.get("mergeStatus"),
    "lastMergeSourceCommit": (p.get("lastMergeSourceCommit") or {}).get("commitId"),
}, indent=2))'
}

# Unresolved == status active or pending. System threads (votes, reviewer joins,
# policy noise) carry no actionable feedback and are dropped.
cmd_threads() {
    local pr=${1:?pr id required} scope=${2:-unresolved}
    local all=0
    [[ $scope == --all || $scope == all ]] && all=1
    req GET "${BASE}/pullRequests/${pr}/threads?${API}" | python3 -c '
import sys, json
show_all = sys.argv[1] == "1"
out = []
for t in json.load(sys.stdin)["value"]:
    if t.get("isDeleted"):
        continue
    if not show_all and t.get("status") not in ("active", "pending"):
        continue
    comments = [c for c in t.get("comments", []) if c.get("commentType") != "system" and not c.get("isDeleted")]
    if not comments:
        continue
    ctx = t.get("threadContext") or {}
    out.append({
        "threadId": t["id"],
        "status": t["status"],
        "file": ctx.get("filePath"),
        "line": (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line"),
        "rootCommentId": comments[0]["id"],
        "lastAuthor": comments[-1]["author"]["displayName"],
        "comments": [{
            "id": c["id"],
            "author": c["author"]["displayName"],
            "published": c.get("publishedDate"),
            "content": c.get("content", ""),
        } for c in comments],
    })
print(json.dumps(out, indent=2))' "$all"
}

cmd_thread() {
    local pr=${1:?pr id required} tid=${2:?thread id required}
    req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json
t = json.load(sys.stdin)
ctx = t.get("threadContext") or {}
print(json.dumps({
    "threadId": t["id"],
    "status": t.get("status"),
    "file": ctx.get("filePath"),
    "line": (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line"),
    "comments": [{
        "id": c["id"],
        "author": c["author"]["displayName"],
        "commentType": c.get("commentType"),
        "published": c.get("publishedDate"),
        "content": c.get("content", ""),
    } for c in t.get("comments", []) if not c.get("isDeleted")],
}, indent=2))'
}

# Reply text comes from a file so Markdown, quotes, and newlines survive untouched.
cmd_reply() {
    local pr=${1:?pr id required} tid=${2:?thread id required} file=${3:?reply file required}
    [[ -f $file ]] || die "reply file not found: $file"
    [[ -s $file ]] || die "reply file is empty: $file"

    if [[ ${ADO_PR_DRY_RUN:-} == 1 ]]; then
        echo "DRY RUN: would reply to PR $pr thread $tid with $file:"
        sed -e 's/^/  | /' "$file"
        return 0
    fi

    # Parent must be the reviewer's real root comment. comments[0] of the raw
    # array can be a system or deleted comment, which would detach the reply.
    # The duplicate guard makes a re-run safe: an identical body is refused.
    local parent body
    parent=$(req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json, re

def norm(x):
    return re.sub(r"\s+", " ", x or "").strip()

t = json.load(sys.stdin)
comments = [c for c in t.get("comments", [])
            if c.get("commentType") != "system" and not c.get("isDeleted")]
if not comments:
    print("ERR no-human-comments")
    raise SystemExit(0)
body = norm(open(sys.argv[1], encoding="utf-8").read())
for c in comments:
    if norm(c.get("content")) == body:
        print("ERR duplicate-of-comment-%s" % c["id"])
        raise SystemExit(0)
print(comments[0]["id"])' "$file")

    case $parent in
        ERR\ no-human-comments) die "thread $tid has no human comment to reply to" ;;
        ERR\ duplicate-of-comment-*) die "this exact reply is already on thread $tid (${parent##*-}); nothing posted" ;;
    esac
    body=$(python3 -c '
import json, sys
print(json.dumps({
    "parentCommentId": int(sys.argv[1]),
    "content": open(sys.argv[2], encoding="utf-8").read(),
    "commentType": 1,
}))' "$parent" "$file")

    local created me
    created=$(req POST "${BASE}/pullRequests/${pr}/threads/${tid}/comments?${API}" "$body" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    [[ -n $created ]] || fail "reply POST returned no comment id for thread $tid"

    # A 200 from POST is not proof the comment is on the thread. Read it back.
    me=$(whoami_id)
    req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json
cid, me = int(sys.argv[1]), sys.argv[2]
t = json.load(sys.stdin)
for c in t.get("comments", []):
    if c["id"] == cid and not c.get("isDeleted"):
        if c["author"]["id"] != me:
            print("FAIL: comment %s on thread %s is not authored by you" % (cid, t["id"]),
                  file=sys.stderr)
            sys.exit(1)
        print("replied: thread %s comment %s (confirmed on readback)" % (t["id"], cid))
        sys.exit(0)
print("FAIL: comment %s is not present on thread %s after POST" % (cid, t["id"]),
      file=sys.stderr)
sys.exit(1)' "$created" "$me"
}

# Valid statuses: active, fixed, wontFix, closed, byDesign, pending.
cmd_resolve() {
    local pr=${1:?pr id required} tid=${2:?thread id required} status=${3:-fixed}
    case $status in
        active|fixed|wontFix|closed|byDesign|pending) ;;
        *) die "invalid status '$status' (active|fixed|wontFix|closed|byDesign|pending)" ;;
    esac

    # Declining a finding is the user's call, never the routine's.
    case $status in
        wontFix|byDesign|closed)
            [[ ${ADO_PR_ALLOW_DECLINE:-} == 1 ]] || die \
                "status '$status' declines a finding -- set ADO_PR_ALLOW_DECLINE=1 only after the user approves it" ;;
    esac

    if [[ ${ADO_PR_DRY_RUN:-} == 1 ]]; then
        echo "DRY RUN: would set PR $pr thread $tid to '$status'"
        return 0
    fi

    # Preconditions read from the server, not assumed: a resolving status
    # requires that my reply is the newest word on the thread, so a thread can
    # never be closed silently, and requires the thread to still be open.
    local me facts cur last_is_me last_author
    me=$(whoami_id)
    IFS=$'\t' read -r cur last_is_me last_author <<<"$(
        req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" | python3 -c '
import sys, json
me = sys.argv[1]
t = json.load(sys.stdin)
comments = [c for c in t.get("comments", [])
            if c.get("commentType") != "system" and not c.get("isDeleted")]
last = comments[-1] if comments else None
print("%s\t%s\t%s" % (
    t.get("status") or "unknown",
    "yes" if (last and last["author"]["id"] == me) else "no",
    (last["author"]["displayName"] if last else "(none)"),
))' "$me")"

    if [[ $cur == "$status" ]]; then
        echo "thread $tid is already '$cur' -- nothing to do"
        return 0
    fi
    if [[ $status != active && $cur != active && $cur != pending ]]; then
        die "thread $tid is '$cur', not open -- refusing to overwrite a status someone else set"
    fi
    if [[ $status != active && $last_is_me != yes ]]; then
        die "the last word on thread $tid is $last_author's, not yours -- reply before resolving"
    fi

    req PATCH "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" "{\"status\":\"${status}\"}" >/dev/null

    # Read the status back rather than trusting the PATCH response.
    local actual
    actual=$(req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status") or "unknown")')
    [[ $actual == "$status" ]] \
        || fail "thread $tid is '$actual' after asking for '$status'"
    echo "thread $tid -> $actual (confirmed on readback)"
}

# Reply and resolve in one step so a failed reply can never be followed by a
# resolve. This is the only sanctioned way for the routine to close a thread.
cmd_reply_and_resolve() {
    local pr=${1:?pr id required} tid=${2:?thread id required}
    local file=${3:?reply file required} status=${4:-fixed}
    cmd_reply "$pr" "$tid" "$file"
    cmd_resolve "$pr" "$tid" "$status"
}

# ---------------------------------------------------------------------------
# Verification. These exist so the routine can prove a claim instead of
# asserting it. Every check reads state back from the server or from git.
# ---------------------------------------------------------------------------

# Shared reducer: one record per thread with the authorship facts that decide
# "did my reply land?" -- derived from publishedDate, never from judgment.
_thread_facts() { # _thread_facts <pr> <myIdentityId>
    local pr=$1 me=$2
    req GET "${BASE}/pullRequests/${pr}/threads?${API}" | python3 -c '
import sys, json
from datetime import datetime

me = sys.argv[1]

def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")) if s else None

out = []
for t in json.load(sys.stdin)["value"]:
    if t.get("isDeleted"):
        continue
    comments = [c for c in t.get("comments", [])
                if c.get("commentType") != "system" and not c.get("isDeleted")]
    if not comments:
        continue
    ctx = t.get("threadContext") or {}
    mine   = [c for c in comments if c["author"]["id"] == me]
    others = [c for c in comments if c["author"]["id"] != me]
    my_last     = max((ts(c.get("publishedDate")) for c in mine), default=None)
    their_ask   = min((ts(c.get("publishedDate")) for c in others), default=None)
    their_last  = max((ts(c.get("publishedDate")) for c in others), default=None)
    out.append({
        "threadId": t["id"],
        "status": t.get("status"),
        "file": ctx.get("filePath"),
        "line": (ctx.get("rightFileStart") or ctx.get("leftFileStart") or {}).get("line"),
        "reviewers": sorted(set(c["author"]["displayName"] for c in others)),
        "commentCount": len(comments),
        "lastAuthor": comments[-1]["author"]["displayName"],
        "myLastReply": my_last.isoformat() if my_last else None,
        "reviewerAsk": their_ask.isoformat() if their_ask else None,
        "reviewerLastComment": their_last.isoformat() if their_last else None,
        # Replied == I answered the reviewer ask. A reviewer confirmation
        # landing after my reply is the healthy outcome, not a missing reply.
        "repliedToAsk": bool(my_last and their_ask and my_last > their_ask),
        # Whether the ball is in my court right now.
        "lastWordIsReviewer": bool(others and comments[-1]["author"]["id"] != me),
        "authoredByMeOnly": not others,
    })
out.sort(key=lambda r: r["threadId"])
print(json.dumps(out, indent=2))' "$me"
}

# Proves a reply actually landed. Posting is not landing.
cmd_replied() {
    local pr=${1:?pr id required} tid=${2:?thread id required}
    local me; me=$(whoami_id)
    _thread_facts "$pr" "$me" | python3 -c '
import sys, json
tid = int(sys.argv[1])
rows = [r for r in json.load(sys.stdin) if r["threadId"] == tid]
if not rows:
    print("CHECK ERROR: thread %s not found, deleted, or has no human comments" % tid,
          file=sys.stderr)
    sys.exit(2)
r = rows[0]
if r["authoredByMeOnly"]:
    print("CHECK ERROR: thread %s has no reviewer comment to answer" % tid, file=sys.stderr)
    sys.exit(2)
if r["repliedToAsk"]:
    print("ok: you answered thread %s at %s (ask was %s)"
          % (tid, r["myLastReply"], r["reviewerAsk"]))
    sys.exit(0)
print("FAIL: no reply from you answering thread %s (ask %s, your last comment %s)"
      % (tid, r["reviewerAsk"], r["myLastReply"]), file=sys.stderr)
sys.exit(1)' "$tid"
}

# Reads a thread's status back -- how the routine confirms a resolve took effect.
cmd_thread_status() {
    local pr=${1:?pr id required} tid=${2:?thread id required} expected=${3:-}
    local actual
    actual=$(req GET "${BASE}/pullRequests/${pr}/threads/${tid}?${API}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status") or "unknown")')
    if [[ -z $expected ]]; then
        echo "$actual"
        return 0
    fi
    [[ $actual == "$expected" ]] \
        || fail "thread $tid status is '$actual', expected '$expected'"
    echo "ok: thread $tid status is '$actual'"
}

# Proves a commit is on the PR's REMOTE source branch. The tip comes from Azure
# DevOps (authoritative -- a local branch can lie), then git proves ancestry.
# `refs?filter=` is a prefix match, so an exact name comparison is required.
cmd_sha_on_branch() {
    local sha=${1:?commit sha required} branch=${2:?branch name required}
    local tip
    tip=$(req GET "${BASE}/refs?filter=heads/${branch}&${API}" | python3 -c '
import sys, json
want = "refs/heads/" + sys.argv[1]
for r in json.load(sys.stdin).get("value", []):
    if r["name"] == want:
        print(r["objectId"])
        break' "$branch")
    [[ -n $tip ]] || die "remote branch heads/$branch not found"

    git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
    git fetch -q origin "$branch" 2>/dev/null || true
    git cat-file -e "${tip}^{commit}" 2>/dev/null \
        || die "remote tip $tip could not be fetched locally"
    git cat-file -e "${sha}^{commit}" 2>/dev/null \
        || fail "commit $sha does not exist in this repository"

    git merge-base --is-ancestor "$sha" "$tip" \
        || fail "$sha is NOT an ancestor of remote heads/$branch (tip ${tip:0:12}) -- it was never pushed"
    echo "ok: $sha is on remote heads/$branch (tip ${tip:0:12})"
}

# Proves the files a reply claims to have changed actually changed there.
cmd_touched() {
    local range=${1:?commit or range required}; shift
    [[ $# -gt 0 ]] || die "at least one path required"
    local changed rc=0
    if [[ $range == *..* ]]; then
        changed=$(git diff --name-only "$range") || die "cannot diff range '$range'"
    else
        changed=$(git show --pretty=format: --name-only "$range") \
            || die "cannot read commit '$range'"
    fi
    for p in "$@"; do
        # Accept Azure DevOps' leading-slash paths and repo-relative paths alike.
        # Match a whole path, a path under a named directory, or a bare filename --
        # never a loose substring, so Foo.cs cannot be satisfied by Foo.csproj.
        if python3 -c '
import sys
needle = sys.argv[1].strip("/")
for line in sys.stdin.read().splitlines():
    line = line.strip()
    if not line:
        continue
    if line == needle or line.startswith(needle + "/") or line.endswith("/" + needle):
        print(line)
        sys.exit(0)
sys.exit(1)' "${p#/}" <<<"$changed" >/dev/null; then
            echo "ok: ${p#/} changed in $range"
        else
            echo "FAIL: ${p#/} was NOT changed in $range" >&2
            rc=1
        fi
    done
    return $rc
}

# Azure DevOps' own verdict on the PR: the required Build, and the comment
# requirements policy that tracks whether every thread is resolved. This is the
# one signal the routine cannot influence by writing prose. Policy evaluations
# only exist under the -preview api-version.
cmd_policy_status() {
    local pr=${1:?pr id required}
    local proj_id
    proj_id=$(req GET "https://dev.azure.com/${ORG}/_apis/projects/${PROJECT}?api-version=7.1" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    [[ -n $proj_id ]] || die "could not resolve project id for ${PROJECT}"

    req GET "https://dev.azure.com/${ORG}/${PROJECT}/_apis/policy/evaluations?artifactId=vstfs:///CodeReview/CodeReviewId/${proj_id}/${pr}&api-version=7.1-preview" \
        | python3 -c '
import sys, json
evals = json.load(sys.stdin).get("value", [])
if not evals:
    print("no branch policies apply to this pull request")
    raise SystemExit(0)

# Only these two reflect work the routine is responsible for: Build follows
# from the pushed code, Comment requirements from resolving every thread.
# Reviewer approvals are a human decision and never fail this check.
OWNED = ("Build", "Comment requirements")

failed = []
for e in evals:
    cfg = e.get("configuration") or {}
    name = ((cfg.get("type") or {}).get("displayName")) or "(policy)"
    ctx = e.get("context") or {}
    detail = ctx.get("buildDefinitionName") or ctx.get("displayName") or ""
    status = e.get("status") or "unknown"
    owned = name in OWNED
    ok = status in ("approved", "notApplicable")
    if owned and not ok:
        failed.append(name)
    print("%-12s %-32s %-10s %s"
          % (status, name, "(routine)" if owned else "(human)", detail))

print()
if failed:
    print("not approved: %s" % ", ".join(failed))
    raise SystemExit(1)
print("build and comment-requirements policies are approved")' 
}

# The after-the-fact audit: every thread on a PR plus a verdict, so a thread
# resolved without a reply cannot hide. Run it on work a previous run finished.
cmd_audit() {
    local pr=${1:?pr id required} fmt=${2:-table}
    local me; me=$(whoami_id)
    local facts; facts=$(_thread_facts "$pr" "$me")

    if [[ $fmt == --json || $fmt == json ]]; then
        printf '%s\n' "$facts"
        return 0
    fi

    printf '%s\n' "$facts" | python3 -c '
import sys, json
rows = json.load(sys.stdin)
if not rows:
    print("no human comment threads on this PR")
    sys.exit(0)

RESOLVED = ("fixed", "closed", "byDesign", "wontFix")
print("%7s  %-9s %-7s %-26s %s" % ("thread", "status", "replied", "verdict", "location"))
print("-" * 104)

needs_attention = 0
for r in rows:
    resolved = r["status"] in RESOLVED
    replied = r["repliedToAsk"]
    if r["authoredByMeOnly"]:
        verdict = "n/a self-authored" if resolved else "open self-authored"
    elif resolved and not replied:
        verdict = "SUSPECT resolved, no reply"
    elif resolved:
        verdict = "ok resolved + replied"
    elif r["lastWordIsReviewer"]:
        # A reviewer spoke last on a still-active thread: my turn, whether that
        # is the original ask or a pushback on my fix.
        verdict = "OPEN needs your reply" if replied else "OPEN unanswered"
    else:
        verdict = "open awaiting reviewer"
    if verdict.startswith(("SUSPECT", "OPEN")):
        needs_attention += 1
    loc = r["file"] or "(PR-level)"
    if r["line"]:
        loc = "%s:%s" % (loc, r["line"])
    print("%7s  %-9s %-7s %-26s %s"
          % (r["threadId"], r["status"], "yes" if replied else "no", verdict, loc))

resolved_n = sum(1 for r in rows if r["status"] in RESOLVED)
print()
print("%d threads; %d resolved; %d need attention" % (len(rows), resolved_n, needs_attention))
sys.exit(1 if needs_attention else 0)'
}

case ${1:-} in
    my-prs)        shift; cmd_my_prs "$@" ;;
    info)          shift; cmd_info "$@" ;;
    threads)       shift; cmd_threads "$@" ;;
    thread)        shift; cmd_thread "$@" ;;
    whoami)        shift; cmd_whoami "$@" ;;
    reply)         shift; cmd_reply "$@" ;;
    resolve)       shift; cmd_resolve "$@" ;;
    reply-and-resolve) shift; cmd_reply_and_resolve "$@" ;;
    replied)       shift; cmd_replied "$@" ;;
    thread-status) shift; cmd_thread_status "$@" ;;
    sha-on-branch) shift; cmd_sha_on_branch "$@" ;;
    touched)       shift; cmd_touched "$@" ;;
    policy-status) shift; cmd_policy_status "$@" ;;
    audit)         shift; cmd_audit "$@" ;;
    help|-h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac
