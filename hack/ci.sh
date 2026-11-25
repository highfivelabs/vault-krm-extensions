#!/usr/bin/env bash
# Copyright 2026 High Five Labs
# SPDX-License-Identifier: Apache-2.0
#
# Everything CI checks, in one place: the hermetic check of
# .github/workflows/hfl-ci.yml (krm-ci's krm-ci.yml) runs this script, and so
# can anyone before opening a pull request.
#
#   hack/ci.sh            run the checks
#   hack/ci.sh --report   run them and print a Markdown proof for the PR
#
# RUNTIME is a krm-rest-runtime checkout. CI checks it out at hfl-ci.yml's
# sibling-ref. Locally, unset, the script makes a temporary worktree of
# ../krm-rest-runtime at that same ref, so the generator matches CI's.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
report=false
[[ ${1:-} == --report ]] && report=true

pinned=$(sed -n 's/^ *sibling-ref: *"\{0,1\}\([0-9a-f]\{40\}\).*/\1/p' .github/workflows/hfl-ci.yml | head -1)
cleanup=()
trap 'for c in "${cleanup[@]}"; do eval "$c"; done' EXIT

if [[ -z ${RUNTIME:-} ]]; then
  src=${RUNTIME_REPO:-$root/../krm-rest-runtime}
  [[ -d $src/.git || -f $src/.git ]] || { echo "need a krm-rest-runtime clone at $src (or set RUNTIME)" >&2; exit 2; }
  git -C "$src" cat-file -e "$pinned^{commit}" 2>/dev/null || git -C "$src" fetch -q origin "$pinned"
  RUNTIME=$(mktemp -d)/krm-rest-runtime
  git -C "$src" worktree add -q --detach "$RUNTIME" "$pinned"
  cleanup+=("git -C '$src' worktree remove --force '$RUNTIME'")
fi
export RUNTIME

log=$(mktemp)
cleanup+=("rm -f '$log'")
rows=() failed=0 start=$SECONDS

step() {
  local name=$1; shift
  local t=$SECONDS rc
  echo "::group::$name" >>"$log"
  echo "--- $name" >&2
  ( set -e; "$@" ) >>"$log" 2>&1
  rc=$?
  echo "::endgroup::" >>"$log"
  if ((rc == 0)); then rows+=("| $name | ✅ pass | $((SECONDS - t))s |")
  else rows+=("| $name | ❌ fail ($rc) | $((SECONDS - t))s |"); failed=1
    echo "    failed; last lines:" >&2; tail -20 "$log" | sed 's/^/    /' >&2
  fi
}

generated() {
  hack/gen/generate.sh
  git diff --exit-code -- types.yaml config/crds zz_generated.report.md examples
  test -z "$(git status --porcelain -- examples)"   # no new example files left out
}

step "Generated files are current" generated
step "Generator inputs are facts only (no Terraform provider prose)" \
  python3 "$RUNTIME/gen/factsonly.py" . --spec hack/gen/specs --check
step "go build ./..." go build ./...
step "go vet ./..." go vet ./...
step "go vet -tags live ./..." go vet -tags live ./...
step "go test ./..." go test -count=1 ./...

if $report; then
  sha=$(git rev-parse HEAD)
  dirty=$(git status --porcelain -- . ':!hack/gen/specs' | wc -l | tr -d ' ')
  {
    echo "### Local CI"
    echo
    if ((failed)); then echo "**Result: ❌ failed**"; else echo "**Result: ✅ all checks passed**"; fi
    echo
    echo "- Commit: \`$sha\`$( ((dirty)) && echo " **plus $dirty uncommitted change(s)**" || echo " (clean tree)")"
    echo "- Runtime: \`highfivelabs/krm-rest-runtime@$pinned\` (hfl-ci.yml's sibling-ref)"
    echo "- Toolchain: $(go version | cut -d' ' -f3-), Python $(python3 -c 'import sys;print(sys.version.split()[0])'), PyYAML $(python3 -c 'import yaml;print(yaml.__version__)' 2>/dev/null || echo missing)"
    echo "- Ran: $(date -u +%Y-%m-%dT%H:%M:%SZ) on $(uname -sm), $((SECONDS - start))s, via \`hack/ci.sh --report\`"
    echo
    echo "| Step | Result | Time |"
    echo "| --- | --- | --- |"
    printf '%s\n' "${rows[@]}"
    echo
    echo "<details><summary>go test output</summary>"
    echo
    echo '```'
    awk '/^::group::go test/{p=1;next} /^::endgroup::/{p=0} p' "$log" | tail -60
    echo '```'
    echo
    echo "</details>"
  }
fi
exit $failed
