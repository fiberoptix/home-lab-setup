#!/usr/bin/env bash
#
# Deploy the Capricorn lab stack to the Docker Swarm.
#
# Runs ON a manager node. Written in Part 3 and run BY HAND first, on purpose: Part 4 adds no
# deploy logic at all, it only arranges for a CI runner to invoke this same script. That is what
# keeps the pipeline portable — GitLab CI today, Jenkins later, in about the same number of lines.
#
#   Recorded claim for Phase 17 to test: if Jenkins forces a change to THIS file, the boundary
#   between "deploy logic" and "CI wrapper" was drawn in the wrong place.
#
# This script owns: registry login, the deploy, waiting for convergence, PROVING THE APP ACTUALLY
# SERVES (the smoke gate at the bottom), and failing loudly.
# The CI wrapper owns: when it runs, who may run it, where the token comes from, which host it
# targets, and who gets told.
#
# Usage (by hand, already logged in):
#     ./deploy_swarm.sh
#
# Usage (from CI, or a fresh node):
#     REG_USER=<deploy-token-username> REG_TOKEN=<token> ./deploy_swarm.sh
#
# Safe to re-run. Note it is NOT side-effect-free: docker stack deploy reconciles the whole stack,
# so any service whose spec changed is recreated. See the convergence note at the bottom.
#
set -euo pipefail

STACK="${STACK:-capricorn}"
STACK_FILE="${STACK_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../manifests" && pwd)/capricorn.stack.yml}"
REGISTRY="${REGISTRY:-gitlab.gothamtechnologies.com:5050}"
REG_USER="${REG_USER:-}"
REG_TOKEN="${REG_TOKEN:-}"
TIMEOUT="${TIMEOUT:-300}"
INTERVAL="${INTERVAL:-5}"

# --- Smoke gate (added Aug 18 2026, after a drill proved convergence is not readiness) -------------
# Andrew's rule: "containers running and ready does not mean the application is ready for business."
# SMOKE_PATH must be an endpoint that EXERCISES A DEPENDENCY. /health here is a static string and
# returned 200 with the database scaled to zero, which is exactly the failure this gate exists to catch.
SMOKE="${SMOKE:-1}"
SMOKE_HOST="${SMOKE_HOST:-127.0.0.1}"
SMOKE_PORT="${SMOKE_PORT:-5002}"
SMOKE_PATH="${SMOKE_PATH:-/api/v1/banking/categories}"
SMOKE_EXPECT="${SMOKE_EXPECT:-\"success\":true}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-90}"
SMOKE_INTERVAL="${SMOKE_INTERVAL:-5}"
# Second gate: a status code alone would pass an EMPTY database. Requires total >= SMOKE_MIN_ROWS.
#
# ⚠️ THE THRESHOLD HAS TO MEAN SOMETHING, and the first draft of this got it wrong: it defaulted to 1.
# 001_schema.sql seeds 12 categories entirely on its own, so a floor of 1 - or of 12 - passes on a
# database where the application's bootstrap NEVER RAN. That is the precise false-green this gate
# exists to prevent, and it would have been shipped.
#
# A fully bootstrapped database reports total=682 (measured Aug 18). Schema-only is ~12. 100 sits
# clearly between them. Per app, the rule is: PICK A NUMBER THE SCHEMA ALONE CANNOT REACH.
SMOKE_ROWS_PATH="${SMOKE_ROWS_PATH:-/api/v1/data/summary}"
SMOKE_MIN_ROWS="${SMOKE_MIN_ROWS:-100}"

die() { printf '\n\033[31mFAILED:\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------------------------
# Pre-flight. Fail on the cheap checks before touching the cluster.
# ---------------------------------------------------------------------------------------------
[ -f "$STACK_FILE" ] || die "stack file not found: $STACK_FILE"

# docker node ls only succeeds on a manager, which makes it a free "am I in the right place" test.
docker node ls >/dev/null 2>&1 || die "not a swarm manager (or swarm is inactive) - run this on a manager"

# The stack references an external secret. Creating it here would mean inventing a password in a
# script; requiring it means the deploy fails fast with a clear reason instead of a confused
# postgres that cannot authenticate.
docker secret inspect pg_password >/dev/null 2>&1 \
    || die "secret 'pg_password' does not exist - create it first:  printf '<password>' | docker secret create pg_password -"

# ---------------------------------------------------------------------------------------------
# Registry login. Only when a token was supplied, so a by-hand re-run reuses the existing login.
# ---------------------------------------------------------------------------------------------
if [ -n "$REG_TOKEN" ]; then
    say "logging in to $REGISTRY as ${REG_USER:-<unset>}"
    [ -n "$REG_USER" ] || die "REG_TOKEN was given but REG_USER was not"
    # --password-stdin, never -p: -p puts the token in the process list where ps can read it,
    # and in shell history. This is the scripted idiom; interactively you omit -p and let
    # docker prompt.
    printf '%s' "$REG_TOKEN" | docker login "$REGISTRY" -u "$REG_USER" --password-stdin >/dev/null \
        || die "docker login to $REGISTRY failed"
    echo "    login ok"
else
    say "no REG_TOKEN supplied - relying on the existing login in ~/.docker/config.json"
fi

# ---------------------------------------------------------------------------------------------
# Deploy.
# ---------------------------------------------------------------------------------------------
say "deploying stack '$STACK' from $STACK_FILE"

# --with-registry-auth is NOT optional for a private registry. Without it the manager keeps the
# credential to itself and tasks scheduled on other nodes are Rejected with
# "error from registry: access forbidden" - while the same image pulls fine by hand on the manager.
#
# It also has a delayed failure mode worth knowing: the credential is frozen into the service spec
# in the Raft log. When the token expires, tasks rescheduled AFTER that date fail to pull even
# though nothing changed and every config file still looks correct. Redeploying refreshes it.
docker stack deploy -c "$STACK_FILE" --with-registry-auth "$STACK"

# ---------------------------------------------------------------------------------------------
# Wait for convergence. THIS is the part a naive deploy job omits.
# ---------------------------------------------------------------------------------------------
# docker stack deploy returns 0 as soon as the manager has ACCEPTED the desired state - not when
# anything is running. A job that stops here reports green while the app crash-loops. So poll, and
# exit non-zero if the cluster never gets there.
#
# Replica count alone is NOT a sufficient test, and this is easy to get wrong. Three of these
# services use `order: start-first`, which starts the replacement task BEFORE stopping the old one,
# so running/desired can read 3/3 continuously through an entire rolling replacement. A deploy that
# swapped every container for a broken image could satisfy a count-only check on the first poll.
#
# So also require UpdateStatus.State. Swarm sets it to `updating` while a rollout is in flight and
# `completed` when it finishes - and crucially to `rollback_started` / `rollback_completed` when
# failure_action fired. A rolled-back service ends up back at full replicas, so a count-only check
# calls an automatic rollback a SUCCESS. It is the opposite: the new version was rejected.
#
# ✅ VERIFIED Aug 18, 2026: on a service that has never been updated, the key is not empty - it is
# ABSENT, and the template fails with `map has no entry for key "UpdateStatus"`. The `2>/dev/null || true`
# below collapses that into an empty string, which this script correctly treats as healthy.
#
# ⚠️ Note the contrast with the volume-wipe lesson recorded in COMMANDS.md, because the rule is not
# "never suppress stderr". Suppression is right HERE because absence is a legitimate, expected state that
# the code goes on to handle. It was wrong THERE because absence of the volume was a PRECONDITION whose
# failure invalidated everything downstream. The test is whether you handle the silence, not whether you
# create it.
#
# UNVERIFIED, to be tested when we deliberately trigger a rollback later in this phase: UpdateStatus
# is a LATCH, not a live signal - it persists until the next update starts. If a redeploy that sends
# an identical spec does not begin a new update, a stale `rollback_completed` from an earlier failure
# could make this script fail a cluster that is actually healthy. Do not trust this paragraph until
# the trap has been run; it is written down as a claim to falsify, not as a fact.
say "waiting for convergence (timeout ${TIMEOUT}s)"

deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
    pending=""
    rolled_back=""
    while read -r name replicas; do
        current="${replicas%%/*}"
        desired="${replicas##*/}"
        state="$(docker service inspect "$name" --format '{{.UpdateStatus.State}}' 2>/dev/null || true)"

        case "$state" in
            rollback*) rolled_back="$rolled_back $name" ;;
        esac

        if [ "$current" != "$desired" ] || [ "$desired" = "0" ]; then
            pending="$pending $name($replicas)"
        elif [ -n "$state" ] && [ "$state" != "completed" ]; then
            pending="$pending $name($state)"
        fi
    done < <(docker stack services "$STACK" --format '{{.Name}} {{.Replicas}}')

    # A completed rollback is a converged cluster running the OLD code. Never report that as green.
    if [ -n "$rolled_back" ]; then
        printf '\n\033[31mrolled back:\033[0m%s\n' "$rolled_back" >&2
        echo "the new version was rejected and the previous one restored - this is a FAILED deploy" >&2
        echo >&2
        docker stack ps "$STACK" --no-trunc \
            --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}' >&2 || true
        die "deploy rolled back:$rolled_back"
    fi

    if [ -z "$pending" ]; then
        echo "    all services converged"
        break
    fi

    if [ "$(date +%s)" -ge "$deadline" ]; then
        printf '\n\033[31mdid not converge:\033[0m%s\n' "$pending" >&2
        # Show WHY, not just that it failed. --no-trunc because the useful half of a task error is
        # usually past the truncation point.
        echo >&2
        docker stack ps "$STACK" --no-trunc \
            --filter 'desired-state=running' \
            --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}' >&2 || true
        die "convergence timeout after ${TIMEOUT}s"
    fi

    printf '    still pending:%s\n' "$pending"
    sleep "$INTERVAL"
done

# ---------------------------------------------------------------------------------------------
# Report. Print the RESOLVED DIGESTS, not the tags that were asked for.
# ---------------------------------------------------------------------------------------------
say "deployed state"
docker stack services "$STACK"

# Swarm resolves a tag to a digest when it accepts the spec and stores the digest, so a service
# does not follow a moving tag the way `docker compose pull` does. Printing the digest is the only
# honest answer to "what is actually running?" - and the only way to notice that a redeploy of
# :latest changed nothing.
say "resolved images (what is ACTUALLY running)"
for svc in $(docker stack services "$STACK" --format '{{.Name}}'); do
    printf '  %-24s %s\n' "$svc" \
        "$(docker service inspect "$svc" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')"
done

# ---------------------------------------------------------------------------------------------
# Smoke gate. Convergence answers "did Swarm do what I asked". This answers "does it work".
# ---------------------------------------------------------------------------------------------
# MEASURED Aug 18 2026, with postgres scaled to 0 and the backend left running:
#
#   docker service ps            2 tasks Running, no failures      <- passed
#   docker stack services        capricorn_backend 2/2             <- passed
#   restart_policy/max_attempts  never triggered                   <- passed
#   the convergence poll above   would converge and print digests  <- passed
#   /health                      {"status":"healthy"}              <- passed
#   /api/v1/banking/health       {"status":"healthy",...}          <- passed
#   /api/v1/banking/categories   500                               <- THE ONLY HONEST SIGNAL
#
# Six of seven checks passed with no database. The orchestrator was not wrong: its job ends at
# "the process is running", and it did that correctly. Everything past that boundary is the
# application's claim about itself, and that claim can be false. So test the claim.
if [ "$SMOKE" = "1" ]; then
    base="http://${SMOKE_HOST}:${SMOKE_PORT}"
    say "smoke gate: is it ready for business? (timeout ${SMOKE_TIMEOUT}s)"

    # Gate 1 - a dependency-exercising endpoint must return 200 AND look right. The body check
    # matters because a 200 with an error payload is a real thing; so is a proxy answering for a
    # dead app.
    deadline=$(( $(date +%s) + SMOKE_TIMEOUT ))
    tmp_body="$(mktemp)"
    trap 'rm -f "$tmp_body"' EXIT

    while :; do
        # ONE request, not two: capture the body and the status from the same call. Two calls can
        # straddle the moment the app becomes ready and report a 200 with an empty body, or worse,
        # pass a check against a response nobody looked at.
        #
        # `|| true` and NOT `|| echo 000`: on a refused connection curl already writes 000 via -w
        # AND exits non-zero, so the fallback appended a second 000 and printed "HTTP 000000".
        # A nonsense status code in a CI log is a real cost - somebody will search for it.
        code="$(curl -sS -o "$tmp_body" -w '%{http_code}' --max-time 10 "${base}${SMOKE_PATH}" 2>/dev/null || true)"
        [ -n "$code" ] || code="000"
        body="$(cat "$tmp_body")"

        if [ "$code" = "200" ] && printf '%s' "$body" | grep -qF "$SMOKE_EXPECT"; then
            echo "    ${SMOKE_PATH} -> 200, body matched"
            break
        fi

        if [ "$(date +%s)" -ge "$deadline" ]; then
            printf '\n\033[31mSMOKE FAILED:\033[0m %s returned %s\n' "${SMOKE_PATH}" "$code" >&2
            printf '  body: %s\n\n' "$(printf '%s' "$body" | head -c 300)" >&2
            echo "The stack CONVERGED and is still broken - which is the whole reason this gate" >&2
            echo "exists. Check the app's own account of itself, not the task states:" >&2
            echo "  docker service logs ${STACK}_backend --tail 60" >&2
            echo "  docker service ps ${STACK}_postgres --no-trunc" >&2
            echo >&2
            die "smoke gate failed on ${SMOKE_PATH} (HTTP ${code})"
        fi

        printf '    waiting for %s (HTTP %s)\n' "${SMOKE_PATH}" "$code"
        sleep "$SMOKE_INTERVAL"
    done

    # Gate 2 - a status code alone would happily pass an EMPTY database. That is the subtler
    # outage: the backend starts before postgres, its one-shot bootstrap never runs, the
    # connection pool then reconnects lazily and every endpoint returns 200 with zero rows.
    # A 500 gets noticed. Green dashboards over an empty database do not.
    if [ -n "$SMOKE_ROWS_PATH" ]; then
        rows_body="$(curl -sS --max-time 10 "${base}${SMOKE_ROWS_PATH}" 2>/dev/null || true)"
        total="$(printf '%s' "$rows_body" | sed -nE 's/.*"total":[[:space:]]*([0-9]+).*/\1/p' | head -1)"

        if [ -z "$total" ]; then
            echo "    ⚠️  could not read \"total\" from ${SMOKE_ROWS_PATH} - row check SKIPPED, not passed"
        elif [ "$total" -lt "$SMOKE_MIN_ROWS" ]; then
            printf '\n\033[31mSMOKE FAILED:\033[0m %s reports total=%s, expected >= %s\n' \
                "${SMOKE_ROWS_PATH}" "$total" "$SMOKE_MIN_ROWS" >&2
            echo "Every endpoint answers 200 over an EMPTY database. The likely cause is a" >&2
            echo "one-shot startup bootstrap that ran before the database was reachable and" >&2
            echo "never re-ran. Restarting the app re-runs it:" >&2
            echo "  docker service update --force ${STACK}_backend" >&2
            die "smoke gate: database is empty (total=${total})"
        else
            echo "    ${SMOKE_ROWS_PATH} -> total=${total} rows"
        fi
    fi
else
    printf '\n\033[33m==> smoke gate SKIPPED (SMOKE=0)\033[0m\n'
    echo "    Convergence only proves Swarm did what it was told. Nothing here has confirmed"
    echo "    the application can serve a request that touches its database."
fi

say "done"
