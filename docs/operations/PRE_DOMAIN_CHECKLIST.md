# What is left after "I bought a domain"

**Date:** 2026-08-17.

Everything that could be done without a domain, a public IP or provider
credentials has been done and verified on a real bench. This is the remainder,
in the order it has to happen. Nothing on the list needs new code.

---

## Done, and verified how

| | verified by |
|---|---|
| Development and pilot are separate environments | pilot brought up on the real bench: `developer_mode 0`, `allow_tests false`, scheduler enabled, `korkem_env pilot` |
| Production process model (gunicorn, socket.io, scheduler, worker) | gunicorn 23.0.0, 2 workers, serving; no asset watcher |
| Static assets served without nginx | `/assets/frappe/dist/css/website.bundle.*.css` → 200, 680 KB |
| `/health` and `/health/ready` | live on the bench, anonymously, 200 / 503 |
| Data survives `down` and recreate | 122 Sales Orders, 3 Work Orders, 15 Customers before and after |
| The queue survives a restart | `redis-queue` is append-only with its own volume |
| Nothing internal is published | MariaDB and Redis have no host ports; the app binds `127.0.0.1` |
| Destructive demo fixtures refuse on a pilot | all ten entry points, on the real bench in pilot mode |
| Real-user onboarding: owner, employee, customer | 18 tests, including that a customer sees only their own orders |
| Both proxy profiles parse | `caddy validate` on `webhooks.Caddyfile` and `app.Caddyfile` |
| **Both proxy profiles actually work, over TLS** | see below |
| The deployment script | run end to end against the real bench |

### The proxy, exercised without a domain

A public name is needed to get a certificate from Let's Encrypt. It is *not*
needed to find out whether these Caddyfiles route correctly — Caddy will issue
from its own internal CA on request. So both profiles were run against the pilot
bench on the Docker network, with **no host ports published**, and driven from
inside the bench container:

```sh
docker run -d --name proxy-check --network korkem-bench_default \
  -e KORKEM_PUBLIC_HOST=korkem.localhost -e KORKEM_ACME_EMAIL=internal \
  -v $PWD/proxy/app.Caddyfile:/etc/caddy/Caddyfile:ro caddy:2-alpine
# → "certificate obtained successfully" … "issuer":"local"
```

**`app` profile** — everything a real user needs, through TLS:

| | |
|---|---|
| `GET /health` | `200`, `{"status": "ok", "service": "korkem"}` |
| `GET /login` | `200` |
| `GET /assets/frappe/dist/css/website.bundle.*.css` | `200`, 680 957 bytes — gunicorn is serving the static files, with no nginx anywhere |
| `GET /api/method/ping` | `200`, `{"message":"pong"}` |
| response headers | `strict-transport-security`, `x-content-type-options`, `x-frame-options`, `referrer-policy` all present; no `Server` header |
| `POST /api/method/login` | `sid=…; Secure; HttpOnly; SameSite=Lax` |

That last row is the one worth keeping. The identical login sent **directly** to
the bench over plain HTTP comes back without `Secure` — so the flag is coming
from the forwarded scheme, which is what `korkem_ai/wsgi.py` exists to restore.

**`webhooks` profile** — the default, and it refuses everything it should:

| path | |
|---|---|
| `/health`, `/login`, `/app`, `/api/method/ping`, `/files/`, `/assets/...` | `404`, every one |
| `…integrations.telegram.webhook` | `401` — reached Frappe, refused by the app for a missing secret |
| `…integrations.whatsapp.webhook` | `403` — reached Frappe, refused because the integration is disabled |
| a 3 MB body to either | connection closed by Caddy; the application never reads it |

**What remains untested is one thing only: the ACME exchange with Let's
Encrypt.** Certificate issuance from a public CA needs a public name and open
ports 80/443. Everything on either side of it is measured.

## Re-verified 2026-09-02, against the bench as it stands today

The table above was measured on 2026-08-17. Two weeks and a Windows desktop
later, it was re-run rather than believed. Same method: Caddy on the bench's
Docker network with **no host ports**, certificate from its own internal CA,
driven from inside the bench container.

| | 2026-08-17 | 2026-09-02 |
|---|---|---|
| `caddy validate`, both profiles | valid | **valid** |
| `app`: `/health`, `/login`, `/api/method/ping` | 200 | **200, 200, 200** |
| `app`: hashed static bundle | 200, 680 957 B | **200, 680 957 B** — byte-identical |
| `app`: HSTS, nosniff, frame-options, referrer-policy | present | **all four present, no `Server` header** |
| `webhooks`: `/health` `/login` `/app` `/api/method/ping` `/files/` `/assets/…` | 404 | **404, every one** |
| `webhooks`: telegram webhook | 401 | **401** |
| `webhooks`: whatsapp webhook | 403 | **403** |
| `webhooks`: 3 MB body | connection closed | **closed, no response code at all** |

**One row was not re-run, and it is the important one:** the `Secure` flag on
the session cookie. It comes from `ProxyFix` in `korkem_ai/wsgi.py`, which only
the *pilot* process model loads, and the pilot stack cannot start here — it is
compose project `korkem-bench` while the development bench holds port 8000 as
`korkem-clean`. The mechanism was verified in code (`wsgi.py` is still
`ProxyFix(application_with_statics(), x_proto=1)`, and `scripts/web.sh` still
launches `korkem_ai.wsgi:application`), but **the runtime check belongs to the
first real deployment.** Do it there: sign in over HTTPS and read the
`Set-Cookie` header. If `Secure` is missing, stop — the cookie is travelling in
a form a network can steal.

### Two things that changed since August

* **A desktop client now exists.** `korkem_flow.exe` and the Android APK both
  carry the server address as a *runtime field*, not a compiled-in constant, so
  pointing them at the real host is typing, not rebuilding. Both need the `app`
  profile: with `webhooks` they get 404 on every request and the login screen
  reports the server as unreachable, which is true and unhelpful.
* **On this development machine the running bench is compose project
  `korkem-clean`, not `korkem-bench`.** `deploy_pilot.sh` targets the latter,
  so running it here starts a *second* stack that fights for port 8000 and has
  its own empty volumes. On a fresh server this is a non-issue. Here, stop the
  development bench first.

---

## Первое, что делают на новом узле

```sh
bench --site <сайт> execute korkem_manufacturing.chain_smoke.run
```

Один проход по всей цепочке: сказанное → заявка → замер с адресом → КП → заказ →
договор с подписью → дизайн, который не принимается без чертежа → отказ назначить
монтаж до отгрузки → отказ выставить счёт за неотгруженное → экран «что застряло».

Он отвечает на вопрос, на который тесты не отвечают: **собран ли этот узел так,
что по нему можно пройти.** Тесты на рабочем сайте выключены, и это правильно —
`allow_tests` на производстве означает, что кто-то может стереть данные завода
одной командой.

Проход останавливается на первом же звене, которое не сработало, и называет его.
Проверено на чистой установке 3 сентября: прошёл целиком.

Следы остаются в базе намеренно — заказ, договор, позиция номенклатуры, все с
пометкой «Проверка» в имени. Удалять их за собой значило бы проверять не то, что
произойдёт у клиента.

## Still to do — and what each one needs from you

### 1. The domain and DNS

**`korkem.asia` was bought on 2026-09-03** at Hoster.kz. It resolves to nothing
yet — there is no server to point it at. The name chosen for the application is
`api.korkem.asia`, leaving the apex free for a landing page later without
renaming a live Frappe site.

A step-by-step runbook for the machine itself, in Russian and written for
somebody who does not administer servers daily, is
[`SERVER_FIRST_RUN_RU.md`](./SERVER_FIRST_RUN_RU.md). It carries what this file
cannot: the swap, the firewall, the private-repo clone, and the reason the
minimum machine is 2 cores / 4 GB rather than the cheapest tier.

- [x] **Buy the domain.** `korkem.asia`, 2026-09-03.
- [ ] **Point it at the machine.** An `A` record (and `AAAA` if the machine has
      IPv6) for the name you will use — e.g. `korkem.example.com` — pointing at
      the server's public address. Verify from *outside* the network:
      `dig +short korkem.example.com`.
- [ ] **Open ports 80 and 443** to that machine, on the host firewall and on
      the router if the server is behind one. **80 is not optional**: it is what
      Let's Encrypt uses for the ACME challenge.

*Needed from you:* the domain name, and the server's public IP.

### 2. Choose the public ingress

Two options; both work with what is already here.

- [ ] **Caddy** (`docker-compose.public.yml`, already written). Needs the two
      ports reachable and obtains the certificate itself. Nothing to buy.
- [ ] **Cloudflare Tunnel.** Needs no open inbound ports and no public IP,
      which matters if the server is on a home or office connection. It would
      replace the Caddy service with a `cloudflared` container pointing at
      `bench:8000` — a compose overlay of about fifteen lines, not written yet
      because it cannot be tested without a Cloudflare account.

*Needed from you:* which one. If Cloudflare: an account and a tunnel token —
**do not paste the token into a chat or a log**; it goes in `.env`, which is
gitignored.

### 3. Configure and start

- [ ] Set in `infra/frappe_bench/.env`:
      `SITE_NAME=<the real hostname>`, `KORKEM_ENV=pilot`,
      `KORKEM_PUBLIC_HOST=<the real hostname>`, `KORKEM_ACME_EMAIL=<your email>`,
      and `KORKEM_PROXY_PROFILE=app` if real users will sign in from outside
      (leave it at `webhooks` if only the bots should be reachable).
- [ ] Real `MYSQL_ROOT_PASSWORD` and `ADMIN_PASSWORD` — generated, not typed.
      `openssl rand -base64 24`.
- [ ] `scripts/fetch_vendor.sh` — a clone of this repository does **not**
      contain frappe, erpnext or crm, and Docker will happily bind-mount three
      empty directories instead of saying so. Since 2026-09-03
      `deploy_pilot.sh` refuses in its own preflight rather than letting
      bootstrap fail ten minutes later; both branches of that check were run.
- [ ] `scripts/deploy_pilot.sh --check`, then `scripts/deploy_pilot.sh`.

**A caution about `SITE_NAME`.** Frappe resolves an incoming request to a site
by its `Host` header. A site created as `korkem.localhost` will not answer to
`korkem.example.com`. If the pilot starts on a fresh site this is just a
setting; if it starts from this bench's data it is a **site rename**
(`bench --site old set-config ...` / `bench rename-site`), which is a separate
operation with its own backup — do not discover this on the day.

### 4. HTTPS

- [ ] `docker compose logs proxy` — Caddy says which certificate it obtained,
      or exactly why it could not.
- [ ] `curl -sI https://<host>/health` → `200`.
- [ ] With the `webhooks` profile, everything except the two webhook paths must
      answer `404`. Check one: `curl -sI https://<host>/app` → `404`.

### 5. Users

- [ ] Create the owner (`onboarding.create_owner`), set their password in the
      desk, and sign in as them once.
- [ ] Create one employee, sign in, confirm they see their own work and not the
      whole factory.
- [ ] Create one customer account bound to a real `Customer`, sign in, confirm
      they see **only** their own orders — and that an order belonging to
      somebody else reads as "not found", never as "belongs to another
      customer".
- [ ] Confirm the company binding: as each user, `tools/scope.current_company()`
      answers the right company.

*Needed from you:* the real names and email addresses. Nothing has been invented
— there is no placeholder user waiting to be renamed.

### 6. The AI provider

- [ ] Settings → AI provider: paste the key, **Test connection**.
      Until this is done the assistant cannot answer anything.

*Needed from you:* one API key. It is entered in the app and stored encrypted.

### 7. Channels — unchanged from Phase 33

- [ ] Telegram: bot token from BotFather and a webhook secret of your choosing.
      Then: Save → Test connection → Configure webhook → Send test message.
- [ ] WhatsApp: access token, phone number ID, app secret and verify token from
      a Meta Business account with a registered number. Their webhook is
      registered in Meta's dashboard; there is no API for it.
- [ ] Link your own Telegram id to a `User` in identity management, then message
      the bot.

The full step-by-step is `docs/ai_phase33_production_channel_launch.md`
§ "Test procedure for the day credentials exist". Nothing about it has changed.

### 8. Backups, before the first real order

**This one does not currently work on a Linux server, and that is a decision
waiting on the owner, not a bug to patch.** `backup_offsite.sh` refuses any
destination outside `/mnt/<drive-letter>/` — a guard written for WSL2, where a
copy inside the VHDX is a copy on the disk that will fail. The requirement is
right; its spelling is Windows. A VPS has no such path, so the cron line below
will not run there. "Off the machine" on a VPS means attached block storage,
object storage (S3/R2) or another host over ssh — which of those decides the
code, so the code waits for the answer.

- [ ] Read `BACKUP_AND_RESTORE.md`.
- [ ] Install the cron line.
- [ ] **Restore once, into a scratch site, and check the data is there.** A
      backup that has never been restored is a belief, not a backup.

### 9. The first real business scenario

Run one whole order through, on the real data, and verify each step in ERPNext
directly rather than from the assistant's reply:

- [ ] a customer places an order → a real `Sales Order`, priced, owned by them
- [ ] the manager dispatches work → a `Work Instruction` for a real employee
- [ ] the employee reports an operation → `produced_qty` moves, and it is
      ERPNext that moved it
- [ ] the customer asks where their order is → their own order, nobody else's
- [ ] a notification reaches a real chat

---

## What could not be prepared, and why

| | why |
|---|---|
| A Cloudflare Tunnel overlay | needs an account and a tunnel token; writing it untested would be a guess |
| A publicly trusted TLS certificate | the routing behind it is verified with Caddy's internal CA; only the ACME exchange needs a public name |
| Any real provider round-trip | needs the tokens |
| A real backup of real data | there is no real data yet, and taking one would need your credentials |
| Rate limiting at the edge | see below |
| SMTP | not required by anything here; needed only if you want password-reset mail |

### A note on rate limiting, because the obvious switch is a trap

Frappe has a site-wide switch — `rate_limit` in the site config — and it is
**not per-client**. Its Redis key (`frappe/rate_limiter.py`) contains only the
time window, so it budgets *total processing seconds for the whole site*: one
abusive caller exhausts it and every real user is refused. It is deliberately
left off.

What exists and is sound is `frappe.rate_limiter.rate_limit(ip_based=True)`, a
per-endpoint decorator, applied nowhere today. Both webhooks are already
protected by something stronger than a rate limit — a shared secret or an HMAC
checked before the body is read — and both cap the body size.

Real edge rate limiting belongs at the ingress, and which ingress is question 2
above: Cloudflare brings its own; with Caddy it needs a plugin, which means a
custom image. Worth revisiting once the ingress is decided, not before.
