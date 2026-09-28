#!/usr/bin/env bash
# Creates a dedicated git worktree for a new workstream branch, instead of
# working in the shared `orchestrator/`/`expense-buddy` checkout every
# session's terminal has pointed at until now.
#
# Why this exists (COORDINATION.md, the shared-checkout git race): this
# project hit the same class of problem repeatedly because every session
# ran git commands against the exact same working directory and index —
# a live merge conflict one session was mid-resolving showed up in another
# session's `git status`; a broad `git add`/`git commit` in one session
# swept up another session's already-staged-but-uncommitted files into the
# wrong commit (Step 3 Component 3's files landing inside the Component 4
# commit is the concrete incident that prompted this fix). A `git worktree`
# gives each session its own working directory and its own index, all
# still sharing the same underlying repo/history/remote — `git add`,
# `git commit`, and even a mid-resolution merge conflict in one worktree
# are physically incapable of touching another worktree's files, since
# they're different directories on disk.
#
# Usage:
#   scripts/new-worktree.sh orchestrator my-branch-name
#   scripts/new-worktree.sh expense-buddy my-branch-name
#
# Creates day2/worktrees/<repo>-<branch>/, checked out on a fresh branch
# named <branch>, based on the real origin/main (fetched first, so you
# never accidentally branch off a stale local main). cd into it and work
# there for the whole lifetime of that workstream; nothing you do inside
# it can affect the shared checkout or any other session's worktree.
#
# When the branch merges (or you're done): `git worktree remove <path>`
# from any worktree (including the shared one), then delete the branch
# with `git branch -d <branch>` if it's not already gone.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <orchestrator|expense-buddy> <branch-name>" >&2
  exit 1
fi

REPO="$1"
BRANCH="$2"

case "$REPO" in
  orchestrator) SRC="/Users/pabloguillen/day2/orchestrator" ;;
  expense-buddy) SRC="/Users/pabloguillen/expense-buddy" ;;
  *)
    echo "Unknown repo '$REPO' — must be 'orchestrator' or 'expense-buddy'." >&2
    exit 1
    ;;
esac

WORKTREE_DIR="/Users/pabloguillen/day2/worktrees/${REPO}-${BRANCH}"

if [ -e "$WORKTREE_DIR" ]; then
  echo "Worktree directory already exists: $WORKTREE_DIR" >&2
  exit 1
fi

# Run from the shared checkout only to fetch/create the worktree itself —
# this is the one operation that's safe to do there regardless of what
# else is going on, since `git worktree add` doesn't touch the shared
# checkout's own working directory or index.
cd "$SRC"
git fetch origin --quiet
git worktree add "$WORKTREE_DIR" -b "$BRANCH" origin/main

echo ""
echo "Worktree ready: $WORKTREE_DIR"
echo "Branch: $BRANCH (based on origin/main, fetched just now)"
echo ""
echo "cd $WORKTREE_DIR"
echo "  — this directory is yours alone until the branch merges. Nothing"
echo "    here can be affected by (or affect) the shared checkout or any"
echo "    other session's worktree."
echo ""
echo "When done: git worktree remove $WORKTREE_DIR (run from anywhere in"
echo "the repo), then git branch -d $BRANCH if it isn't already gone."
