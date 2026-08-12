#!/usr/bin/env bash
#
# push_gitlab.sh — push a COMPLETE plaintext snapshot of this working tree to the
# PRIVATE GitLab remote, INCLUDING normally-gitignored files (PASSWORDS.md,
# github_credentials.md, proxmox/credentials, proxmox/nas_credentials,
# working/, ddns/, vmware/*.zip, etc.).
#
# (Formerly gl-backup.sh — renamed for symmetry with push_github.sh. Older commit
# messages and docs refer to the old name; the behaviour is unchanged.)
#
# Why this exists:
#   - GitHub (origin)  = PUBLIC showcase. Secrets are .gitignore'd and NEVER pushed.
#                        Use ./push_github.sh, which refuses to push if a secret
#                        would leak.
#   - GitLab (gitlab)  = PRIVATE full mirror. Gets EVERYTHING, in plaintext.
#   This script bridges those two worlds from a single working tree. Sending
#   secrets here is the POINT, which is why it must never touch origin.
#
# Safety:
#   - Uses an isolated temporary index. Your real index, working tree, and the
#     GitHub-bound 'main' branch are NEVER touched.
#   - Pushes ONLY to the 'gitlab' remote, and aborts if that remote looks like
#     GitHub.
#   - Excludes junk (.DS_Store) and never includes the .git directory.
#
# Usage:
#   ./push_gitlab.sh                  # snapshot with an auto timestamp message
#   ./push_gitlab.sh "your message"   # snapshot with a custom message
#   ./push_gitlab.sh --dry-run        # build the snapshot, push NOTHING
#
set -euo pipefail

GITLAB_REMOTE="gitlab"
GITLAB_BRANCH="main"

DRY_RUN=0
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ARGS+=("$arg") ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Confirm the gitlab remote is the private GitLab mirror (defense in depth).
if ! git remote get-url "$GITLAB_REMOTE" >/dev/null 2>&1; then
  echo "ERROR: remote '$GITLAB_REMOTE' not configured. Aborting." >&2
  exit 1
fi

# This script deliberately stages secrets. If '$GITLAB_REMOTE' were ever
# repointed at a public host, that would be the worst possible accident.
GITLAB_URL="$(git remote get-url "$GITLAB_REMOTE")"
case "$GITLAB_URL" in
  *github.com*)
    echo "ERROR: remote '$GITLAB_REMOTE' points at GitHub ($GITLAB_URL)." >&2
    echo "       This script sends SECRETS. Refusing to run." >&2
    exit 1 ;;
esac

# Stamp every snapshot with where 'main' was when it was taken.
#
# The GitLab history is a chain of snapshots and is FULLY DISJOINT from main --
# no common ancestor -- so without this there is no way to tell which real commit
# a snapshot corresponds to. Worse, forgetting the message argument used to
# replace the reason for the snapshot with a bare clock reading. The tree is
# always captured perfectly; it was only ever the "why" that got lost.
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
if HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null)"; then
  HEAD_SUBJ="$(git log -1 --pretty=%s HEAD)"
  HEAD_REF="main @ ${HEAD_SHA}"
  # Note when the snapshot contains work that is not in any commit, because then
  # the SHA alone does not describe the tree being pushed.
  git diff-index --quiet HEAD -- 2>/dev/null || HEAD_REF="${HEAD_REF}+dirty"
else
  HEAD_REF="no commits yet"
  HEAD_SUBJ=""
fi

if [ "${#ARGS[@]}" -gt 0 ] && [ -n "${ARGS[0]}" ]; then
  MSG="${ARGS[0]} [${HEAD_REF}]"
else
  MSG="Snapshot ${STAMP} — ${HEAD_REF}${HEAD_SUBJ:+: ${HEAD_SUBJ}}"
fi

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

if [ "$DRY_RUN" = "1" ]; then
  echo "--dry-run: built snapshot ${COMMIT:0:12} (\"$MSG\")"
  echo "  $(git ls-tree -r --name-only "$COMMIT" | wc -l) files would go to ${GITLAB_REMOTE}/${GITLAB_BRANCH}"
  echo "  including these normally-ignored paths:"
  git ls-tree -r --name-only "$COMMIT" \
    | grep -E '^(PASSWORDS\.md|github_credentials\.md|proxmox/(credentials|nas_credentials)|www/scripts/smb_credentials|working/|ddns/)' \
    | sed 's/^/    /' || echo "    (none found - unexpected, check .gitignore)"
  echo "Nothing pushed."
  exit 0
fi

echo "Pushing full snapshot to ${GITLAB_REMOTE}/${GITLAB_BRANCH} ..."
git push "$GITLAB_REMOTE" "${COMMIT}:refs/heads/${GITLAB_BRANCH}"

# Keep our local tracking ref in sync so the next snapshot chains cleanly.
git update-ref "refs/remotes/${GITLAB_REMOTE}/${GITLAB_BRANCH}" "$COMMIT"

echo "Done. Snapshot ${COMMIT:0:12} -> ${GITLAB_REMOTE}/${GITLAB_BRANCH} (private GitLab, full plaintext mirror)."
