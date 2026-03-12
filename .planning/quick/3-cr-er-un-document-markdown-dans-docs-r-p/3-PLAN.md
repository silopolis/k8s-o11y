---
phase: quick
plan: 3
type: execute
wave: 1
depends_on: []
files_modified: [docs/kubernetes-monitoring-stack.md]
autonomous: true
requirements: [K8S-DOC-01, K8S-DOC-02, K8S-DOC-03, K8S-DOC-05]
must_haves:
  truths:
    - Document covers kube-prometheus-stack components and configuration
    - Document explains Prometheus Operator and Adapter roles
    - Document includes Jsonnet vs CRDs comparison table
    - Document describes all 7 CRDs with their roles
    - Document provides Helmfile deployment structure and examples
  artifacts:
    - path: docs/kubernetes-monitoring-stack.md
      provides: Complete documentation for Kubernetes monitoring stack
      min_lines: 200
  key_links:
    - from: specs/specs.md section 2.1-2.5
      to: docs/kubernetes-monitoring-stack.md
      via: content transcription and synthesis
---

<objective>
Create a comprehensive markdown document in docs/ covering the Kubernetes monitoring stack requirements from points 2.1 to 2.5 of the specifications.

Purpose: Document the kube-prometheus-stack ecosystem, configuration approaches, and deployment structure for the Dawan infrastructure team.
Output: docs/kubernetes-monitoring-stack.md with all required sections (2.1, 2.2, 2.3, 2.5).
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
@/home/tarax/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md
@specs/specs.md (points 2.1 à 2.5)
@AGENTS.md (markdown style guidelines)
</context>

<tasks>

<task type="auto">
  <name>Create kubernetes-monitoring-stack.md with sections 2.1-2.5</name>
  <files>docs/kubernetes-monitoring-stack.md</files>
  <action>
Create a comprehensive markdown document at docs/kubernetes-monitoring-stack.md covering:

**Section 2.1 — Découverte de la stack kube-prometheus-stack:**
- Chart Helm components: Prometheus (via operator), Alertmanager, Grafana, node_exporter (DaemonSet), kube-state-metrics
- Key values: retention, resources, storageSpec, alertmanager.config
- Dashboard provisioning via ConfigMaps with grafana_dashboard label

**Section 2.2 — Écosystème Prometheus sur Kubernetes:**
- Opérateur Prometheus: manages lifecycle of Prometheus/Alertmanager/ThanosRuler via CRDs, watches ServiceMonitor/PodMonitor/PrometheusRule for auto-configuration
- Adaptateur Prometheus: exposes Prometheus metrics as custom metrics API for HPA scaling
- Include 5-line summary for each with concrete use cases

**Section 2.3 — Approches de configuration: Jsonnet vs CRDs:**
- Comparison table covering: Principe, Avantages, Inconvénients, Exemple d'utilisation, Outillage nécessaire
- CRD descriptions table: ServiceMonitor, PodMonitor, PrometheusRule, Alertmanager, AlertmanagerConfig, Probe, ScrapeConfig (one sentence each)

**Section 2.5 — Déploiement avec Helmfile:**
- Expected k8s/ structure
- Complete helmfile.yaml with prometheus-community and traefik repositories
- values/traefik.yaml with metrics.prometheus.enabled, access log JSON, IngressRoute
- values/kube-prometheus-stack.yaml with 7-day retention, 10Gi PVC, Alertmanager receiver, disabled etcd/kubeScheduler/kubeProxy

Follow markdown style from AGENTS.md:
- Use semantic line breaks (no hard limit)
- 2 blank lines above headings, 1 below
- Use *italic* and **bold** (not underscores)
- Code fences with language tags
- :::note/:::warning admonitions where appropriate
  </action>
  <verify>
npx markdownlint-cli2 docs/kubernetes-monitoring-stack.md
  </verify>
  <done>
Document exists at docs/kubernetes-monitoring-stack.md with:
- All 4 sections (2.1, 2.2, 2.3, 2.5) complete
- Both comparison tables filled
- All 7 CRDs described
- Helmfile and values examples provided
- Markdown linting passes with no errors
  </done>
</task>

<task type="auto">
  <name>Update docs/index.md with navigation link</name>
  <files>docs/index.md</files>
  <action>
Update docs/index.md to include a link to the new kubernetes-monitoring-stack.md document. Add it in an appropriate section related to Kubernetes monitoring documentation.

If the file is empty, create a simple index structure:
- Title: Documentation Index
- Section: Kubernetes Monitoring
- Link to kubernetes-monitoring-stack.md with brief description
  </action>
  <verify>
cat docs/index.md | grep -q "kubernetes-monitoring-stack"
  </verify>
  <done>
Index file contains navigation link to the new documentation file
  </done>
</task>

</tasks>

<verification>
- Document covers all points from specs 2.1, 2.2, 2.3, and 2.5
- Comparison tables are complete with all columns filled
- CRD descriptions are concise (one sentence each)
- Helmfile structure matches expected k8s/ layout
- Markdown follows project style guidelines (AGENTS.md)
- npx markdownlint-cli2 passes without errors
</verification>

<success_criteria>
- docs/kubernetes-monitoring-stack.md exists with 200+ lines
- All 4 required sections are present and complete
- Both comparison tables (Jsonnet vs CRDs, CRD descriptions) are filled
- Helmfile deployment examples are provided
- Markdown linting passes
- docs/index.md links to the new document
</success_criteria>

<output>
After completion, create `.planning/quick/3-cr-er-un-document-markdown-dans-docs-r-p/3-SUMMARY.md`
</output>
