#!/usr/bin/env bash
# Prepare a GitLab project for the agent ticket workflow. Runs on the HOST with your
# own glab login (glab auth login) or GITLAB_TOKEN; needs Maintainer rights.
#
#   scripts/gitlab-setup.sh gitlab.com/group/project               create state labels
#   scripts/gitlab-setup.sh gitlab.com/group/project --templates   + MR with issue/MR templates and CI include
#   scripts/gitlab-setup.sh gitlab.com/group/project --protect     + make sure the default branch is protected
#                                                                    (push: no one, merge: Maintainers)
#   Self-hosted: git.example.com/group/project
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
spec="${1:-}"; spec="${spec#https://}"
[[ "$spec" == *.*/*/* ]] || { sed -n '2,10p' "$0"; exit 1; }
shift
templates=0 protect=0
while [ $# -gt 0 ]; do
  case "$1" in --templates) templates=1 ;; --protect) protect=1 ;; *) echo "unknown: $1" >&2; exit 1 ;; esac
  shift
done

command -v glab >/dev/null || { echo "glab missing (brew install glab)" >&2; exit 1; }
host="${spec%%/*}"; path="${spec#*/}"
enc="$(jq -rn --arg p "$path" '$p|@uri')"
api() { glab api --hostname "$host" "$@"; }
default="$(api "projects/$enc" | jq -r .default_branch)"
echo "Project $host/$path (default branch: $default)"

# ---------------------------------------------------------------- labels
echo "→ labels"
TICKET_TRANSLATE=0 GLAB_BIN=glab "$here/bin/ticket" labels -R "$spec"

# ---------------------------------------------------------------- templates via merge request
if [ "$templates" -eq 1 ]; then
  echo "→ templates as a merge request"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  git clone -q --depth 1 "https://$host/$path.git" "$tmp/repo"
  cd "$tmp/repo"
  git switch -q -c chore/agent-ticketing
  mkdir -p .gitlab/issue_templates .gitlab/merge_request_templates .gitlab/ci
  cp "$here/templates/gitlab/issue_templates/Agent task.md" .gitlab/issue_templates/
  [ -e .gitlab/merge_request_templates/Default.md ] || cp "$here/templates/gitlab/merge_request_templates/Default.md" .gitlab/merge_request_templates/
  [ -e .gitlab/ci/devsecops.gitlab-ci.yml ] || cp "$here/templates/gitlab/devsecops.gitlab-ci.yml" .gitlab/ci/
  git add -A
  git commit -q -m "ci(gitlab): add agent ticket workflow templates" \
    -m "Issue template for agent tasks, MR template and a DevSecOps CI include (.gitlab/ci/devsecops.gitlab-ci.yml)."
  git push -q -u origin chore/agent-ticketing
  api -X POST "projects/$enc/merge_requests" -f source_branch=chore/agent-ticketing -f "target_branch=$default" \
    -f "title=ci(gitlab): add agent ticket workflow templates" -F remove_source_branch=true \
    -f "description=Adds the \"Agent task\" issue template, an MR template and a DevSecOps CI include for the agent sandbox. Include it from .gitlab-ci.yml: \`include: [{local: .gitlab/ci/devsecops.gitlab-ci.yml}]\`." \
    | jq -r .web_url
  cd "$here"
fi

# ---------------------------------------------------------------- protected default branch
if [ "$protect" -eq 1 ]; then
  echo "→ protected branch $default"
  bname="$(jq -rn --arg b "$default" '$b|@uri')"
  if cur="$(api "projects/$enc/protected_branches/$bname" 2>/dev/null)"; then
    echo "  already protected: push=$(jq -c '[.push_access_levels[].access_level_description]' <<<"$cur") merge=$(jq -c '[.merge_access_levels[].access_level_description]' <<<"$cur") force_push=$(jq -r .allow_force_push <<<"$cur")"
    echo "  (unchanged - adjust under Settings > Repository > Protected branches if needed)"
  else
    api -X POST "projects/$enc/protected_branches" -f "name=$default" -F push_access_level=0 -F merge_access_level=40 -F allow_force_push=false >/dev/null
    echo "  protected: push = no one, merge = Maintainers, no force push"
  fi
  cat <<'EOF'
  Note: give the agents a project/group access token with role "Developer" (scope "api").
  Developers can push agent/* branches and open MRs, but cannot push or merge to the
  protected default branch - whatever the prompt says.
EOF
fi
echo "✔ done"
