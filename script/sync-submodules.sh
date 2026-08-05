#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ── lock: prevent concurrent runs ─────────────────────────────────────────────
LOCKFILE="$ROOT_DIR/.sync-submodules.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "[ERROR] Another instance of sync-submodules is already running. Exiting."
  exit 1
fi
trap 'rm -f "$LOCKFILE"' EXIT

# ── helpers ────────────────────────────────────────────────────────────────────

# Returns 0 (true) if the given path has ANY uncommitted/untracked changes
submodule_is_dirty() {
  local path="$1"
  [[ ! -d "$path/.git" && ! -f "$path/.git" ]] && return 1
  pushd "$path" > /dev/null
  local dirty=1
  if ! git diff --quiet          2>/dev/null || \
     ! git diff --cached --quiet 2>/dev/null || \
     [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    dirty=0
  fi
  popd > /dev/null
  return $dirty
}

# Returns 0 (true) if the repo is currently mid-rebase/merge/cherry-pick
repo_is_mid_operation() {
  local path="$1"
  local git_dir
  git_dir=$(git -C "$path" rev-parse --git-dir 2>/dev/null) || return 1
  [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" || \
     -f "$git_dir/MERGE_HEAD"   || -f "$git_dir/CHERRY_PICK_HEAD" ]]
}

# Backs up a dirty submodule to .sync-backup/<dir>-<timestamp>/
# Uses rsync if available (faster, supports large repos), falls back to cp
backup_submodule() {
  local path="$1"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_dir="$ROOT_DIR/.sync-backup/${path}-${timestamp}"
  echo "  [BACKUP] Saving '$path' -> '$backup_dir' ..."
  mkdir -p "$backup_dir"
  if command -v rsync &>/dev/null; then
    rsync -a --exclude='.git/' "$path/" "$backup_dir/"
  else
    cp -a "$path/." "$backup_dir/"
  fi
  echo "  [BACKUP] Restore: cp -a '${backup_dir}/.' '${ROOT_DIR}/${path}/'"
}

# Resolve default branch from local remote-tracking ref (no network needed)
get_default_branch() {
  git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "main"
}

# ── read .gitmodules ───────────────────────────────────────────────────────────

if [[ ! -f .gitmodules ]]; then
  echo "[INFO] No .gitmodules found. Nothing to do."
  exit 0
fi

mapfile -t SUBMODULE_NAMES < <(git config -f .gitmodules --get-regexp 'submodule\..*\.path' | sed -E 's/^submodule\.(.+)\.path .*/\1/')

declare -A SUB_PATH SUB_URL
SUBMODULE_PATHS=()
for name in "${SUBMODULE_NAMES[@]}"; do
  SUB_PATH["$name"]=$(git config -f .gitmodules --get "submodule.$name.path")
  SUB_URL["$name"]=$(git config -f .gitmodules --get "submodule.$name.url")
  SUBMODULE_PATHS+=("${SUB_PATH[$name]}")
done

# Build exclusion list: always-safe dirs + the script dir itself
SCRIPT_DIR="$(basename "$(dirname "${BASH_SOURCE[0]}")")"
EXCLUDED_DIRS=("$SCRIPT_DIR" "docs" "deploy" ".sync-backup")

is_excluded() {
  local dir="$1"
  for ex in "${EXCLUDED_DIRS[@]}"; do
    [[ "$dir" == "$ex" ]] && return 0
  done
  return 1
}

# ── step 1: remove stale submodules ───────────────────────────────────────────

echo "==> Removing folders that are no longer registered as submodules..."
stale_removed=false
for dir_slash in */; do
  dir="${dir_slash%/}"
  is_excluded "$dir" && continue
  found=false
  for sub in "${SUBMODULE_PATHS[@]}"; do
    [[ "$sub" == "$dir" ]] && found=true && break
  done
  # Detect dangling gitlinks (HEAD may not exist yet on fresh repos)
  is_gitlink=0
  if git rev-parse --verify HEAD &>/dev/null; then
    is_gitlink=$(git ls-tree HEAD "$dir" 2>/dev/null | awk '{print $1}' | grep -c '^160000$' || true)
  fi
  if [[ "$found" == false ]] && ([[ -e "$dir/.git" ]] || [[ "$is_gitlink" -gt 0 ]]); then
    # Guard: abort if mid-operation
    if repo_is_mid_operation "$dir"; then
      echo "  [ERROR] '$dir' is mid-rebase/merge — skipping removal to avoid data loss."
      continue
    fi
    # Guard: backup if dirty
    if submodule_is_dirty "$dir"; then
      echo "  [WARN] '$dir' has uncommitted changes — backing up before removal."
      backup_submodule "$dir"
    fi
    echo "  -> Removing stale submodule: $dir"
    git submodule deinit -f "$dir" 2>/dev/null || true
    git rm --cached "$dir" 2>/dev/null || true
    rm -rf "$dir"
    stale_removed=true
  fi
done

if [[ "$stale_removed" == true ]]; then
  echo "==> Committing removal of stale submodule gitlinks..."
  git commit -m "chore: remove stale submodule gitlinks" || true
fi

# ── step 2: sync URLs ──────────────────────────────────────────────────────────

echo "==> Syncing git submodule URLs from .gitmodules..."
git submodule sync --recursive

# ── step 3: re-register renamed/url-changed submodules ────────────────────────

echo "==> Detecting new/renamed submodules and re-registering them..."
for name in "${SUBMODULE_NAMES[@]}"; do
  path="${SUB_PATH[$name]}"
  url="${SUB_URL[$name]}"
  registered_url=$(git config -f .git/config --get "submodule.$name.url" 2>/dev/null || true)
  if [[ -z "$registered_url" || "$registered_url" != "$url" ]]; then
    # Guard: abort if mid-operation
    if [[ -d "$path" ]] && repo_is_mid_operation "$path"; then
      echo "  [ERROR] '$path' is mid-rebase/merge — skipping re-registration."
      continue
    fi
    # Guard: backup if dirty
    if [[ -d "$path" ]] && submodule_is_dirty "$path"; then
      echo "  [WARN] '$path' has uncommitted changes — backing up before re-registration."
      backup_submodule "$path"
    fi
    echo "  -> Re-registering submodule: $path -> $url"
    git submodule deinit -f "$path" 2>/dev/null || true
    git rm --cached "$path" 2>/dev/null || true
    rm -rf "$path" ".git/modules/$name"
    git submodule add -f "$url" "$path"
  fi
done

# ── step 4: init new submodules ───────────────────────────────────────────────

echo "==> Initializing new submodules (skip existing)..."
git submodule update --init --recursive --no-fetch 2>/dev/null || \
  git submodule update --init --recursive

# ── step 5: pull latest (preserving local changes) ────────────────────────────
# NOTE: Uses POSIX sh syntax only — git submodule foreach runs via /bin/sh (dash).
# Do NOT use [[ ]], bash arrays, or other bash-specific syntax here.

echo "==> Pulling latest on each submodule's default branch (preserving local changes)..."
git submodule foreach --recursive '
  # ── resolve default branch from local ref (no network required) ──────────
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed "s|refs/remotes/origin/||")
  if [ -z "$default_branch" ]; then
    # fallback: try remote (requires network); if unavailable, use "main"
    default_branch=$(git remote show origin 2>/dev/null | awk "/HEAD branch/ {print \$NF}")
    [ -z "$default_branch" ] && default_branch="main"
  fi

  # ── abort if mid-rebase/merge ─────────────────────────────────────────────
  git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ] || \
     [ -f "$git_dir/MERGE_HEAD" ]   || [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
    echo "  [SKIP] $name: mid-rebase/merge — skipping pull to avoid data loss."
    return 0
  fi

  # ── stash ALL changes (tracked + staged + untracked new files) ───────────
  stashed=false
  is_tracked_dirty=false
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    is_tracked_dirty=true
  fi
  has_untracked=$(git ls-files --others --exclude-standard | head -1)

  if [ "$is_tracked_dirty" = true ] || [ -n "$has_untracked" ]; then
    echo "  -> $name: stashing local changes (including untracked files)..."
    if git stash push --include-untracked -m "sync-submodules auto-stash"; then
      stashed=true
    else
      echo "  [WARN] $name: stash failed — skipping pull to preserve changes."
      return 0
    fi
  fi

  # ── fetch & pull ──────────────────────────────────────────────────────────
  git fetch origin

  # Stay on current branch if already tracking; otherwise stay detached HEAD
  # (avoids silently moving the submodule commit pointer)
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
  if [ "$current_branch" = "DETACHED" ]; then
    # Pull the remote branch tip without checking it out
    git fetch origin "$default_branch" && \
      git merge --ff-only "origin/$default_branch" 2>/dev/null || \
      echo "  [WARN] $name: cannot fast-forward detached HEAD — manual merge required."
  else
    git pull --rebase origin "$current_branch" 2>/dev/null || {
      echo "  [ERROR] $name: pull --rebase failed. Aborting rebase and restoring stash."
      git rebase --abort 2>/dev/null || true
      if [ "$stashed" = true ]; then
        git stash pop || echo "  [WARN] $name: stash pop failed — run: git stash pop in $path"
      fi
      return 0
    }
  fi

  # ── restore stash ─────────────────────────────────────────────────────────
  if [ "$stashed" = true ]; then
    echo "  -> $name: restoring local changes..."
    git stash pop || echo "  [WARN] $name: stash pop had conflicts — resolve manually then run: git stash drop"
  fi
'

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "==> Submodule status:"
git submodule status --recursive

echo ""
echo "Done."
