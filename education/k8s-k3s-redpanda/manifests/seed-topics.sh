#!/usr/bin/env bash
#
# Declarative-ish topic seeding for Redpanda.
#
# Converges on CORRECTNESS, not just presence:
#   missing topic        -> created
#   Tier 1 config drift  -> fixed in place (retention, cleanup policy, ...)
#   Tier 2 drift (RF)    -> reported, exit 1  (needs a reassignment operation)
#   Tier 3 drift (parts) -> reported, exit 1  (NOT fixable; see Ch3 2d)
#
# Exits 0 only when every topic matches its declared shape, so a pipeline can
# gate on it. Deliberately does NOT auto-"fix" partition count: growing a keyed
# topic relocates ~half the keys and splits their history.
#
# No jq: the Redpanda broker image ships rpk and bash but not jq, so the topic
# summary is parsed with awk.
#
# Usage:
#   BROKERS=redpanda.redpanda.svc.cluster.local:9093 ./seed-topics.sh
#   ./seed-topics.sh                 # uses the ambient rpk profile

set -uo pipefail        # NOT -e: collect every drift before failing

if [ -n "${BROKERS:-}" ]; then
  RPK=(rpk -X "brokers=${BROKERS}")
else
  RPK=(rpk)
fi

# Reachability is not drift. Without this check an unreachable cluster makes
# `topic describe` fail, every topic looks absent, every create fails, and the
# script reports permanent un-fixable damage to topics that are in fact fine.
# Exit 2 says "I could not tell", which is a different page than exit 1's
# "I looked and the declared state is not there".
if ! "${RPK[@]}" cluster info >/dev/null 2>&1; then
  echo "UNREACHABLE: no broker answered. This is a connectivity or quorum"
  echo "problem, NOT topic drift; nothing was created or altered."
  exit 2
fi

# name : partitions : replication factor : comma-separated tier-1 configs
TOPICS=(
  "orders:6:3:retention.ms=604800000"
  "executions:6:3:retention.ms=604800000"
  "orders-v2:6:3:retention.ms=604800000"
)

drift=0

for spec in "${TOPICS[@]}"; do
  IFS=: read -r name want_p want_rf cfgs <<<"$spec"

  if ! "${RPK[@]}" topic describe "$name" >/dev/null 2>&1; then
    echo "CREATE   $name  partitions=$want_p rf=$want_rf"
    if ! "${RPK[@]}" topic create "$name" -p "$want_p" -r "$want_rf" >/dev/null; then
      echo "ERROR    $name  create failed"
      drift=1
      continue
    fi
  else
    summary=$("${RPK[@]}" topic describe "$name" 2>/dev/null)
    have_p=$(awk '/^PARTITIONS/{print $2}' <<<"$summary")
    have_rf=$(awk '/^REPLICAS/{print $2}'  <<<"$summary")

    # An empty parse is not a match and not a mismatch -- it means the output
    # shape changed under us. Saying "declared=6 actual=" invites someone to
    # "fix" a topic that was never inspected.
    if ! [[ "$have_p" =~ ^[0-9]+$ && "$have_rf" =~ ^[0-9]+$ ]]; then
      echo "ERROR    $name  could not parse describe output (p='$have_p' rf='$have_rf')"
      drift=1
      continue
    fi

    ok=1
    # Two independent ifs, not if/elif. Chaining them reports only the first
    # fault, so a topic that is wrong in both dimensions sends you round the
    # deploy loop twice -- the serial reveal the no--e design exists to avoid.
    if [ "$have_p" != "$want_p" ]; then
      echo "DRIFT    $name  partitions: declared=$want_p actual=$have_p  << NOT AUTO-FIXABLE"
      drift=1; ok=0
    fi
    if [ "$have_rf" != "$want_rf" ]; then
      echo "DRIFT    $name  replication: declared=$want_rf actual=$have_rf  << needs reassignment"
      drift=1; ok=0
    fi
    [ "$ok" -eq 1 ] && echo "OK       $name  partitions=$have_p rf=$have_rf"
  fi

  # Tier 1: reconcile in-place configs regardless of the above.
  [ -z "${cfgs:-}" ] && continue
  configs=$("${RPK[@]}" topic describe "$name" -c 2>/dev/null)
  IFS=, read -ra kvs <<<"$cfgs"
  for kv in "${kvs[@]}"; do
    key=${kv%%=*}
    want=${kv#*=}
    have=$(awk -v k="$key" '$1==k{print $2}' <<<"$configs")
    if [ "$have" != "$want" ]; then
      echo "FIX      $name  $key: $have -> $want"
      if ! "${RPK[@]}" topic alter-config "$name" --set "$kv" >/dev/null 2>&1; then
        echo "ERROR    $name  could not set $key"
        drift=1
      fi
    fi
  done
done

if [ "$drift" -ne 0 ]; then
  echo
  echo "FAILED: declared state not reached. See DRIFT lines above."
  exit 1
fi

echo
echo "OK: all topics match declared state"
