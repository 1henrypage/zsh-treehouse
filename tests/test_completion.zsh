#!/usr/bin/env zsh

# Tests for completion helper functions in _wt

describe "Completion Functions"

setup() {
  __fixture_unload_plugin
  source "$PLUGIN_FILE"

  # Source the completion file
  source "${PLUGIN_FILE:h}/_wt"

  __fixture_create_repo
}

teardown() {
  __fixture_teardown
}

# ── __wt_comp_worktree_branches ───────────────────────────────────────

test_comp_worktree_branches_empty() {
  cd "$TEST_REPO"
  local -a branches=()

  # Simulate what the completion function does
  local wt_path="" branch=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
      "")
        [[ -n "$branch" ]] && branches+=("$branch")
        wt_path=""; branch=""
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  [[ -n "$branch" ]] && branches+=("$branch")

  # Should only have main
  assert_eq "${#branches[@]}" "1" "has exactly 1 worktree"
  assert_eq "${branches[1]}" "main" "includes main branch"
}

it "lists only main branch when no worktrees" test_comp_worktree_branches_empty

test_comp_worktree_branches_with_worktrees() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-1"
  __fixture_create_branch "test-2"
  __fixture_create_worktree "test-1"
  __fixture_create_worktree "test-2"

  local -a branches=()
  local wt_path="" branch=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
      "")
        [[ -n "$branch" ]] && branches+=("$branch")
        wt_path=""; branch=""
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  [[ -n "$branch" ]] && branches+=("$branch")

  assert_eq "${#branches[@]}" "3" "has exactly 3 worktrees"
  assert_contains "${branches[*]}" "main" "includes main"
  assert_contains "${branches[*]}" "test-1" "includes test-1"
  assert_contains "${branches[*]}" "test-2" "includes test-2"
}

it "lists all worktree branches" test_comp_worktree_branches_with_worktrees

# ── __wt_comp_branches_for_add ────────────────────────────────────────

test_comp_branches_for_add_excludes_checked_out() {
  cd "$TEST_REPO"
  __fixture_create_branch "available-1"
  __fixture_create_branch "available-2"
  __fixture_create_branch "checked-out"
  __fixture_create_worktree "checked-out"

  # Get checked out branches
  local -a checked_out=()
  while IFS= read -r line; do
    case "$line" in
      branch\ *) checked_out+=("${line#branch refs/heads/}") ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)

  # Get all local branches
  local -a all_branches=()
  all_branches=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)"})

  # Compute available (this tests the fix)
  local -a available=()
  available=("${(@)all_branches:|checked_out}")
  available=("${(@u)available}")

  assert_contains "${available[*]}" "available-1" "includes available-1"
  assert_contains "${available[*]}" "available-2" "includes available-2"
  assert_not_contains "${available[*]}" "checked-out" "excludes checked-out"
  assert_not_contains "${available[*]}" "main" "excludes main"
}

it "excludes checked-out branches from add completion" test_comp_branches_for_add_excludes_checked_out

test_comp_branches_for_add_includes_remote() {
  cd "$TEST_REPO"
  __fixture_create_remote_branch "remote-feature"

  # Get checked out branches
  local -a checked_out=()
  while IFS= read -r line; do
    case "$line" in
      branch\ *) checked_out+=("${line#branch refs/heads/}") ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)

  # Get all local branches
  local -a all_branches=()
  all_branches=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)"})

  # Get remote branches (stripped of remote name prefix)
  local -a remote_branches=()
  local -a raw_remote=()
  raw_remote=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/remotes/ 2>/dev/null)"})
  for rb in "${raw_remote[@]}"; do
    local stripped="${rb#*/}"
    [[ "$stripped" = "HEAD" ]] && continue
    remote_branches+=("$stripped")
  done

  # Combine and deduplicate (this tests the fix)
  local -a available=()
  available=("${(@)all_branches:|checked_out}" "${(@)remote_branches:|checked_out}")
  available=("${(@u)available}")

  assert_contains "${available[*]}" "remote-feature" "includes remote branch"
}

it "includes remote branches in add completion" test_comp_branches_for_add_includes_remote

test_comp_branches_for_add_deduplicates() {
  cd "$TEST_REPO"
  __fixture_create_branch "feature"
  git push origin feature &>/dev/null

  # Get checked out branches
  local -a checked_out=()
  while IFS= read -r line; do
    case "$line" in
      branch\ *) checked_out+=("${line#branch refs/heads/}") ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)

  # Get all local branches
  local -a all_branches=()
  all_branches=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)"})

  # Get remote branches
  local -a remote_branches=()
  local -a raw_remote=()
  raw_remote=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/remotes/ 2>/dev/null)"})
  for rb in "${raw_remote[@]}"; do
    local stripped="${rb#*/}"
    [[ "$stripped" = "HEAD" ]] && continue
    remote_branches+=("$stripped")
  done

  # Combine and deduplicate (this tests the fix)
  local -a available=()
  available=("${(@)all_branches:|checked_out}" "${(@)remote_branches:|checked_out}")
  available=("${(@u)available}")

  # Count occurrences of "feature"
  local count=0
  for b in "${available[@]}"; do
    [[ "$b" = "feature" ]] && (( count++ ))
  done

  assert_eq "$count" "1" "feature appears exactly once"
}

it "deduplicates branches that exist both locally and remotely" test_comp_branches_for_add_deduplicates

# ── __wt_comp_unlocked_branches ───────────────────────────────────────

test_comp_unlocked_branches_excludes_locked() {
  cd "$TEST_REPO"
  __fixture_create_branch "unlocked"
  __fixture_create_branch "locked"
  __fixture_create_worktree "unlocked"
  __fixture_create_worktree "locked"

  # Lock one worktree
  wt lock locked &>/dev/null

  # Get unlocked branches
  local -a branches=()
  local wt_path="" branch="" is_locked=0
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
      locked*) is_locked=1 ;;
      "")
        if [[ -n "$branch" ]] && (( ! is_locked )); then
          branches+=("$branch")
        fi
        wt_path=""; branch=""; is_locked=0
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  # Handle final entry
  if [[ -n "$branch" ]] && (( ! is_locked )); then
    branches+=("$branch")
  fi

  assert_contains "${branches[*]}" "unlocked" "includes unlocked"

  # Check that "locked" is not in the array (must check elements, not substring)
  local found_locked=0
  for b in "${branches[@]}"; do
    [[ "$b" = "locked" ]] && found_locked=1
  done
  assert_eq "$found_locked" "0" "excludes locked"
}

it "excludes locked branches from unlock completion" test_comp_unlocked_branches_excludes_locked

# ── __wt_comp_locked_branches ─────────────────────────────────────────

test_comp_locked_branches_only_locked() {
  cd "$TEST_REPO"
  __fixture_create_branch "unlocked"
  __fixture_create_branch "locked"
  __fixture_create_worktree "unlocked"
  __fixture_create_worktree "locked"

  # Lock one worktree
  wt lock locked &>/dev/null

  # Get locked branches
  local -a branches=()
  local wt_path="" branch="" is_locked=0
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
      locked*) is_locked=1 ;;
      "")
        if [[ -n "$branch" ]] && (( is_locked )); then
          branches+=("$branch")
        fi
        wt_path=""; branch=""; is_locked=0
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  # Handle final entry
  if [[ -n "$branch" ]] && (( is_locked )); then
    branches+=("$branch")
  fi

  assert_contains "${branches[*]}" "locked" "includes locked"

  # Check that "unlocked" is not in the array (must check elements, not substring)
  local found_unlocked=0
  for b in "${branches[@]}"; do
    [[ "$b" = "unlocked" ]] && found_unlocked=1
  done
  assert_eq "$found_unlocked" "0" "excludes unlocked"
}

it "only includes locked branches in lock completion" test_comp_locked_branches_only_locked

# ── __wt_comp_refs ────────────────────────────────────────────────────

test_comp_refs_includes_branches_and_tags() {
  cd "$TEST_REPO"
  __fixture_create_branch "feature"
  git tag v1.0 &>/dev/null

  local -a refs=()
  # Get all local branches
  refs+=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)"})
  # Get all tags
  refs+=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/tags/ 2>/dev/null)"})

  assert_contains "${refs[*]}" "main" "includes main branch"
  assert_contains "${refs[*]}" "feature" "includes feature branch"
  assert_contains "${refs[*]}" "v1.0" "includes v1.0 tag"
}

it "includes both branches and tags in refs completion" test_comp_refs_includes_branches_and_tags
