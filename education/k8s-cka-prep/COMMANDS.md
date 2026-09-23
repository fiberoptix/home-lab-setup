# Kubernetes (CKA) command ledger

Every command this track has used, **organised by the question it answers rather than by the chapter it
appeared in.** Chapters teach in the order things were learned; an incident does not cooperate with that
order. The skill this file trains is *which question to ask second*.

**Started Sep 23, 2026**, seeded from chapters 01–04 and the Phase 18 record. ⚠️ **It should have existed
from Stage 0** — `education/METHOD.md` asks for it — so §1–§12 are a reconstruction from the record, not a
log kept at the keyboard. **From chapter 05 on, entries are added as they are run.**

**Verified?** column:
- ✅ **ran it here** — executed in this lab, output understood
- ⚠️ **standard, not run here** — believed correct, **not** exercised. Do not present as tested.
- 🔲 **planned** — designed, not yet run.

📌 **Two working rules for this whole file.** Kubernetes commands are run **on a node**, never from the
workstation — the exam's desktop has no `kubectl` at all (`lab-parity.md` §5). And `etcdctl` needs three
certificate flags every time; they are written out once in §3 and shortened to `etcdctl …` after that.

---

## 0. How blocks of these get run

⭐ **Multi-line blocks go in `scratch/run_command.sh` and run as a file, from the workstation** — the same
practice as the Swarm track, for the same reason: a pasted block beginning with `ssh` leaves the remaining
lines in the terminal's buffer, where the wrong shell consumes them.
⚠️ **That runner is for lab plumbing and verification only.** For exam practice, type commands on the node
— there is no runner in the exam.

---

## 1. The 3am order — is the CLUSTER healthy?

Ask these in this order. Each answer narrows where to look next.

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Are all nodes up? | `kubectl get nodes -o wide` | ✅ | Workers read `<none>` under ROLES — **normal**, there is no worker role |
| Is anything not running? | `kubectl get pods -A --no-headers \| awk '$4!="Running" && $4!="Completed"'` | ✅ | Empty = healthy. Baseline: 43 system pods |
| Does etcd have quorum, and do the members agree? | `etcdctl … endpoint status --cluster -w table` | ✅ | One `IS LEADER true`; `RAFT INDEX` equal or 1–2 apart (sampling). Thousands apart = a member falling behind |
| Who holds the VIP? | `ip -br addr show eth0` on each control plane | ✅ | **Exactly one** shows `192.168.1.206/32`. Two = duplicate addresses on the wire |
| Is the API answering *through* the VIP? | `kubectl get --raw /livez` | ✅ | `admin.conf` points at `.206`, so this tests the VIP, not a node |
| Is the pod network healthy by its own account? | `kubectl get tigerastatus` | ✅ | `apiserver`, `calico`, `ippools`, `tiers` all `True` |

---

## 2. Why won't this node become Ready — or the kubelet start?

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| What is the kubelet actually doing? | `systemctl show kubelet -p UnitFileState -p ActiveState -p SubState -p NRestarts` | ✅ | `activating (auto-restart)` + rising `NRestarts` on a prepared, un-joined node is **correct** |
| Why won't it start? | `sudo journalctl -u kubelet -n 3 --no-pager -o cat` | ✅ | `open /var/lib/kubelet/config.yaml: no such file` = **no role yet**, not a fault. `init`/`join` writes that file |
| Does the node have a role at all? | `sudo ls -A /etc/kubernetes/` | ✅ | Only `manifests/` = no role |
| Is swap really off? | `swapon --show` | ✅ | Silence is success. Check `/etc/fstab` too, or it returns after a reboot |
| Are the kernel modules loaded? | `lsmod \| grep -E '^overlay\|^br_netfilter'` | ✅ | Loaded *now*; `/etc/modules-load.d/k8s.conf` is what survives a reboot |
| Did the kernel accept the sysctls? | `sysctl -n net.ipv4.ip_forward net.bridge.bridge-nf-call-iptables` | ✅ | Read from the kernel, not the file. `net.bridge.*` does not exist until `br_netfilter` is loaded |
| Can containerd serve CRI at all? | `sudo ctr plugins ls \| awk '/grpc.*\<cri\>/{print $4}'` | ✅ | Must print `ok`. Docker-built hosts ship `disabled_plugins = ["cri"]` |
| Do the cgroup drivers match? | `grep SystemdCgroup /etc/containerd/config.toml` | ✅ | Must be `true`. A mismatch fails **later and intermittently**, not at install |
| Which Kubernetes packages are frozen? | `apt-mark showhold` | ✅ | Baseline: `containerd.io cri-tools kubeadm kubectl kubelet` |
| Is the running kernel the installed one? | `uname -r` against `ls /boot/vmlinuz-*` | ✅ | A newer file than the running kernel = a pending reboot |
| What installed that package, and when? | `sudo zgrep -h -A3 -B3 '<pkg>' /var/log/apt/history.log*` | ✅ | Found the 6.8.0-139 kernel arrived via `unattended-upgrade` at 02:07, not our build |
| Will unattended-upgrades reboot a node by itself? | `sudo apt-config dump \| grep -iE 'Unattended-Upgrade::(Allowed-Origins\|Automatic-Reboot)'` | ✅ | `Automatic-Reboot` unset = never. Allowed-Origins excluded Docker's and Kubernetes' repos |

---

## 3. The control plane and etcd

The full `etcdctl` form — the three certificate flags are required every time:

```bash
kubectl -n kube-system exec etcd-vm-k8s-cka-control-1 -- etcdctl \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  endpoint status --cluster -w table
```

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Who are the members? | `etcdctl … member list -w table` | ✅ | `started` = in the list. It does **not** mean they agree — compare raft indices |
| Is one member down? | `etcdctl … endpoint status --cluster -w table` | ✅ | A dead member prints `context deadline exceeded` **and the table still prints for the rest** |
| Was there an election? | the `RAFT TERM` column, before and after | ✅ | Unchanged term = no election. Killing a follower should not change it |
| Was this static pod replaced, or restarted? | `kubectl get pod -n kube-system -o custom-columns=NAME:.metadata.name,CREATED:.metadata.creationTimestamp,RESTARTS:.status.containerStatuses[0].restartCount,UID:.metadata.uid` | ✅ | A manifest edit **recreates** the pod — new UID, fresh counter. `RESTARTS 0` does not mean untouched |
| Why can't ordinary pods land on a control plane? | `kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key` | ✅ | `node-role.kubernetes.io/control-plane` = `NoSchedule` |
| Same, the longer way | `kubectl describe node <n> \| grep Taints` | ⚠️ | Standard; this lab used the custom-columns form above |
| When do the certificates expire? | `sudo kubeadm certs check-expiration` | ✅ | Control-plane certs only. **Kubelet client certs are not listed** and rotate sooner |
| What does the API server's certificate actually cover? | `sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text \| grep -A1 "Subject Alternative Name"` | ⚠️ | This lab read the SANs from the `init --dry-run` output instead (§8) |
| What did `init` record about the cluster? | `kubectl -n kube-system get cm kubeadm-config -o yaml` | ⚠️ | Standard; not run here |

---

## 4. The container runtime — what does containerd actually hold?

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| What containers does Kubernetes see? | `sudo crictl ps -a` | ✅ | Needs `/etc/crictl.yaml` pointing at the socket — current `crictl` has no fallback |
| Did `crictl` reach containerd? | `sudo crictl version` | ✅ | A `RuntimeVersion` line = connected. `crictl --version` only proves the binary exists |
| Which images can the kubelet use? | `sudo crictl images` | ✅ | Reads containerd's **`k8s.io`** namespace |
| Pull an image the kubelet will see | `sudo ctr -n k8s.io image pull <image>` | ✅ | Without `-n k8s.io`, `ctr` pulls into `default` and **`crictl` never sees it** |
| What did plain `ctr` pull? | `sudo ctr -n default images ls` | ⚠️ | Suggested, not run — the invisibility was shown through `crictl` |

---

## 5. The VIP and high availability

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Who holds the VIP? | `ip -br addr show eth0 \| grep -o '192.168.1.206/32'` on each | ✅ | Leader election for the VIP is **separate** from etcd's — they need not be the same node |
| How long was the API down? | `while ! timeout 3 kubectl get --raw /livez >/dev/null 2>&1; do sleep 2; done` from a surviving node, timed | ✅ | Measured **17 s** after an abrupt power cut (lease 15 s, renew 10 s, retry 2 s) |
| How long before a dead node reads NotReady? | `kubectl -n kube-system exec kube-controller-manager-<node> -- kube-controller-manager --help 2>&1 \| grep -A1 node-monitor-grace-period` | ✅ | **50 s** by default in v1.35 — ask the binary; 40 s is an older value that gets recited |
| Is that setting overridden here? | `sudo grep node-monitor /etc/kubernetes/manifests/kube-controller-manager.yaml` | ✅ | Not set = the binary default applies |

---

## 6. The pod network (Calico)

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Is Calico healthy? | `kubectl get tigerastatus` | ✅ | `goldmane`/`whisker` **must be absent** — dropped deliberately |
| Is it on every node? | `kubectl -n calico-system get ds calico-node` | ✅ | 5 desired, 5 ready |
| What pod CIDR is Calico really using? | `kubectl get ippool default-ipv4-ippool -o yaml \| grep -E "cidr\|blockSize\|ipipMode\|vxlanMode"` | ✅ | `-o wide` shows only name and age — the CRD defines no columns. Ask for YAML |
| Which blocks has Calico handed out? | `kubectl get ipamblocks -o custom-columns=BLOCK:.spec.cidr,AFFINITY:.spec.affinity` | ✅ | One `/26` per node, **chosen pseudo-randomly** — do not guess from order |
| What does the node object claim? | `kubectl get node <n> -o jsonpath='{.spec.podCIDR}{"\n"}'` | ✅ | **Inert here** — Calico's IPAM decides pod addresses, not this field |
| Can pods on different nodes reach each other? | `kubectl run a --image=busybox:1.38.0 --overrides='{"spec":{"nodeName":"vm-k8s-cka-worker-1"}}' -- sleep 3600` (and `b` on worker-2), then `kubectl exec a -- ping -c3 -W2 <b's IP>` | ✅ | Pin both to named nodes, or both may land on one. **`ttl=62` = routed, not tunnelled** |
| Is a CSI driver installed? | `kubectl get csidrivers` | ✅ | `csi.tigera.io` is Calico's, `Ephemeral` only — **present, and cannot provision a volume** |
| What can Calico's operator deploy? | `kubectl explain gatewayapi.spec` | ✅ | Found an Envoy-based Gateway API option. Not used |

---

## 7. Services and DNS

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Do Service rules work from a node? | `curl -sk --max-time 5 https://10.96.0.1:443/livez` | ✅ | `ok`. `10.96.0.1` is on no interface — it exists only as kube-proxy rules |
| Do they work from inside a pod? | `kubectl exec <pod> -- wget -qO- --no-check-certificate --timeout=5 https://10.96.0.1/livez` | ✅ | A different path from the node check; they can fail independently |
| Does CoreDNS answer? | `kubectl exec <pod> -- nslookup kubernetes.default.svc.cluster.local` | ✅ | Server `10.96.0.10`, answer `10.96.0.1` |
| Does CoreDNS forward? | `kubectl exec <pod> -- nslookup kubernetes.io` | ✅ | Addresses vary run to run — someone else's CDN |

---

## 8. Bootstrapping and joining

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Will the certificate cover the VIP — *before* committing? | `sudo kubeadm init … --dry-run 2>&1 \| grep -iE "apiserver serving cert\|podSubnet\|serviceSubnet"` | ✅ | `.206` must be in the SANs. Irreversible part of the irreversible step |
| Did the dry run leave anything behind? | `sudo find /etc/kubernetes \( -name "*.key" -o -name "*.conf" -o -name "*dryrun*" \) -print` | ✅ | It left **a complete PKI with private keys**. Use `sudo` — see §12 |
| The certificate key expired (2 h) | `sudo kubeadm init phase upload-certs --upload-certs` | ⚠️ | Standard; this build joined inside the window |
| The join token expired (24 h) | `kubeadm token create --print-join-command` | ⚠️ | Standard; not needed here |
| Did the join download the shared PKI? | the join output: `[download-certs]` and `Using the existing "sa" key` | ✅ | The service-account key must be identical on every control plane |

---

## 9. Host prerequisites

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Is the firewall on? | `sudo ufw status` | ✅ | **Not** `systemctl is-active ufw` — that printed `active` with the firewall off (one-shot unit) |
| Is NetworkManager going to fight the CNI? | `dpkg-query -W network-manager` | ✅ | Not installed on these nodes |
| Is firewalld present? | `systemctl is-active firewalld` | ✅ | Absent |
| How much memory is free? | `free -m` | ✅ | Sep 23: ≈ 2.4 GB on control-1, ≈ 3.3 GB per worker |

---

## 10. Before allocating an address

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Is this address free? | `sudo ip neigh del <ip> dev eth0; ping -c1 -W1 <ip>; ip neigh show <ip> dev eth0` | ✅ | **A `lladdr` means occupied even if the ping failed.** `FAILED` with no `lladdr` = free |
| Can the sweep actually see a quiet host? | the same, against `.150` | ✅ | **Positive control** — `.150` ignores ping and still shows `REACHABLE`. Without it, `FAILED` and "broken instrument" look the same |

---

## 11. Lab-side (Proxmox)

| Question | Command | ✓ | What it tells you — and the trap |
|---|---|---|---|
| Does a snapshot exist? | `qm listsnapshot <id>` **and** `zfs list -t snapshot -o name,creation \| grep vm-<id>-disk` | ✅ | **Both.** A snapshot was recorded as taken in three files and did not exist |
| What happened to a snapshot? | `grep -hE "qm(del)?snapshot:<id>" /var/log/pve/tasks/index` | ✅ | The task log showed it created and deleted inside three minutes |
| When was that task? | `date -d @$((16#<hex-from-UPID>))` | ✅ | Decodes the UPID timestamp |
| Is the guest agent answering? | `qm agent <id> ping` and `qm config <id> \| grep agent` | ✅ | Needed for a consistent hot snapshot |
| Shut down cleanly | `qm shutdown <id> --timeout 120`, then `qm status <id>` | ✅ | **Returning is not stopping** — check `status: stopped` before snapshotting |
| Take / restore the baseline | `qm snapshot <id> <name>` · `qm rollback <id> <name>` | ✅ | All five, same name. Rollback of five: 6 s |
| Simulate a power failure | `qm stop <id>` | ✅ | Abrupt — no graceful lease handoff. That is the point |
| Prove a restore restored | plant a ConfigMap **and** a file first; after rollback both must be gone | ✅ | A restore and a reboot print the same thing — without a marker you cannot tell |

---

## 12. Ask the thing, not your memory — and the instruments that lied

**Ask the binary you are going to run:**

| Question | Command | ✓ | Why |
|---|---|---|---|
| Does this flag exist in this version? | `sudo ctr run --rm --net-host <image> x /<binary> <subcommand> --help` | ✅ | kube-vip's examples were written for v0.x; its flag casing is inconsistent |
| What is this default, really? | `<binary> --help \| grep -A1 <flag>` | ✅ | Found 50 s where 40 s was recited |
| Does this image tag exist? | the registry's tag list (Docker Hub v2 `tags/list`) | ✅ | Chose `busybox:1.38.0` from the list, not from memory |

**Checks that could not report their own failure** — every one produced output that looked like a
result. ⭐ **Each check needs a case where it is known to fail.**

| The check | Why it lied | The fix |
|---|---|---|
| `ip neigh show <ip> \|\| echo "no entry"` | `ip neigh show` exits 0 even when it prints nothing, so the fallback can never fire | Read the output; test for `lladdr` |
| `ls -la /etc/kubernetes/tmp/ 2>/dev/null` | No `sudo` on a `drwx------` directory: the permission error was discarded, and empty output read as "clean" | `sudo`, and never discard stderr on a check |
| An etcd-leader lookup that printed nothing | The parse failed silently; the next line asserted the result anyway | Print the raw table and read `IS LEADER` yourself |
| `jsonpath='{…}{"\n"}'` passed through `ssh "…"` | Two shells ate the quoting | Run on the node, or use `-o yaml \| grep` |
| A timer labelled "from shutdown start" | Started after the shutdown loop | Start the clock at the first action it claims to cover |
| `grep … \| sed 's/^$/MISSING/'` | When `grep` matches nothing, `sed` receives no line to substitute | Count matches and test the count |
| "NotReady after ~40 s" — scored as passed | Checked after both 40 s and the real 50 s had passed | Measure finely enough to tell a prediction from its alternative |

---

## 13. Chapter 05 onward — added as run

🔲 *Empty until Part 1 runs.* metrics-server, the storage provisioner, the Gateway API CRDs and Traefik
each add their missing-component signature and their proof here, the moment they are run.
