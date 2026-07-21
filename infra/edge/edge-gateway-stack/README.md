# Edge Gateway Stack: Caddy + VLESS XHTTP + Honeypot + Optional Tarpit

This directory contains a full, runnable reference layout for the staged architecture discussed in the troubleshooting guide.

## Architecture

- Edge TLS and routing: Caddy on port 443
- Proxy backend: Xray VLESS + XHTTP on `127.0.0.1:8080`
- Unauthorized traffic: local honeypot static site
- Optional scanner sink: micro-tarpit on `127.0.0.1:9090`

## Directory Layout

```text
edge-gateway-stack/
  docker-compose.yml
  .env.example
  caddy/
    Caddyfile
    snippets/
      xray-routes.caddy
    sites/
      main-domain.caddy
      second-domain.example.caddy
  xray/
    server-config.json
    client-config.json
    reality-local-fallback-snippet.json
    output/
      server-config.json
      client-config.json
  honeypot/
    index.html
  static-second-domain/
    index.html
  tarpit/
    tarpit.py
  scripts/
    collect-tarpit.ps1
    collect-tarpit.sh
    render-xray.ps1
    render-xray.sh
    test-routing.ps1
  systemd/
    xray-compose.service
```

## 1) Fill Environment Variables

Copy and edit:

```bash
cp .env.example .env
```

Required values in `.env`:

- `DOMAIN`
- `CLIENT_UUID`
- `XHTTP_AUTH_HEADER`
- `XHTTP_PATH`
- Optional TLS email and log levels

Recommended log env split:

- `CADDY_LOG_LEVEL=WARN` for runtime/error logs
- `CADDY_ACCESS_LOG_LEVEL=INFO` for request access logs

## 2) Render Templated Files

This reference keeps config files with `${VAR}` placeholders for readability.
Render them before deployment using your preferred method (for example `envsubst`) or replace values manually.

Files that include placeholders:

- `xray/server-config.json`
- `xray/client-config.json`

Render command (Bash, output to `xray/output/`):

```bash
set -a
. ./.env
set +a

mkdir -p xray/output
envsubst < xray/server-config.json > xray/output/server-config.json
envsubst < xray/client-config.json > xray/output/client-config.json
```

Convenient one-command script:

```bash
./scripts/render-xray.sh
```

PowerShell render command (Windows):

```powershell
./scripts/render-xray.ps1
```

Quick verification:

```bash
grep -R '\${' xray/output || echo "No unresolved placeholders in rendered xray configs"
```

Runtime note:

- Docker uses `xray/output/server-config.json` as the live server config mount.
- You can re-run rendering after editing `.env` without modifying template files.

Note: Caddy files use Caddy runtime placeholders in the form `{$VAR}` and are resolved inside the Caddy container from environment variables.

## 3) Pre-deployment Cleanup (Old Local Services)

Before deploying this stack, remove or disable older local installs to avoid port and service conflicts.

### 3.1 Remove old local Caddy service (host install)

Only do this if the old Caddy is not needed by other applications.

```bash
sudo systemctl stop caddy || true
sudo systemctl disable caddy || true
sudo systemctl status caddy || true
```

Optional package removal (depends on install method):

```bash
# Debian/Ubuntu
sudo apt remove -y caddy || true

# RHEL/CentOS/Fedora
sudo dnf remove -y caddy || sudo yum remove -y caddy || true
```

### 3.2 Remove old xray-compose systemd service (legacy path)

```bash
sudo systemctl stop xray-compose.service || true
sudo systemctl disable xray-compose.service || true
sudo rm -f /etc/systemd/system/xray-compose.service
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

Verify cleanup:

```bash
systemctl status caddy || true
systemctl status xray-compose.service || true
sudo ss -lntp | grep -E ':80|:443' || true
```

Expected result before new deployment:

- No old host-level `caddy` service running.
- No stale `xray-compose.service` pointing to legacy working directory.
- Ports `80/443` free for the new dockerized Caddy stack.

## 4) Start Services

```bash
docker compose up -d
```

## 5) Validate Behavior

- No header should return honeypot page:

```bash
curl -vk https://YOUR_DOMAIN/YOUR_PATH
```

- Correct header should be forwarded to Xray:

```bash
curl -vk -H "X-App-Auth: YOUR_SECRET" https://YOUR_DOMAIN/YOUR_PATH
```

Or use the included PowerShell helper:

```powershell
./scripts/test-routing.ps1 -Domain YOUR_DOMAIN -Path /api/v1/telemetry -HeaderValue YOUR_SECRET
```

## 6) Deployment Notes

- Keep Xray listen address on loopback when behind Caddy.
- Use high-entropy header values and rotate periodically.
- Prefer ALPN `h2` before `http/1.1` for better traffic blending.
- Start with XHTTP `packet-up` mode in stricter DPI environments.

### Caddy log files

This stack writes Caddy logs to files mounted from the host:

- Access log: `./log/caddy/access.log`
- Runtime/error log: `./log/caddy/error.log`

Useful commands on server:

```bash
tail -f ./log/caddy/access.log
tail -f ./log/caddy/error.log
```

## 7) Tarpit Telemetry Collection

The scanner routes forward source metadata to tarpit using `X-Real-IP`, `X-Forwarded-For`, and `X-Original-URI`.
The tarpit service emits one JSON log event per trapped request.

Collect recent tarpit events (PowerShell):

```powershell
./scripts/collect-tarpit.ps1 -Since "6h"
```

Collect recent tarpit events (Linux shell):

```bash
chmod +x ./scripts/collect-tarpit.sh
./scripts/collect-tarpit.sh 6h
```

Outputs:

- `tarpit-raw.log` (raw container log stream)
- `tarpit-events.csv` (parsed events for triage)

Suggested triage fields:

1. `client_ip`
2. `host`
3. `path`
4. `user_agent`
5. `hold_seconds`

## 8) Register as systemd service (server)

Use the included unit file to manage docker compose with systemd:

- Source file: `systemd/xray-compose.service`

Install steps on Linux server:

1. Copy your edge-gateway-stack folder to the server, for example `/opt/xray/edge-gateway-stack`.
2. Edit `systemd/xray-compose.service` and set `WorkingDirectory` to your actual server path.
3. Install unit file:

```bash
sudo cp systemd/xray-compose.service /etc/systemd/system/xray-compose.service
sudo systemctl daemon-reload
sudo systemctl enable --now xray-compose.service
```

Useful commands:

```bash
sudo systemctl status xray-compose.service
sudo systemctl restart xray-compose.service
sudo systemctl stop xray-compose.service
```

## 9) Add Another Domain

1. Create a new site file under `caddy/sites/`, for example `caddy/sites/example-two.com.caddy`.
2. Add a site block and import the shared routes snippet:

```caddy
example-two.com {
  import xray_routes
}
```

3. Reload Caddy by recreating the container or restarting the stack:

```bash
docker compose up -d
```

Static-only domain option:

- Use `caddy/sites/second-domain.example.caddy` as a template.
- Place site files in `static-second-domain/`.
- This directory is mounted to `/var/www/second-domain` in Caddy.

## 10) Optional Phase 2 (REALITY Local Fallback)

If Phase 1 still faces blocking, pivot to self-hosted REALITY local fallback.
See `xray/reality-local-fallback-snippet.json` for a baseline `realitySettings` block.

## 11) Cloudflare Email Routing (Free Custom-Domain Alerts)

Use Cloudflare Email Routing if you want custom-domain alert addresses without hosting a mail server.

Suggested aliases:

- `cert-alerts@YOUR_DOMAIN`
- `security-alerts@YOUR_DOMAIN`
- `honeypot-alerts@YOUR_DOMAIN`

Setup steps:

1. Open Cloudflare dashboard and select your domain.
2. Go to `Email` -> `Email Routing` and click `Get started`.
3. Choose destination mailbox (your real inbox, for example Outlook or Proton address).
4. Add routing rules (aliases above) and map each alias to your destination mailbox.
5. Cloudflare will prompt required DNS records. Apply all required MX/TXT records.
6. Verify destination mailbox ownership when Cloudflare requests verification.
7. Send a test message to each alias and confirm delivery.

Operational notes:

- Email Routing is forwarding-only. Mailbox hosting/webmail stays with your destination provider.
- Keep at least two recipients for critical cert alerts (primary + backup owner).
- Add inbox rules/filters at destination mailbox so cert and security alerts are separated.

Recommended mapping:

1. ACME and certificate expiry notifications -> `cert-alerts@YOUR_DOMAIN`
2. Caddy/Xray operational and security alerts -> `security-alerts@YOUR_DOMAIN`
3. Honeypot/tarpit ban triage notifications -> `honeypot-alerts@YOUR_DOMAIN`

## 12) Safety Note

This architecture improves resilience but does not guarantee invisibility or immunity.
Tune and validate with your own network conditions.
