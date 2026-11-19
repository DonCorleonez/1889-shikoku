# Deploying to shikoku.doncorleonez.my.id (Oracle Cloud, Ampere A1)

This puts the 1889 Shikoku hotseat site (with AI players) on an Oracle Cloud
**Ampere A1 (ARM64)** VM and publishes it through a Cloudflare Tunnel.

```
visitor ──HTTPS──▶ Cloudflare ──Tunnel──▶ cloudflared on VM ──▶ 127.0.0.1:8189
                                                                └ nginx ─▶ app ─▶ Postgres, Redis
```

Two parts:

1. **VM part:** run the site with Docker on `127.0.0.1:8189` (Part 1).
2. **Cloudflare part (Muse):** route `shikoku.doncorleonez.my.id` to that port
   (Part 2 has a ready-to-paste prompt).

Part 1 must be running before Part 2 can be checked end to end.

## What is verified

On every push to `main`, `debloat/**` or `deploy/**`, the workflow
`.github/workflows/selfhost-image.yml` builds this exact stack **natively on an
ARM64 GitHub runner** (same CPU architecture as Ampere A1), starts it, and
checks over HTTP: `/`, `/new_game`, `/assets/main.css`,
`/assets/tutorial.json`, `/assets/version.json` and `/logos/1889/AR.svg` all
return 200, and the 1889 game bundle (`g_1889.js`) was built. It then publishes
the images to ghcr.io.

Not verified by CI: playing a game in a real browser, Cloudflare routing, and
the Oracle VM itself. Part 1 step 5 and Part 2 step 5 check those.

ARM64 note: the upstream lockfile pins `mini_racer 0.6.2` (V8 16), which has no
ARM64 binary. On ARM64 the image build moves only `mini_racer` and
`libv8-node` to the newest release (which ships an `aarch64-linux` binary);
all other gems stay at the locked versions. Production pages render in the
browser, so the server does not use V8 to serve pages.

---

## Part 1 — Oracle VM (Docker)

### 1. VM requirements

- Shape **VM.Standard.A1.Flex** (Always Free works), at least **1 OCPU / 6 GB RAM**.
  The stack uses about 1.5 GB RAM at rest with 2 app workers.
- Image: **Ubuntu 22.04 or 24.04 (aarch64)**, or Oracle Linux 8/9 (aarch64).
- About **6 GB free disk** for images and the build.
- **No inbound ports need to be opened** in the Oracle security list or the
  VM firewall: the site binds to 127.0.0.1 and the Cloudflare Tunnel only makes
  outbound connections. Keep SSH (22) as the only open port.

Check the architecture first:

```bash
uname -m          # must print aarch64
```

### 2. Install Docker (Ubuntu)

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl git
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # then log out and back in
docker compose version            # must print v2.x
```

On Oracle Linux use `sudo dnf install -y dnf-plugins-core && sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && sudo systemctl enable --now docker`.

### 3. Get the code and configure

```bash
git clone https://github.com/DonCorleonez/1889-shikoku.git
cd 1889-shikoku
git checkout <BRANCH_OR_COMMIT>      # the deploy instructions name it

cp .env.selfhost.example .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 24)/" .env
echo "GIT_REV=$(git rev-parse --short HEAD)" >> .env
# If port 8189 is already used on the VM, change WEB_PORT in .env
```

### 4. Start it

**Option A, build on the VM (default, no login needed).** Takes about 5–10
minutes on 1–2 OCPUs.

```bash
docker compose -f docker-compose.selfhost.yml up -d --build
```

**Option B, pull the CI-built images.** Faster. Needs the ghcr.io packages
`1889-shikoku-app` and `1889-shikoku-web` to be public (GitHub → profile →
Packages → package → Package settings → Change visibility), or a
`docker login ghcr.io` with a token that has `read:packages`.

```bash
cat >> .env <<'EOF'
SHIKOKU_APP_IMAGE=ghcr.io/doncorleonez/1889-shikoku-app:sha-<SHORT_SHA>-arm64
SHIKOKU_WEB_IMAGE=ghcr.io/doncorleonez/1889-shikoku-web:sha-<SHORT_SHA>-arm64
EOF
docker compose -f docker-compose.selfhost.yml pull web rack
docker compose -f docker-compose.selfhost.yml up -d --no-build
```

### 5. Check it on the VM

```bash
docker compose -f docker-compose.selfhost.yml ps                 # web, rack, db, redis: running
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8189/new_game          # 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8189/assets/main.css    # 200
curl -s http://127.0.0.1:8189/assets/version.json                # shows the deployed commit
```

The first `rack` start runs database migrations. Give it about 30 seconds
before the first request. Lines such as `sh: 1: Syntax error` in the rack log
during startup are a known harmless message (they also appear upstream).

### Update, logs, stop, backup

```bash
cd 1889-shikoku && git pull && sed -i "s/^GIT_REV=.*/GIT_REV=$(git rev-parse --short HEAD)/" .env
docker compose -f docker-compose.selfhost.yml up -d --build

docker compose -f docker-compose.selfhost.yml logs -f rack
docker compose -f docker-compose.selfhost.yml down          # data stays in the pgdata volume

# hotseat saves live in each player's browser; the database only holds accounts
docker compose -f docker-compose.selfhost.yml exec -T db pg_dump -U shikoku shikoku | gzip > shikoku-db-$(date +%F).sql.gz
```

Containers restart automatically after a VM reboot (`restart: unless-stopped`,
and Docker is enabled at boot by the installer).

---

## Part 2 — Cloudflare Tunnel (prompt for Muse)

Paste this to Muse:

> **Task: publish shikoku.doncorleonez.my.id through a Cloudflare Tunnel.**
>
> A web app now runs on my **Oracle Cloud Ampere A1 VM (ARM64, aarch64)** at
> **`http://localhost:8189`** (plain HTTP, Docker, bound to 127.0.0.1 only).
> Please:
>
> 1. **Check whether `cloudflared` already runs on this VM** (`systemctl status
>    cloudflared`, `docker ps | grep cloudflared`).
>    - **If yes:** find out how the tunnel is managed: *dashboard-managed*
>      (started with `--token`, shows "Remotely managed" in Zero Trust →
>      Networks → Tunnels) or *locally managed* (`/etc/cloudflared/config.yml`
>      or `~/.cloudflared/config.yml` with an `ingress:` list). Add the route to
>      that tunnel. Don't create a new tunnel, and don't change existing routes.
>    - **If no:** install the ARM64 build (`cloudflared-linux-arm64.deb` from the
>      Cloudflare downloads page, or the Cloudflare apt repo), create a tunnel
>      in Zero Trust → Networks → Tunnels (or reuse my existing one by adding
>      this VM as a connector), and install it as a service with
>      `sudo cloudflared service install <token>`.
>
> 2. **Add the route:**
>    - Dashboard: Tunnel → *Public Hostname* → *Add*: subdomain `shikoku`,
>      domain `doncorleonez.my.id`, service `HTTP`, URL `localhost:8189`.
>      This also creates the DNS record. If a DNS record for `shikoku` already
>      points at an old server or tunnel, replace it and tell me.
>    - config.yml: add this rule **above** the final `- service: http_status:404`:
>      ```yaml
>      - hostname: shikoku.doncorleonez.my.id
>        service: http://localhost:8189
>      ```
>      then `cloudflared tunnel route dns <tunnel> shikoku.doncorleonez.my.id`,
>      `cloudflared tunnel ingress validate`, and restart cloudflared.
>
> 3. **If cloudflared runs in a Docker container**, `localhost` is the container.
>    Either run it with `network_mode: host`, or use
>    `http://host.docker.internal:8189` with
>    `extra_hosts: ["host.docker.internal:host-gateway"]` (the app is bound to
>    127.0.0.1, so a bridge-IP route also needs `WEB_PORT` exposed on that
>    interface). Tell me which option you picked.
>
> 4. **Settings for this hostname:** SSL/TLS mode Full or Flexible. No Cloudflare
>    Access unless I ask. **Rocket Loader off** (it breaks the game's
>    JavaScript).
>
> 5. **Verify:** `curl -s -o /dev/null -w '%{http_code}' https://shikoku.doncorleonez.my.id/new_game`
>    returns `200`. In a browser, the page loads, and *Hotseat* → *Shikoku 1889*
>    → *Create* starts a game where the AI seats move on their own.
>
> Report what you changed (tunnel, route, DNS record, config edits) and the
> verification result.

---

## What works on this copy

- **Only 1889 Shikoku is included.** All other titles were removed from this build.
- **Hotseat games with AI players work.** Games are saved in each browser's
  local storage, so the server stores nothing for them and no account is needed.
- **Accounts and online multiplayer are not set up.** Upstream they rely on
  email sending and a Turnstile anti-bot widget. To enable them later, create a
  Turnstile widget for `shikoku.doncorleonez.my.id` and set `TURNSTILE_*` in
  `.env`. Email verification would also need a mail provider in `lib/mail.rb`.
- 1889 is published on 18xx.games with its designer's permission. The MIT
  license doesn't cover those rights, so keep this copy for personal play,
  not a public service.
