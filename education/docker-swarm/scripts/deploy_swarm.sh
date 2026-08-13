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
# This script owns: registry login, the deploy, waiting for convergence, and failing loudly.
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
# The field is EMPTY on a service that has never been updated since creation, so empty is healthy.
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

say "done"
