# Phase 1: Core Observability Stack - Context

**Gathered:** 2025-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Deploy kube-prometheus-stack via Helmfile to provide Prometheus, Grafana, Alertmanager, and node-level metrics with persistent storage and pre-configured dashboards. This is the foundation phase — all subsequent phases depend on Prometheus Operator CRDs and core monitoring infrastructure being operational.

</domain>

<decisions>
## Implementation Decisions

### Storage Strategy
- **Prometheus storage type:** emptyDir (not PVC) — appropriate for single-node Talos Docker where dynamic provisioning isn't available
- **Retention period:** 2-3 days (shorter than spec's 7 days for local dev environment)
- **Storage size limit:** 2GB — safe for local Docker, sufficient for cluster metrics
- **Alertmanager storage:** emptyDir — alert state is ephemeral, acceptable for training purposes
- **Rationale:** PVCs would stay Pending without dynamic provisioner; emptyDir with retention limits prevents disk exhaustion

### Verification Approach
- **Deployment verification:** Automated via Helmfile hooks — run kubectl commands post-deploy
- **Health check level:** Basic — verify pods are Running and services exist
- **Grafana access method:** NodePort services — semi-automatic, requires node IP but no ingress setup
- **Verification strictness:** Lenient — warn on failures but continue deployment, manual verification acceptable
- **Rationale:** Automated hooks ensure basic health without blocking; NodePort provides immediate access without waiting for Traefik

### Component Customization
- **etcd monitoring:** Disabled — Talos manages etcd, standard Prometheus scraping won't work (mTLS)
- **kubeScheduler monitoring:** Enabled — standard component, should be accessible
- **kubeProxy monitoring:** Enabled — standard component with metrics exposed
- **CoreDNS monitoring:** Enabled — important for cluster DNS visibility
- **Default components (node-exporter, kube-state-metrics):** Enabled — core to cluster monitoring
- **Rationale:** etcd is explicitly disabled for Talos compatibility; other control plane components enabled for complete cluster visibility

### Configuration Structure
- **Values files structure:** Split by concern — separate files for prometheus, grafana, alertmanager configs
- **Inline vs external values:** Mix approach — common/simple config inline in helmfile.yaml, complex config in external values files
- **Environment handling:** Future-ready structure — directories for base/, local/, staging/ to support GitOps evolution
- **Organization parameter:** Environment variable — inject ORGANIZATION env var at deploy time, reference in resource names/labels
- **Rationale:** Split structure improves maintainability; env var approach makes project reusable across teams/organizations

### Claude's Discretion
- Exact Helmfile hook implementation (kubectl wait commands vs status checks)
- Specific NodePort port numbers (keep defaults 30000-32767 range)
- Grafana dashboard import method (provisioning vs manual)
- Alertmanager default receiver configuration (null vs webhook)
- File naming conventions within values/ directory

</decisions>

<specifics>
## Specific Ideas

- Storage strategy is driven by Talos Docker single-node constraint — production would use PVC with proper CSI
- Verification should focus on "is it running?" not "is it fully configured?" — detailed config happens in later phases
- The organization parameter is important for making this reusable — likely referenced in external_labels and resource names
- Keep kube-prometheus-stack defaults where possible — only override what's necessary for Talos compatibility

</specifics>

<deferred>
## Deferred Ideas

- **Advanced alert routing configuration** — belongs in Phase 4 (Alerting and Application)
- **Persistent storage for production** — documented as PVC approach for future environments
- **Thanos/Cortex for long-term storage** — v2 requirement, out of scope for 2-day deadline
- **Custom Grafana dashboards** — belongs in Phase 5 (Visualization and Dashboards)
- **Authentication/SSO for Grafana** — production hardening (PRD-03), defer to v2
- **Backup strategies for Prometheus data** — production hardening (PRD-04), defer to v2

</deferred>

---

*Phase: 01-core-observability-stack*
*Context gathered: 2025-03-11*
