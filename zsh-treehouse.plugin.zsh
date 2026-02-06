#!/usr/bin/env zsh

# zsh-treehouse: A zsh plugin for managing git worktrees
# https://github.com/henry/zsh-treehouse

# Guard against double-sourcing
(( $+functions[wt] )) && return

# ── Configuration ─────────────────────────────────────────────────────
: ${WT_DIR:="$HOME/.treehouse"}

# Add plugin directory to fpath for completion discovery
fpath=(${0:A:h} $fpath)

# ── Color Constants ───────────────────────────────────────────────────
typeset -g __WT_RED='%F{red}'
typeset -g __WT_GREEN='%F{green}'
typeset -g __WT_YELLOW='%F{yellow}'
typeset -g __WT_BLUE='%F{blue}'
typeset -g __WT_CYAN='%F{cyan}'
typeset -g __WT_BOLD='%B'
typeset -g __WT_RESET='%f%b'

# ── Output Helpers ────────────────────────────────────────────────────
__wt_err() { print -P "${__WT_RED}error:${__WT_RESET} $1" >&2; }
__wt_info() { print -P "${__WT_CYAN}$1${__WT_RESET}"; }
__wt_success() { print -P "${__WT_GREEN}$1${__WT_RESET}"; }

# ── Internal Helpers ──────────────────────────────────────────────────

# Check that we are inside a git repository
__wt_ensure_git_repo() {
  git rev-parse --git-dir &>/dev/null || {
    __wt_err "not inside a git repository"
    return 1
  }
}

# Get the repository name from the remote URL or directory basename
__wt_repo_name() {
  local url
  url="$(git remote get-url origin 2>/dev/null)"
  if [[ -n "$url" ]]; then
    local name="${url##*/}"
    print "${name%.git}"
    return
  fi
  # Fallback: basename of main repo root
  print "$(basename "$(__wt_main_root)")"
}

# Get the absolute path to the main repository root
# Works from both the main worktree and linked worktrees
__wt_main_root() {
  local commondir
  commondir="$(git rev-parse --git-common-dir 2>/dev/null)"
  if [[ "$commondir" = /* ]]; then
    # Absolute path — we're in a linked worktree
    print "$(dirname "$commondir")"
  else
    # Relative path (.git) — we're in the main worktree
    print "$(git rev-parse --show-toplevel)"
  fi
}

# Convert a branch name to its worktree directory path
# Slashes in branch names are replaced with -- (e.g. feature/login -> feature--login)
__wt_branch_to_path() {
  local branch="$1"
  local repo_name="$(__wt_repo_name)"
  local safe_branch="${branch//\//--}"
  print "${WT_DIR}/${repo_name}/${safe_branch}"
}

# Given a branch name, find the worktree path
# Tries the computed conventional path first, then scans git worktree list
__wt_resolve_worktree_path() {
  local branch="$1"
  # Strategy 1: check the conventional path
  local expected="$(__wt_branch_to_path "$branch")"
  if [[ -d "$expected" ]]; then
    print "$expected"
    return
  fi
  # Strategy 2: scan porcelain output for matching branch
  local wt_path=""
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *)
        local b="${line#branch refs/heads/}"
        if [[ "$b" = "$branch" ]]; then
          print "$wt_path"
          return
        fi
        ;;
      "") wt_path="" ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)
  # Handle final entry (porcelain may not end with blank line)
  if [[ -n "$wt_path" ]]; then
    local lastline
    lastline="$(git worktree list --porcelain 2>/dev/null | tail -n1)"
    case "$lastline" in
      branch\ *)
        local b="${lastline#branch refs/heads/}"
        if [[ "$b" = "$branch" ]]; then
          print "$wt_path"
          return
        fi
        ;;
    esac
  fi
}

# Check if a worktree path has uncommitted changes
__wt_is_dirty() {
  local wt_path="$1"
  [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]]
}

# ── Subcommands ───────────────────────────────────────────────────────

__wt_cmd_add() {
  local branch="$1"
  [[ -z "$branch" ]] && { __wt_err "usage: wt add <branch>"; return 1; }
  __wt_ensure_git_repo || return 1

  local target="$(__wt_branch_to_path "$branch")"

  if [[ -d "$target" ]]; then
    __wt_err "worktree already exists at $target"
    return 1
  fi

  mkdir -p "$(dirname "$target")"

  if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    # Local branch exists
    git worktree add "$target" "$branch"
  else
    # Check for a remote tracking branch
    local remote_ref
    remote_ref="$(git for-each-ref --format='%(refname:short)' "refs/remotes/*/$branch" 2>/dev/null | head -1)"
    if [[ -n "$remote_ref" ]]; then
      git worktree add --track -b "$branch" "$target" "$remote_ref"
    else
      # Brand new branch off HEAD
      git worktree add -b "$branch" "$target"
    fi
  fi

  local rc=$?
  if (( rc == 0 )); then
    __wt_success "created worktree for '$branch' at $target"
  fi
  return $rc
}

__wt_cmd_rm() {
  local force=0
  local branch=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--force) force=1; shift ;;
      *) branch="$1"; shift ;;
    esac
  done

  [[ -z "$branch" ]] && { __wt_err "usage: wt rm [-f|--force] <branch>"; return 1; }
  __wt_ensure_git_repo || return 1

  local wt_path
  wt_path="$(__wt_resolve_worktree_path "$branch")"
  [[ -z "$wt_path" ]] && { __wt_err "no worktree found for branch '$branch'"; return 1; }

  local rm_args=()
  (( force )) && rm_args+=(--force)

  git worktree remove "${rm_args[@]}" "$wt_path" || return 1
  __wt_success "removed worktree at $wt_path"

  # Offer to delete the branch
  print -n "Also delete branch '$branch'? [y/N] "
  local reply
  read -q reply
  print # newline after read -q
  if [[ "$reply" = "y" ]]; then
    if (( force )); then
      git branch -D "$branch" 2>/dev/null
    else
      git branch -d "$branch" 2>/dev/null
    fi
    if (( $? == 0 )); then
      __wt_success "deleted branch '$branch'"
    else
      __wt_err "could not delete branch '$branch' (not fully merged? use -f)"
    fi
  fi
}

__wt_print_ls_entry() {
  local wt_path="$1" head="$2" branch="$3" locked="$4"
  local status_icon lock_icon=""
  if __wt_is_dirty "$wt_path"; then
    status_icon="%F{red}*%f"
  else
    status_icon="%F{green}ok%f"
  fi
  (( locked )) && lock_icon=" %F{yellow}[locked]%f"
  print -P "  ${__WT_BOLD}${__WT_CYAN}${branch:-'(detached)'}${__WT_RESET}  %F{yellow}${head}%f  ${wt_path}  ${status_icon}${lock_icon}"
}

__wt_cmd_ls() {
  __wt_ensure_git_repo || return 1

  local wt_path="" head="" branch="" locked=0
  local has_entries=0

  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      HEAD\ *) head="${line#HEAD }"
               head="${head[1,7]}" ;; # short hash
      branch\ *) branch="${line#branch refs/heads/}" ;;
      locked*) locked=1 ;;
      "")
        if [[ -n "$wt_path" ]]; then
          has_entries=1
          __wt_print_ls_entry "$wt_path" "$head" "$branch" "$locked"
        fi
        wt_path=""; head=""; branch=""; locked=0
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)

  # Handle final entry (porcelain doesn't end with blank line)
  if [[ -n "$wt_path" ]]; then
    has_entries=1
    __wt_print_ls_entry "$wt_path" "$head" "$branch" "$locked"
  fi

  if (( ! has_entries )); then
    __wt_info "no worktrees found"
  fi
}

__wt_cmd_cd() {
  local branch="$1"
  [[ -z "$branch" ]] && { __wt_err "usage: wt cd <branch>"; return 1; }
  __wt_ensure_git_repo || return 1

  local wt_path
  wt_path="$(__wt_resolve_worktree_path "$branch")"
  [[ -z "$wt_path" ]] && { __wt_err "no worktree found for branch '$branch'"; return 1; }

  cd "$wt_path" || return 1
}

__wt_cmd_base() {
  __wt_ensure_git_repo || return 1
  local mainroot
  mainroot="$(__wt_main_root)"
  cd "$mainroot" || return 1
}

__wt_cmd_prune() {
  __wt_ensure_git_repo || return 1
  git worktree prune -v
}

__wt_print_status_entry() {
  local wt_path="$1" branch="$2"
  print -P "\n${__WT_BOLD}${__WT_CYAN}${branch}${__WT_RESET}  ($wt_path)"
  local st
  st="$(git -C "$wt_path" status --short 2>/dev/null)"
  if [[ -z "$st" ]]; then
    print -P "  ${__WT_GREEN}clean${__WT_RESET}"
  else
    print "$st" | while IFS= read -r sline; do
      print "  $sline"
    done
  fi
}

__wt_cmd_status() {
  __wt_ensure_git_repo || return 1

  local wt_path="" branch="" has_entries=0

  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_path="${line#worktree }" ;;
      branch\ *) branch="${line#branch refs/heads/}" ;;
      "")
        if [[ -n "$wt_path" && -n "$branch" ]]; then
          has_entries=1
          __wt_print_status_entry "$wt_path" "$branch"
        fi
        wt_path=""; branch=""
        ;;
    esac
  done < <(git worktree list --porcelain 2>/dev/null)

  # Handle final entry
  if [[ -n "$wt_path" && -n "$branch" ]]; then
    has_entries=1
    __wt_print_status_entry "$wt_path" "$branch"
  fi

  if (( ! has_entries )); then
    __wt_info "no worktrees found"
  fi
}

__wt_cmd_lock() {
  local branch="$1"
  [[ -z "$branch" ]] && { __wt_err "usage: wt lock <branch>"; return 1; }
  __wt_ensure_git_repo || return 1

  local wt_path
  wt_path="$(__wt_resolve_worktree_path "$branch")"
  [[ -z "$wt_path" ]] && { __wt_err "no worktree found for branch '$branch'"; return 1; }

  git worktree lock "$wt_path" && __wt_success "locked worktree for '$branch'"
}

__wt_cmd_unlock() {
  local branch="$1"
  [[ -z "$branch" ]] && { __wt_err "usage: wt unlock <branch>"; return 1; }
  __wt_ensure_git_repo || return 1

  local wt_path
  wt_path="$(__wt_resolve_worktree_path "$branch")"
  [[ -z "$wt_path" ]] && { __wt_err "no worktree found for branch '$branch'"; return 1; }

  git worktree unlock "$wt_path" && __wt_success "unlocked worktree for '$branch'"
}

__wt_cmd_run() {
  local branch="$1"
  [[ -z "$branch" ]] && { __wt_err "usage: wt run <branch> <command...>"; return 1; }
  shift
  [[ $# -eq 0 ]] && { __wt_err "usage: wt run <branch> <command...>"; return 1; }
  __wt_ensure_git_repo || return 1

  local wt_path
  wt_path="$(__wt_resolve_worktree_path "$branch")"
  [[ -z "$wt_path" ]] && { __wt_err "no worktree found for branch '$branch'"; return 1; }

  # Run in a subshell so we don't change the current directory
  (cd "$wt_path" && eval "$@")
}

__wt_cmd_help() {
  print -P "${__WT_BOLD}wt${__WT_RESET} - git worktree manager\n"
  print    "Usage: wt <command> [args]\n"
  print    "Commands:"
  print    "  add <branch>          Create a worktree for a branch"
  print    "  rm [-f] <branch>      Remove a worktree (optionally delete branch)"
  print    "  ls                    List worktrees with status"
  print    "  cd <branch>           Change to a worktree directory"
  print    "  base                  Change to the main repo directory"
  print    "  prune                 Clean up stale worktree references"
  print    "  status                Show git status across all worktrees"
  print    "  lock <branch>         Lock a worktree"
  print    "  unlock <branch>       Unlock a worktree"
  print    "  run <branch> <cmd>    Run a command in a worktree"
  print    "  help                  Show this help"
  print    ""
  print    "Config:"
  print    "  WT_DIR                Worktree base directory (default: ~/.treehouse)"
}

# ── Main Dispatcher ───────────────────────────────────────────────────

wt() {
  local subcmd="$1"
  [[ -z "$subcmd" ]] && { __wt_cmd_help; return 0; }
  shift

  case "$subcmd" in
    add)    __wt_cmd_add "$@" ;;
    rm)     __wt_cmd_rm "$@" ;;
    ls)     __wt_cmd_ls "$@" ;;
    cd)     __wt_cmd_cd "$@" ;;
    base)   __wt_cmd_base "$@" ;;
    prune)  __wt_cmd_prune "$@" ;;
    status) __wt_cmd_status "$@" ;;
    lock)   __wt_cmd_lock "$@" ;;
    unlock) __wt_cmd_unlock "$@" ;;
    run)    __wt_cmd_run "$@" ;;
    help|-h|--help) __wt_cmd_help ;;
    *)      __wt_err "unknown command: $subcmd"; __wt_cmd_help; return 1 ;;
  esac
}
