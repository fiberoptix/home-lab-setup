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
# Third gate (added Aug 18 2026, after drill C6b): the gates above only defend the port they call.
# A deploy that replaced the frontend with a stock nginx image sailed through both - UpdateStatus
# `completed`, backend smoke green - because nothing ever asked :5001 a question. One assertion per
# published port, and the body match must be something ONLY OUR APP would serve (nginx's welcome
# page returns 200; `grep -ci capricorn` on it returned 0, measured).
SMOKE_UI_PORT="${SMOKE_UI_PORT:-5001}"
SMOKE_UI_PATH="${SMOKE_UI_PATH:-/}"
SMOKE_UI_EXPECT="${SMOKE_UI_EXPECT:-capricorn}"

die() { printf '\n\033[31mFAILED:\033[0m %s\n' "$*" >&2; exit 1; }
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------------------------------------
# Pre-flight. Fail on the cheap checks before touching the cluster.
# ---------------------------------------------------------------------------------------------
[ -f "$STACK_FILE" ] || die "stack file not found: $STACK_FILE"

# docker node ls only succeeds on a manager, which makes it a free "am I in the right place" test.
docker node ls >/dev/null 2>&1 || die "not a swarm manager (or swarm is inactive) - run this on a manager"

# Is the CLUSTER healthy, not just "am I a manager"? Added Aug 19 2026 after trap C4 burned 300
# seconds arriving at a wrong answer.
#
# ⭐ The lesson: a deploy into a degraded cluster produces a result that CANNOT BE TRUSTED IN EITHER
# DIRECTION. With docker-swarm-1 powered off, this script deployed, then declared "did not converge"
# and named capricorn_backend and capricorn_frontend - both of which were completely healthy - while
# capricorn_postgres, which had ceased to exist, passed the check. Green or red, the verdict was
# uninformative, and it took five minutes to produce.
#
# So ask the cheap question FIRST and answer it accurately: a node that is not Ready means tasks may
# be unschedulable and phantom tasks on the unreachable node will corrupt every replica count taken
# afterwards. Two seconds, and it names the actual fault.
degraded="$(docker node ls --format '{{.Hostname}} {{.Status}} {{.Availability}}' \
    | awk '$2 != "Ready" || $3 != "Active" { printf " %s(%s/%s)", $1, $2, $3 }')"
if [ -n "$degraded" ]; then
    printf '\n\033[31mCLUSTER DEGRADED:\033[0m%s\n' "$degraded" >&2
    echo "Refusing to deploy. Not because the deploy would necessarily fail - it might well" >&2
    echo "succeed - but because NOTHING THIS SCRIPT CHECKS AFTERWARDS WOULD MEAN ANYTHING:" >&2
    echo "  * tasks on an unreachable node still count as Running (Swarm cannot confirm a" >&2
    echo "    shutdown it cannot deliver), so replica counts read high and hide real failures" >&2
    echo "  * a service pinned to the missing node can never schedule, and reports the phantom" >&2
    echo "    as its healthy replica" >&2
    echo >&2
    echo "  docker node ls" >&2
    echo "  docker service ps <service> --no-trunc     # the only view that stays honest" >&2
    echo >&2
    # An escape hatch, on purpose. During a real incident, deploying into a degraded cluster is
    # sometimes exactly the right call, and a tool that makes the correct action impossible gets
    # worked around in ways nobody records. Make it deliberate and make it LOUD, not impossible.
    if [ "${ALLOW_DEGRADED:-0}" = "1" ]; then
        printf '\033[33m  ALLOW_DEGRADED=1 - proceeding anyway. Treat every check below as ADVISORY.\033[0m\n' >&2
    else
        die "cluster degraded:$degraded (override with ALLOW_DEGRADED=1 if this is deliberate)"
    fi
fi

# The stack references an external secret. Creating it here would mean inventing a password in a
# script; requiring it means the deploy fails fast with a clear reason instead of a confused
# postgres that cannot authenticate.
#
# ⚠️ The name is hardcoded, and drill D showed the limit of that: an `external:` secret can carry a
# `name:` override in the manifest (we rotated via `name: pg_password_v2`), in which case this check
# inspects a secret the stack no longer uses. Good enough while the manifest is ours; a general tool
# would have to parse the manifest's secrets block instead of assuming.
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

# Printing the path above is a courtesy, not a control - a voided drill proved nobody reads it at
# the moment it matters. What CAN be asserted is that an override was intentional: if STACK_FILE
# came from the environment, make it impossible to miss.
default_stack_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/../manifests" && pwd)/capricorn.stack.yml"
if [ "$STACK_FILE" != "$default_stack_file" ]; then
    printf '\n\033[33m==> NON-DEFAULT STACK FILE\033[0m\n'
    printf '    deploying: %s\n    default:   %s\n' "$STACK_FILE" "$default_stack_file"
    printf '    If you are running a drill, this line is your precondition - check it NOW.\n'
fi

# Snapshot each service's UpdateStatus BEFORE deploying. UpdateStatus is a latch that persists
# until the next update begins, so a rollback_completed left over from an OLD failure would
# otherwise fail this deploy of a healthy cluster. Comparing to the pre-deploy state separates
# "this deploy rolled back" from "an earlier one did".
declare -A pre_state
while read -r name; do
    pre_state["$name"]="$(docker service inspect "$name" \
        --format '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}' 2>/dev/null || true)"
done < <(docker stack services "$STACK" --format '{{.Name}}' 2>/dev/null || true)

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
# Replica count alone is NOT a sufficient test, and this is easy to get wrong. Two of these
# services (frontend and backend) use `order: start-first`, which starts the replacement task
# BEFORE stopping the old one, so running/desired can read 3/3 continuously through an entire
# rolling replacement - and can briefly read 4/3. A deploy that swapped every container for a
# broken image could satisfy a count-only check on the first poll.
#
# 🚨 REWRITTEN Aug 19 2026, after trap C4 proved the previous version INVERTED. It read the
# `Replicas` column of `docker stack services` and tested `current != desired`. With
# docker-swarm-1 powered off, that produced, for five minutes:
#
#   still pending: capricorn_backend(3/2) capricorn_frontend(4/3)     <- both perfectly healthy
#   ...and capricorn_postgres silently PASSING, having ceased to exist
#
# Two separate defects, one root cause - the WRONG INSTRUMENT:
#
#   1. `Replicas` counts a task whose desired state is Shutdown but whose current state is still
#      Running, which is exactly what a task on an UNREACHABLE node looks like forever, because
#      Swarm cannot confirm a shutdown it cannot deliver. One phantom inflated backend to 3/2.
#   2. For postgres, the phantom was the ONLY thing counted: one unconfirmable ghost on the dead
#      node plus one replacement stuck Pending on an unsatisfiable pin summed to a green 1/1.
#
# So count TASKS, filtered to `desired-state=running`, which excludes phantoms by construction -
# the same filter the failure dump below has always used, which is why that dump printed the
# CORRECT task list directly underneath a wrong headline. ⭐ Ask the layer that knows.
#
# ⚠️ And note what the `!=` test was incidentally protecting, because replacing it with `<` on its
# own would have been a REGRESSION: the equality test also blocked the window between
# `docker stack deploy` returning and the manager setting UpdateStatus, during which a stale
# `completed` from a previous rollout could be read as this rollout finishing. That window is now
# covered explicitly by the settle delay below.
# ⚠️ OPEN CLAIM for Phase 17: the settle delay is a mitigation, not a proof. The rigorous version
# compares each service's `.Version.Index` across the deploy and only trusts UpdateStatus for
# services whose index actually moved. Untested here, so not claimed as done.
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
# ✅ VERIFIED Aug 18 2026 (drill C6a): a deliberately unpullable image made failure_action fire and
# this loop caught `rollback_started` in 1.3 seconds. Detection works.
#
# ⚠️ Still open: UpdateStatus is a LATCH - it persists until the next update starts. If a redeploy
# sends an identical spec, no new update begins, and a stale `rollback_completed` from an earlier
# failure would linger. The pre_state snapshot taken before the deploy handles it: a rollback state
# that is IDENTICAL to what we saw before deploying is reported loudly but not treated as this
# deploy's failure.
say "waiting for convergence (timeout ${TIMEOUT}s)"

# Settle delay: see the UpdateStatus window noted above. `docker stack deploy` returns when the
# manager has ACCEPTED the spec, and UpdateStatus flips to `updating` a moment later. Polling inside
# that gap can read the PREVIOUS rollout's `completed` and call a brand-new deploy converged.
sleep "$INTERVAL"

deadline=$(( $(date +%s) + TIMEOUT ))
while :; do
    pending=""
    rolled_back=""
    while read -r name; do
        # Desired count from the SPEC, not from a formatted column. Replicated services carry it
        # directly; a global service has none, so fall back to the number of tasks Swarm wants.
        desired="$(docker service inspect "$name" \
            --format '{{if .Spec.Mode.Replicated}}{{.Spec.Mode.Replicated.Replicas}}{{end}}' 2>/dev/null || true)"
        if [ -z "$desired" ]; then
            desired="$( { docker service ps "$name" --filter desired-state=running \
                --format '{{.ID}}' 2>/dev/null || true; } | awk 'END {print NR+0}')"
        fi

        # Running count from TASKS Swarm still wants alive. `desired-state=running` is what excludes
        # the phantom on an unreachable node: its desired state is Shutdown, so it is not counted
        # here even though `docker stack services` reports it as a live replica.
        running="$( { docker service ps "$name" --filter desired-state=running \
            --format '{{.CurrentState}}' 2>/dev/null || true; } | awk '/^Running/ {n++} END {print n+0}')"

        state="$(docker service inspect "$name" --format '{{.UpdateStatus.State}}' 2>/dev/null || true)"

        case "$state" in
            rollback*)
                if [ "$state" = "${pre_state[$name]:-}" ]; then
                    # Stale latch from a PREVIOUS deploy - it was already there before we started.
                    printf '    ⚠️  %s carries a pre-existing %s (stale latch, not this deploy) - verify by hand\n' \
                        "$name" "$state"
                else
                    rolled_back="$rolled_back $name"
                fi
                ;;
        esac

        # `-lt`, not `!=`: an OVERSHOOT is not a failure. start-first legitimately runs desired+1
        # for part of a rollout, and blocking on that is what produced C4's five-minute wrong
        # answer. Whether a rollout has FINISHED is UpdateStatus's job, tested immediately below -
        # one instrument per question.
        if [ "$running" -lt "$desired" ] || [ "$desired" = "0" ]; then
            pending="$pending $name($running/$desired)"
        elif [ -n "$state" ] && [ "$state" != "completed" ]; then
            pending="$pending $name($state)"
        fi
    done < <(docker stack services "$STACK" --format '{{.Name}}')

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
            # This used to SKIP, which is a false green by another name: a gate that cannot read
            # its instrument must not wave the deploy through. Disable explicitly with
            # SMOKE_ROWS_PATH="" if the endpoint is intentionally gone.
            printf '\n\033[31mSMOKE FAILED:\033[0m could not read "total" from %s\n' "${SMOKE_ROWS_PATH}" >&2
            printf '  body: %s\n' "$(printf '%s' "$rows_body" | head -c 300)" >&2
            die "smoke gate: row-count endpoint unreadable - a gate that cannot measure must not pass"
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

    # Gate 3 - every published port gets one assertion. C6b (Aug 18 2026): the frontend was
    # replaced wholesale by nginx's welcome page and gates 1-2 stayed green, because both only
    # ever talk to :5002. A port nobody asks a question of can serve anything.
    if [ -n "$SMOKE_UI_PORT" ]; then
        ui_base="http://${SMOKE_HOST}:${SMOKE_UI_PORT}"
        deadline=$(( $(date +%s) + SMOKE_TIMEOUT ))
        while :; do
            ui_code="$(curl -sS -o "$tmp_body" -w '%{http_code}' --max-time 10 "${ui_base}${SMOKE_UI_PATH}" 2>/dev/null || true)"
            [ -n "$ui_code" ] || ui_code="000"
            ui_body="$(cat "$tmp_body")"

            # 200 is not the test - nginx's welcome page is a 200. The body must contain something
            # only OUR frontend serves.
            if [ "$ui_code" = "200" ] && printf '%s' "$ui_body" | grep -qiF "$SMOKE_UI_EXPECT"; then
                echo "    ${SMOKE_UI_PORT}${SMOKE_UI_PATH} -> 200, body matched '${SMOKE_UI_EXPECT}'"
                break
            fi

            if [ "$(date +%s)" -ge "$deadline" ]; then
                printf '\n\033[31mSMOKE FAILED:\033[0m port %s returned HTTP %s without %s\n' \
                    "${SMOKE_UI_PORT}" "$ui_code" "'${SMOKE_UI_EXPECT}'" >&2
                printf '  body starts: %s\n\n' "$(printf '%s' "$ui_body" | head -c 200)" >&2
                echo "A 200 here is NOT success - a stock nginx answers 200 too. Whatever is on" >&2
                echo "this port right now, it is not our application:" >&2
                echo "  docker service inspect ${STACK}_frontend --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'" >&2
                echo "  curl -s ${ui_base}${SMOKE_UI_PATH} | head" >&2
                die "smoke gate failed on published port ${SMOKE_UI_PORT}"
            fi

            printf '    waiting for %s%s (HTTP %s, no body match)\n' "${SMOKE_UI_PORT}" "${SMOKE_UI_PATH}" "$ui_code"
            sleep "$SMOKE_INTERVAL"
        done
    fi
else
    printf '\n\033[33m==> smoke gate SKIPPED (SMOKE=0)\033[0m\n'
    echo "    Convergence only proves Swarm did what it was told. Nothing here has confirmed"
    echo "    the application can serve a request that touches its database."
fi

say "done"
