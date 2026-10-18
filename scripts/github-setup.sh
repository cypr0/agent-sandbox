#!/usr/bin/env bash
# Prepare a GitHub repo for the agent ticket workflow. Runs on the HOST with
# your own gh login (needs admin rights for --ruleset).
#
#   scripts/github-setup.sh owner/repo                 create state labels
#   scripts/github-setup.sh owner/repo --templates     + PR with issue form, PR template, CI workflow
#   scripts/github-setup.sh owner/repo --ruleset       + ruleset "agent-guard" on the default branch
#   Options can be combined. --bypass-app <slug> (repeatable) exempts a GitHub App
#   from the ruleset (e.g. renovate when it uses automergeType "branch").
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
repo="${1:-}"; [ -n "$repo" ] && [[ "$repo" == */* ]] || { sed -n '2,10p' "$0"; exit 1; }
shift
templates=0 ruleset=0 apps=()
while [ $# -gt 0 ]; do
  case "$1" in
    --templates) templates=1 ;;
    --ruleset) ruleset=1 ;;
    --bypass-app) apps+=("$2"); shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
  shift
done

command -v gh >/dev/null || { echo "gh missing (brew install gh)" >&2; exit 1; }
default="$(gh repo view "$repo" --json defaultBranchRef -q .defaultBranchRef.name)"
echo "Repo $repo (default branch: $default)"

# ---------------------------------------------------------------- labels
echo "→ labels"
TICKET_TRANSLATE=0 GH_BIN=gh "$here/bin/ticket" labels -R "$repo"

# ---------------------------------------------------------------- templates via pull request
if [ "$templates" -eq 1 ]; then
  echo "→ templates as a pull request"
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  gh repo clone "$repo" "$tmp/repo" -- --depth 1 -q
  cd "$tmp/repo"
  git switch -q -c chore/agent-ticketing
  mkdir -p .github/ISSUE_TEMPLATE .github/workflows
  cp "$here/templates/github/ISSUE_TEMPLATE/agent-task.yml" .github/ISSUE_TEMPLATE/
  [ -e .github/pull_request_template.md ] || cp "$here/templates/github/pull_request_template.md" .github/
  [ -e .github/workflows/devsecops.yaml ] || cp "$here/templates/github/workflows/devsecops.yaml" .github/workflows/
  if [ -f .github/labels.yaml ] && ! grep -q 'agent/todo' .github/labels.yaml; then
    { echo; sed -n '/^# Agent workflow/,$p' "$here/templates/github/labels-snippet.yaml"; } >> .github/labels.yaml
  fi
  git add -A
  git commit -q -m "ci(github): add agent ticket workflow templates" \
    -m "Issue form for agent tasks, PR template, DevSecOps workflow and agent/* state labels."
  git push -q -u origin chore/agent-ticketing
  gh pr create -R "$repo" --base "$default" --head chore/agent-ticketing \
    --title "ci(github): add agent ticket workflow templates" \
    --body "Adds the \"Agent task\" issue form, a PR template, a DevSecOps workflow and the agent/* labels (label sync) for the agent sandbox."
  cd "$here"
fi

# ---------------------------------------------------------------- ruleset
if [ "$ruleset" -eq 1 ]; then
  echo "→ ruleset agent-guard on $default"
  bypass='[{"actor_id":5,"actor_type":"RepositoryRole","bypass_mode":"always"}]'
  for a in "${apps[@]+"${apps[@]}"}"; do
    id="$(gh api "apps/$a" -q .id)"
    bypass="$(jq -c --argjson id "$id" '. + [{"actor_id":$id,"actor_type":"Integration","bypass_mode":"always"}]' <<<"$bypass")"
    echo "  exemption for app $a (id $id)"
  done
  body="$(jq -n --argjson bypass "$bypass" '{
    name: "agent-guard", target: "branch", enforcement: "active",
    conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
    bypass_actors: $bypass,
    rules: [
      {type: "deletion"},
      {type: "non_fast_forward"},
      {type: "pull_request", parameters: {required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
        require_code_owner_review: false, require_last_push_approval: false, required_review_thread_resolution: false}}
    ]}')"
  existing="$(gh api "repos/$repo/rulesets" -q '.[] | select(.name=="agent-guard") | .id' 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    gh api -X PUT "repos/$repo/rulesets/$existing" --input - <<<"$body" >/dev/null && echo "  updated"
  else
    gh api -X POST "repos/$repo/rulesets" --input - <<<"$body" >/dev/null && echo "  created"
  fi
  cat <<'EOF'
  Note: repository admins may bypass the ruleset. If the agent uses a token of
  YOUR account (admin), it does not protect against the agent - use a bot account
  with write access instead (see README, "Own identity for the agents").
EOF
fi
echo "✔ done"
