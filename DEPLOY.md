# Deploying to shikoku.doncorleonez.my.id

This puts the 1889 Shikoku hotseat site (with AI players) on your own VPS and
publishes it through your existing Cloudflare Tunnel.

```
visitor ──HTTPS──▶ Cloudflare ──Tunnel──▶ cloudflared on VPS ──▶ 127.0.0.1:8189
                                                                 └ nginx ─▶ app ─▶ Postgres, Redis
```

There are two parts:

1. **VPS part (Hermes):** run the site with Docker on `127.0.0.1:8189`.
2. **Cloudflare part (Muse):** add `shikoku.doncorleonez.my.id` to the tunnel,
   pointing at that port. A ready-to-paste prompt is below.

Part 1 must be running before Part 2 can be checked end to end.

---

## Part 1 — VPS (Docker)

Needs Docker with the compose plugin, about 2 GB free RAM, and about 5 GB of disk.
The first build compiles every game's JavaScript and takes **10–20 minutes**.

```bash
git clone https://github.com/DonCorleonez/1889-shikoku.git
cd 1889-shikoku

cp .env.selfhost.example .env
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 24)/" .env
# If port 8189 is already used on the VPS, change WEB_PORT in .env

docker compose -f docker-compose.selfhost.yml up -d --build
```

Check it locally on the VPS:

```bash
docker compose -f docker-compose.selfhost.yml ps          # all four "running"
curl -sI http://127.0.0.1:8189/new_game | head -1         # HTTP/1.1 200 OK
```

**Update to the latest code later:**

```bash
cd 1889-shikoku && git pull
docker compose -f docker-compose.selfhost.yml up -d --build
```

**Logs / stop:**

```bash
docker compose -f docker-compose.selfhost.yml logs -f rack
docker compose -f docker-compose.selfhost.yml down        # data is kept in the pgdata volume
```

The site only listens on `127.0.0.1`, so nothing is exposed to the internet
until the tunnel route exists.

---

## Part 2 — Cloudflare Tunnel (prompt for Muse)

Paste this to Muse:

> **Task: publish shikoku.doncorleonez.my.id through my existing Cloudflare Tunnel.**
>
> My VPS already runs `cloudflared` for a Cloudflare Tunnel (it serves other
> subdomains of `doncorleonez.my.id`, e.g. `kanban.doncorleonez.my.id`).
> A new web app now runs on that same VPS at **`http://localhost:8189`**
> (plain HTTP, Docker, bound to 127.0.0.1 only). Please:
>
> 1. **Find out how the tunnel is managed.**
>    - *Dashboard-managed* (`cloudflared` started with `--token`, or the tunnel
>      shows "Remotely managed" in Zero Trust → Networks → Tunnels), or
>    - *Locally managed* (`/etc/cloudflared/config.yml` or `~/.cloudflared/config.yml`
>      with an `ingress:` list).
>
> 2. **Add the route** for the same tunnel. Don't create a new tunnel, and don't
>    change existing routes.
>    - Dashboard: Tunnel → *Public Hostname* → *Add*: subdomain `shikoku`,
>      domain `doncorleonez.my.id`, service type `HTTP`, URL `localhost:8189`.
>      This also creates the DNS record.
>    - config.yml: add this rule **above** the final `- service: http_status:404`
>      catch-all:
>      ```yaml
>      - hostname: shikoku.doncorleonez.my.id
>        service: http://localhost:8189
>      ```
>      Then run `cloudflared tunnel route dns <tunnel-name-or-id> shikoku.doncorleonez.my.id`,
>      validate with `cloudflared tunnel ingress validate`, and restart
>      cloudflared (`sudo systemctl restart cloudflared`, or restart its container).
>
> 3. **If cloudflared itself runs in a Docker container**, `localhost` means the
>    container, not the VPS. Use the address the existing routes use to reach
>    host services instead, e.g. `http://host.docker.internal:8189` with
>    `extra_hosts: ["host.docker.internal:host-gateway"]`, or the host's
>    docker bridge IP such as `http://172.17.0.1:8189`. Note that the app is
>    bound to 127.0.0.1, so a bridge-IP route also needs `WEB_PORT` exposed on
>    that interface. Tell me which option you picked.
>
> 4. **Keep these Cloudflare settings for this hostname:** SSL/TLS mode
>    Full or Flexible (the origin is plain HTTP through the tunnel, so either works).
>    Don't put Cloudflare Access in front unless I ask, and don't enable Rocket Loader
>    (it breaks the game's JavaScript).
>
> 5. **Verify:** `curl -sI https://shikoku.doncorleonez.my.id/new_game` returns
>    `200`. In a browser, the page loads, and choosing *Hotseat* → *Shikoku 1889*
>    → *Create* starts a game where the AI seats move on their own.
>
> Report what you changed (route, DNS record, any config file edits) and the
> verification result.

---

## What works on this copy

- **Hotseat games with AI players work fully.** Games are saved in each browser's local
  storage, so nothing is stored on the server, and no account is needed.
- **Accounts and online multiplayer are not set up.** Upstream these rely on email
  sending (Elastic Email) and a Turnstile anti-bot widget registered for
  18xx.games. To enable them later, create a Turnstile widget for
  `shikoku.doncorleonez.my.id` in Cloudflare and set the `TURNSTILE_*` values in
  `.env`. Email verification would still need a mail provider wired into `lib/mail.rb`.
- The game titles are published on 18xx.games with permission from their
  designers. The MIT license doesn't cover those rights, so keep this copy for
  personal play, not a public service.
