#!/usr/bin/env zsh

# Test Harness — TAP output, assertions, test lifecycle
# ~100 lines of pure zsh test infrastructure

# ── Global State ──────────────────────────────────────────────────────
typeset -g __TEST_COUNT=0
typeset -g __TEST_PASSED=0
typeset -g __TEST_FAILED=0
typeset -g __CURRENT_GROUP=""
typeset -g __STDOUT=""
typeset -g __STDERR=""
typeset -g __EXIT_CODE=0

# Temp files for output capture
typeset -g __tmpout=$(mktemp)
typeset -g __tmperr=$(mktemp)

# Clean up temp files on exit
trap "rm -f $__tmpout $__tmperr" EXIT INT TERM

# ── Output Capture ────────────────────────────────────────────────────

# Strip ANSI escape codes from a string
__strip_ansi() {
  print -r -- "$1" | sed $'s/\033\[[0-9;]*m//g'
}

# Normalize path (resolve symlinks like /var -> /private/var on macOS)
__normalize_path() {
  if [[ -e "$1" ]]; then
    print -r -- "${1:A}"
  else
    print -r -- "$1"
  fi
}

# Capture stdout, stderr, and exit code from a command
__capture() {
  __STDOUT=""
  __STDERR=""
  __EXIT_CODE=0

  # Run command and capture outputs
  {
    "$@"
  } >$__tmpout 2>$__tmperr
  __EXIT_CODE=$?

  __STDOUT="$(<$__tmpout)"
  __STDERR="$(<$__tmperr)"

  # Strip ANSI codes for easier assertions
  __STDOUT="$(__strip_ansi "$__STDOUT")"
  __STDERR="$(__strip_ansi "$__STDERR")"
}

# ── Assertions ────────────────────────────────────────────────────────

__test_pass() {
  (( __TEST_COUNT++ ))
  (( __TEST_PASSED++ ))
  print "ok $__TEST_COUNT - $1"
}

__test_fail() {
  (( __TEST_COUNT++ ))
  (( __TEST_FAILED++ ))
  print "not ok $__TEST_COUNT - $1"
  [[ -n "$2" ]] && print "  # $2"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-expected equality}"

  # Normalize paths if both look like absolute paths
  if [[ "$actual" == /* && "$expected" == /* ]]; then
    actual="$(__normalize_path "$actual")"
    expected="$(__normalize_path "$expected")"
  fi

  if [[ "$actual" = "$expected" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "expected '$expected', got '$actual'"
  fi
}

assert_neq() {
  local actual="$1"
  local expected="$2"
  local msg="${3:-expected inequality}"

  if [[ "$actual" != "$expected" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "expected not '$expected', but got it"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-expected to contain substring}"

  if [[ "$haystack" == *"$needle"* ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "expected to find '$needle' in '$haystack'"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-expected not to contain substring}"

  if [[ "$haystack" != *"$needle"* ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "did not expect to find '$needle'"
  fi
}

assert_match() {
  local string="$1"
  local pattern="$2"
  local msg="${3:-expected to match regex}"

  if [[ "$string" =~ $pattern ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "expected '$string' to match pattern '$pattern'"
  fi
}

assert_exit_code() {
  local expected="$1"
  local msg="${2:-expected exit code $expected}"

  if (( __EXIT_CODE == expected )); then
    __test_pass "$msg"
  else
    __test_fail "$msg" "expected exit code $expected, got $__EXIT_CODE"
  fi
}

assert_dir_exists() {
  local dir="$1"
  local msg="${2:-expected directory to exist: $dir}"

  if [[ -d "$dir" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "directory does not exist: $dir"
  fi
}

assert_dir_not_exists() {
  local dir="$1"
  local msg="${2:-expected directory not to exist: $dir}"

  if [[ ! -d "$dir" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "directory exists but shouldn't: $dir"
  fi
}

assert_file_exists() {
  local file="$1"
  local msg="${2:-expected file to exist: $file}"

  if [[ -f "$file" ]]; then
    __test_pass "$msg"
  else
    __test_fail "$msg" "file does not exist: $file"
  fi
}

# ── Test Lifecycle ────────────────────────────────────────────────────

describe() {
  __CURRENT_GROUP="$1"
  print "\n# $__CURRENT_GROUP"
}

it() {
  local description="$1"
  local test_func="$2"

  # Call setup if defined
  if (( $+functions[setup] )); then
    setup
  fi

  # Run the test
  $test_func

  # Call teardown if defined
  if (( $+functions[teardown] )); then
    teardown
  fi
}

# ── Summary ───────────────────────────────────────────────────────────

print_summary() {
  print "\n1..$__TEST_COUNT"
  print "# tests $__TEST_COUNT"
  print "# pass $__TEST_PASSED"
  print "# fail $__TEST_FAILED"

  if (( __TEST_FAILED > 0 )); then
    return 1
  fi
  return 0
}
