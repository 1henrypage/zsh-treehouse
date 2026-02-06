# zsh-treehouse Test Suite

A lightweight custom test harness written in pure zsh, producing TAP output.

## Running Tests

Run the full test suite:

```zsh
zsh tests/run_all.zsh
```

The exit code will be 0 if all tests pass, 1 if any fail.

## Test Files

- **harness.zsh** (~100 lines) - Test framework with assertions, output capture, TAP output
- **fixtures.zsh** (~60 lines) - Git repo setup, worktree fixtures, teardown
- **run_all.zsh** - Test runner that sources all test files and prints summary
- **test_helpers.zsh** - Tests for `__wt_*` helper functions (19 tests)
- **test_dispatcher.zsh** - Tests for command routing and help (21 tests)
- **test_add.zsh** - Tests for `wt add` (15 tests)
- **test_cd_base.zsh** - Tests for `wt cd` and `wt base` (11 tests)
- **test_ls.zsh** - Tests for `wt ls` (13 tests)
- **test_status.zsh** - Tests for `wt status` (13 tests)
- **test_lock_unlock.zsh** - Tests for `wt lock` and `wt unlock` (15 tests)
- **test_rm.zsh** - Tests for `wt rm` (13 tests)
- **test_run.zsh** - Tests for `wt run` (16 tests)

**Total: 140 tests**

## Test Harness Features

### Assertions

- `assert_eq <actual> <expected> [msg]` - String equality (auto-normalizes paths)
- `assert_neq <actual> <expected> [msg]` - String inequality
- `assert_contains <haystack> <needle> [msg]` - Substring match
- `assert_not_contains <haystack> <needle> [msg]` - Substring absence
- `assert_match <string> <pattern> [msg]` - Regex match
- `assert_exit_code <code> [msg]` - Exit code check
- `assert_dir_exists <path> [msg]` - Directory existence
- `assert_dir_not_exists <path> [msg]` - Directory absence
- `assert_file_exists <path> [msg]` - File existence

### Output Capture

```zsh
__capture command arg1 arg2
# Access results:
echo "$__STDOUT"    # Captured stdout (ANSI-stripped)
echo "$__STDERR"    # Captured stderr (ANSI-stripped)
echo "$__EXIT_CODE" # Exit code
```

### Test Lifecycle

```zsh
describe "Test Group Name"

setup() {
  # Runs before each test
  __fixture_unload_plugin
  source "$PLUGIN_FILE"
  __fixture_create_repo
}

teardown() {
  # Runs after each test
  __fixture_teardown
}

test_something() {
  # Test implementation
  assert_eq "foo" "foo" "should match"
}

it "description" test_something
```

## Test Fixtures

Each test gets a fresh isolated environment:

- `__fixture_create_repo` - Creates bare repo, clones it, makes initial commit
- `__fixture_create_branch <name>` - Creates local branch with commit
- `__fixture_create_remote_branch <name>` - Creates remote-only branch
- `__fixture_create_worktree <name>` - Calls `wt add` to create worktree
- `__fixture_make_dirty <path>` - Adds uncommitted file to worktree
- `__fixture_teardown` - Cleans up temp dir, restores environment
- `__fixture_unload_plugin` - Removes `wt` function for fresh sourcing

## Design Philosophy

- **Pure zsh** - No external dependencies beyond git
- **Fast** - Lightweight harness, ~2 seconds for full suite
- **TAP output** - Standard Test Anything Protocol format
- **Isolated** - Each test gets fresh git repo in temp directory
- **No mocks** - Tests use real git operations for accuracy

## Known Limitations

- Interactive input tests (e.g., `wt rm` branch deletion prompt) are limited because `read -q` reads from `/dev/tty` directly, not stdin
- Tests run sequentially (no parallelization)

## Adding New Tests

1. Create `tests/test_<feature>.zsh`
2. Follow the pattern in existing test files:
   - Start with `describe "Feature Name"`
   - Define `setup()` and `teardown()`
   - Write test functions
   - Register with `it "description" test_function_name`
3. The test will be automatically discovered by `run_all.zsh`
