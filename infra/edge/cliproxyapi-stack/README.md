# CLIProxyAPI Stack

This stack runs CLIProxyAPI as a separate local service under `infra/edge`, intended to sit behind the shared edge Caddy layer.

## Layout

- `docker-compose.yml` starts the CLIProxyAPI container from a published image.
- `cpa-usage-keeper` provides the optional usage dashboard and SQLite persistence.
- `config.yaml` is the active local config.
- `config.example.yaml` is the template for new deployments.
- `auths/` stores credential files mounted to `/root/.cli-proxy-api` in the container.
- `logs/` stores CLIProxyAPI log output.
- `keeper/` stores CPA Usage Keeper data, logs, and backups.

## Security model

- CLIProxyAPI publishes as `127.0.0.1:8317` on the host.
- In Docker bridge mode, CLIProxyAPI should bind `host: ""` (all container interfaces); localhost-only restriction is enforced by compose port bindings.
- The pprof endpoint listens on `127.0.0.1:8316` only.
- OAuth callback ports are published on localhost only for local browser redirects: `1455` (Codex), `54545` (Claude), and `51121` (Antigravity).
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

1. Replace placeholder values in `config.yaml`.
2. Add auth material under `auths/`.
3. Start the stack with `docker compose up -d` from this directory.
4. Point the edge Caddy site at `127.0.0.1:8317` for API traffic only.
5. Open the usage dashboard at `http://127.0.0.1:18080` (or your configured `KEEPER_HOST_PORT`).

## Notes

- This stack intentionally uses the published container image instead of a local build context so it remains runnable from `infra/edge` as a standalone deployment unit.
- If you want to disable management entirely, set `remote-management.secret-key` to an empty string.
