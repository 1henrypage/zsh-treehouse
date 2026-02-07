# zsh-treehouse — Project Context

## What This Is

A zsh plugin (`zsh-treehouse`) that wraps `git worktree` into a concise `wt <subcommand>` interface. Loaded via Antigen or by sourcing directly. Worktrees are stored in `$WT_DIR/<repo-name>/<branch>` (default `~/.treehouse`).

## File Structure

```
zsh-treehouse.plugin.zsh   # Main plugin — all logic, helpers, subcommands, dispatcher
_wt                        # Zsh completion function (discovered via fpath)
README.md                  # User documentation
CLAUDE.md                  # This file
LICENSE                    # MIT
```

## Coding Conventions

- **Language:** Pure zsh (no bash-isms, no external dependencies beyond git)
- **Internal functions:** Prefixed `__wt_` (double underscore) to avoid namespace pollution
- **Subcommand functions:** Named `__wt_cmd_<name>`
- **Output:** Use `print -P` with `%F{color}` / `%B` / `%f%b` for colored output
- **Errors:** Go to stderr via `>&2`, always return non-zero
- **No pipes into while loops** that need to return values — use process substitution `< <(cmd)` instead
- **Porcelain parsing:** `git worktree list --porcelain` doesn't end with a trailing blank line — always handle the final entry after the loop

## Key Gotchas

- `wt cd` and `wt base` work because `wt` is a **sourced function**, not a script — `cd` changes the real shell directory
- `wt run` uses a **subshell** `(cd ... && eval ...)` deliberately to NOT change the directory
- Branch slashes become `--` in directory names: `feature/login` -> `feature--login`
- The plugin never needs to reverse-map directory names to branches — it uses `git worktree list --porcelain` which has real branch names
- `fpath` setup in the plugin file must happen before `compinit` — Antigen handles this, but manual users need to be aware
- `local` declarations inside while-loop bodies leak as debug output — extract loop bodies into helper functions (`__wt_print_ls_entry`, `__wt_print_status_entry`)

## How to Test

Source the plugin in any git repo and run through the commands:

```zsh
source ./zsh-treehouse.plugin.zsh

wt help                          # Should print usage
wt add test-branch               # Creates worktree at ~/.treehouse/<repo>/test-branch
wt add feature/slash-test        # Creates at ~/.treehouse/<repo>/feature--slash-test
wt ls                            # Shows both worktrees
wt cd test-branch                # Changes directory
wt base                          # Returns to main repo
wt status                        # Shows git status for all worktrees
wt run test-branch git log -3    # Runs command without cd
wt lock test-branch              # Locks
wt unlock test-branch            # Unlocks
wt rm test-branch                # Removes (prompts for branch deletion)

# Agent workflow commands
wt add agent-task                # Create worktree for agent work
wt run agent-task 'echo "work" > file.txt && git add -A && git commit -m "agent work"'
wt diff agent-task               # Show what changed vs main
wt integrate agent-task          # Rebase and merge into main
wt reset agent-task              # Reset worktree back to main
```

Error cases to verify:
- `wt ls` outside a git repo — should print "not inside a git repository"
- `wt cd nonexistent` — should print "no worktree found"
- `wt add` with no args — should print usage
- `wt integrate` with uncommitted changes — should refuse
- `wt reset` with dirty worktree — should refuse unless `-f` flag used

## Configuration

- `WT_DIR` env var controls base directory (default `~/.treehouse`)
