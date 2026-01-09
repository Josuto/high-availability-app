#!/usr/bin/env bash
set -euo pipefail

# ---- Input validation -------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <root-folder>"
  echo "Example: $0 infra-ecs"
  exit 1
fi

ROOT_DIR="$1"

PATTERN="^${ROOT_DIR}/(deployment|modules|tests)/.*\.(tf|tfvars|tftest\.hcl)$"

echo "Pre-push check for changes under '${ROOT_DIR}'..."

# ---- Read refs from pre-push stdin ------------------------------------

while read -r local_ref local_sha remote_ref remote_sha; do
  # First push or new branch
  if [[ "$remote_sha" == "0000000000000000000000000000000000000000" ]]; then
    RANGE="$local_sha"
  else
    RANGE="$remote_sha..$local_sha"
  fi

  if git diff --name-only "$RANGE" | grep -E -q "$PATTERN"; then
    echo "Relevant changes detected. Running tests..."
    (
      cd "$ROOT_DIR"
      ./run-tests.sh
    )
    exit 0
  fi
done

echo "No relevant changes detected. Skipping tests."
exit 0
