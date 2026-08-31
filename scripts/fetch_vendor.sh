#!/usr/bin/env bash
# Restore the four upstream projects the bench is built from, at the commits
# pinned in vendor.lock.
#
#   scripts/fetch_vendor.sh            all four
#   scripts/fetch_vendor.sh frappe     one of them
#   scripts/fetch_vendor.sh --check    verify checkouts match the lock
#
# Why this exists
# ---------------
# `git clone` of this repository used to give you a tree that could not build
# itself: bootstrap.sh reads frappe, erpnext and crm from /workspace/vendor,
# which is a bind mount of directories a developer had cloned by hand. Nothing
# said which versions, and all four sat on floating branches — so two clones a
# week apart produced different products and neither could be told from the
# other.
#
# What this is not
# ----------------
# Not a package manager. It is `git clone` plus a commit, because that is all
# the problem needs. The four projects stay out of our history (3.8 GB of
# somebody else's commits) and stay pristine on disk: nothing here writes into
# a checkout except to move it to the pinned commit.

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$ROOT/vendor.lock"
CHECK_ONLY=0
WANTED=()

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    -*) echo "unknown option: $arg" >&2; exit 2 ;;
    *) WANTED+=("$arg") ;;
  esac
done

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$LOCK" ] || fail "vendor.lock is missing"

status=0

while read -r name url commit branch; do
  case "$name" in ''|\#*) continue ;; esac
  if [ ${#WANTED[@]} -gt 0 ] && [[ ! " ${WANTED[*]} " == *" $name "* ]]; then
    continue
  fi

  dir="$ROOT/$name"

  if [ "$CHECK_ONLY" = 1 ]; then
    if [ ! -d "$dir/.git" ]; then
      warn "  $name: missing"
      status=1
    elif [ "$(git -C "$dir" rev-parse HEAD)" != "$commit" ]; then
      warn "  $name: at $(git -C "$dir" rev-parse --short HEAD), lock says ${commit:0:10}"
      status=1
    else
      printf '  %-10s %s ✓\n' "$name" "${commit:0:10}"
    fi
    continue
  fi

  if [ ! -d "$dir/.git" ]; then
    say "$name — cloning ($branch, then pinning)"
    # Not --depth 1: the pinned commit is usually not the branch tip, and a
    # shallow clone cannot check it out. Bench also reads describe/tags.
    git clone --branch "$branch" "$url" "$dir"
  fi

  current="$(git -C "$dir" rev-parse HEAD)"
  if [ "$current" = "$commit" ]; then
    printf '  %-10s already at %s\n' "$name" "${commit:0:10}"
    continue
  fi

  # Refuse to move a checkout somebody is working in. Losing an upstream fix
  # somebody was testing is a worse outcome than stopping.
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    fail "$name has local changes. Commit, stash or remove them, then re-run."
  fi

  say "$name — moving ${current:0:10} → ${commit:0:10}"
  git -C "$dir" fetch --quiet origin "$commit" 2>/dev/null || git -C "$dir" fetch --quiet origin
  git -C "$dir" checkout --quiet "$commit"
done < "$LOCK"

if [ "$CHECK_ONLY" = 1 ]; then
  [ "$status" = 0 ] && say "vendor checkouts match vendor.lock" || warn "run scripts/fetch_vendor.sh to fix"
  exit "$status"
fi

say "vendor restored"
