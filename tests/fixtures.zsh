#!/usr/bin/env zsh

# Test Fixtures — Git repo setup and teardown
# ~60 lines of test environment management

# ── Fixture State ─────────────────────────────────────────────────────
typeset -g TEST_TMPDIR=""
typeset -g TEST_REPO=""
typeset -g TEST_BARE_REPO=""
typeset -g TEST_ORIG_PWD="$PWD"
typeset -g TEST_ORIG_WT_DIR="$WT_DIR"

# ── Fixture Creation ──────────────────────────────────────────────────

# Create a fresh git repository with initial commit
__fixture_create_repo() {
  TEST_TMPDIR=$(mktemp -d)
  TEST_BARE_REPO="$TEST_TMPDIR/origin.git"
  TEST_REPO="$TEST_TMPDIR/repo"

  # Create bare repo (simulates origin)
  git init --bare "$TEST_BARE_REPO" &>/dev/null

  # Clone it
  git clone "$TEST_BARE_REPO" "$TEST_REPO" &>/dev/null
  cd "$TEST_REPO"

  # Make initial commit
  print "initial" > README.md
  git add README.md
  git commit -m "Initial commit" &>/dev/null
  git push origin main &>/dev/null

  # Set up WT_DIR in test tmpdir
  export WT_DIR="$TEST_TMPDIR/treehouse"
  mkdir -p "$WT_DIR"
}

# Create a local branch with a commit
__fixture_create_branch() {
  local branch="$1"
  local safe_name="${branch//\//-}"
  git checkout -b "$branch" &>/dev/null
  print "content-$branch" > "file-$safe_name.txt"
  git add "file-$safe_name.txt"
  git commit -m "Add $branch" &>/dev/null
  git checkout main &>/dev/null
}

# Create a remote-only branch (push to bare repo, delete locally)
__fixture_create_remote_branch() {
  local branch="$1"
  git checkout -b "$branch" &>/dev/null
  print "remote-$branch" > "remote-$branch.txt"
  git add "remote-$branch.txt"
  git commit -m "Add remote $branch" &>/dev/null
  git push origin "$branch" &>/dev/null
  git checkout main &>/dev/null
  git branch -D "$branch" &>/dev/null
}

# Create a worktree using wt add
__fixture_create_worktree() {
  local branch="$1"
  wt add "$branch" &>/dev/null
}

# Make a worktree dirty (add uncommitted file)
__fixture_make_dirty() {
  local wt_path="$1"
  print "uncommitted" > "$wt_path/dirty.txt"
}

# Create a commit in a worktree
__fixture_commit_in_worktree() {
  local branch="$1"
  local filename="$2"
  local message="$3"
  local wt_path="$(__wt_branch_to_path "$branch")"

  print "content-$filename" > "$wt_path/$filename"
  git -C "$wt_path" add "$filename"
  git -C "$wt_path" commit -m "$message" &>/dev/null
}

# ── Fixture Teardown ──────────────────────────────────────────────────

__fixture_teardown() {
  # Return to original directory
  cd "$TEST_ORIG_PWD"

  # Restore original WT_DIR
  export WT_DIR="$TEST_ORIG_WT_DIR"

  # Clean up temp directory
  if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
    rm -rf "$TEST_TMPDIR"
  fi

  TEST_TMPDIR=""
  TEST_REPO=""
  TEST_BARE_REPO=""
}

# ── Double-sourcing Helper ────────────────────────────────────────────

# Unload the wt function to allow re-sourcing the plugin
__fixture_unload_plugin() {
  if (( $+functions[wt] )); then
    unfunction wt
  fi
  # Unload all internal functions too
  local func
  for func in ${(k)functions}; do
    if [[ "$func" == __wt_* ]]; then
      unfunction "$func"
    fi
  done
}
