# Crucible Agentic Factory

Crucible Agentic Factory is a monorepo for an evolvable agentic engineering system: ingestors, orchestrators, memory, launchers, code agents, instructions, skills, MCPs, worktrees, verification sensors, feedback loops, and the edge stack it can eventually maintain on its own.

## Design Goal

This repository treats the edge as one managed component inside a broader agentic operating system. The long-term intent is to compress an AI engineering organization into software while keeping each capability independently testable, replaceable, and governable.

## Initial Domains

- `services/edge` - edge routing, proxying, and operational ingress
- `services/ingestor` - telemetry, event capture, and external signal intake
- `services/orchestrator` - planning, coordination, and task routing
- `services/memory` - persistent state, retrieval, and knowledge shaping
- `services/launcher` - execution, worktree handling, and agent launch flows
- `apps/control-plane` - human-facing control surface and triage UI
- `agents/codex` - Codex-driven workflows and agent instructions
- `agents/claude-code` - Claude Code-driven workflows and agent instructions
- `instructions` - shared operating instructions and policies
- `skills` - reusable task skills and workflows
- `mcps` - MCP definitions and integration contracts
- `verify` - sensors, checks, and validation harnesses
- `feedback` - evaluation outputs, learning signals, and review loops
- `infra/edge` - edge deployment artifacts and runtime glue

## Migrated Edge Stack

The full Xray edge gateway stack now lives in `infra/edge/edge-gateway-stack`.

That subtree includes:

- Caddy routing and site configuration
- Xray server and client templates
- tarpit service and collectors
- render scripts and systemd units
- the static honeypot and supporting assets

For the durable plan and pending requirements, see [docs/backlog.md](docs/backlog.md).

## Working Model

The preferred system model is:

1. Sense - ingest telemetry, events, and external signals
2. Think - plan, route, and select actions
3. Act - launch agents, worktrees, and automations
4. Learn - evaluate outcomes and retain useful signals
5. Govern - enforce instructions, policy, audit, and release gates

## Next Steps

1. Add repository metadata and workspace scaffolding.
2. Define the architecture charter in `docs/architecture`.
3. Add initial automation and verification hooks.
4. Evolve edge, ingestion, and control-plane components behind stable contracts.
