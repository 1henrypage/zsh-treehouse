#!/usr/bin/env zsh

# Tests for __wt_* helper functions

describe "Helper Functions"

setup() {
  __fixture_unload_plugin
  source "$PLUGIN_FILE"
  __fixture_create_repo
}

teardown() {
  __fixture_teardown
}

# ── __wt_err ──────────────────────────────────────────────────────────

test_wt_err_prints_to_stderr() {
  __capture __wt_err "test error message"
  assert_contains "$__STDERR" "error:" "prints 'error:' prefix"
  assert_contains "$__STDERR" "test error message" "includes message"
}

it "outputs error to stderr" test_wt_err_prints_to_stderr

# ── __wt_info ─────────────────────────────────────────────────────────

test_wt_info_prints_to_stdout() {
  __capture __wt_info "test info"
  assert_contains "$__STDOUT" "test info" "prints info message"
}

it "outputs info to stdout" test_wt_info_prints_to_stdout

# ── __wt_success ──────────────────────────────────────────────────────

test_wt_success_prints_to_stdout() {
  __capture __wt_success "test success"
  assert_contains "$__STDOUT" "test success" "prints success message"
}

it "outputs success to stdout" test_wt_success_prints_to_stdout

# ── __wt_ensure_git_repo ──────────────────────────────────────────────

test_ensure_git_repo_succeeds_in_repo() {
  cd "$TEST_REPO"
  __capture __wt_ensure_git_repo
  assert_exit_code 0 "returns 0 inside git repo"
}

it "succeeds inside git repository" test_ensure_git_repo_succeeds_in_repo

test_ensure_git_repo_fails_outside_repo() {
  cd /tmp
  __capture __wt_ensure_git_repo
  assert_exit_code 1 "returns 1 outside git repo"
  assert_contains "$__STDERR" "not inside a git repository" "prints error message"
}

it "fails outside git repository" test_ensure_git_repo_fails_outside_repo

# ── __wt_repo_name ────────────────────────────────────────────────────

test_repo_name_from_origin_url() {
  cd "$TEST_REPO"
  local name=$(__wt_repo_name)
  assert_eq "$name" "origin" "extracts name from origin URL"
}

it "extracts repo name from origin URL" test_repo_name_from_origin_url

test_repo_name_fallback_to_basename() {
  cd "$TEST_REPO"
  # Remove origin temporarily
  local orig_url=$(git remote get-url origin)
  git remote remove origin &>/dev/null
  local name=$(__wt_repo_name)
  assert_eq "$name" "repo" "falls back to directory basename"
  # Restore origin
  git remote add origin "$orig_url" &>/dev/null
}

it "falls back to basename when no origin" test_repo_name_fallback_to_basename

# ── __wt_main_root ────────────────────────────────────────────────────

test_main_root_from_main_worktree() {
  cd "$TEST_REPO"
  local root=$(__wt_main_root)
  assert_eq "$root" "$TEST_REPO" "returns main repo path"
}

it "returns main root from main worktree" test_main_root_from_main_worktree

test_main_root_from_linked_worktree() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-branch"
  __fixture_create_worktree "test-branch"
  local wt_path="$WT_DIR/origin/test-branch"
  cd "$wt_path"
  local root=$(__wt_main_root)
  assert_eq "$root" "$TEST_REPO" "returns main repo path from linked worktree"
}

it "returns main root from linked worktree" test_main_root_from_linked_worktree

# ── __wt_branch_to_path ───────────────────────────────────────────────

test_branch_to_path_simple() {
  cd "$TEST_REPO"
  local path=$(__wt_branch_to_path "simple")
  local expected="$WT_DIR/origin/simple"
  assert_eq "$path" "$expected" "converts simple branch name"
}

it "converts simple branch to path" test_branch_to_path_simple

test_branch_to_path_with_slashes() {
  cd "$TEST_REPO"
  local path=$(__wt_branch_to_path "feature/login")
  local expected="$WT_DIR/origin/feature--login"
  assert_eq "$path" "$expected" "converts slashes to double-dash"
}

it "converts slashes to -- in path" test_branch_to_path_with_slashes

# ── __wt_resolve_worktree_path ────────────────────────────────────────

test_resolve_worktree_finds_existing() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-resolve"
  __fixture_create_worktree "test-resolve"
  local path=$(__wt_resolve_worktree_path "test-resolve")
  local expected="$WT_DIR/origin/test-resolve"
  assert_eq "$path" "$expected" "resolves existing worktree path"
}

it "resolves existing worktree path" test_resolve_worktree_finds_existing

test_resolve_worktree_returns_empty_for_nonexistent() {
  cd "$TEST_REPO"
  local path=$(__wt_resolve_worktree_path "nonexistent")
  assert_eq "$path" "" "returns empty for nonexistent worktree"
}

it "returns empty for nonexistent worktree" test_resolve_worktree_returns_empty_for_nonexistent

test_resolve_worktree_with_slashes() {
  cd "$TEST_REPO"
  __fixture_create_branch "feature/slash"
  __fixture_create_worktree "feature/slash"
  local path=$(__wt_resolve_worktree_path "feature/slash")
  local expected="$WT_DIR/origin/feature--slash"
  assert_eq "$path" "$expected" "resolves slash branch correctly"
}

it "resolves worktree with slash branch" test_resolve_worktree_with_slashes

# ── __wt_is_dirty ─────────────────────────────────────────────────────

test_is_dirty_returns_false_for_clean() {
  cd "$TEST_REPO"
  __wt_is_dirty "$TEST_REPO"
  local rc=$?
  assert_eq "$rc" "1" "returns 1 (false) for clean worktree"
}

it "returns false for clean worktree" test_is_dirty_returns_false_for_clean

test_is_dirty_returns_true_for_dirty() {
  cd "$TEST_REPO"
  print "uncommitted" > "$TEST_REPO/dirty.txt"
  __wt_is_dirty "$TEST_REPO"
  local rc=$?
  assert_eq "$rc" "0" "returns 0 (true) for dirty worktree"
}

it "returns true for dirty worktree" test_is_dirty_returns_true_for_dirty

# ── __wt_default_branch ───────────────────────────────────────────────

test_default_branch_returns_main() {
  cd "$TEST_REPO"
  local branch=$(__wt_default_branch)
  assert_eq "$branch" "main" "returns 'main' when it exists"
}

it "returns main when it exists" test_default_branch_returns_main

test_default_branch_returns_master_when_no_main() {
  cd "$TEST_REPO"
  # Rename main to master
  git branch -m main master &>/dev/null
  local branch=$(__wt_default_branch)
  assert_eq "$branch" "master" "returns 'master' when main doesn't exist"
  # Rename back
  git branch -m master main &>/dev/null
}

it "returns master when main doesn't exist" test_default_branch_returns_master_when_no_main

test_default_branch_fallback_to_head() {
  cd "$TEST_REPO"
  # Create and checkout a different branch
  git checkout -b custom-default &>/dev/null
  # Delete main
  git branch -D main &>/dev/null
  local branch=$(__wt_default_branch)
  assert_eq "$branch" "custom-default" "falls back to HEAD branch"
  # Restore main
  git branch main origin/main &>/dev/null
  git checkout main &>/dev/null
  git branch -D custom-default &>/dev/null
}

it "falls back to HEAD branch when neither main nor master exists" test_default_branch_fallback_to_head
