# Phase 21: Visitor analytics on vm-www-1 (.184) — Matomo

**Status:** ✅ LIVE Nov 27, 2026 (approved via AskQuestion: "Yes, go ahead and build"). Both apps ship the tracker:
Dionysus `05e84a4` (site 1), Capricorn `664e4c4` (site 2, its Phase 31). Prerequisite (Traefik access log) done
Nov 27 12:21 EST — `phase7` → DIONYSUS.

**Live check (Nov 27, 1:17 PM EST, measured by the AI after Andrew reported "both work"):** both PROD pages' HTML
references the tracker; Matomo DB: Dionysus 1 visit / 3 actions (12:58 EST), Capricorn 1 visit / 1 action (13:08 EST);
the hourly `core:archive` cron ran on its own at 13:05 (`done`). ✅ T2 for Dionysus (3 route changes = 3 actions in one
visit). 🔲 Still open: T2 for Capricorn (1 action seen — switch modules and expect more); T3 (ad blocker);
T4 from OUTSIDE (`https://<WAN IP>:8443` must time out — phone on cellular).

## ▶️ BUILD RESULTS (Nov 27, 2026, 12:28–12:36 EST)
- **Matomo 5.14.3** (`matomo:5-apache`) + **MariaDB 11.4.13** (`mariadb:11.4`) in `/opt/matomo` (compose project `matomo`,
  volumes `matomo_html`, `matomo_db`; DB on `matomo_internal` only). RAM: 165 MiB + 106 MiB.
  Passwords: `/opt/matomo/.env` (root 600) + `PASSWORDS.md` → "Matomo visitor analytics". Super user `andrew`.
- **Sites:** 1 = Dionysus (`https://dionysus.gothamtechnologies.com`), 2 = Capricorn (`https://cap.gothamtechnologies.com`),
  both America/New_York.
- **Traefik:** entrypoint `lan` `:8443` added (+ port `8443:8443`); recreated in 1.5 s, cap/www/dionysus 200 before/after.
  Every pre-existing router is pinned to `websecure` (measured) — so `lan` carries ONLY `matomo-ui`.
- **`184.fw`:** `IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8443` (backup `/root/184.fw.bak-20261127`); compiled, live.
- **Install:** wizard driven with `curl` from `.195` (the IDE browser refuses the self-signed cert). GeoIP: DB-IP City Lite
  (`misc/DBIP-City.mmdb`, 127 MB), provider `geoip2php`, updater monthly. `PrivacyManager.ipAnonymizerEnabled = 0` (full IPs).
  Global excluded IP `108.6.178.182`. `config.ini.php` [General]: `proxy_client_headers[] = HTTP_X_FORWARDED_FOR`,
  `proxy_ips[] = 172.18.0.0/16`, `assume_secure_protocol = 1`, `force_ssl = 1`, `enable_browser_archiving_triggering = 0`,
  `trusted_hosts[] = "192.168.1.184:8443"` (the image pre-sets proxy host/scheme headers; a duplicate line was removed).
- **Archiving:** `/etc/cron.d/matomo-archive` — hourly at :05, log `/var/log/matomo-archive.log`; first manual run exit 0.

**Validation (measured):**
| Trap | Test | Result |
|---|---|---|
| T4 | `/index.php`, `/matomo.php`, `/s/index.php` on dionysus + cap | each app's own page — never Matomo ✅ |
| T4 | `:443` with `Host: 192.168.1.184` | Capricorn ✅ |
| T4 | `:8443` from a non-LAN source (inside `.184`), also with forged `X-Forwarded-For: 192.168.1.5` | 403 ✅ |
| T4 | `:8443` from `.195` | Matomo ✅ — 🔲 from OUTSIDE (`<WAN IP>:8443` must time out) not yet tested |
| T7 | `/s/a.js` on dionysus + cap | 200 `text/javascript` ✅ |
| T1 | hit via public name from `.195` (exclusion swapped to `192.0.2.1` for the test) | `visitIp` `108.6.178.182` (real WAN, not 172.18.x), correct home-area city + lat/long ✅ |
| T1 | same with forged `X-Forwarded-For: 1.2.3.4` | ignored — same real IP ✅ (Traefik drops client XFF) |
| — | exclusion with home IP in place | both hits dropped ✅ (negative shown before the positive) |
| T6 | `core:archive` manual run | exit 0 ✅ |
| T2, T3 | SPA route changes; ad blocker | 🔲 after the snippets ship |
Test visit deleted (`PrivacyManager.deleteDataSubjects`: 1 visit, 2 actions); exclusion restored to `108.6.178.182`.

⚠️ **Gotchas found:** `SitesManager.setGlobalExcludedIps` refuses an empty value — swap to a TEST-NET IP to test, then
restore. curl's default user agent may be counted as a bot — test with a browser UA. The install cookie jar + session
token (`working/matomo-install.*`) were deleted the same session.

## 🧩 SNIPPETS — as handed to the Dionysus and Capricorn projects (both SHIPPED Nov 27; their repos own the live code)
**Dionysus** (`frontend/index.html` `<head>`; site ID **1**). Gated on the PROD hostname so DEV/QA never send data:
```html
<script>
  if (location.hostname === 'dionysus.gothamtechnologies.com') {
    var _paq = (window._paq = window._paq || []);
    _paq.push(['enableLinkTracking']);
    _paq.push(['setTrackerUrl', '/s/a.php']);
    _paq.push(['setSiteId', '1']);
    var g = document.createElement('script');
    g.async = true; g.src = '/s/a.js';
    document.head.appendChild(g);
  }
</script>
```
…and ONE page view per route change (react-router v6, e.g. in `Layout.tsx`, which already has `useLocation`) — this
also covers the first page, so the head snippet must NOT call `trackPageView` itself (T2):
```tsx
useEffect(() => {
  const paq = (window as { _paq?: unknown[][] })._paq
  if (!paq) return
  paq.push(['setCustomUrl', window.location.href])
  paq.push(['setDocumentTitle', document.title])
  paq.push(['trackPageView'])
}, [location.pathname, location.search])
```
**Capricorn:** the same with hostname `cap.gothamtechnologies.com` and site ID **2**. It has NO URL routing (navigation is
`currentPath` state in `components/Layout.tsx`; the URL never changes), so it sends VIRTUAL page views:
`setCustomUrl('https://cap.gothamtechnologies.com/' + currentPath)` on each `currentPath` change.
Its record: `unified_ui_DEV_PROD_GCP/project/phases/phase31_matomo_analytics.md`.

**Andrew's decisions (Nov 27, AskQuestion):** (1) backups — **keep `.184` unbacked** (July decision stands, now
knowingly covering Matomo history + Dionysus SQLite); (2) **full IPs**, no anonymisation; (3) **exclude the home WAN IP**
`108.6.178.182` (accepts hiding friends on his Wi-Fi; the WAN IP is dynamic — re-check if it changes);
(4) track **Dionysus AND Capricorn** (Capricorn's snippet is its own project's change); (5) git path — not answered,
proposal stands.
**Depends on:** Phase 7 (vm-www-1, Traefik), Phase 12 (`.184` DMZ firewall).

---

## 1. Goal (Andrew, Nov 27)
A web dashboard **only Andrew can reach** showing who uses the apps on `.184` — first of all how often his
friends use Dionysus (live since Nov 27). Wanted: history of connections, **a map** of where they come from,
**rich per-person and per-session detail**.

**Choice made (AskQuestion, Nov 27):** Matomo, over Grafana+Loki, GoAccess and Umami — the only one with a
per-visitor profile (every visit, every page, device, location) that follows a friend across IP changes.
Traefik's access log stays as the raw, app-independent record underneath.

## 2. What Matomo will show
Visitor log (each visit: IP, city/region/country, ISP, device type/model, OS, browser, screen, language, referrer,
duration, the pages in order) · **visitor profile** (all visits of one person, first/last seen, visit count) ·
**Visitor Map + Real-time Map** (core plugin `UserCountryMap`) · visits per day/week, returning vs new, top pages.
GeoIP = DB-IP City Lite, auto-downloaded monthly by Matomo (`.184` has internet egress; LAN egress is dropped).
Not included: heatmaps / session recordings (paid plugins).

## 3. Design

```
friend's browser ──https──► Traefik (.184:443)
   │  GET  /s/a.js  ┐   router `dionysus-stats` (Host dionysus… && Path /s/a.js | /s/a.php)
   │  POST /s/a.php ┘   middleware replacePathRegex → /matomo.js | /matomo.php ──► matomo:80 (web net)
   └─ everything else ─► router `dionysus` (unchanged) ──► dionysus-frontend-prod

any LAN PC (192.168.1.x) ──https──► .184:8443 ──► Traefik entrypoint `lan` (NOT forwarded by the router)
   router `matomo-ui` (entrypoint lan ONLY, ipAllowList 192.168.1.0/24) ──► matomo:80 (UI, login)
```

- **Location:** `/opt/matomo/` (beside `/opt/traefik`, `/opt/splash`) — compose project `matomo`, owned by THIS repo
  (it is ingress observability = infra, not an app). Images pinned: `matomo:5-apache`, `mariadb:11.4` (LTS).
- **Networks:** `matomo` joins `web` (Traefik must reach the tracker) + its own `matomo_internal` with MariaDB.
  MariaDB is on `matomo_internal` ONLY.
- **"Only Andrew" = LAN-only UI at `https://192.168.1.184:8443`** (Andrew, Nov 27: "open it from computers on my
  192.168.1/xx network like capricorn"; replaces the first draft's SSH tunnel). Four layers:
  1. the router forwards only 80/443 to `.184` — 8443 has no path from the internet;
  2. `184.fw` gains `IN ACCEPT -source 192.168.1.0/24 -p tcp -dport 8443` (the Phase 12 DMZ is about `.184` NOT
     reaching INTO the LAN — the OUT rules are untouched, and the LAN already reaches `.184` on 80/443);
  3. a NEW Traefik entrypoint `lan` (:8443) carries ONLY the `matomo-ui` router, with an `ipAllowList` of
     `192.168.1.0/24` — the public `websecure` entrypoint never routes the UI, so a router mistake cannot expose it;
  4. the Matomo login.
  TLS = Traefik's default self-signed cert (browser warning once, same as `https://192.168.1.184` for Capricorn —
  Let's Encrypt cannot issue for a LAN-only name without DNS-01/Route53 credentials, which Phase 7 chose not to hold).
  Only two exact paths on Dionysus's public host are internet-facing: the tracker script and the tracking endpoint.
  ⚠️ Any LAN device reaches the login page (household devices too). Tailnet clients probably do as well — the
  host's subnet router SNATs to `.150`, inside the /24 — UNVERIFIED.
  Rejected: Matomo port 8090 straight on the LAN (login over plain HTTP); a `/matomo` path on `Host(192.168.1.184)`
  (Capricorn owns that router; Matomo is poor under a sub-path).
- **Same-origin tracker paths** (`/s/a.js`, `/s/a.php` on `dionysus.gothamtechnologies.com`): no third-party
  host, no extra DNS name or certificate, and file names that ad-block lists do not match on.
- **Real visitor IP into Matomo:** Traefik strips client-sent `X-Forwarded-For` and sets its own (entrypoint not
  configured to trust forwarded headers), so Matomo trusts `HTTP_X_FORWARDED_FOR` only from the `web` subnet:
  `proxy_client_headers[] = HTTP_X_FORWARDED_FOR`, `proxy_ips[] = <web subnet CIDR, measured at build>`.
- **Archiving:** browser-triggered archiving OFF; host cron hourly `docker exec matomo php console core:archive`.
- **Dionysus side (NOT this repo — Dionysus project change):** a tracker snippet in the SPA that loads `/s/a.js`,
  posts to `/s/a.php`, and calls `trackPageView` on EVERY route change (React router), not just page load.
  This repo supplies the snippet + site ID; the Dionysus repo commits and deploys it.
- **Backfill (optional):** Matomo's `import_logs.py` could replay the Traefik log from Nov 27 12:21 onward. Traefik
  JSON is not one of its built-in formats — needs a custom regex or conversion; skip unless Andrew wants those hours.

## 4. Decisions for Andrew
1. **Backups.** `.184` is deliberately UNBACKED (July 9 WON'T-FIX: "WWW = vanity, rebuildable"). Matomo's history is
   not rebuildable — and neither, now, is Dionysus's SQLite volume. `.184` cannot reach the NAS (DMZ), so in-guest
   dumps have nowhere to go. Options: (a) add 184 to `critical-nightly` (vzdump from the host → NAS; reverses July);
   (b) accept the loss. ⛔ Not changed without Andrew.
2. **IP anonymisation:** OFF (full IPs — "rich info on the person") vs Matomo's 2-byte default. Plan assumes OFF.
3. **Excluding Andrew:** exclude the home WAN IP `108.6.178.182` (also hides friends using Andrew's Wi-Fi) or use
   Matomo's opt-out cookie on Andrew's own browsers. Plan assumes the cookie.
4. **Capricorn / splash too?** Capricorn is not ours to change (needs its own project's snippet). Default: Dionysus
   only; the Traefik access log already covers all three hosts.
5. **Where the compose lives in git:** proposed `services/vm-www-1/matomo/` (compose +
   `config.ini.php` template); passwords in a gitignored `.env` + `PASSWORDS.md`.

## 5. Traps declared up front (each gets a test in §7)
- **T1** Every visit shows Traefik's IP (`172.18.x`) — proxy headers not trusted. Silent: reports still fill up.
- **T2** Only the first page of each visit is counted — SPA route changes not tracked.
- **T3** Ad blockers drop the tracker — under-counting that looks like "nobody uses it".
- **T4** The UI leaks through Traefik (a label, a catch-all router, or `Host(192.168.1.184)` — Capricorn's).
- **T5** `trusted_hosts` mismatch: UI at `192.168.1.184:8443` refuses to load or redirects to the wrong host/port.
- **T6** Archiving not running: Visitor Log has data, every report says "no data".
- **T7** Router priority: Dionysus's catch-all `Host()` router beats the stats router and `/s/a.js` returns the SPA.
- **T8** A Dionysus redeploy touches Matomo, or a Matomo change touches Capricorn/Dionysus (Traefik restart).

## 6. Tasks
1. Measure: Docker Hub reachable from `.184`; `web` subnet CIDR; free RAM/disk (Nov 27: 5.6 GiB avail, 18 GB free).
2. Write `/opt/matomo/docker-compose.yml` + `.env` (DB passwords → `PASSWORDS.md`); `docker compose up -d`.
3. LAN access: Traefik `entryPoints.lan` (:8443) in `/opt/traefik/traefik.yml` + port `8443:8443` in its compose
   (backup first; ~2 s Traefik restart, all three sites checked before/after); `184.fw` rule for 8443 from the /24.
4. Install wizard at `https://192.168.1.184:8443`; super-user to `PASSWORDS.md`; site "Dionysus" (site ID recorded).
5. `config.ini.php`: `trusted_hosts` (`192.168.1.184:8443`), `proxy_client_headers`, `proxy_ips`, `assume_secure_protocol`;
   browser archiving off; GeoIP provider DB-IP + auto-update; anonymisation per decision 2.
6. Traefik labels on `matomo`: the two tracker paths on `websecure` (+ `replacePathRegex`, explicit priority) and the
   `matomo-ui` router on `lan` ONLY (+ `ipAllowList`).
7. Host cron for `core:archive` (hourly) — `/etc/cron.d/matomo-archive`.
8. Hand the snippet to the Dionysus project; it deploys via its own pipeline.
9. Docs: `phase7` DIONYSUS/Matomo facts, `MEMORY.md` §4 `.184` row, `INDEX.md` row → ✅, `reference/` if a recipe emerges.

## 7. Validation (each from the place the user stands, not from inside the box)
- T4: from OUTSIDE the LAN (phone on cellular): `https://dionysus…/index.php`, `/s/`, `https://cap…/index.php` and
  `https://<WAN IP>/` never show Matomo; `https://<WAN IP>:8443` times out. From a LAN PC other than `.195`:
  `https://192.168.1.184:8443` shows the login. From inside `.184` with a non-LAN source faked via `X-Forwarded-For`:
  still refused (ipAllowList must use the socket IP, not the header).
- T1: phone on cellular visits Dionysus → Visitor Log shows the carrier's public IP and a plausible city, not 172.18.x.
- T2: click through 3 routes → one visit with 3 actions.
- T3: repeat with uBlock Origin (default lists) in a desktop browser → still tracked.
- T6: after the hourly cron, Visits Overview shows the test visits.
- T7: `curl -sI https://dionysus…/s/a.js` → `Content-Type: application/javascript`, not `text/html`.
- T8: cap/www/dionysus 200 before and after every step; Matomo still up after a Dionysus redeploy.
- Rollback of the LAN path is one firewall line + one entrypoint, and is written down.

## 8. Rollback
`docker compose -f /opt/matomo/docker-compose.yml down` removes the tracker routes with the container (labels live on it);
Dionysus keeps working if the snippet's script fails to load (async). LAN path: delete the 8443 line from `184.fw`,
restore `/opt/traefik/*.bak-<date>` and `docker compose up -d --pull never` in `/opt/traefik`.
