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

# ---- Detect changes using stdin (native git hook) or local/remote comparison (pre-commit framework) ----

# Check if stdin has data (native git pre-push hook provides this)
if read -t 0; then
  # Read from stdin - native git pre-push hook
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
else
  # No stdin data - running via pre-commit framework
  # Compare current branch with its remote tracking branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  remote_branch=$(git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null || echo "")

  if [[ -n "$remote_branch" ]]; then
    # Remote tracking branch exists - check for changes since remote
    if git diff --name-only "$remote_branch"..HEAD | grep -E -q "$PATTERN"; then
      echo "Relevant changes detected. Running tests..."
      (
        cd "$ROOT_DIR"
        ./run-tests.sh
      )
      exit 0
    fi
  else
    # No remote tracking branch - check uncommitted + committed changes
    # This handles first push scenarios
    if git diff --name-only HEAD | grep -E -q "$PATTERN" || \
       git diff --name-only --cached | grep -E -q "$PATTERN" || \
       git ls-files "$ROOT_DIR" | grep -E -q "$PATTERN"; then
      echo "Relevant changes detected (new branch). Running tests..."
      (
        cd "$ROOT_DIR"
        ./run-tests.sh
      )
      exit 0
    fi
  fi
fi

echo "No relevant changes detected. Skipping tests."
exit 0
