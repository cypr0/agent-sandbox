#!/usr/bin/env bash
# shellcheck disable=SC2034  # $out is read inside the eval'd check expressions
# Regression test for the documentation writer tooling: docs-license (offline fixture),
# the documentation check of devsecops-gate, and "ticket run docs" argument handling.
#   tests/test-docs.sh      (host with bash >= 4 and jq, or in the container)
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SANDBOX_BIN:-$here/bin}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
ok()   { pass=$((pass + 1)); }
nok()  { fail=$((fail + 1)); echo "FAIL  $*"; }
check() { if eval "$2"; then ok; else nok "$1"; fi; }

# ---------------------------------------------------------------- docs-license (offline API fixture)
mkdir -p "$tmp/api"
printf '{"key":"mit","body":"MIT License\\n\\nCopyright (c) [year] [fullname]\\n"}' >"$tmp/api/mit"
printf '{"key":"apache-2.0","body":"Copyright [yyyy] [name of copyright owner]\\n"}' >"$tmp/api/apache-2.0"
export DOCS_LICENSE_API="file://$tmp/api" GH_TOKEN=""
out="$(bash "$BIN/docs-license" mit "Jane Doe" 2031)"
check "mit placeholders filled" '[[ "$out" == *"Copyright (c) 2031 Jane Doe"* ]]'
out="$(bash "$BIN/docs-license" MIT "Jane Doe" 2031)"
check "key is case-insensitive" '[[ "$out" == *"2031 Jane Doe"* ]]'
out="$(bash "$BIN/docs-license" apache-2.0 "Jane Doe")"
check "apache appendix stays verbatim" '[[ "$out" == *"[yyyy] [name of copyright owner]"* ]]'
check "missing holder is refused" '! (cd "$tmp" && DOCS_COPYRIGHT_HOLDER="" HOME="$tmp" GIT_CONFIG_GLOBAL=/dev/null bash "$BIN/docs-license" mit >/dev/null 2>&1)'
check "unknown license is refused" '! bash "$BIN/docs-license" no-such-license "x" >/dev/null 2>&1'
unset DOCS_LICENSE_API

# ---------------------------------------------------------------- devsecops-gate: documentation check
r="$tmp/repo"; mkdir -p "$r/docs"
git -C "$r" init -q -b main
git -C "$r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$r" update-ref refs/remotes/origin/main HEAD
git -C "$r" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git -C "$r" switch -q -c agent/1-docs
gate_docs() { (cd "$r" && bash "$BIN/devsecops-gate" --no-tests -q 2>/dev/null) | grep 'Documentation'; }

printf '# Arch\n\nSee [ops](OPERATIONS.md) and [home](../README.md#top) and [web](https://example.org).\n' >"$r/docs/ARCHITECTURE.md"
printf '# Ops\n\n```sh\necho hi\n```\n' >"$r/docs/OPERATIONS.md"
printf '# Readme\n\n[Architecture](docs/ARCHITECTURE.md)\n' >"$r/README.md"
check "clean docs pass" '[[ "$(gate_docs)" == *PASS* ]]'

printf '# Readme\n\n[missing](docs/NOPE.md)\n' >"$r/README.md"
check "broken relative link fails" '[[ "$(gate_docs)" == *FAIL* ]]'

printf '# Readme\n\n[Architecture](docs/ARCHITECTURE.md)\n\n```sh\necho open fence\n' >"$r/README.md"
check "unclosed code fence fails" '[[ "$(gate_docs)" == *FAIL* ]]'

printf '# Readme\n\n[Architecture](docs/ARCHITECTURE.md)\n\nTODO: describe usage\n' >"$r/README.md"
check "TODO leftover warns" '[[ "$(gate_docs)" == *WARN* ]]'

printf '# Readme\n\n[Architecture](docs/ARCHITECTURE.md)\n' >"$r/README.md"
mkdir -p "$r/templates"; printf '<!--\n  Template for something.\n-->\n# <Project name>\n[x](docs/missing.md)\n' >"$r/templates/T.md"
check "templates are skipped" '[[ "$(gate_docs)" == *PASS* ]]'

# ---------------------------------------------------------------- ticket run docs (stubs for gh and claude)
cat >"$tmp/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in "issue view") echo "agent/approved" ;; esac
STUB
cat >"$tmp/claude" <<'STUB'
#!/usr/bin/env bash
printf 'CLAUDE %s\n' "$*"
STUB
chmod +x "$tmp/gh" "$tmp/claude"
run_ticket() { (cd "$tmp" && PATH="$tmp:$PATH" GH_BIN="$tmp/gh" TICKET_TRANSLATE=0 TICKET_DEFAULT_REPO=o/r bash "$BIN/ticket" "$@" 2>&1); }
out="$(run_ticket run docs o/r --path kubernetes/apps/x/y --only readme,architecture)"
check "docs on a repo + path" '[[ "$out" == *"CLAUDE /write-docs o/r kubernetes/apps/x/y --only readme,architecture"* ]]'
out="$(run_ticket run docs o/r#5)"
check "docs on an issue" '[[ "$out" == *"CLAUDE /write-docs https://github.com/o/r/issues/5"* ]]'
out="$(run_ticket run docs gitlab.com/grp/proj)"
check "docs on a GitLab repo" '[[ "$out" == *"CLAUDE /write-docs gitlab.com/grp/proj"* ]]'

echo "docs: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
