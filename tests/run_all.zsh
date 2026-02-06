#!/usr/bin/env zsh

# Test Runner — Sources all test files and prints summary

# Get the directory where this script lives
TEST_DIR="${0:A:h}"

# Plugin file path (accessible to all test files)
typeset -g PLUGIN_FILE="$TEST_DIR/../zsh-treehouse.plugin.zsh"

# Source harness and fixtures
source "$TEST_DIR/harness.zsh"
source "$TEST_DIR/fixtures.zsh"

# Print TAP version
print "TAP version 13"

# Source all test files
for test_file in "$TEST_DIR"/test_*.zsh; do
  if [[ -f "$test_file" ]]; then
    source "$test_file"
  fi
done

# Print summary and exit with appropriate code
print_summary
exit $?
