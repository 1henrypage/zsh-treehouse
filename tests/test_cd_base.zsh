#!/usr/bin/env zsh

# Tests for wt cd and wt base
# Note: These tests call wt cd/base directly (not via __capture)
# since cd must affect the real shell's PWD

describe "wt cd and wt base"

setup() {
  __fixture_unload_plugin
  source "$PLUGIN_FILE"
  __fixture_create_repo
}

teardown() {
  __fixture_teardown
}

# ── wt cd ─────────────────────────────────────────────────────────────

test_cd_no_args_shows_error() {
  cd "$TEST_REPO"
  __capture wt cd
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "usage: wt cd <branch>" "shows usage"
}

it "cd: shows error with no arguments" test_cd_no_args_shows_error

test_cd_nonexistent_branch_shows_error() {
  cd "$TEST_REPO"
  __capture wt cd nonexistent
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "no worktree found for branch 'nonexistent'" "shows error"
}

it "cd: shows error for nonexistent branch" test_cd_nonexistent_branch_shows_error

test_cd_changes_directory() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-cd"
  wt add test-cd &>/dev/null
  wt cd test-cd &>/dev/null
  local expected="$WT_DIR/origin/test-cd"
  assert_eq "$PWD" "$expected" "changes to worktree directory"
}

it "cd: changes to worktree directory" test_cd_changes_directory

test_cd_works_with_slash_branch() {
  cd "$TEST_REPO"
  __fixture_create_branch "feature/cd-slash"
  wt add feature/cd-slash &>/dev/null
  wt cd feature/cd-slash &>/dev/null
  local expected="$WT_DIR/origin/feature--cd-slash"
  assert_eq "$PWD" "$expected" "changes to slash branch worktree"
}

it "cd: works with slash branch" test_cd_works_with_slash_branch

# ── wt base ───────────────────────────────────────────────────────────

test_base_changes_to_main_root() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-base"
  wt add test-base &>/dev/null
  wt cd test-base &>/dev/null
  wt base &>/dev/null
  assert_eq "$PWD" "$TEST_REPO" "returns to main repo"
}

it "base: changes to main repository" test_base_changes_to_main_root

test_base_works_from_linked_worktree() {
  cd "$TEST_REPO"
  __fixture_create_branch "test-base-linked"
  wt add test-base-linked &>/dev/null
  local wt_path="$WT_DIR/origin/test-base-linked"
  cd "$wt_path"
  wt base &>/dev/null
  assert_eq "$PWD" "$TEST_REPO" "returns to main repo from linked worktree"
}

it "base: works from linked worktree" test_base_works_from_linked_worktree

test_base_outside_repo_shows_error() {
  cd /tmp
  __capture wt base
  assert_exit_code 1 "returns 1"
  assert_contains "$__STDERR" "not inside a git repository" "shows error"
}

it "base: shows error outside repository" test_base_outside_repo_shows_error

# ── Round-trip ────────────────────────────────────────────────────────

test_cd_then_base_returns_to_main() {
  cd "$TEST_REPO"
  local orig_pwd="$PWD"
  __fixture_create_branch "roundtrip"
  wt add roundtrip &>/dev/null
  wt cd roundtrip &>/dev/null
  wt base &>/dev/null
  assert_eq "$PWD" "$orig_pwd" "round-trip cd+base returns to original"
}

it "round-trip: cd then base returns to main" test_cd_then_base_returns_to_main
