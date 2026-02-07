# zsh-treehouse

<p align="center"><img src="assets/banner.png" width="600" alt="treehouse banner"></p>

A zsh plugin that makes git worktrees easy to use. Stop stashing — start using worktrees.

## Installation

### Antigen

```zsh
antigen bundle 1henrypage/zsh-treehouse --branch=main
```

### Manual

Clone the repo and source it in your `.zshrc`:

```zsh
source /path/to/zsh-treehouse/zsh-treehouse.plugin.zsh
```

> **Note:** The source line must come **before** `compinit` for tab completion to work.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `WT_DIR` | `~/.treehouse` | Base directory where worktrees are stored |

Set it in your `.zshrc` before sourcing the plugin:

```zsh
export WT_DIR="$HOME/.treehouse"
```

## How It Works

Worktrees are created under `$WT_DIR/<repo-name>/<branch>`. The repo name is derived from the `origin` remote URL.

Branch names with slashes are flattened using `--` as a separator:

| Branch | Directory |
|---|---|
| `main` | `~/.treehouse/myrepo/main` |
| `feature/login` | `~/.treehouse/myrepo/feature--login` |
| `fix/auth/token` | `~/.treehouse/myrepo/fix--auth--token` |

## Commands

| Command | Description |
|---|---|
| `wt add <branch>` | Create a worktree for a branch |
| `wt rm [-f] <branch>` | Remove a worktree (prompts to delete branch) |
| `wt ls` | List all worktrees with status |
| `wt cd <branch>` | Change directory to a worktree |
| `wt base` | Change directory back to the main repo |
| `wt prune` | Clean up stale worktree references |
| `wt status` | Show git status across all worktrees |
| `wt lock <branch>` | Lock a worktree to prevent removal |
| `wt unlock <branch>` | Unlock a locked worktree |
| `wt run <branch> <cmd>` | Run a command inside a worktree |
| `wt help` | Show help |

## Examples

```zsh
# Create a worktree for a hotfix
wt add hotfix/payment-bug

# List your worktrees
wt ls

# Jump into the worktree
wt cd hotfix/payment-bug

# Go back to main repo
wt base

# Run tests in a worktree without leaving your current directory
wt run hotfix/payment-bug "make test"

# Check status of all worktrees at once
wt status

# Remove when done (will ask about deleting the branch too)
wt rm hotfix/payment-bug
```

## Tab Completion

Full zsh completion is included. Press `<TAB>` after any subcommand:

- `wt <TAB>` — shows all subcommands
- `wt add <TAB>` — shows available branches (excludes already checked-out)
- `wt cd <TAB>` — shows existing worktree branches
- `wt lock <TAB>` — shows only unlocked worktrees
- `wt unlock <TAB>` — shows only locked worktrees

## License

MIT
