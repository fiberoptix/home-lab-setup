# Rancher on K3s — command ledger

Every command this track used, **organised by the question it answers rather than by the chapter it
appeared in.** The chapters teach in build order; an incident does not arrive in build order.

🤖 Like the chapters, these commands were **run by the AI on VM 187**, at Andrew's instruction, not typed
by him. "✅ ran here" means executed in this lab with the output understood; it does not mean practised.

**Verified?** column:
- ✅ **ran here (AI)** — executed on VM 187, output in the chapter named
- ⚠️ **standard, not run here** — believed correct, **not** exercised. Do not present as tested.
- 🔲 **planned** — designed, not yet run (drills D5, D6)

---

## 0. Where to run them

| Rule | Why |
|---|---|
| `ssh agamache@192.168.1.187`, then `sudo kubectl …` | K3s's `kubectl` reads `/etc/rancher/k3s/k3s.yaml`, which is root-only (mode 600) |
| Helm: `sudo -E env KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm …` | Plain `sudo helm` looks for `localhost:8080` and fails (Ch 2, Step 3) |
| ⛔ Never copy the kubeconfig off the VM | One merged context on the workstation and a command lands on the wrong cluster |
| Show a credential file's **keys**, never its values | `registries.yaml`, Secrets, the Alertmanager config can all hold tokens |

---

## 1. The 3am order — is it Rancher, the cluster, or the app?

Ask in this order. Rancher down is **not** an app outage (Ch 5, D2), so find out which layer you are in
before you touch anything.

| # | Command | Question | Verified? |
|---|---|---|---|
| 1 | `curl -s http://hello-rancher.gothamtechnologies.com/` | Is the app answering, and with which version? | ✅ Ch 4 |
| 2 | `curl -sk https://rancher.gothamtechnologies.com/ping` | Is Rancher answering? (`pong`) | ✅ Ch 2 |
| 3 | `sudo kubectl get node -o wide` | Is the node `Ready`? | ✅ Ch 2 |
| 4 | `sudo kubectl get pods -A --no-headers \| awk '$4!="Running" && $4!="Completed"'` | Is anything not running? (prints nothing when healthy — 31 pods, none listed, Oct 27) | ✅ re-run while writing |
| 5 | `sudo kubectl -n cattle-system rollout status deploy/rancher` | Is the Rancher Deployment rolled out? | ✅ Ch 2 |
| 6 | `sudo kubectl get clusters.management.cattle.io local -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'` | Does Rancher consider its own cluster Ready? | ✅ Ch 2 |
| 7 | `sudo kubectl get gitrepo -n fleet-local -o wide` | Is GitOps on the latest commit? | ✅ Ch 4 |

---

## 2. What is installed, and which version?

| Command | Question | Verified? |
|---|---|---|
| `sudo -E env KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm list -A` | Every Helm release, its chart and version | ✅ Ch 1 |
| `sudo kubectl get deploy -n cattle-system` | Rancher's own Deployments | ✅ Ch 1 |
| `sudo kubectl get crd --no-headers \| wc -l` | How many resource types exist (153 here) | ✅ Ch 1 |
| `sudo kubectl get crd --no-headers \| awk '{print $1}' \| sed 's/^[^.]*\.//' \| sort \| uniq -c \| sort -rn \| head` | Which API groups own them | ✅ Ch 1 |
| `sudo kubectl get clusters.management.cattle.io` | Which clusters Rancher manages | ✅ Ch 1 |
| `sudo kubectl get users.management.cattle.io -o custom-columns=NAME:.metadata.name,USER:.username` | Rancher's users — stored as Kubernetes objects | ✅ Ch 1 |
| `sudo ls /var/lib/rancher/k3s/server/db/` | Where everything is actually stored (`state.db`) | ✅ Ch 1 |
| `sudo kubectl get apps.catalog.cattle.io -n cattle-monitoring-system rancher-monitoring -o jsonpath='{.spec.chart.metadata.annotations}'` | Which Rancher versions a Rancher chart supports | ✅ Ch 3 |
| `sudo kubectl top node` · `sudo kubectl top pods -A --sort-by=memory` | What it costs | ✅ Ch 1, Ch 3 |
| `ps -C k3s-server -o pid,rss,etime,cmd` | Memory of the one K3s process | ✅ Ch 1 |

---

## 3. Installing (the order matters — Ch 2)

| Command | Purpose | Verified? |
|---|---|---|
| `curl -fsSL -o /root/k3s-install-<ver>.sh "https://raw.githubusercontent.com/k3s-io/k3s/<ver>/install.sh"` then `INSTALL_K3S_VERSION=<ver> sh /root/k3s-install-<ver>.sh server` | K3s, pinned, installer read before it runs (never `curl \| sh`) | ✅ Ch 2 |
| Helm tarball + `.sha256sum`, compare, `install -m 0755` | Helm, pinned and checksummed | ✅ Ch 2 |
| `helm upgrade --install cert-manager jetstack/cert-manager --version v1.21.3 -n cert-manager --create-namespace --set crds.enabled=true --wait` | cert-manager before Rancher | ✅ Ch 2 |
| `helm upgrade --install rancher rancher-latest/rancher --version 2.15.2 -n cattle-system --create-namespace -f rancher-values.yaml -f <bootstrap file>` | Rancher; values in a file, password in a separate file deleted after | ✅ Ch 2 |
| `kubectl patch settings.management.cattle.io server-url --type merge -p '{"value":"https://…"}'` | First-login settings without the browser | ✅ Ch 2 |
| `helm upgrade --install rancher-monitoring-crd …` then `rancher-monitoring … -f monitoring-values.yaml` | Monitoring: CRDs chart first | ✅ Ch 3 |
| `sudo bash 3-k3s.sh --check` (also `4-`, `5-`, `6-`) | Re-run every script in check mode; **expect 0 changes** | ✅ Ch 2–4 |

---

## 4. Is the certificate right? (Ch 2, Step 7)

| Command | Question | Verified? |
|---|---|---|
| `sudo kubectl get secret -n cattle-system tls-rancher -o jsonpath='{.data.tls\.crt}' \| base64 -d \| openssl x509 -noout -subject -issuer -dates` | Rancher's own CA — who, and until when | ✅ Ch 2 |
| `echo \| openssl s_client -connect rancher.gothamtechnologies.com:443 -servername rancher.gothamtechnologies.com 2>/dev/null \| openssl x509 -noout -serial -ext subjectAltName` | What Traefik actually serves | ✅ Ch 2 |
| `curl -s -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://rancher…/ping; echo exit=$?` | Does an untrusting client fail? (`000 20`, exit 60) | ✅ Ch 2 |
| `curl … --cacert <(…tls-rancher…) https://rancher…/ping` | Does it pass with the CA? (200) | ✅ Ch 2 |
| `curl -sk https://rancher.gothamtechnologies.com/cacerts \| openssl x509 -noout -subject -issuer` | The CA a client should trust | ✅ Ch 2 |

---

## 5. Is monitoring telling the truth? (Ch 3)

The Prometheus API checks run inside the Prometheus pod:
`P="sudo kubectl exec -n cattle-monitoring-system prometheus-rancher-monitoring-prometheus-0 -c prometheus --"`

| Command | Question | Verified? |
|---|---|---|
| `$P wget -qO- 'http://localhost:9090/api/v1/targets?state=active' \| python3 -c 'import json,sys,collections; t=json.load(sys.stdin)["data"]["activeTargets"]; c=collections.Counter((x["labels"].get("job"),x["health"]) for x in t); [print(f"{n:3d}  {h:5s} {j}") for (j,h),n in sorted(c.items())]'` | Is every target up? (the full one-liner from Ch 3, §3) | ✅ Ch 3 |
| `$P wget -qO- 'http://localhost:9090/api/v1/alerts' \| python3 -c 'import json,sys; a=json.load(sys.stdin)["data"]["alerts"]; print(len(a),"alerts;", sorted({(x["labels"]["alertname"],x["state"]) for x in a}))'` | What is firing? | ✅ Ch 3 |
| `$P wget -qO- 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_head_series'` | How many active series (memory driver) | ✅ Ch 3 |
| `sudo kubectl get prometheus -n cattle-monitoring-system rancher-monitoring-prometheus -o jsonpath='{.spec.retention} {.spec.retentionSize} {.spec.scrapeInterval}'` | What retention is really applied | ✅ Ch 3 |
| `$P du -sh /prometheus` | How big the data really is | ✅ Ch 3 · 🔲 D5 |
| `$P df -h /prometheus` | Is the volume's size enforced? (No — the whole disk shows) | ✅ Ch 3 |
| `sudo kubectl get servicemonitors -A --no-headers \| wc -l` · `… prometheusrules …` | What the operator is configured with | ✅ Ch 3 |
| `sudo kubectl get secret -n cattle-monitoring-system alertmanager-rancher-monitoring-alertmanager -o jsonpath='{.data.alertmanager\.yaml}' \| base64 -d \| grep -nE 'receiver\|name:\|_configs\|route'` | Where alerts go — structure only | ✅ Ch 3 |
| `sudo kubectl get cm -n cattle-monitoring-system grafana-nginx-proxy-config -o jsonpath='{.data}' \| tr ',' '\n' \| grep -o -E 'proxy_cache[a-z_]*[^;]*;' \| sort -u` | Is a proxy caching errors? | ✅ Ch 3 |

---

## 6. Is GitOps delivering? (Ch 4)

| Command | Question | Verified? |
|---|---|---|
| `sudo kubectl get gitrepo -n fleet-local -o wide` | Which commit has Fleet fetched? | ✅ Ch 4 |
| `sudo kubectl get gitrepo -n fleet-local hello-lab -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'` | Conditions, with messages — **alert on `Ready`, not `Stalled`** | ✅ Ch 4, Ch 5 D3 |
| `sudo kubectl get bundles -n fleet-local` · `sudo kubectl get bundledeployments -A` | Did it render, and was it delivered? | ✅ Ch 4 |
| `sudo kubectl get clusters.fleet.cattle.io -A` | Which clusters Fleet targets | ✅ Ch 4 |
| `sudo -E env KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm list -A \| grep hello` | The Helm release Fleet made | ✅ Ch 4 |
| `sudo kubectl -n hello-lab rollout status deploy/hello-lab` | Fleet says NotReady — is it really? | ✅ Ch 4 |
| `git revert <bump-commit-hash>` and push | Roll back — **by hash** | ✅ Ch 5 D3 |
| `sudo kubectl get deploy -n cattle-fleet-system` | Fleet's own controllers (independent of Rancher) | ✅ Ch 4 |

---

## 7. Can the node pull images? (Ch 4, Ch 5 D4)

| Command | Question | Verified? |
|---|---|---|
| `sudo grep -oE "^ *[a-z]+:\|\"http://[^\"]*\"" /etc/rancher/k3s/registries.yaml` | The registry config's shape — keys only | ✅ Ch 4 |
| `sudo stat -c '%a %U %n' /etc/rancher/k3s/registries.yaml` | Is it root-only? (600) | ✅ Ch 4 |
| `sudo systemctl restart k3s` | Apply a changed `registries.yaml` (read at start only) | ✅ Ch 5 D4 |
| `sudo kubectl get events -n <ns> --sort-by=.lastTimestamp \| tail` | **Why** a pull failed (the 401 lives here) | ✅ Ch 5 D4 |
| `sudo kubectl describe pod <pod>` | The same, per pod | ⚠️ standard — D4 read the events directly |
| `sudo crictl images` | What the node has cached | ✅ re-run while writing (three `hello-lab` tags cached) |
| `sudo crictl rmi <image>` | Force a real pull (drill only) | ✅ Ch 5 D4 |

---

## 8. What can this identity do? (Ch 4, Step 6)

| Command | Question | Verified? |
|---|---|---|
| `sudo kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>` | Everything it may do in a namespace | ✅ Ch 4 |
| `sudo kubectl auth can-i get secrets -n <ns> --as=…` | One question — **read the answer; "no" exits 1** | ✅ Ch 4 |
| `kubectl create token <sa> -n <ns> --duration=8760h` | Mint a token (signed, not stored) | ✅ Ch 4 |
| `kubectl auth whoami` | Who does this kubeconfig say I am? | ✅ in the `deploy_push` job |
| `kubectl delete sa <sa> -n <ns>` | Revoke every token for that account | ⚠️ standard, not run here |

---

## 9. Drills (Ch 5)

| Command | Purpose | Verified? |
|---|---|---|
| The outside poll loop (Ch 5, "How the drills were measured") | Time-to-serve as a user sees it | ✅ D1 |
| `sudo journalctl -b -1 --no-pager -o short-precise \| grep -iE "timed out\|killing process"` | Why the last shutdown was slow | ✅ D1 |
| `systemctl show -p DefaultTimeoutStopUSec` | systemd's stop limit (1min 30s) | ✅ D1 |
| `sudo kubectl -n cattle-system scale deploy/rancher --replicas=0` (then `=1`) | Take Rancher away; bring it back | ✅ D2 |
| `for i in $(seq 1 30); do curl -sf --max-time 2 <url> >/dev/null && OK=$((OK+1)) \|\| FAIL=$((FAIL+1)); sleep 1; done` | Count availability during a drill | ✅ D2–D4 |
| `$P du -sh /prometheus` after 24 h | Is `retentionSize` holding? | 🔲 D5 |
| `helm upgrade rancher … -f rancher-values.yaml` to a newer version | The upgrade drill | 🔲 D6 |
