# Rancher on K3s · Chapter 4 — Shipping to It: GitOps with Fleet, and the Push Model

> **Series:** Home-Lab Education · Phase 20 (Rancher on K3s)
> **Built and verified:** October 27, 2026, 22:30–22:50 EDT on VM 187 `vm-k3s-rancher-1` (`192.168.1.187`) and GitLab project `production/rancher-k3s`; outputs re-captured read-only at 23:24–23:50 the same night
> **Versions at time of writing:** Fleet (bundled with Rancher 2.15.2) · K3s v1.35.9+k3s1 · GitLab CI images `docker:27`, `alpine:3.22` · kubectl v1.35.9 in the push job
> **Script:** `proxmox/build-scripts/rancher-k3s/6-gitops.sh` · manifests in [`manifests/`](manifests/) (`fleet-gitrepo.yaml`, `push-rbac.yaml`, `apps-repo/`)
> **Read this after:** Chapter 3 · **before:** Chapter 5

> 🤖 **DECLARATION — read this before you trust anything below.** Every command in this chapter was
> **executed** on VM 187 or in GitLab CI, and every output quoted is real. But it was
> **[run by the AI, not by Andrew]{custom-style="Key"}**, at his explicit instruction — so the commands are
> verified, and the operator judgement behind them was not earned at a keyboard. The pipeline timings are
> quoted from the build record; the pipeline's own job logs are not reproduced here.

---

## What this chapter covers

A cluster with nothing on it teaches nothing. This chapter wires the lab so that
[a commit to GitLab becomes a running pod without anyone typing `kubectl`]{custom-style="Key"}, and it does
it twice, two different ways, so they can be compared:

- [the **pull model** — Fleet, inside the cluster, watches a Git repository]{custom-style="Key"} and applies what it finds
- the **push model** — a CI job, outside the cluster, holds a cluster credential and applies changes itself
- 🚨 [who holds which credential in each model]{custom-style="Key"} — the real difference between them
- how a node is allowed to pull images from a private registry (K3s has its own file for this)
- what Fleet turns a folder of YAML into, object by object
- why Fleet's status can say *NotReady* about an app that is perfectly healthy
- how long a change takes, from `git push` to serving: **36–42 seconds**

---

## 1. Two ways to ship

Both models start the same way: a developer commits, CI builds an image and pushes it to a registry. They
differ in **the last step — who changes the cluster**.

| | Pull model (Fleet) | Push model (`deploy_push` job) |
|---|---|---|
| Who connects to whom | the cluster reaches out to GitLab | the CI runner reaches into the cluster's API |
| What CI holds | **no cluster credential at all** | a token that can change the cluster |
| What the cluster holds | a read-only Git token, a read-only registry token | nothing extra |
| What "deployed" means | whatever is in Git, continuously re-applied | whatever the last job applied |
| How you roll back | `git revert` | re-run an older job, or `kubectl` by hand |

![Figure 1 — Pull versus push: which direction each connection goes, and which credential it carries. In the pull model only read-only tokens exist, and they live in the cluster. In the push model the credential that can change the cluster lives on the CI runner.](images/ch04_fig1_pull_vs_push.png)

⭐ The reason the industry moved towards pull is in the second row. [In the pull model, stealing everything
GitLab holds does not give you the cluster]{custom-style="Key"}; an attacker would have to get a malicious
commit merged to `main`, which is a reviewed, logged, revertible event. In the push model, whoever can read
[the runner's credential can change the cluster directly]{custom-style="Key"}. ⚠️ That framing is general GitOps practice,
recited; what was built here is one of each, side by side, on the same app.

---

## 2. The apps repository

Everything that ships lives in one GitLab project, `production/rancher-k3s`, laid out so that
[source, deployment manifests and the push-model copy are separate folders]{custom-style="Key"}:

```
.gitlab-ci.yml                       build → bump → (manual) deploy_push
hello-lab/            app.py, Dockerfile           the source — CI builds this
fleet/hello-lab/      fleet.yaml, kustomization.yaml,
                      deployment.yaml, service.yaml, ingress.yaml   what Fleet applies
push/hello-lab-push/  kustomization.yaml           the push-model copy (no Ingress, 1 replica)
README.md
```

*(Condensed from `git ls-files`. One stray file, `hello-lab/__pycache__/app.cpython-314.pyc`, was
committed by accident; it is harmless because the Dockerfile copies only `app.py`.)*

`hello-lab` is deliberately tiny: [a Python HTTP server that answers with the commit it was built from]{custom-style="Key"},
so [every `curl` tells you exactly which version is serving]{custom-style="Key"}:

```bash
curl -s http://hello-rancher.gothamtechnologies.com/
```

```
{"app": "hello-lab", "version": "3a2687e8", "delivered_by": "fleet", "pod": "hello-lab-66b58bbb5f-px6d8", "namespace": "hello-lab"}
```

The Deployment is written the way a production one should be: non-root (`runAsUser: 65534`), read-only root
filesystem, all Linux capabilities dropped, readiness and liveness probes on `/healthz`, a 64 Mi memory limit.
See [`deployment.yaml`](manifests/apps-repo/fleet/hello-lab/deployment.yaml).

---

## Step 1 — Let the node pull from the private registry

**What it gives you:** pods on this node can pull images from `gitlab.gothamtechnologies.com:5050`.

The obvious move is wrong. On a Docker host you would log in with `docker login` or edit
`/etc/docker/daemon.json`. [K3s does not use Docker]{custom-style="Key"} — it runs its own containerd and reads
[its registry settings from **`/etc/rancher/k3s/registries.yaml`**, and nothing else]{custom-style="Key"}. Without that file, the
[first deploy fails as `ImagePullBackOff` with an error that looks like a network or DNS fault]{custom-style="Key"}.

What `6-gitops.sh` writes there (the template from the script — the credential values come from a root-only
file, never from Git):

```yaml
mirrors:
  "gitlab.gothamtechnologies.com:5050":
    endpoint:
      - "http://gitlab.gothamtechnologies.com:5050"
configs:
  "gitlab.gothamtechnologies.com:5050":
    auth:
      username: "$PULL_USER"
      password: "$PULL_TOKEN"
```

Two halves. `mirrors` says **how to reach** the registry — here, over plain HTTP. `configs` says **how to
log in** — a GitLab deploy token with only the `read_registry` scope.

🚨 **Tripping point — the file is read only when K3s starts.** Writing it changes nothing until
`systemctl restart k3s`. The script restarts K3s itself when it changes the file. Running containers
survive a K3s restart (⚠️ K3s's documented behaviour, recited — not isolated in a test here), but
[an edit without a restart is silently ignored]{custom-style="Key"}.

**Confirm — structure only.** This file holds a credential, so show its keys, never its values:

```bash
sudo grep -oE "^ *[a-z]+:|\"http://[^\"]*\"" /etc/rancher/k3s/registries.yaml
sudo stat -c '%a %U %n' /etc/rancher/k3s/registries.yaml
```

```
mirrors:
    endpoint:
"http://gitlab.gothamtechnologies.com:5050"
configs:
    auth:
      username:
      password:

600 root /etc/rancher/k3s/registries.yaml
```

[Notice what this credential is attached to: **the node**, not a namespace.]{custom-style="Key"} Every pod on this node, in any
namespace, can pull from that registry with it. On one node running one app that is fine; it is also why
[a real cluster usually uses per-namespace `imagePullSecrets` instead]{custom-style="Key"}. ⚠️ Recited
practice; only the node-wide form was built here.

> **Lab vs PROD — plaintext transport for credentials.** *In the lab:* the node pulls images over
> **plain HTTP** (`http://…:5050`), and Fleet fetches Git over **plain HTTP** too (Step 3) — each sending a
> deploy token in every request. *Why it's acceptable here:* the traffic crosses one flat home LAN that
> Andrew controls end to end, the tokens are read-only, and the lab's GitLab is served over HTTP.
> *In production:* registry and Git are served over TLS, and the cluster trusts their CA; [a credential never
> crosses the network in cleartext]{custom-style="Key"}. *If you carry the habit:* [anyone who can capture traffic]{custom-style="Key"}
> on the path collects the tokens, and the `http://` endpoint in `registries.yaml` becomes a copy-paste default
> for the next cluster. ⚠️ *The production practice is recited; the HTTP behaviour is verified.*

---

## Step 2 — CI: build the image, then bump the tag in Git

**What it gives you:** [every commit to `hello-lab/` produces an image tagged with its commit]{custom-style="Key"}, and a second
commit that tells Fleet to deploy it.

The pipeline has three stages: `build`, `bump`, `deploy`. The first two run automatically, and only when
something under `hello-lab/` changed:

```yaml
.app_changed: &app_changed
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    changes: [hello-lab/**/*]

build:
  stage: build
  image: docker:27
  rules: *app_changed
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build --pull --build-arg GIT_SHA="$CI_COMMIT_SHORT_SHA" -t "$IMAGE:$CI_COMMIT_SHORT_SHA" hello-lab
    - docker push "$IMAGE:$CI_COMMIT_SHORT_SHA"
```

*(Excerpt — `tags:` lines removed; full file in [`manifests/apps-repo/gitlab-ci.yml`](manifests/apps-repo/gitlab-ci.yml).)*

[The image tag is the commit hash, never `latest`]{custom-style="Key"}. That is what makes the next job
possible: [the tag in Git names exactly one image, so the Git history *is* the deployment history]{custom-style="Key"}.

[The **bump** job is the bridge between CI and Fleet.]{custom-style="Key"} It clones the repo, rewrites one line, and commits:

```yaml
bump:
  stage: bump
  needs: [build]
  resource_group: fleet-bump
  variables:
    GIT_STRATEGY: none
  script:
    - git clone -q "http://oauth2:<BUMP_TOKEN>@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" repo && cd repo
    - LATEST=$(git log -1 --format=%H -- hello-lab)
    - if [ "$LATEST" != "$CI_COMMIT_SHA" ]; then echo "main has a newer hello-lab commit ($LATEST); skipping"; exit 0; fi
    - |
      sed -i -E "s|^( *newTag:).*|\1 ${CI_COMMIT_SHORT_SHA} # written by the CI bump job — do not edit by hand|" fleet/hello-lab/kustomization.yaml
    - git diff --quiet && { echo "tag already ${CI_COMMIT_SHORT_SHA}"; exit 0; }
    - 'git commit -qam "deploy: hello-lab ${CI_COMMIT_SHORT_SHA} [skip ci]"'
    - git push -q origin HEAD:"$CI_DEFAULT_BRANCH" || { git pull -q --rebase origin "$CI_DEFAULT_BRANCH" && git push -q origin HEAD:"$CI_DEFAULT_BRANCH"; }
```

*(Excerpt — the `apk add git` and `git config` lines are removed. The real job writes `${BUMP_TOKEN}` where
this shows `<BUMP_TOKEN>`; the placeholder form keeps this repository's GitHub push guard, which blocks any
URL with an inline credential, from mistaking it for a real token.)*

Each line exists for a reason:

- **`[skip ci]`** in the message — without it, the bump commit would trigger another pipeline, which
  [would bump again, forever]{custom-style="Key"}.
- **`resource_group: fleet-bump`** — only one bump runs at a time, so two quick commits cannot race to
  write the same line.
- **The `LATEST` check** — if a newer app commit is already on `main`, [this older job steps aside rather]{custom-style="Key"}
  than rolling the tag *backwards*.
- **The push retry** — if `main` moved while the job ran, rebase once and push again.

The history shows the pattern — every app commit followed by a bot commit:

```bash
git log --format='%h %an  %s' -10
```

```
0682a5d fiberoptix  Revert "D2: replicas 3 while Rancher is scaled to 0"
c83b005 fiberoptix  Revert "D3: deliberately broken manifest (replicas: three)"
58d445a fiberoptix  D3: deliberately broken manifest (replicas: three)
b778273 fiberoptix  D2: replicas 3 while Rancher is scaled to 0
65f94cd ci-tag-bump  deploy: hello-lab 3a2687e8 [skip ci]
3a2687e fiberoptix  hello-lab: exit on SIGTERM (PID 1 has no default handler)
b65f936 ci-tag-bump  deploy: hello-lab 5b687bd9 [skip ci]
5b687bd fiberoptix  hello-lab: report delivery path (fleet vs push)
bea279c ci-tag-bump  deploy: hello-lab fd227698 [skip ci]
fd22769 fiberoptix  hello-lab app, Fleet manifests, CI (build/bump/push-model)
```

*(The four newest commits are Chapter 5's drills.)*

🚨 **Tripping point — two YAML traps, caught before the first push.** The pipeline file was parsed locally
before it was committed, and two lines did not mean what they looked like:

1. `- git commit -qam "deploy: hello-lab …"` [written **unquoted** is not a string]{custom-style="Key"}. The `: ` inside it makes
   YAML read the line as a **mapping** (key `git commit -qam "deploy`), and GitLab rejects the job. Fix: wrap
   the whole command in single quotes, as above.
2. The `sed` line contains ` # written by…`. In a plain YAML scalar, [space-then-`#` starts a comment]{custom-style="Key"},
   [so everything after it would have been silently dropped from the command]{custom-style="Key"}. Fix: the `- |` block scalar,
   where `#` is just a character.

⭐ The general lesson: [**parse CI YAML before you push it**]{custom-style="Key"} (`python3 -c 'import yaml; …'`, or GitLab's CI
Lint). [Both of these would have produced a pipeline that looked plausible and did something else.]{custom-style="Key"}

🚨 **Tripping point — pull before you commit.** Because the bump job pushes to `main` after every build,
[your local clone is behind after every deploy]{custom-style="Key"}. In the first end-to-end test the local push
was rejected because `main` had moved, and the stopwatch waited **304 seconds** for a deploy that had never
started. Not a system fault — an operator one. The re-run took 36 seconds.

---

## Step 3 — Fleet: point it at the repository

**What it gives you:** [the cluster watches `fleet/hello-lab` on `main` and keeps the cluster matching it]{custom-style="Key"}.

Fleet came with Rancher (Chapter 1, §4). Wiring it to a repository is one object, a **`GitRepo`**, plus a
Secret holding a read-only deploy token:

```yaml
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: hello-lab
  namespace: fleet-local
spec:
  repo: http://gitlab.gothamtechnologies.com/production/rancher-k3s.git
  branch: main
  paths:
    - fleet/hello-lab
  clientSecretName: gitlab-rancher-k3s-read
  pollingInterval: 15s
```

- **`namespace: fleet-local`** — Fleet's *workspace* for Rancher's own cluster. [GitRepos in `fleet-local`
  deploy to the `local` cluster]{custom-style="Key"}; downstream clusters are targeted from `fleet-default`
  (⚠️ that half is recited — there are no downstream clusters here).
- **`paths`** — only this folder. [The source code and the push-model copy are invisible to Fleet.]{custom-style="Key"}
- **`pollingInterval: 15s`** — how often Fleet asks GitLab "has `main` moved?". Short for the lab, to make
  timings visible.

The Secret's shape — type and key names only:

```bash
sudo kubectl get secret -n fleet-local gitlab-rancher-k3s-read \
  -o go-template="{{.type}}{{range \$k,\$v := .data}} {{\$k}}{{end}}{{\"\n\"}}"
```

```
kubernetes.io/basic-auth password username
```

[Fleet over a plain-HTTP Git URL with a basic-auth Secret **works**]{custom-style="Key"}; the build plan had listed it as
unverified, and it fetched on the first poll.

Inside the repository folder, two small files tell Fleet *how* to render it:

```yaml
# fleet.yaml
defaultNamespace: hello-lab
kustomize:
  dir: .
```

```yaml
# kustomization.yaml (excerpt)
images:
  - name: hello-lab
    newName: gitlab.gothamtechnologies.com:5050/production/rancher-k3s/hello-lab
    newTag: 3a2687e8 # written by the CI bump job — do not edit by hand
```

The Deployment says only `image: hello-lab`; Kustomize's `images:` block rewrites that to the full registry
path and tag. [The bump job edits exactly one line in the whole repository]{custom-style="Key"} — `newTag`.

### What Fleet turns a folder into

This is the part worth slowing down for. [Fleet does not apply YAML directly.]{custom-style="Key"} It passes it through a chain
of objects, each owned by a different Fleet component:

![Figure 2 — The delivery path, with measured timings: from a commit in GitLab, through CI and the bump commit, to Fleet's chain of objects and a rolling update. Total: 36–42 seconds. Which Fleet component does which step is from Fleet's design (recited); the times are measured.](images/ch04_fig2_delivery_path.png)

**Confirm — each link in the chain:**

```bash
sudo kubectl get gitrepo -n fleet-local -o wide
sudo kubectl get bundles -n fleet-local
sudo kubectl get bundledeployments -A
sudo kubectl get clusters.fleet.cattle.io -A
```

```
NAME        REPO                                                              COMMIT                                     BUNDLEDEPLOYMENTS-READY   STATUS
hello-lab   http://gitlab.gothamtechnologies.com/production/rancher-k3s.git   0682a5dc00f48922fa927e88b5bd2c21d255e273   1/1

NAME                        BUNDLEDEPLOYMENTS-READY   STATUS
fleet-agent-local           1/1
hello-lab-fleet-hello-lab   1/1

NAMESPACE                                NAME                        DEPLOYED   MONITORED   STATUS
cluster-fleet-local-local-1a3d67d0a899   fleet-agent-local           True       True
cluster-fleet-local-local-1a3d67d0a899   hello-lab-fleet-hello-lab   True       True

NAMESPACE     NAME    BUNDLES-READY   LAST-SEEN              STATUS
fleet-local   local   2/2             2026-10-28T03:21:01Z
```

Read it top to bottom:

1. **GitRepo** `hello-lab` — has fetched commit `0682a5dc…`, the current `main`.
2. **Bundle** `hello-lab-fleet-hello-lab` — the rendered contents of one path, named
   *GitRepo name + path*. ⭐ [A Bundle is "what to deploy", independent of where]{custom-style="Key"}.
3. **BundleDeployment** — one per Bundle *per target cluster*, in a namespace belonging to that cluster.
   Here there is one cluster, so one each.
4. **Cluster** `local` — Fleet's record of the target, with 2 of 2 bundles ready.

The second Bundle, `fleet-agent-local`, [is Fleet deploying **its own agent** through the same mechanism]{custom-style="Key"}.

And the last link — [the agent installs each BundleDeployment **as a Helm release**]{custom-style="Key"}:

```bash
sudo -E env KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm list -A | grep -E "NAME|hello"
```

```
NAME                     	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART
hello-lab-fleet-hello-lab	hello-lab	21      	2026-10-28 02:57:40.709117945 +0000 UTC	deployed	hello-lab-fleet-hello-lab-v0.0.0+git-0682a5dc00f4
```

*(Column padding trimmed; the empty APP VERSION column is removed.)*

[The repository contains no Helm chart, yet there is a Helm release]{custom-style="Key"}, revision 21, whose chart version is the
Git commit. [Fleet wrapped the Kustomize output in a generated chart]{custom-style="Key"}, so the app gets
Helm's release history. The Deployment carries the marks of it:

```
{"app":"hello-lab","app.kubernetes.io/managed-by":"Helm","objectset.rio.cattle.io/hash":"a4294e0dc46b25bf1dffd8a5885af2b08124aac2"}
hello-lab-fleet-hello-lab
```

*(Labels, then the `meta.helm.sh/release-name` annotation, of `deploy/hello-lab`.)*

🚨 **Consequence:** do not `helm upgrade` or `kubectl edit` that release by hand. [The next commit Fleet
applies overwrites your change]{custom-style="Key"}, and until then the cluster no longer matches Git — the one
thing GitOps promises. Change Git. ⚠️ Recited, not tested here: Fleet reports hand-made drift as *Modified*,
and reverts it on its own only if the GitRepo sets `correctDrift`, which this one does not.

[The components behind the chain are separate Deployments, none of them Rancher itself:]{custom-style="Key"}

```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
fleet-controller   1/1     1            1           61m
gitjob             1/1     1            1           61m
helmops            1/1     1            1           61m
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
fleet-agent   1/1     1            1           60m
```

*(`kubectl get deploy` in `cattle-fleet-system`, then `cattle-fleet-local-system`.)* ⚠️ Their division of
labour is from Fleet's design, recited: **gitjob** polls Git and produces Bundles; **fleet-controller** turns
Bundles into BundleDeployments for each target cluster; **fleet-agent** runs on the target and does the
Helm install; **helmops** handles Helm-chart sources and is not used by this repository. What *was* verified is the
consequence: because these are their own Deployments, [GitOps kept delivering with Rancher scaled to
zero]{custom-style="Key"} (Chapter 5, drill D2).

**Confirm — Fleet's own view:**

```bash
sudo kubectl get gitrepo -n fleet-local hello-lab -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```

```
Ready=True
GitPolling=True
Reconciling=False
Stalled=False
Accepted=True
```

---

## Step 4 — Ship a change, and time it

**What it gives you:** proof that the whole path works, and a number for how long it takes.

The measured path, from the build record: commit to `hello-lab/` → **build 9 s** → **bump 6 s** → bump
commit lands on `main` → Fleet's next poll (**up to 15 s**) → Helm upgrade → rolling update → the new
version answering. [Push to new version serving: 36–42 seconds]{custom-style="Key"}, across the runs timed.

How "serving" was decided: `curl` in a loop until the `version` field equals the new commit. Not the
[pipeline's green tick, and not Fleet's status]{custom-style="Key"} — [the app's own answer, from outside the cluster]{custom-style="Key"}.

### 🚨 Tripping point — Fleet's status can lag a finished rollout

After one deploy, Fleet reported the app **`NotReady`**, *"[progressing] Updated: 1/2"*, for about four
minutes — while the Deployment was already `2/2` with `NewReplicaSetAvailable`, and `curl` returned the new
version. [The agent had evaluated status once, mid-rollout, and did not look again until it restarted.]{custom-style="Key"}

⭐ So [a Fleet "NotReady" is a question, not an answer]{custom-style="Key"}. Before acting on it, ask the
Deployment itself:

```bash
sudo kubectl -n hello-lab rollout status deploy/hello-lab
```

If that says *successfully rolled out* and the app answers with the right version, the rollout is done and
Fleet's status will catch up. ⚠️ The four-minute lag was observed once; how often it happens was not
measured.

### Rolling back is a commit

Because Git *is* the desired state, [a rollback is `git revert` of the bump commit]{custom-style="Key"},
pushed like any other change. [Fleet sees `main` move and rolls back to the older tag]{custom-style="Key"}, which the node
usually still has cached. The two `Revert` commits at the top of the history above are exactly that,
from Chapter 5's drills; the broken-manifest revert recovered in **21 seconds**.

---

## Step 5 — Container hygiene: exit when asked

**What it gives you:** rollouts that take seconds, not 30 extra each — and reboots that do not hang.

When Kubernetes replaces a pod, it sends the container **SIGTERM** and waits up to
`terminationGracePeriodSeconds` (here the default, 30) before killing it:

```
gitlab.gothamtechnologies.com:5050/production/rancher-k3s/hello-lab:3a2687e8 30 {"rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"},"type":"RollingUpdate"}
```

*(Image, grace period and strategy of `deploy/hello-lab`.)*

The first version of `hello-lab` ignored SIGTERM. Not through a bug in the code: [a process running as PID 1
gets no default action for SIGTERM]{custom-style="Key"} — the kernel will not kill it on the program's behalf,
and Python installs no handler. [So every old pod sat out the full 30 seconds and was then killed.]{custom-style="Key"} The fix
is three lines:

```python
if __name__ == "__main__":
    # As PID 1, Python gets no default SIGTERM action; without this every rollout waits the full
    # 30 s terminationGracePeriod before the kubelet SIGKILLs the old pod.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    HTTPServer(("", PORT), Handler).serve_forever()
```

The cost turned out to be bigger than slow rollouts. In the reboot drill, the push-model copy was still
running the old image, and [that one container stretched the VM's shutdown to 87 seconds]{custom-style="Key"};
once it was redeployed with the fix, shutdown took 4 (Chapter 5, drill D1). ⭐ For every image you ship:
[check that PID 1 handles]{custom-style="Key"} SIGTERM, or run it under a small init such as `tini`. ⚠️ `tini`
is recited, not used here.

---

## Step 6 — The push model, for comparison

**What it gives you:** the same app deployed the old way, from CI, so the two models can be compared on
the same cluster.

### 6a. An identity that can do very little

The push job needs a cluster identity. [It gets a **ServiceAccount** confined to one namespace,]{custom-style="Key"}
`hello-lab-push` — never `hello-lab`, which belongs to Fleet:

```yaml
kind: Role
metadata:
  name: gitlab-deployer
  namespace: hello-lab-push
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

*(Excerpt of [`push-rbac.yaml`](manifests/push-rbac.yaml); the Namespace, ServiceAccount and RoleBinding
are in the same file.)* A `Role`, not a `ClusterRole`: [its power ends at the namespace
boundary]{custom-style="Key"}. [No `delete`, no Secrets, no Ingress.]{custom-style="Key"}

**Confirm — ask the API server what the identity can do**, by impersonating it:

```bash
sudo kubectl auth can-i --list --as=system:serviceaccount:hello-lab-push:gitlab-deployer \
  -n hello-lab-push | head -12
sudo kubectl auth can-i get secrets -n hello-lab-push \
  --as=system:serviceaccount:hello-lab-push:gitlab-deployer
sudo kubectl auth can-i create deployments -n hello-lab \
  --as=system:serviceaccount:hello-lab-push:gitlab-deployer
```

```
Resources                                       Non-Resource URLs                      Resource Names   Verbs
selfsubjectreviews.authentication.k8s.io        []                                     []               [create]
selfsubjectaccessreviews.authorization.k8s.io   []                                     []               [create]
selfsubjectrulesreviews.authorization.k8s.io    []                                     []               [create]
services                                        []                                     []               [get list watch create update patch]
deployments.apps                                []                                     []               [get list watch create update patch]
pods                                            []                                     []               [get list watch]
replicasets.apps                                []                                     []               [get list watch]
                                                [/.well-known/openid-configuration/]   []               [get]
                                                [/.well-known/openid-configuration]    []               [get]
                                                [/api/*]                               []               [get]
                                                [/api]                                 []               [get]
no
no
```

Exactly the Role, plus the self-review permissions every identity gets. It cannot read Secrets, and it
cannot touch Fleet's namespace.

🚨 **Tripping point — `can-i` says "no" with exit code 1.** The script's first version tested
`kubectl auth can-i … | grep -q no` under `set -o pipefail`; on a correct "no", `can-i` exits 1, the
pipeline failed, and [the script printed two **false alarms** claiming the account *could* read Secrets]{custom-style="Key"}.
[Read the answer, not the exit status]{custom-style="Key"}:

```bash
cani() { KUBECONFIG=/root/push-kubeconfig.yaml kubectl auth can-i "$@" 2>/dev/null || true; }
[ "$(cani get secrets -n hello-lab-push)" = no ] && ok "cannot read secrets in hello-lab-push" || warn "SA can read secrets"
```

### 6b. A token, and where it lives

`6-gitops.sh --push-kubeconfig` mints a token for that ServiceAccount and wraps it in a kubeconfig:

```bash
TOKEN=$(kubectl create token gitlab-deployer -n hello-lab-push --duration=8760h)
```

`--duration=8760h` is one year (it expires 2027-10-28). The kubeconfig was uploaded to GitLab as a
protected **file** variable, `PUSH_KUBECONFIG`, and then shredded on the VM. Note what the cluster keeps:

```bash
sudo kubectl get secrets -n hello-lab-push
```

```
No resources found in hello-lab-push namespace.
```

[A token from `kubectl create token` is **signed, not stored**]{custom-style="Key"} — [the cluster holds no copy, so there is
nothing in the cluster to delete]{custom-style="Key"}. It stays valid until it expires, unless the ServiceAccount
itself is deleted. ⚠️ That revocation behaviour is from the Kubernetes documentation, recited; it was not
tested here.

### 6c. The job

The manual `deploy_push` job downloads a pinned `kubectl` (checking its SHA-256), points it at the
kubeconfig, renders the push copy, sets the image tag and applies:

```yaml
    - export KUBECONFIG="$PUSH_KUBECONFIG"
    - kubectl auth whoami
    - |
      kubectl kustomize push/hello-lab-push \
        | sed -E "s#(image: .*/hello-lab):.*#\1:${CI_COMMIT_SHORT_SHA}#" \
        | kubectl apply -f -
    - kubectl -n hello-lab-push rollout status deploy/hello-lab --timeout=180s
```

*(Excerpt.)* The push copy reuses the Fleet manifests through Kustomize and patches them — namespace
`hello-lab-push`, **no Ingress** (so it never competes for the `hello-rancher` hostname), one replica.

The job was run from GitLab during the build — first as job 1041, and again after drill D1 (Chapter 5)
with the fixed image. **Confirm — what it left behind:**

```bash
sudo kubectl get deploy -n hello-lab-push
sudo kubectl get deploy -n hello-lab-push hello-lab -o jsonpath="{.spec.template.spec.containers[0].image}{\"\n\"}"
```

```
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
hello-lab   1/1     1            1           47m

gitlab.gothamtechnologies.com:5050/production/rancher-k3s/hello-lab:3a2687e8
```

[Same image, two namespaces, two delivery mechanisms.]{custom-style="Key"} The difference is not in what runs, but in [who could
have changed it]{custom-style="Key"}.

> **Lab vs PROD — a cluster credential on a privileged CI runner.** *In the lab:* `PUSH_KUBECONFIG` is
> handed to jobs on the GitLab runner at `.182`, and that runner mounts the host's **Docker socket** into
> its jobs (lab ledger L19). Any job that runs there can reach
> the Docker daemon, and from there the host and every credential passing through it. *Why it's acceptable
> here:* one person writes every job; the token is confined to one throwaway namespace and cannot read
> Secrets; it exists to be compared, not relied on. *In production:* prefer the pull model; where push is
> unavoidable, use runners that do not share the Docker socket, short-lived credentials issued per job
> (for example OIDC federation), and protected environments. *If you carry the habit:*
> [the runner becomes the softest way into every cluster it deploys to]{custom-style="Key"}, and the
> namespace-scoped Role is the only thing between a compromised job and production. ⚠️ *The production
> controls are recited; the Role's limits were verified with `can-i`.*

---

## Where this lab differs from production

| Here | In production | Why it matters |
|---|---|---|
| Registry and Git over plain HTTP, carrying deploy tokens | TLS everywhere | **Callout in Step 1** |
| Push-model token on a runner that mounts the Docker socket | Pull model; or isolated runners with per-job credentials | **Callout in Step 6** |
| Registry credential is node-wide (`registries.yaml`) | Per-namespace `imagePullSecrets`, or a registry the nodes trust by identity | One credential, every namespace |
| Apps on Rancher's own `local` cluster, via `fleet-local` | Apps on downstream clusters, via `fleet-default` | Chapter 1's callout |
| `pollingInterval: 15s` | Longer polling, or a Git webhook to trigger Fleet | Load on GitLab at scale |
| Bump job commits straight to `main` | Often a merge request, or a separate config repository | Review of what ships |
| One-year push token | Hours, or per job | Exposure window |

---

## Commands to know by heart

| Question | Command |
|---|---|
| Is Fleet on the latest commit? | `kubectl get gitrepo -n fleet-local -o wide` |
| Did it render and deliver? | `kubectl get bundles -n fleet-local` · `kubectl get bundledeployments -A` |
| What did it actually install? | `helm list -A` (with `KUBECONFIG` set — Chapter 2) |
| Fleet says NotReady — is it? | `kubectl -n <ns> rollout status deploy/<name>` |
| Which version is serving? | `curl` the app's own version endpoint |
| What can this identity do? | `kubectl auth can-i --list -n <ns> --as=system:serviceaccount:<ns>:<sa>` |
| Mint a ServiceAccount token | `kubectl create token <sa> -n <ns> --duration=<h>` |
| How does this node log in to the registry? | keys of `/etc/rancher/k3s/registries.yaml` — never its values |
| Roll back | `git revert <bump commit>` and push |

---

## Glossary

**GitOps** — [Git holds the desired state, and an agent keeps the cluster matching it]{custom-style="Key"}.

**pull model / push model** — [whether the cluster fetches changes (pull) or CI sends them (push)]{custom-style="Key"}.

**Fleet** — Rancher's GitOps engine; installed with Rancher, but running as its own Deployments.

**workspace** — a Fleet namespace grouping GitRepos and target clusters. `fleet-local` = Rancher's own
cluster.

**GitRepo** — Fleet object: which repository, branch and paths to watch.

**Bundle** — [the rendered contents of one path: what to deploy]{custom-style="Key"}.

**BundleDeployment** — one Bundle bound to one target cluster.

**`registries.yaml`** — K3s's registry configuration: endpoints (`mirrors`) and logins (`configs`). Read at
start only.

**deploy token** — a GitLab credential scoped to one project and one purpose (`read_repository`,
`read_registry`).

**`[skip ci]`** — a commit-message marker telling GitLab not to run a pipeline for that commit.

**ServiceAccount token** — a signed credential for a ServiceAccount; from `kubectl create token`, not
stored in the cluster.

**PID 1** — the first process in a container. [It gets no default signal handling]{custom-style="Key"}.

---

## Check yourself

Answer these out loud. Section references, not answers.

1. In one sentence each: what does GitLab hold in the pull model, and what does it hold in the push model? (§1)
2. Why can the bump job's commit not trigger an endless chain of pipelines? (Step 2)
3. Two developers merge app changes a minute apart. What stops the older pipeline rolling the tag backwards? (Step 2)
4. A teammate adds `docker login` to the node and pods still cannot pull. Why, and where does the login belong? (Step 1)
5. You edited `registries.yaml` and nothing changed. What did you forget? (Step 1)
6. Name the four Fleet objects between a commit and a running pod, in order. (Step 3)
7. There is no Helm chart in the repository. Why does `helm list` show a release for the app? What happens if you `helm upgrade` it by hand? (Step 3)
8. Fleet says *NotReady* and `curl` returns the new version. What do you run, and what do you conclude? (Step 4)
9. Every rollout of a new image takes 30 seconds longer than it should. What do you check in the image? (Step 5)
10. The push token leaks. What can the holder do, what can they not do, and how do you stop it? (Step 6)
