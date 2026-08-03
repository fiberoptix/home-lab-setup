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

set -euo pipefail

IMAGE=${IMAGE:-oms:dev}
HERE=$(cd "$(dirname "$0")" && pwd)

echo "==> building $IMAGE"
docker build -t "$IMAGE" "$HERE"

echo "==> importing into k3s containerd (namespace k8s.io)"
docker save "$IMAGE" | sudo k3s ctr images import -

echo "==> verifying k3s can see it"
sudo k3s ctr images ls -q | grep -F "$IMAGE" || {
  echo "ERROR: $IMAGE not present in k3s containerd"; exit 1
}
echo "OK: $IMAGE ready"
