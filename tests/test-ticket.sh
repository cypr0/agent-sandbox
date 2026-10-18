#!/usr/bin/env bash
# Regression test for bin/ticket: reference parsing and the forge calls it makes,
# against stub gh/glab binaries (no network, no tokens).
#   tests/test-ticket.sh      (host with bash >= 4 and jq, or in the container)
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
T="${TICKET_BIN:-$here/bin/ticket}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
calls="$tmp/calls"

cat >"$tmp/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$CALLS"
case "$1 $2" in
  "repo view") echo main ;;
  "api repos/o/r/issues/5/comments") echo 4711 ;;
esac
STUB
cat >"$tmp/glab" <<'STUB'
#!/usr/bin/env bash
echo "glab $*" >>"$CALLS"
case "$*" in
  *"projects/grp%2Fsub%2Fproj/issues/12/notes?"*) echo '[{"id":99,"body":"<!-- agent-plan -->\nold"}]' ;;
  *"api --hostname gitlab.com projects/grp%2Fsub%2Fproj") echo '{"default_branch":"main"}' ;;
  *) echo '{"web_url":"https://gitlab.com/grp/sub/proj/-/merge_requests/3"}' ;;
esac
STUB
chmod +x "$tmp/gh" "$tmp/glab"
export CALLS="$calls" GH_BIN="$tmp/gh" GLAB_BIN="$tmp/glab" TICKET_TRANSLATE=0 TICKET_DEFAULT_REPO=o/r GITLAB_HOST=gitlab.com

pass=0 fail=0
expect() { # expect <description> <pattern> - pattern must appear in the recorded calls/output
  if grep -qF -- "$2" "$calls" "$tmp/out" 2>/dev/null; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL  $1: '$2' not found"; sed 's/^/      /' "$calls" "$tmp/out" 2>/dev/null | tail -5; fi
}
run() { : >"$calls"; (cd "$tmp" && bash "$T" "$@") >"$tmp/out" 2>&1; }

# reference parsing
run info https://github.com/o/r/issues/42;                         expect "gh issue url" "FORGE=github"; expect "gh nr" "NR=42"
run info https://github.com/o/r/pull/7;                            expect "gh pr url" "KIND=pr"
run info o/r#9;                                                    expect "gh short" "REPO=o/r"
run info 9;                                                        expect "default repo" "REPO=o/r"
run info https://gitlab.com/grp/sub/proj/-/issues/12;              expect "gl issue url" "FORGE=gitlab"; expect "gl path" "REPO=grp/sub/proj"
run info https://git.example.com/team/app/-/merge_requests/3;      expect "gl mr url" "HOST=git.example.com"; expect "gl mr kind" "KIND=pr"
run info gitlab.com/grp/proj!3;                                    expect "gl short mr" "URL=https://gitlab.com/grp/proj/-/merge_requests/3"
run info gl:grp/proj#4;                                            expect "gl prefix" "URL=https://gitlab.com/grp/proj/-/issues/4"

# GitHub writes
run state o/r#5 planned;                                           expect "gh state" "--add-label agent/planned"
run comment o/r#5 - <<<"hello";                                    expect "gh comment" "issue comment 5 -R o/r --body-file"
printf '<!-- agent-plan -->\nplan\n' >"$tmp/plan.md"
run upsert-comment o/r#5 '<!-- agent-plan -->' "$tmp/plan.md";     expect "gh upsert updates" "api -X PATCH repos/o/r/issues/comments/4711"
printf 'body\n' >"$tmp/pr.md"
run pr o/r#5 --branch agent/5-x --title "feat: x" --body-file "$tmp/pr.md"; expect "gh pr" "pr create -R o/r --base main --head agent/5-x"
run pr o/r#5 --branch main --title x --body-file "$tmp/pr.md";    expect "protected source branch refused" "must not be a protected branch"

# GitLab writes
run state gitlab.com/grp/sub/proj#12 in-progress;                  expect "gl state" "add_labels=agent/in-progress"
run upsert-comment gitlab.com/grp/sub/proj#12 '<!-- agent-plan -->' "$tmp/plan.md"; expect "gl upsert updates" "-X PUT projects/grp%2Fsub%2Fproj/issues/12/notes/99"
run pr gitlab.com/grp/sub/proj#12 --branch agent/12-x --title "fix: y" --body-file "$tmp/pr.md" --draft
expect "gl mr" "projects/grp%2Fsub%2Fproj/merge_requests"; expect "gl draft" "title=Draft: fix: y"
run pr-comment gitlab.com/grp/sub/proj!3 "$tmp/pr.md";             expect "gl mr note" "merge_requests/3/notes"

echo "ticket: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
