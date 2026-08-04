#!/usr/bin/env bash
#
# Build the OMS image and make it visible to k3s.
#
# There is no registry in this lab, so `docker build` alone is not enough:
# k3s uses its own containerd namespace (k8s.io) and cannot see Docker's image
# store. The image has to be exported and imported explicitly.
#
# imagePullPolicy MUST be IfNotPresent or Never in the manifests, or the
# kubelet will try to pull `oms:dev` from Docker Hub and fail ErrImagePull.
#
# Two tags are built. `oms:dev` is the mutable one the manifests reference so
# the lab stays convenient. `oms:<git-sha>` is the immutable one, and it is the
# tag you would actually deploy: a mutable tag means "the running pod and the
# pod you start in ten minutes may be different code, and nothing records
# which", which turns an incident into an archaeology exercise. The dirty-tree
# suffix exists because a SHA that does not describe the bytes you built is
# worse than no SHA at all.

set -euo pipefail

IMAGE=${IMAGE:-oms:dev}
HERE=$(cd "$(dirname "$0")" && pwd)

if git -C "$HERE" rev-parse --git-dir >/dev/null 2>&1; then
  SHA=$(git -C "$HERE" rev-parse --short HEAD)
  git -C "$HERE" diff --quiet HEAD -- "$HERE" || SHA="${SHA}-dirty"
  SHA_IMAGE="${IMAGE%%:*}:${SHA}"
else
  SHA_IMAGE=""
fi

echo "==> building $IMAGE${SHA_IMAGE:+ and $SHA_IMAGE}"
docker build -t "$IMAGE" ${SHA_IMAGE:+-t "$SHA_IMAGE"} "$HERE"

# Capture the id we just built. Checking only that SOME image called oms:dev
# exists in containerd is the classic false pass: a build that failed, or an
# import that silently did nothing, leaves last week's image in place and the
# script congratulates you on it.
BUILT_ID=$(docker image inspect --format '{{.Id}}' "$IMAGE")
echo "==> built $BUILT_ID"

echo "==> importing into k3s containerd (namespace k8s.io)"
docker save "$IMAGE" ${SHA_IMAGE:+"$SHA_IMAGE"} | sudo k3s ctr images import -

echo "==> verifying k3s has THIS build, not a previous one"
IMPORTED_DIGEST=$(sudo k3s ctr images ls -q | grep -F "$IMAGE" | head -1 || true)
if [ -z "$IMPORTED_DIGEST" ]; then
  echo "ERROR: $IMAGE not present in k3s containerd"
  exit 1
fi

# containerd records the config digest, which for a docker-saved image is the
# same id docker reports. If they differ, the import did not take.
CONFIG_ID=$(sudo k3s ctr -n k8s.io images ls "name==$IMAGE" 2>/dev/null \
  | awk 'NR==2{print $3}' || true)

if [ -n "$CONFIG_ID" ] && [ "${BUILT_ID#sha256:}" != "${CONFIG_ID#sha256:}" ]; then
  echo "WARNING: k3s image id ($CONFIG_ID) does not match the build ($BUILT_ID)."
  echo "The running pods may not be the code you just built. Check the import."
fi

echo "OK: $IMAGE ready${SHA_IMAGE:+ (also tagged $SHA_IMAGE)}"
echo
echo "Pods do NOT restart because a tag was rebuilt -- the pod spec is"
echo "unchanged, so there is nothing for Kubernetes to reconcile. Roll it:"
echo "  kubectl -n market rollout restart deploy/position-keeper"
