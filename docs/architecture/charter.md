# Architecture Charter

## Purpose

Crucible Agentic Factory is an agentic engineering system designed to compress recurring engineering work into governed software components. The system is expected to grow from a small set of manually operated services into an orchestrated organization of agents, sensors, memory, and launch workflows.

## Core Principles

- Treat the edge as a managed subsystem, not the product boundary.
- Separate sense, think, act, learn, and govern concerns.
- Keep instructions, skills, MCPs, and workflows versioned and testable.
- Prefer narrow contracts over implicit coupling.
- Make verification part of the runtime, not an afterthought.
- Preserve human override paths for every automated action.

## Domain Map

- Sense: ingestors, telemetry, scanners, external events
- Think: orchestrators, planners, policy engines, memory routing
- Act: launchers, worktrees, executors, deployments
- Learn: feedback loops, evals, reviews, retrospectives
- Govern: instructions, controls, audit logs, release gates

## Expected Evolution

The repository should evolve from documentation plus scaffolding into a reusable monorepo containing:

- edge runtime services
- internal agent runtimes
- shared memory and instruction systems
- sensor and verification pipelines
- release and deployment automations
- a control-plane UI for operations and triage

## Non-Goals For The First Phase

- Full product UI implementation
- Autonomous production changes without review gates
- Hidden coupling between subsystems
- Hardcoded assumptions about one model provider or one agent framework
