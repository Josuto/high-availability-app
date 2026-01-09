#!/usr/bin/env bash
set -euo pipefail

ROOTS=("infra-ecs" "infra-eks")

PATTERN_SUFFIX='/(deployment|modules|tests)/.*\.(tf|tfvars|tftest\.hcl)$'

# Read stdin ONCE
PUSH_REFS="$(cat)"

if [[ -z "$PUSH_REFS" ]]; then
  echo "No push refs received. Skipping."
  exit 0
fi

for ROOT in "${ROOTS[@]}"; do
  PATTERN="^${ROOT}${PATTERN_SUFFIX}"

  while read -r local_ref local_sha remote_ref remote_sha; do
    if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
      RANGE="$local_sha"
    else
      RANGE="$remote_sha..$local_sha"
    fi

    if git diff --name-only "$RANGE" | grep -E -q "$PATTERN"; then
      echo "Relevant changes detected in ${ROOT}. Running tests..."
      (
        cd "$ROOT"
        ./run-tests.sh
      )
      break
    fi
  done <<< "$PUSH_REFS"
done
