#!/usr/bin/env bash
#
# push_github.sh — push the CURATED tree to the PUBLIC GitHub remote (origin/main).
#
# Why this exists:
#   GitHub is the dangerous remote. There is NO encryption on this repo — the only
#   thing standing between a public repository and PASSWORDS.md is .gitignore. That
#   made "verify before you push" a convention a human or an agent could skip.
#   This script turns it into a gate that fails CLOSED: if any check fails, nothing
#   is pushed.
#
#   GitLab is the opposite problem and has its own script: ./push_gitlab.sh sends
#   EVERYTHING including secrets to the private mirror.
#
# Checks (all must pass):
#   1. 'origin' really is GitHub, and we are on the curated branch.
#   2. No TRACKED file has a secret-looking name.
#   3. Every known sensitive path that exists on disk is actually gitignored.
#   4. The outgoing diff contains no private-key blocks and no URLs with an
#      embedded password (the GitLab wallet lives in .git/config and must never
#      be committed).
#
# Usage:
#   ./push_github.sh              # run checks, show what goes public, confirm, push
#   ./push_github.sh --dry-run    # run checks and show the plan, push NOTHING
#   ./push_github.sh --yes        # skip the interactive prompt (for non-TTY use)
#
set -euo pipefail

REMOTE="origin"
BRANCH="main"

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; BLD=$'\033[1m'; RST=$'\033[0m'
fail() { echo "${RED}${BLD}BLOCKED:${RST} $*" >&2; exit 1; }
ok()   { echo "  ${GRN}ok${RST}   $*"; }
warn() { echo "  ${YLW}warn${RST} $*"; }

echo "${BLD}push_github.sh — public remote safety checks${RST}"

# --- 1. right remote, right branch -------------------------------------------
git remote get-url "$REMOTE" >/dev/null 2>&1 || fail "remote '$REMOTE' is not configured."
ORIGIN_URL="$(git remote get-url "$REMOTE")"
case "$ORIGIN_URL" in
  *github.com*) ok "remote '$REMOTE' is GitHub ($ORIGIN_URL)" ;;
  *) fail "remote '$REMOTE' is NOT GitHub ($ORIGIN_URL). Refusing to guess." ;;
esac

CURRENT="$(git rev-parse --abbrev-ref HEAD)"
[ "$CURRENT" = "$BRANCH" ] || fail "on branch '$CURRENT', but the curated branch is '$BRANCH'."
ok "on branch '$BRANCH'"

# --- 2. no tracked file with a secret-looking name ---------------------------
# Names, not contents: this is the check that catches a secret that was never
# ignored in the first place.
SECRET_NAMES='(^|/)(PASSWORDS|passwords)|credential|(^|/)\.env($|\.)|\.key$|\.pem$|\.p12$|\.pfx$|id_rsa|id_ed25519|(^|/)secrets?\.'
if OFFENDERS="$(git ls-files | grep -nEi "$SECRET_NAMES" || true)"; [ -n "$OFFENDERS" ]; then
  echo "$OFFENDERS" | sed 's/^/       /'
  fail "the files above are TRACKED and look sensitive. They would become public."
fi
ok "no tracked file has a secret-looking name"

# --- 3. known sensitive paths are still ignored ------------------------------
#
# NOTE ON `[ -e "$p" ] || continue`: a path that does not exist is skipped, which
# is correct (not every machine has every file) but means THIS LIST GOES QUIET WHEN
# A FILE MOVES rather than complaining. On Aug 21, 2026 smb_credentials moved from
# www/scripts/ to www/, and this gate stopped covering it without a word -- the
# third time in two days that a path-specific safety rule silently failed to follow
# a file (the others were .gitignore and the nginx deny rule). Hence step 3b below,
# which checks by NAME and cannot be outrun by a move.
SENSITIVE=(
  PASSWORDS.md
  github_credentials.md
  proxmox/credentials
  proxmox/nas_credentials
  www/smb_credentials                # canonical since Aug 21, 2026
  www/ubuntu/smb_credentials         # stray-copy check (tree renamed from www/scripts)
  www/fedora/smb_credentials         # ditto (renamed from www/scripts_fedora)
  www/scripts/smb_credentials        # pre-rename names, kept for old working copies
  www/scripts_fedora/smb_credentials
  working
  ddns
)
MISSING_IGNORE=()
for p in "${SENSITIVE[@]}"; do
  [ -e "$p" ] || continue                      # not present on this machine, fine
  git check-ignore -q "$p" || MISSING_IGNORE+=("$p")
done
if [ ${#MISSING_IGNORE[@]} -gt 0 ]; then
  printf '       %s\n' "${MISSING_IGNORE[@]}"
  fail "the paths above exist but are NO LONGER gitignored. Fix .gitignore first."
fi
ok "all ${#SENSITIVE[@]} known sensitive paths are ignored (or absent)"

# --- 3b. the same check, by NAME, wherever the file lives --------------------
# A list of paths protects the paths you thought of. This finds every file whose
# NAME says it holds a credential, anywhere in the tree, and asserts each one is
# ignored. It is what would have caught the move above on the day it happened.
UNIGNORED=()
while IFS= read -r f; do
  git check-ignore -q "$f" || UNIGNORED+=("$f")
done < <(find . -type f \
              \( -name 'smb_credentials' -o -name '*credentials*' -o -name '.smbcredentials' \) \
              -not -path './.git/*' -printf '%P\n' 2>/dev/null)
if [ ${#UNIGNORED[@]} -gt 0 ]; then
  printf '       %s\n' "${UNIGNORED[@]}"
  fail "the credential-named files above are NOT gitignored, wherever they came from."
fi
ok "every credential-named file in the tree is ignored (name-based sweep)"

# --- 4. scan the outgoing diff for secret CONTENT ----------------------------
git fetch -q "$REMOTE" "$BRANCH" 2>/dev/null || warn "could not fetch $REMOTE/$BRANCH; scanning full history instead"

if git rev-parse --verify -q "refs/remotes/${REMOTE}/${BRANCH}^{commit}" >/dev/null; then
  RANGE="refs/remotes/${REMOTE}/${BRANCH}..HEAD"
else
  RANGE="HEAD"
fi

# Only high-confidence patterns, so this never cries wolf over the WORD
# "password" appearing in documentation.
KEY_BLOCK='BEGIN [A-Z ]*PRIVATE KEY'
# The password component must not START with '<' or '*', which is what makes
# this ignore documented placeholders like http://root:<pw>@host and the
# root:***@host form used when echoing a remote URL. A real secret starting with
# either character is not a case worth weakening the check for.
URL_WITH_PW='[a-z][a-z0-9+.-]*://[^/@[:space:]]+:[^<*/@[:space:]][^/@[:space:]]*@'
AWS_KEY='AKIA[0-9A-Z]{16}'

ADDED="$(git diff -U0 "$RANGE" -- . 2>/dev/null | grep '^+' | grep -v '^+++' || true)"
CONTENT_HITS=""
for pat in "$KEY_BLOCK" "$URL_WITH_PW" "$AWS_KEY"; do
  hit="$(printf '%s\n' "$ADDED" | grep -En "$pat" || true)"
  [ -n "$hit" ] && CONTENT_HITS="${CONTENT_HITS}${hit}"$'\n'
done
if [ -n "${CONTENT_HITS//[$'\n\t ']/}" ]; then
  printf '%s' "$CONTENT_HITS" | sed 's/^/       /'
  fail "the outgoing changes contain key material or a URL with an embedded password."
fi
ok "outgoing diff has no private keys, credentialed URLs, or AWS keys"

# --- what would actually go public ------------------------------------------
AHEAD="$(git rev-list --count "$RANGE" 2>/dev/null || echo 0)"
echo
if [ "$AHEAD" = "0" ]; then
  echo "Nothing to push — ${REMOTE}/${BRANCH} already matches HEAD."
  exit 0
fi

echo "${BLD}$AHEAD commit(s) would become PUBLIC on ${ORIGIN_URL}:${RST}"
git --no-pager log --oneline "$RANGE" | sed 's/^/  /'
echo
echo "${BLD}Files:${RST}"
git --no-pager diff --stat "$RANGE" | tail -1 | sed 's/^/  /'

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
  echo
  warn "your working tree has UNCOMMITTED changes — they are NOT part of this push."
fi

if [ "$DRY_RUN" = "1" ]; then
  echo
  echo "${YLW}--dry-run: all checks passed, nothing pushed.${RST}"
  exit 0
fi

# --- confirm and push -------------------------------------------------------
if [ "$ASSUME_YES" != "1" ]; then
  if [ -t 0 ]; then
    echo
    read -r -p "Push these to PUBLIC GitHub? type 'yes' to continue: " reply
    [ "$reply" = "yes" ] || { echo "aborted."; exit 1; }
  else
    fail "not a terminal and --yes was not given. Refusing to push unattended."
  fi
fi

echo
git push "$REMOTE" "$BRANCH"
echo "${GRN}Done.${RST} Pushed to ${REMOTE}/${BRANCH} (public GitHub, curated tree)."
