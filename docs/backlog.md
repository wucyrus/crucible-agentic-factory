# Backlog

This document captures the durable plan for Crucible Agentic Factory. Items are written as requirements so the repository can evolve without losing the original intent.

## Completed Foundation

- [x] Establish the monorepo identity as `crucible-agentic-factory`.
- [x] Define the architectural model: sense, think, act, learn, govern.
- [x] Migrate the full Xray edge gateway stack into `infra/edge/edge-gateway-stack`.
- [x] Add an open-source local `gitleaks` pre-commit secret scan hook.
- [x] Add a GitHub Actions `gitleaks` scan job mirroring local checks.

## Planned Requirements

### R-001 Edge Network Access

The system must be able to reach and manage edge network infrastructure as a first-class capability.

Acceptance criteria:

- Edge routing and deployment artifacts live inside the repo.
- The edge stack remains maintainable by the agentic system.
- Verification and rollout hooks exist before automated changes are allowed.

### R-002 Cloudflare Email Routing Aliases

The system should provision and document Cloudflare Email Routing aliases for operational addresses.

Acceptance criteria:

- Alias names are documented.
- Inbound routing is tracked separately from outbound notification delivery.
- DNS and mailbox setup steps are reproducible.

### R-003 Daily Tarpit Collection

The system should run a daily job that collects tarpit events and notifies email recipients with a triage summary.

Acceptance criteria:

- A scheduled job exists on the target server.
- The job exports a CSV and a raw log snapshot.
- A notification path sends the summary to email.
- The workflow is documented and replayable.

### R-004 Versioned Docs Build

The system should create a GitHub Action that builds a versioned architecture document into the honeypot/static content path.

Acceptance criteria:

- The build is reproducible from source.
- The generated artifact is versioned.
- The publish step is gated by review or release rules.

### R-005 Monorepo Reusability

The repository should remain a reusable monorepo with clear ownership boundaries and low coupling.

Acceptance criteria:

- Domain folders are stable and documented.
- Shared contracts are versioned.
- No subsystem requires a rewrite of the whole tree to evolve.

### R-006 cli-proxy-api Runtime Stack

The repo should be able to host an additional cli-proxy-api runtime stack behind the same edge server.

Acceptance criteria:

- The new service has an isolated route and health check.
- Edge routing can reverse proxy to the service without breaking the Xray flow.
- Config changes do not leak between runtimes.
- OAuth credentials and installed provider plugins survive container recreation.

### R-007 Control Plane UI

The system should eventually include a UI for service operations, threat triage, secret rotation, and administrative actions.

Acceptance criteria:

- The UI starts read-only.
- Privileged operations require strong auth and audit logging.
- Secret rotation and triage are separated into explicit workflows.

### R-008 Automation for Releases

The repo should automate version bumps, deployment, and post-deploy verification.

Acceptance criteria:

- Version bumps are traceable.
- Deployments have rollback paths.
- Verify steps run after each release.

### R-009 Agentic Runtime Capabilities

The system should model the agentic organization as code: ingestor, orchestrator, memory, launcher, agents, instructions, skills, MCPs, worktrees, workspace, hooks, verify sensors, and feedback loops.

Acceptance criteria:

- Each capability has a stable folder or contract.
- Provider-specific logic is isolated.
- Feedback influences future runs without bypassing governance.

## Working Rule

If a task changes the architecture, the relevant requirement should be updated here first or in the same change set.
