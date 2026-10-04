# CLIProxyAPI Stack

This stack runs CLIProxyAPI as a separate local service under `infra/edge`, intended to sit behind the shared edge Caddy layer.

## Layout

- `docker-compose.yml` starts the CLIProxyAPI container from a published image.
- `cpa-usage-keeper` provides the optional usage dashboard and SQLite persistence.
- `config.yaml` is the active local config.
- `config.example.yaml` is the template for new deployments.
- `auths/` stores credential files mounted to `/root/.cli-proxy-api` in the container.
- `plugins/` stores native CLIProxyAPI provider plugins mounted to `/CLIProxyAPI/plugins`.
- `logs/` stores CLIProxyAPI log output.
- `keeper/` stores CPA Usage Keeper data, logs, and backups.

## Security model

- CLIProxyAPI publishes as `127.0.0.1:8317` on the host.
- In Docker bridge mode, CLIProxyAPI should bind `host: ""` (all container interfaces); localhost-only restriction is enforced by compose port bindings.
- The pprof endpoint stays container-local at `127.0.0.1:8316` and is not published by compose.
- OAuth callback ports are published on localhost only: `8085`, `1455` (Codex), `54545` (Claude), `51121` (Antigravity), and `11451`.
- `remote-management.allow-remote` should be enabled for Docker bridge mode, because requests arrive from a bridge IP instead of `127.0.0.1`.
- This does not expose management publicly when compose host bindings stay localhost-only (`127.0.0.1:8317:8317`).
- CPA Usage Keeper maps to `127.0.0.1:18080` by default (container port `8080`), configurable via `KEEPER_HOST_PORT`.
- Public edge traffic should only proxy API endpoints to `127.0.0.1:8317`.
- Public edge traffic should tarpit `/management.html`, `/console`, `/v0/management*`, and `/v0/resource/plugins*`.
- Management access should use an SSH tunnel authenticated with a private key.
- Shared Caddy lives under `infra/edge/caddy-stack` and should be the ingress source of truth.
- Set `CPA_MANAGEMENT_KEY` to the same management secret used by CLIProxyAPI.
- Keep `AUTH_ENABLED=true` and set `LOGIN_PASSWORD` to protect the Keeper dashboard when exposed through the browser.

Management API auth reminder:

- `/v0/management/*` requires a management key even from localhost.
- Provide either `X-Management-Key: <secret-key>` or `Authorization: Bearer <secret-key>`.

## SSH Tunnel (Private Key)

Use SSH local forwarding with your private key to access localhost-only services on the server.

One-off command:

```bash
ssh -i /path/to/private_key -N \
	-L 8317:127.0.0.1:8317 \
	-L 18080:127.0.0.1:18080 \
	user@host
```

Open after tunnel is up:

- `http://127.0.0.1:8317` for CLIProxyAPI management
- `http://127.0.0.1:18080` for CPA Usage Keeper dashboard

### Convenient `~/.ssh/config` Profile

Add an SSH host profile to avoid repeating tunnel flags.

```sshconfig
Host cliproxy-edge
	HostName your.server.domain.or.ip
	User your-user
	Port 22
	IdentityFile ~/.ssh/your_private_key
	IdentitiesOnly yes
	ServerAliveInterval 30
	ServerAliveCountMax 3
	ExitOnForwardFailure yes
	LocalForward 8317 127.0.0.1:8317
	LocalForward 18080 127.0.0.1:18080
```

Start tunnel:

```bash
ssh -N cliproxy-edge
```

Optional background mode:

```bash
ssh -f -N cliproxy-edge
```

## Usage

1. Copy `config.example.yaml` to `config.yaml` and replace placeholder values.
2. Create runtime directories if needed: `mkdir -p auths plugins logs keeper`.
3. Add auth material under `auths/`.
4. Start the stack with `docker compose up -d` from this directory.
5. Point the edge Caddy site at `127.0.0.1:8317` for API traffic only.
6. Open the usage dashboard at `http://127.0.0.1:18080` (or your configured `KEEPER_HOST_PORT`).

## Native provider plugins

CLIProxyAPI v8 can load optional native provider plugins from `/CLIProxyAPI/plugins`. The compose stack persists that directory on the host as `./plugins`, so installed plugins survive container recreation and image refreshes.

The example config enables native plugins globally. Provider-specific plugins remain optional and should be installed only when needed.

For a provider plugin that adds CLI login commands, verify the contributed flags after installation:

```bash
docker compose exec cli-proxy-api \
  /CLIProxyAPI/CLIProxyAPI --help
```

For example, once the optional Gemini CLI provider plugin is installed, headless/mobile SSH login can use:

```bash
docker compose exec -it cli-proxy-api \
  /CLIProxyAPI/CLIProxyAPI --geminicli-login --no-browser
```

If the browser callback cannot reach the VPS-local listener, use the plugin's manual callback fallback and paste the complete callback URL back into the SSH session.

## Updating

The container image and provider plugins have separate lifecycles.

Refresh the published images and recreate the stack with:

```bash
docker compose pull
docker compose up -d --force-recreate
```

Verify the running CLIProxyAPI version and available login flags after an update:

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI --help
```

Updating the CLIProxyAPI image does not automatically install provider plugins. Installed plugins are retained under `./plugins`.

## Notes

- This stack intentionally uses the published container image instead of a local build context so it remains runnable from `infra/edge` as a standalone deployment unit.
- `config.example.yaml` intentionally remains legacy-compatible rather than being migrated wholesale to the canonical v8 layout because it currently uses compatibility-only quota settings such as `quota-exceeded.switch-project` and `quota-exceeded.switch-preview-model`.
- If you want to disable management entirely, set `remote-management.secret-key` to an empty string.
