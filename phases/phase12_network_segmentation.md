# Phase 12: Perimeter Lockdown — Public Reaches Only the WWW/App Box (.184 as DMZ)

**Status:** ✅ IMPLEMENTED (July 8, 2026) — Tasks 1–4 done and validated; two optional checks remain
**Priority:** 🔴 High — define and verify the public boundary; make .184 inbound-only
**Created:** July 1, 2026 (rewritten same day after Andrew clarified the intended model)
**Author:** AI Assistant + Andrew
**Scope:** INFRASTRUCTURE layer (router port-forwards, Proxmox firewall on .184). One dependent
change lives in the Capricorn project (`unified_ui_DEV_PROD_GCP`): switch the PROD-local deploy
from "pull from registry" to "push images in."

---

## 📋 Andrew's Requirements (July 1, 2026)

1. **Public (internet)** may reach **only** the www/app server on **.184** (splash +
   Capricorn PROD demo), over **80/443**. Nothing else on the network is public.
2. **Internal LAN stays flat** — every internal host may reach every other host.
   No internal micro-segmentation between the trusted VMs.
3. **.184 does not need to reach any other internal host** — data is pushed *to* it; it
   serves the public. So .184 can be inbound-only (a DMZ box).

> This replaces the earlier draft of this phase (which proposed internal east-west
> segmentation). Per Andrew, internal traffic is fully trusted; the control is at the
> **perimeter** (router) plus making **.184 inbound-only**.

---

## 🔍 Current State (verified July 1, 2026)

- Single flat bridge `vmbr0`, `192.168.1.0/24`. Fine — internal stays flat by design.
- **Public entry:** router (Verizon G3100) DDNS `bullpup.ddns.net` (108.6.178.182).
  MEMORY documents forwards **80→.184:80** and **443→.184:443**, **no port 22**. If that is
  the complete list, the internet already cannot reach .180/.181/.183/Proxmox. **Verify.**

### ✅ Router port-forward table — VERIFIED July 8, 2026 (logged into G3100 admin UI)

The "only 80/443" assumption was **WRONG**. The full table had 13 rules. DMZ Host = **Disabled**
(IPv4 + IPv6 — good, no catch-all exposure). UPnP is **enabled** (the "UPnP IGD" rows are
device-punched holes). Table as found:

| Application | WAN port | Proto | → Internal | Int port | Notes |
|---|---|---|---|---|---|
| (none) | 4577 | TCP | 127.0.0.1 | 4577 | router loopback (Verizon internal) |
| (none) | 4567 | TCP | 127.0.0.1 | 4567 | router loopback (Verizon internal) |
| (none) | 63145 | UDP | .100 | 63145 | manual |
| (none) | 35000 | TCP | .100 | 7547 | ⚠️ TR-069/CWMP — review/remove |
| UPnP IGD | 16987 | TCP | .200 | 32400 | Plex (auto via UPnP) |
| UPnP IGD | 41641 | UDP | .224 | 41641 | Tailscale (low risk, WireGuard-auth) |
| UPnP IGD | 41643 | UDP | .150 | 41641 | Tailscale on Proxmox |
| UPnP IGD | 41642 | UDP | .115 | 41641 | Tailscale |
| ~~ARD~~ | ~~3283~~ | ~~Both~~ | ~~.200~~ | ~~3283~~ | **DELETED Jul 8** (→ Tailscale) |
| ~~ARD~~ | ~~5900~~ | ~~Both~~ | ~~.200~~ | ~~5900~~ | **DELETED Jul 8** — public VNC, →Tailscale |
| ~~ARD~~ | ~~5988~~ | ~~Both~~ | ~~.200~~ | ~~5988~~ | **DELETED Jul 8** (→ Tailscale) |
| Traefik 80 | 80 | TCP | .184 | 80 | intended (kept) |
| Traefik 443 | 443 | TCP | .184 | 443 | intended (kept) |

**Done this session (Jul 8):** deleted the three `ARD` rows (3283/5900/5988 → .200) + Applied.
Andrew reaches the Mac-mini over Tailscale (confirmed .200 runs Tailscale); LAN + Tailscale
access unaffected — only public internet exposure removed. Good news confirmed: **no forward
to .180/.181/.183 and no port 22** — those boxes are not directly internet-reachable.

**Decisions made (Jul 8):**
- **`.100` = Verizon equipment (ARRIS, MAC `8c:5a:25:19:37:b2`) — LEAVE IT.** Its forwards
  (WAN 35000→.100:7547 TR-069/gSOAP, and .100:63145) are ISP-managed. Accepted risk; not ours
  to change. (Probe showed 7547=gSOAP/2.7 `stb` namespace, 8080=Allegro RomPager, 80/443=lighttpd 403.)
- **`.200:32400` Plex — KEEP** (Andrew wants public Plex streaming).
- The two `127.0.0.1` (4567/4577) rules are router-internal; leave alone.

**Still open on the router (review):**
- **UPnP enabled** — any internal host (incl. a compromised .184) can punch its own inbound
  holes. For a tight perimeter, disable UPnP and make the Tailscale/Plex forwards explicit.
  (Tailscale still works without UPnP via DERP relay; may add minor latency.) NOTE: if UPnP is
  disabled, Plex (.200:32400) and the Tailscale holes would need to be re-added as manual rules.
- **.184 listeners** (confirmed via `ss -tlnp`): `0.0.0.0:80`, `:443`, `:22`, and `:8080`
  (Traefik dashboard via docker-proxy). :8080 is LAN-only (not forwarded); the public cap
  hostname does not expose the Traefik API (`/api/rawdata` → 404). Good.
- **.184's only internal OUTBOUND dependency:** the PROD-local deploy makes .184 pull images
  from the GitLab registry. In `unified_ui_DEV_PROD_GCP/.gitlab-ci.yml` (`deploy_prod_local`):
  - `ssh agamache@.184 "docker login ... gitlab.gothamtechnologies.com:5050"` → **.184 → .181:5050**
  - `ssh agamache@.184 "docker pull $REGISTRY/.../{frontend,backend,postgres}:latest"` → **.184 → .181:5050**
  - `docker pull redis:7.2.4-alpine` → Docker Hub (internet, fine)
  - The runner (.182) SSHes *into* .184 (inbound to .184 — fine).
- At runtime the Capricorn stack on .184 is self-contained (own postgres/redis); other calls
  are to the internet (Let's Encrypt, apt). No internal runtime dependency found.

**Conclusion:** the only thing stopping .184 from being fully inbound-only is the deploy-time
registry **pull**. Fix that and .184 needs zero internal-host access.

---

## 🛠️ Implementation Plan (proposed — review before executing)

### Task 1 — Verify & tighten the perimeter (router) — ⏳ IN PROGRESS (Jul 8)
- [x] Read the full G3100 port-forward table (see verified table above). Assumption of
      "only 80/443" was wrong — 13 rules found.
- [x] Removed public VNC/ARD (3283/5900/5988 → .200); Mac-mini now Tailscale-only.
- [x] `.100` (Verizon ARRIS equipment) forwards — reviewed, **LEAVE** (ISP-managed, accepted).
- [x] Plex `.200:32400` — **KEEP** (Andrew's decision).
- [x] UPnP — **LEAVE ENABLED** (Andrew's decision, Jul 8; keeps Plex/Tailscale auto-forwards).
- [ ] Confirm DDNS still points to the current WAN IP.
- [ ] (Optional external check) from an off-LAN vantage point, confirm only 80/443 answer on the WAN IP.

**Task 1 effectively closed** for this pass: the only *unwanted* public exposure (Mac VNC/ARD)
is removed. Remaining forwards are all intentional or ISP-managed. DDNS/off-LAN checks are
nice-to-have, not blockers.

### Task 2 — Make the PROD-local deploy "push" instead of "pull" (Capricorn project) — ✅ DONE (Jul 8)
- Implemented in `unified_ui_DEV_PROD_GCP/.gitlab-ci.yml` `deploy_prod_local`: the **runner**
  (.182) now does `docker login`/`pull`, then `docker save frontend backend postgres | ssh
  agamache@.184 "docker load"`. .184 never contacts the registry. Job image alpine → docker:27.
- Committed to `production` as `e0f3057` (only the CI file — no develop code promoted) and
  cherry-picked to `develop` as `9e5d2dc`; both pushed to GitLab.
- **Live-tested:** pipeline #137, job #722 `deploy_prod_local` succeeded in 47s. Log confirms
  pulls happened on the runner and images entered .184 via `docker load` over SSH. Fresh stack
  up, https://cap.gothamtechnologies.com HTTP 200.
- NOTE: `redis:7.2.4-alpine` still comes from Docker Hub *from .184* at compose-up — that is
  internet egress (allowed under the OUT rules), not internal.

### Original Task 2 notes (for reference)
- Change `deploy_prod_local` in `unified_ui_DEV_PROD_GCP/.gitlab-ci.yml` so the **runner**
  supplies the images and .184 never contacts the registry. Options:
  - `docker save frontend backend postgres | ssh agamache@.184 "docker load"` (runner already
    has/pulls the images), then `docker compose up -d` on .184; OR
  - runner builds and `docker save`s the three app images and SCPs a tarball + `docker load`.
  - `redis:7.2.4-alpine` also comes in the same way (or stays a Docker Hub pull — that's
    internet, not internal, so allowed either way).
- Remove the `docker login … :5050` and `docker pull $REGISTRY/…` lines from the .184 SSH block.
- **This is a Capricorn-project change** (coordinate; it must merge/deploy before Task 3 blocks
  .184→.181, or the next deploy fails).

### Task 3 — Make .184 inbound-only (Proxmox firewall on the .184 VM) — ✅ DONE (Jul 8)
Implemented on pve (.150) as `/etc/pve/firewall/184.fw` (VM-level; datacenter firewall was
**disabled** — enabled it via new `/etc/pve/firewall/cluster.fw` with `enable: 1`).
- Prep done first: `qm snapshot 184 pre_phase12_firewall` + old 184.fw saved to
  `/root/184.fw.bak-20260708` on pve. (A stale 184.fw already existed — allowed SSH from the
  whole /24 and had no OUT rules; it was inert because the datacenter fw was off. Replaced.)
- **IN (policy DROP):** 80/tcp + 443/tcp from anywhere; 22/tcp from **.182** (runner), **.195**
  (Andrew workstation, static IP), **.150** (pve); ICMP from LAN.
- **OUT (policy ACCEPT):** ACCEPT to gateway **.1** first, then DROP to 192.168.1.0/24,
  10/8, 172.16/12, 192.168/16 → internet-only egress (Docker Hub, apt, Let's Encrypt).
  .184 DNS is public (8.8.8.8/1.1.1.1) so no internal DNS exception needed.
- Other VMs untouched: 181/182/183/200 have `firewall=1` on the NIC but **no .fw file**, so the
  now-enabled datacenter firewall applies nothing to them (185.fw exists; VM stopped).
- Rollback: restore `/root/184.fw.bak-20260708` → `pve-firewall restart`; or `rm
  /etc/pve/firewall/cluster.fw` to disable the datacenter fw entirely; VM snapshot as last resort.

### Task 4 — Minor hardening (optional) — ✅ effectively closed (Jul 8)
- Traefik :8080 dashboard is now unreachable from the LAN (IN policy DROP catches it) —
  verified blocked from .195. Binding it to 127.0.0.1 in the compose is now cosmetic; skipped.

### Leave unchanged
- All other VMs' firewalls: **no change** — internal everything-to-everything per Andrew.

---

## 🧪 Validation / Acceptance Criteria (run July 8, 2026 after implementation)
1. [~] Router forwards to .184 = only 80/443 (verified). BUT other hosts still have forwards
   (.100 TR-069/63145, .200 Plex — both intentional/accepted); public VNC/ARD to .200 removed Jul 8.
2. [ ] From off-LAN, only 80/443 on the WAN IP respond — still pending (needs off-LAN vantage).
3. [x] `deploy_prod_local` run #722 succeeded with .184 never contacting .181 (log: pulls on
   runner, `docker save | ssh docker load` into .184).
4. [x] From .184: OUT to `.181:5050`, `.181:80`, `.180:5002`, `.183:9000`, `.150:8006` all
   **blocked**; Docker Hub reachable (HTTP 401 = handshake OK); DNS resolves; gateway .1 OK.
5. [x] Public: cap.gothamtechnologies.com and www.gothamtechnologies.com both HTTP 200.
6. [x] Internal unchanged for others: .181→.184:80 still open (LAN can view the site);
   .182→.184:22 open (deploys work). Other VMs have no firewall applied.
7. [x] Admin SSH .195→.184 works. Bonus: .181→.184:22 now **blocked** (SSH allowlist works);
   .184:8080 (Traefik dashboard) now blocked from LAN.

---

## ❓ Decisions Needed From Andrew — ALL RESOLVED (Jul 8)
1. ✅ **Deploy method = `docker save|load` over SSH** — approved, implemented, live-tested (job #722).
2. ✅ .184 DNS = public 8.8.8.8/1.1.1.1; no internal DNS exception needed (`resolvectl` verified).
3. ✅ Traefik :8080 — now blocked from LAN by the IN policy; localhost bind unnecessary.
4. ✅ Order followed: deploy change proven first, then the OUT-block applied.
5. ✅ **Egress model = "Option A: internet yes, LAN no"** (Andrew chose it over full lockdown, so
   redis/apt/Let's Encrypt keep working). Andrew confirmed .195 is a **static IP**; if it ever
   changes, edit the SSH rule in the Proxmox UI (Datacenter → pve → VM 184 → Firewall).

> **CI facts verified (Jul 8):** `deploy_prod_local` (capricorn/.gitlab-ci.yml:166–195) has .184
> `docker login` + 4× `docker pull` from $REGISTRY (.181:5050). `deploy_qa` (:143–148) does the
> same to .180. Both embed the registry password (see PASSWORDS.md) inline (:143, :187) — ties to Capricorn phase22a C-3.
> Runner's own push job (:77) correctly uses masked `$CI_REGISTRY_USER/$CI_REGISTRY_PASSWORD`.

## 🚫 Out of Scope
- Internal segmentation between the trusted VMs (explicitly not wanted).
- App-level auth / Capricorn API hardening (Capricorn project, phase22c) — still worth doing,
  since the public app on .184 is the sole internet-facing surface, but separate from this phase.
- Rotating leaked credentials (Capricorn/docs concern).

## 🔒 Rollback
Capture .184's current `<vmid>.fw` before editing; restore + `pve-firewall restart` to revert.
Console access via Proxmox UI guarantees recovery if SSH is cut. Deploy change is a normal
`.gitlab-ci.yml` revert.

---

*Nothing implemented yet. Plan for review per the mandatory phase process.*
