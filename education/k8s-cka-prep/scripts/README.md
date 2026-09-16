# Build scripts — three stages, deliberately separated

Three scripts, run in order, each doing one job. **The split is the design**: they have
different lifespans and very different portability, and blending them is what makes build
scripts un-reusable somewhere else.

| # | Script | Job | Portable to another employer? |
|---|---|---|---|
| 1 | [`1-provision-vms.sh`](1-provision-vms.sh) | Create N Ubuntu VMs from a cloud-init template | ⛔ **No — Proxmox-specific.** Only its *contract* transfers |
| 2 | [`2-personalize.sh`](2-personalize.sh) | Fit a host to its **environment**: hostname, time, base packages, admin access, update policy | ✅ **Yes** — no dependencies at all |
| 3 | [`3-k8s-base.sh`](3-k8s-base.sh) | Make a host **kubeadm-ready**. Assigns no role | ✅ **Yes** — pure upstream procedure |

```bash
# on the machine that talks to the hypervisor
bash 1-provision-vms.sh --check      &&  bash 1-provision-vms.sh

# then on each node
sudo bash 2-personalize.sh --hostname k8s-cp-1 --timezone America/New_York \
     --sudo-nopasswd agamache --cockpit --freeze-updates
sudo bash 3-k8s-base.sh
```

⭐ **If a host is handed to you already built — which is the normal case at a firm — skip
script 1 entirely and start at 2.** Scripts 2 and 3 do not care how the host appeared.

---

## What each script promises

**Script 1 produces:** N Ubuntu hosts with known hostnames and static addresses, a disk of
the requested size **with the root filesystem actually grown to match**, SSH reachable by
key, guest agent running.
⚠️ **Only the contract transfers.** At another employer, replace the `qm` calls with
vSphere/`govc`, Terraform, a cloud CLI, PXE — or a ticket to someone else.

**Script 2 produces:** correct hostname (in three places, not one), synchronised clock,
base CLI tooling, and — only if asked — passwordless sudo, Cockpit, and frozen automatic
updates.

**Script 3 produces:** swap off, kernel modules and sysctls set, containerd running with
the **CRI plugin enabled** and `SystemdCgroup = true`, and kubeadm/kubelet/kubectl at a
pinned minor, apt-held. ⛔ **No cluster. No role.**

---

## The five things worth knowing before you run any of it

🚨 **1. `containerd.io` ships with the CRI plugin DISABLED.** Its packaged config contains
`disabled_plugins = ["cri"]`, because Docker does not need CRI — and the kubelet talks to
containerd *through* CRI. Leave it and `kubeadm init` hangs waiting for a kubelet that can
never reach a runtime, **and the error names the kubelet, not containerd.** Script 3
regenerates the config. ⛔ **Never install Docker on a Kubernetes node**; it is what puts
that config there.

🚨 **2. A resized virtual disk is not a resized filesystem.** The hypervisor grows the
block device; only `growpart` grows the partition. Script 1 verifies `df` **from inside the
guest**, because the hypervisor's view cannot see this. A silent failure surfaces later as
an error about *image layers* rather than about disk space.

🚨 **3. "Free" IP addresses.** A ping sweep proves an address is **quiet**, not
**unclaimed** — a live host can drop ICMP entirely. Script 1 probes with **ARP**, which a
host's IP firewall cannot refuse on a local subnet, and refuses to assign an address that
answers.

🚨 **4. `hostnamectl` alone is not enough.** It never touches `/etc/hosts`, and a stale
`127.0.1.1` line makes every later `sudo` print *"unable to resolve host"*. On a cloud-init
host the hostname also reverts at the next boot unless `preserve_hostname` is pinned — and
that symptom appears days later, long after anyone connects it to the build. Script 2 does
all three.

🚨 **5. Two expiries that will waste an afternoon.** After `kubeadm init --upload-certs`
the certificate key additional control planes need **expires in 2 HOURS**
(`kubeadm init phase upload-certs --upload-certs` regenerates it), and the join token
expires in **24 hours** (`kubeadm token create`). A deliberate, unhurried pace makes both
*more* likely to bite, not less.

---

## Conventions these scripts follow

- **`--check` on all three.** Verifies and reports, changes nothing. Run it first.
- **Idempotent, and they say so.** Every step reports `ok` (already correct) or `did`
  (changed), and the summary prints a change count. **A second run must report 0 changes** —
  that is the test, and it is printed rather than assumed.
- **Refuse rather than guess.** Wrong distro, an occupied IP, a VMID whose name does not
  match, an invalid hostname, or a Cockpit install that would drag NetworkManager onto a
  netplan host all stop the script.
- **Probe capabilities, not proxies.** Script 3 asks containerd whether its CRI plugin
  reports `ok`, rather than reading the config file and hoping.
- **Report honestly.** `systemctl is-active` prints a value *and* exits non-zero, so a
  naive `cmd || echo absent` prints both. And claiming `CRI enabled: yes` when containerd
  is not installed is a false green. Both were real bugs here, found by testing on one node
  before touching five.
- **No `jq`.** The CKA environment provides **`yq`** and does not list `jq`. Practising with
  a tool the exam lacks is a trap you discover under a clock.

⚠️ **Duplication is deliberate.** Script 2's hostname/sudo/Cockpit logic is a knowing copy
of this lab's `www/ubuntu/setup_*.sh`, because these scripts must work where those files do
not exist. They are **not** expected to track each other, and these must **not** be turned
back into callers of them.
