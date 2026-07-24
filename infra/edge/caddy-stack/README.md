# Shared Caddy Ingress

This directory contains the shared Caddy ingress layer for edge stacks under `infra/edge`.

## Scope

- `Caddyfile` defines global options and imports.
- `snippets/` contains reusable route blocks such as `xray_routes`.
- `sites/` contains concrete virtual hosts and optional templates.

## Ownership

- Keep ingress and TLS policy here as a single source of truth.
- Application stacks should expose localhost-only services and should not carry their own Caddy configuration trees.

## Current site files

- `main-domain.caddy`
- `second-domain.caddy`
- `third-domain.caddy`
- `fourth-domain.caddy`
- `second-domain.caddy.example`
- `third-domain.caddy.example`
- `fourth-domain.caddy.example`
