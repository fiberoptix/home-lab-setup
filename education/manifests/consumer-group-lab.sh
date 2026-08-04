#!/usr/bin/env bash
#
# Chapter 5 lab — consumer groups, rebalancing and delivery semantics.
# Replays the 3 Aug 2026 session on vm-k8-redpanda-1 step by step.
#
#   ./consumer-group-lab.sh reset      wipe the topic and group, start clean
#   ./consumer-group-lab.sh seed N     produce N keyed records
#   ./consumer-group-lab.sh start N    start consumer cN in the background
#   ./consumer-group-lab.sh who        who owns what, and surplus-member check
#   ./consumer-group-lab.sh work       records processed per consumer
#   ./consumer-group-lab.sh keys       the key -> partition map
#   ./consumer-group-lab.sh dups       offsets processed more than once
#   ./consumer-group-lab.sh load N     slow trickle of N records, backgrounded
#   ./consumer-group-lab.sh stop       kill every consumer and the load generator
#
# The point of the lab is the contrast in step 5:
#   kill %N       SIGTERM  -> commits, leaves cleanly, ZERO duplicates
#   kill -9 %N    SIGKILL  -> cannot commit, successor replays, DUPLICATES
#
# Run it from a directory you don't mind filling with c*.log files.

set -uo pipefail

TOPIC=${TOPIC:-orders}
GROUP=${GROUP:-oms-processor}
PARTS=${PARTS:-6}
KEYS=${KEYS:-12}
LOGDIR=${LOGDIR:-.}

# Records carry a key so partitioning is deterministic: hash(key) % PARTS.
# Equal volume per key means partition load == number of keys that hashed there,
# which is what makes the skew in Ch5 3 legible.
emit() {                       # emit <from> <to>
  local i k
  for i in $(seq "$1" "$2"); do
    k="ORD-$(( (i % KEYS) + 1 ))"
    printf '%s\t{"order":"%s","seq":%d,"event":"FILL"}\n' "$k" "$k" "$i"
  done
}

case "${1:-}" in

  reset)
    rpk topic delete "$TOPIC" 2>/dev/null
    rpk group delete "$GROUP" 2>/dev/null
    rpk topic create "$TOPIC" -p "$PARTS" -r 3
    rm -f "$LOGDIR"/c*.log
    echo "clean: topic $TOPIC ($PARTS partitions), group $GROUP deleted, logs removed"
    ;;

  seed)
    n=${2:-120}
    # pipefail is set, so this catches a produce that failed while the emit
    # side succeeded. Reporting "produced 120 records" after the brokers
    # refused them makes every later count in the lab a lie.
    if ! emit 1 "$n" | rpk topic produce "$TOPIC" -f '%k\t%v\n' >/dev/null; then
      echo "ERROR: produce failed; the record count below is NOT $n"
      rpk topic describe "$TOPIC" -p
      exit 1
    fi
    echo "produced $n records"
    rpk topic describe "$TOPIC" -p
    ;;

  load)                        # trickle, so you can watch lag build during a kill
    n=${2:-600}
    # seq is inclusive at both ends, so the end point is start + n - 1.
    ( emit 10000 $((10000 + n - 1)) | while IFS= read -r line; do
        printf '%s\n' "$line"; sleep 0.1
      done | rpk topic produce "$TOPIC" -f '%k\t%v\n' >/dev/null ) &
    echo "load generator started as job $! ($n records at 10/s)"
    ;;

  start)
    n=${2:?usage: start N}
    # APPEND, never truncate. Restarting c1 after a kill is the central move of
    # the lab, and `>` would erase the pre-crash offsets -- which are exactly
    # the evidence `dups` compares against.
    # < /dev/null keeps nohup from writing its "ignoring input" banner into the log
    nohup rpk topic consume "$TOPIC" -g "$GROUP" -o start \
      -f '%p %o %k\n' < /dev/null >> "$LOGDIR/c$n.log" 2>&1 &
    echo "c$n started, pid $!"
    ;;

  who)
    rpk group describe "$GROUP"
    echo
    # $7 is MEMBER-ID. The full header is
    #   TOPIC PARTITION CURRENT-OFFSET LOG-START-OFFSET LOG-END-OFFSET LAG \
    #   MEMBER-ID CLIENT-ID HOST
    # -- nine columns, which is worth checking against your rpk version before
    # trusting any fixed index (Ch5 1).
    m=$(rpk group describe "$GROUP" | awk '/^MEMBERS/{print $2}')
    o=$(rpk group describe "$GROUP" | awk -v t="$TOPIC" 'NF>6 && $1==t{print $7}' | sort -u | wc -l)
    echo "members=$m  owners=$o"
    # if/fi, not &&: a trailing && test that is false makes the whole script
    # exit 1, so the healthy case would look like a failure to any caller.
    if [ "$m" -gt "$o" ]; then
      echo "  -> $((m - o)) surplus consumer(s): more members than partitions (Ch5 2)"
    fi
    ;;

  work)
    for f in "$LOGDIR"/c*.log; do
      [ -e "$f" ] || continue
      printf '%-10s %5s records   partitions: %s\n' "$(basename "$f" .log)" \
        "$(grep -c '^[0-9]' "$f")" \
        "$(awk '/^[0-9]/{print $1}' "$f" | sort -un | tr '\n' ' ')"
    done
    ;;

  keys)
    cat "$LOGDIR"/c*.log 2>/dev/null | awk '/^[0-9]/{print $3, $1}' | sort -u \
      | awk '{k[$2]=k[$2]" "$1} END{for (p=0;p<'"$PARTS"';p++) printf "p%s:%s\n", p, (k[p]==""?" (none)":k[p])}'
    ;;

  dups)
    # A partition has ONE owner at a time, so the same offset appearing in two
    # logs means a successor replayed from an uncommitted position.
    for p in $(seq 0 $((PARTS - 1))); do
      d=$(cat "$LOGDIR"/c*.log 2>/dev/null | awk -v p="$p" '$1==p{print $2}' | sort -n | uniq -d)
      [ -n "$d" ] && printf 'p%s duplicated offsets: %s\n' "$p" "$(echo "$d" | tr '\n' ' ')"
    done
    echo "(empty output = clean handovers only)"
    ;;

  stop)
    pkill -f "rpk topic consume $TOPIC" 2>/dev/null
    pkill -f "rpk topic produce $TOPIC" 2>/dev/null
    echo "stopped consumers and producers"
    ;;

  *)
    sed -n '3,20p' "$0"
    exit 1
    ;;
esac
