# This repo's dual-remote model, secret hygiene, GitHub/GitLab details

Topic reference (not tied to one phase). Loaded ON TOUCH via `phases/INDEX.md`. Blocks below are copied VERBATIM from `MEMORY.md` as of tag `pre-memory-diet` (Nov 24, 2026).

---

## COPIED VERBATIM FROM `MEMORY.md` @ `pre-memory-diet` (lines 2562–2678) — Nov 24, 2026 (memory-diet, copy-first) — GITHUB + HOME-LAB-SETUP REPO

## GITHUB

- **Repo:** https://github.com/fiberoptix/home-lab-setup
- **User:** fiberoptix (SSH: ~/.ssh/id_ed25519)
- **Email:** andrew.gamache@gmail.com
- **Credentials:** See `github_credentials.md` (git-ignored)

---

## HOME-LAB-SETUP REPO (this repo) — dual-remote (Capricorn method, NO encryption)

Same model as Capricorn/capricorn-docs: SAFE content → GitHub, EVERYTHING → GitLab.
There is NO git-crypt and NO encryption — safety on GitHub comes purely from .gitignore.

- **GitHub (PUBLIC):** https://github.com/fiberoptix/home-lab-setup — remote `origin` (SSH, id_ed25519).
  Curated showcase. Secrets are .gitignore'd and NEVER reach GitHub. Push with: **`./push_github.sh`**.
- **GitLab (PRIVATE):** http://gitlab.gothamtechnologies.com/production/home-lab-setup — remote `gitlab`.
  Full plaintext mirror of the ENTIRE working tree (incl. ignored secrets/binaries).
  Auth = HTTP "wallet" baked into the remote URL in .git/config
  (`http://root:<GitLab root pw — see PASSWORDS.md>@gitlab.gothamtechnologies.com/production/home-lab-setup.git`),
  identical to how Capricorn/capricorn-docs authenticate. No SSH key needed for GitLab.
  The real password lives ONLY in .git/config (never pushed) + PASSWORDS.md (gitignored).
- ⚠️ **PUSH ONLY VIA THE TWO SCRIPTS (Aug 12, 2026). NEVER a raw `git push`.**
  **`gl-backup.sh` WAS RENAMED to `push_gitlab.sh`** (`git mv`, history preserved) so the two
  remotes have symmetrical entry points. The old name no longer exists — a stale `./gl-backup.sh`
  just errors, which is the intended loud failure.
  - **`./push_github.sh`** → PUBLIC GitHub (origin/main), curated tree. **New and it FAILS CLOSED.**
    Four gates: origin really is GitHub and branch is `main`; no TRACKED file has a secret-looking
    name; every known sensitive path that exists is still gitignored; and the outgoing diff has no
    private-key blocks, no URL with an embedded password (**this is what would catch the GitLab
    wallet leaking**), and no AWS keys. Then it prints the commits going public and requires a typed
    `yes`. **Refuses to push unattended unless given `--yes`.** If it blocks, FIX THE CAUSE.
    ⚠️ **KNOWN FALSE SIGNAL, found Sep 17, 2026 — it warns `your working tree has UNCOMMITTED changes`
    when the tree is clean.** The check is `git diff-index --quiet HEAD --` with **no preceding
    `git update-index --refresh`**, so it trusts cached mtimes. ⭐ **It fires most readily in exactly
    the order `CURSOR_RULES` mandates** — GitLab first, then GitHub — because `push_gitlab.sh` touches
    the tree seconds earlier and leaves the stat cache stale, and **this repo is on CIFS where mtime
    drift is already the documented hazard.** ✅ **Confirm it is spurious with the CONTENT-level
    question, not the stat one:** `git diff HEAD --stat` (empty) and `git ls-files -m` (empty);
    `git update-index --refresh` then makes `diff-index --quiet` exit 0. ⛔ **Do NOT re-commit in
    response to it mid-push** — there is nothing to commit, and that is the damage this false positive
    invites. 🔲 Real fix is one line in the script (refresh before the check); not done yet.
  - **`./push_gitlab.sh "message"`** → PRIVATE GitLab (gitlab/main), full plaintext mirror. Same
    proven logic as before (temp index, never touches the real index/worktree/`main`, handles nested
    git repos). Added guard: it ABORTS if the `gitlab` remote ever resolves to github.com, because
    this script deliberately stages secrets.
  - **Both take `--dry-run`** — every check runs, nothing is pushed. Verified Aug 12: the GitLab
    dry-run built a 208-file snapshot including PASSWORDS.md and the nested openclaw-ansible files,
    and the real index was byte-identical afterwards.
- ⚠️ **WHAT THE GITLAB MIRROR DOES AND DOES NOT PRESERVE** (understood properly Aug 12).
  `gitlab/main` and `main` are **FULLY DISJOINT — `git merge-base` finds no common ancestor.**
  As of Aug 12: **82 real commits on `main` vs 22 snapshots on `gitlab/main`.** The mirror preserves
  **files perfectly** and **history coarsely**; it IS a real commit chain, so diffing between
  snapshots works normally. What it never had was correlation — no way to tell which `main` commit a
  snapshot matched — and two of the older snapshots are messaged only `Full snapshot <timestamp>`,
  where the reason for the snapshot is simply gone.
  - ✅ **Fixed Aug 12: snapshots are now AUTO-STAMPED.** Default message is
    `Snapshot <ts> — main @ <sha>[+dirty]: <HEAD subject>`; a message you pass gets `[main @ <sha>]`
    appended. **`+dirty` means the snapshot contains work that is in NO commit**, which is the case
    worth noticing — the SHA alone would not describe the tree being pushed.
  - **Nothing is lost on the GitHub side.** `push_github.sh` never creates a commit; it only pushes.
    Commit messages are authored normally with `git commit` and are unaffected by either script.
  - **Neither script pushes tags** (there are currently 0 tags in the repo). If tagging ever starts,
    `push_github.sh` needs `--follow-tags`.
  - Do NOT `git push gitlab main` directly — that sends only the curated tree, not the secrets.
- **No auto-push-to-both.** Pushes are explicit; ALWAYS ASK "GitHub, GitLab, or both?" first.
  See the "GIT REMOTES & COMMIT ROUTING" section in CURSOR_RULES.
- **GitLab always looks "diverged" from `main` (e.g. 82 ahead / 22 behind). That is BY DESIGN** —
  it is a separate snapshot history built by push_gitlab.sh, not a problem to reconcile.
- **Ignored-and-therefore-GitHub-safe:** PASSWORDS.md, github_credentials.md, proxmox/credentials,
  proxmox/nas_credentials, /working/, /ddns/, *.pem, *.key, *.crt, .env*,
  www/smb_credentials  (verify: `git check-ignore <f>`).
- **smb_credentials:** 🚨 **MOVED Aug 21, 2026 — it is `www/smb_credentials` now, NOT
  `www/ubuntu/smb_credentials`.** Holds `SMB_PASSWORD='...'`; gitignored (GitHub never sees it) but
  rides the GitLab mirror, so a LAN clone lets setup_smb_mount.sh run unattended. ⛔ **Do not move it
  back into a script tree.** `www/docker-compose.yml` bind-mounts `www/ubuntu` and
  `www/fedora` into the nginx script server but never `www/`, so above the mount the NAS
  password is *unreachable* rather than merely *denied* — the deny rule hid the contents but
  `autoindex` still advertised the filename. Both `setup_smb_mount.sh` scripts read the new path
  first and still accept the old ones. ⭐ **The move also silently emptied `push_github.sh`'s
  sensitive-path gate** (it skips paths that do not exist), which is why that script now also does a
  **name-based sweep** for credential-named files anywhere in the tree.
- **Secret hygiene:** NEVER put real passwords/tokens in tracked files (they go public on GitHub).
  History was purged once already (git filter-repo) after a leak — keep it clean.
  🚨 **AND THAT LEAK IS NOT FULLY REMEDIATED — promoted here Sep 17, 2026 from a June 18, 2026 session
  block where it was the ONLY record in the project.** The scrub removed the master password, the
  SonarQube admin password and two SonarQube project tokens from tracked files and purged them from all
  54 commits (`546b85a` → `24cda0c`, force-pushed to GitHub). ⛔ **But the password was never ROTATED —
  Andrew's call at the time, and the offer remains open.** ⚠️ **GitHub can retain orphaned commits
  reachable by SHA until it garbage-collects**, so the only true fix is rotation.
  ⭐ **Recorded because `git filter-repo` reads as "handled" and a purge is not a rotation.**
  🚨🚨 **AND A SECOND ONE IS LIVE NOW — found Nov 4, 2026 (`MAKE_MEMORIES` pass 14c audit).** The **NAS/SMB
  password** — the same string as the **GitLab root password** (Phase 20 E7) — sits in plain prose **7 times
  in 4 tracked files** (`MEMORY.md` ×2, `phases/current_phase.md` ×2, `phases/phase16_docker_swarm.md` ×1,
  `proxmox/Home_Lab_Proxmox_Storage.md` ×2), **all 7 on public `origin/main`, first in commit `46a01db`
  (Aug 13, 2026)**. Every instance is a teaching note about the `.pw` file format (`password=<value>`).
  `push_github.sh` cannot see it: its gates look for key blocks, credential-named files and
  passwords-in-URLs, not a password in a sentence.
  ✅ **RESOLVED Nov 4 (Andrew's decisions):** the 7 copies **REDACTED** to `password=<value>`; **NOT rotated**
  (🙋 lab-only — the NAS and GitLab resolve to `192.168.1.x` even in public DNS, the password is used
  nowhere internet-facing, and a rotation that misses one of its ~10 homes trips the NAS auto-block on the
  PVE host's IP); **no history purge** (pointless without a rotation). ⚠️ So the old value **stays valid
  AND stays readable in public GitHub history** — accepted, not overlooked.
  ✅ **AND THE GATE NOW EXISTS: `push_github.sh` step 5** reads every real value from `PASSWORDS.md`
  (rows labelled …password/token/value/secret/passphrase), `proxmox/credentials`, `proxmox/nas_credentials`
  and every `*smb_credentials*`, and **blocks if any appears in a tracked file or an outgoing commit**,
  printing only file names and the value's SHAPE. **Proven Nov 4 on the real leak:** blocked naming exactly
  these 4 files / 7 lines, then passed after the redaction. ⚠️ Its first version matched every table cell
  and blocked on 10 public values (usernames, an email, URLs) for 1 real one — **a gate that always blocks
  gets bypassed**, so it reads labels. ⛔ **Never type a credential value into a tracked file — write
  `<value>`.**
  ✅ Also proven rather than assumed, same era: staging a fake `_gatetest.key` made `push_github.sh`
  block, name the file, and exit 1 without pushing — **the gate was demonstrated, not trusted.**
- **Branch:** `main` only (docs/scripts repo — no CI/CD or registry like Capricorn).

---
