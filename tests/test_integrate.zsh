#!/usr/bin/env zsh

# Tests for wt integrate

describe "wt integrate"

setup() {
  __fixture_unload_plugin
  source "$PLUGIN_FILE"
  __fixture_create_repo
}

teardown() {
  __fixture_teardown
}

# ── Argument Validation ───────────────────────────────────────────────

test_integrate_no_args_shows_error() {
  cd "$TEST_REPO"
  __capture wt integrate
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "usage: wt integrate" "shows usage"
}

it "shows error with no arguments" test_integrate_no_args_shows_error

test_integrate_nonexistent_branch_shows_error() {
  cd "$TEST_REPO"
  __capture wt integrate nonexistent
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "no worktree found for branch 'nonexistent'" "shows error"
}

it "shows error for nonexistent branch" test_integrate_nonexistent_branch_shows_error

test_integrate_outside_repo_shows_error() {
  cd /tmp
  __capture wt integrate test-branch
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "not inside a git repository" "shows error"
}

it "shows error outside repository" test_integrate_outside_repo_shows_error

# ── Safety Checks ─────────────────────────────────────────────────────

test_integrate_refuses_dirty_worktree() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-dirty"
  __fixture_create_worktree "integrate-dirty"

  local wt_path="$WT_DIR/origin/integrate-dirty"
  __fixture_make_dirty "$wt_path"

  __capture wt integrate integrate-dirty
  assert_exit_code 1 "returns 1 when worktree is dirty"
  assert_contains "$__STDERR" "uncommitted changes" "shows error about uncommitted changes"
}

it "refuses when worktree has uncommitted changes" test_integrate_refuses_dirty_worktree

test_integrate_refuses_dirty_main() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-main-dirty"
  __fixture_create_worktree "integrate-main-dirty"

  # Make main worktree dirty
  print "uncommitted" > "$TEST_REPO/main-dirty.txt"

  __capture wt integrate integrate-main-dirty
  assert_exit_code 1 "returns 1 when main is dirty"
  assert_contains "$__STDERR" "main worktree has uncommitted changes" "shows error about main being dirty"
}

it "refuses when main worktree has uncommitted changes" test_integrate_refuses_dirty_main

test_integrate_refuses_wrong_branch_in_main() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-wrong-main"
  __fixture_create_worktree "integrate-wrong-main"

  # Checkout a different branch in main
  git -C "$TEST_REPO" checkout -b other-branch &>/dev/null

  __capture wt integrate integrate-wrong-main
  assert_exit_code 1 "returns 1 when main is on wrong branch"
  assert_contains "$__STDERR" "must be on 'main'" "shows error about wrong branch"

  # Cleanup
  git -C "$TEST_REPO" checkout main &>/dev/null
  git -C "$TEST_REPO" branch -D other-branch &>/dev/null
}

it "refuses when main worktree is not on default branch" test_integrate_refuses_wrong_branch_in_main

# ── Core Behavior ─────────────────────────────────────────────────────

test_integrate_merges_worktree_into_main() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-merge"
  __fixture_create_worktree "integrate-merge"

  # Make a commit in worktree
  __fixture_commit_in_worktree "integrate-merge" "feature.txt" "Add feature"

  # Integrate
  wt integrate integrate-merge &>/dev/null

  # Check that main now contains the commit
  git -C "$TEST_REPO" log --oneline | grep -q "Add feature"
  local rc=$?
  assert_eq "$rc" "0" "main contains worktree commit"
}

it "rebases and merges worktree into main" test_integrate_merges_worktree_into_main

test_integrate_uses_fast_forward_only() {
  cd "$TEST_REPO"
  # Create worktree without initial commit
  wt add integrate-ff &>/dev/null

  # Get commit count before making changes
  local before_count=$(git -C "$TEST_REPO" rev-list --count main)

  # Make commits in worktree
  __fixture_commit_in_worktree "integrate-ff" "file1.txt" "First"
  __fixture_commit_in_worktree "integrate-ff" "file2.txt" "Second"

  # Integrate
  wt integrate integrate-ff &>/dev/null

  # Get commit count after
  local after_count=$(git -C "$TEST_REPO" rev-list --count main)

  # Should have exactly 2 more commits (no merge commit)
  local diff=$((after_count - before_count))
  assert_eq "$diff" "2" "adds commits without merge commit (fast-forward)"
}

it "uses fast-forward only" test_integrate_uses_fast_forward_only

test_integrate_shows_success_message() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-success"
  __fixture_create_worktree "integrate-success"

  __fixture_commit_in_worktree "integrate-success" "feature.txt" "Add feature"

  __capture wt integrate integrate-success
  assert_exit_code 0 "returns 0"
  assert_contains "$__STDOUT" "integrated" "shows success message"
  assert_contains "$__STDOUT" "integrate-success" "includes branch name"
  assert_contains "$__STDOUT" "main" "includes default branch name"
}

it "shows success message" test_integrate_shows_success_message

test_integrate_after_rebase() {
  cd "$TEST_REPO"
  __fixture_create_branch "integrate-rebase"
  __fixture_create_worktree "integrate-rebase"

  # Make a commit in main
  cd "$TEST_REPO"
  print "main-change" > main-file.txt
  git add main-file.txt
  git commit -m "Main change" &>/dev/null

  # Make a commit in worktree
  __fixture_commit_in_worktree "integrate-rebase" "worktree-file.txt" "Worktree change"

  # Integrate should rebase first, then merge
  wt integrate integrate-rebase &>/dev/null

  # Check that main has both changes
  local wt_path="$WT_DIR/origin/integrate-rebase"
  assert_file_exists "$TEST_REPO/main-file.txt" "main has main change"
  assert_file_exists "$TEST_REPO/worktree-file.txt" "main has worktree change"
}

it "rebases onto main before merging" test_integrate_after_rebase

# ── Helper assertion ──────────────────────────────────────────────────

assert_file_exists() {
  local file="$1"
  local msg="${2:-expected file to exist: $file}"

  if [[ -f "$file" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "file does not exist: $file"
  fi
}
