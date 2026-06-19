#!/usr/bin/env bash
#
# gl-backup.sh — push a COMPLETE plaintext snapshot of this working tree to the
# PRIVATE GitLab remote, INCLUDING normally-gitignored files (PASSWORDS.md,
# github_credentials.md, proxmox/credentials, proxmox/nas_credentials,
# working/, ddns/, vmware/*.zip, etc.).
#
# Why this exists:
#   - GitHub (origin)  = PUBLIC showcase. Secrets are .gitignore'd and NEVER pushed.
#   - GitLab (gitlab)  = PRIVATE full mirror. Gets EVERYTHING, in plaintext.
#   This script bridges those two worlds from a single working tree.
#
# Safety:
#   - Uses an isolated temporary index. Your real index, working tree, and the
#     GitHub-bound 'main' branch are NEVER touched.
#   - Pushes ONLY to the 'gitlab' remote, never to 'origin'/GitHub.
#   - Excludes junk (.DS_Store) and never includes the .git directory.
#
# Usage:
#   ./gl-backup.sh                # snapshot with an auto timestamp message
#   ./gl-backup.sh "your message" # snapshot with a custom message
#
set -euo pipefail

GITLAB_REMOTE="gitlab"
GITLAB_BRANCH="main"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Confirm the gitlab remote is the private GitLab mirror (defense in depth).
if ! git remote get-url "$GITLAB_REMOTE" >/dev/null 2>&1; then
  echo "ERROR: remote '$GITLAB_REMOTE' not configured. Aborting." >&2
  exit 1
fi

MSG="${1:-Full snapshot $(date '+%Y-%m-%d %H:%M:%S %Z')}"

# Isolated temp index so the real index/working tree stay untouched.
# Use an unused path (not a pre-created empty file, which git rejects as corrupt).
TMP_INDEX="$(mktemp -u)"
export GIT_INDEX_FILE="$TMP_INDEX"

# Nested git repos (e.g. working/openclaw-ansible) would otherwise be recorded as
# empty gitlink pointers, losing their files. Temporarily move each nested .git
# OUT of the work tree (to an external holding dir) so the nested repo's WORKING
# FILES are captured as plain files while its .git internals are NOT captured.
# Everything is always restored, even on error.
HOLD_DIR="$(mktemp -d)"
mapfile -t NESTED_GIT < <(find . -mindepth 2 -name .git -not -path './.git/*' 2>/dev/null)
NESTED_HELD=()
restore_nested() {
  local i
  for i in "${!NESTED_HELD[@]}"; do
    [ -e "${NESTED_HELD[$i]}" ] && mv "${NESTED_HELD[$i]}" "${NESTED_GIT[$i]}"
  done
  rmdir "$HOLD_DIR" 2>/dev/null || true
}
trap 'restore_nested; rm -f "$TMP_INDEX"' EXIT
for i in "${!NESTED_GIT[@]}"; do
  held="${HOLD_DIR}/nested_${i}.git"
  mv "${NESTED_GIT[$i]}" "$held"
  NESTED_HELD[$i]="$held"
done

# Stage EVERYTHING (tracked + ignored), excluding only macOS junk.
git add -f -A -- . ':!:.DS_Store' ':!:**/.DS_Store'

# Restore nested .git dirs immediately now that files are staged.
restore_nested
NESTED_GIT=(); NESTED_HELD=()

TREE="$(git write-tree)"

# Chain onto the previous GitLab snapshot if there is one (keeps history),
# otherwise create the first (root) snapshot commit.
git fetch -q "$GITLAB_REMOTE" "$GITLAB_BRANCH" 2>/dev/null || true
PARENT_ARGS=()
if git rev-parse --verify -q "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}^{commit}" >/dev/null; then
  PARENT_ARGS=(-p "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}")
fi

COMMIT="$(git commit-tree "$TREE" "${PARENT_ARGS[@]}" -m "$MSG")"

echo "Pushing full snapshot to ${GITLAB_REMOTE}/${GITLAB_BRANCH} ..."
git push "$GITLAB_REMOTE" "${COMMIT}:refs/heads/${GITLAB_BRANCH}"

# Keep our local tracking ref in sync so the next snapshot chains cleanly.
git update-ref "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}" "$COMMIT"

echo "Done. Snapshot ${COMMIT:0:12} -> ${GITLAB_REMOTE}/${GITLAB_BRANCH} (private GitLab, full plaintext mirror)."
