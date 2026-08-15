# helm-serve

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/btungut)](https://artifacthub.io/packages/helm/btungut/helm-serve)
[![Release](https://img.shields.io/github/v/release/btungut/helm-serve?include_prereleases&style=plastic)](https://github.com/btungut/helm-serve/releases)
[![LICENSE](https://img.shields.io/github/license/btungut/helm-serve?style=plastic)](https://github.com/btungut/helm-serve/blob/master/LICENSE.md)

**A Helm library chart for shipping stateless services, scheduled jobs, observability, and ingress TLS without repeating Kubernetes boilerplate.**

`helm-serve` is a DRY Helm library chart that standardizes how teams render `Deployment`, `CronJob`, `Service`, `Ingress`, Traefik CRDs, `ServiceMonitor`, and `PrometheusRule` resources. You describe the workload once in `values.yaml`; the chart expands that into production-ready manifests with sane defaults, `tpl` support, and a clean extension model.

This project does **not** build or combine Docker base images. Your application keeps its own image; `helm-serve` provides the reusable Kubernetes deployment layer around that image. In practice, it collects the common operational pieces that every service needs into one library: workload definition, service discovery, ingress, TLS, health probes, environment/configuration injection, resource defaults, and metrics wiring.

The result is a small application chart with a consistent runtime contract. Each application supplies its image and feature values, while the shared library renders the Kubernetes resources. A fix in this library can therefore benefit every consuming service without copying template folders between repositories.

One chart dependency replaces the copy-pasted template folder every microservice repo drags around — and every fix or feature lands once, in the library, for all consumers.

---

## Why teams use it

- **One library, two workload modes**: run long-lived web/API services and scheduled jobs with the same abstraction.
- **Low YAML surface area**: keep application charts small while still producing full Kubernetes resources.
- **Built for day-2 operations**: probes, resources, metadata injection, metrics wiring, and ingress are already modeled.
- **Consumer-owned naming**: keep your own helper conventions through `templatePrefix` instead of adopting someone else's naming scheme.
- **Fail-fast by design**: missing required values (`image`, `schedule`, `ingress.rule.host`, ...) abort the render with a clear message instead of shipping broken manifests to the cluster.

---

## What's New in v0.2.3-beta2

`v0.2.2` introduced the observability layer. `v0.2.3-beta2` builds on top of that and closes a real production gap: **Ingress TLS is now a first-class capability instead of a hand-written add-on.**

| Area | v0.2.2 | v0.2.3-beta2 |
|---|---|---|
| Observability | Metrics Service, `ServiceMonitor`, `PrometheusRule` | Preserved as-is |
| Ingress TLS | Not modeled by the library | Built in with 3 TLS modes |
| Multi-domain HTTPS | Manual/custom templating needed | Supported via `ingress.tls.hosts` |
| SNI / multiple certs | Manual/custom templating needed | Supported via `ingress.tls.secrets[]` |
| `tpl` in TLS fields | N/A | Supported for hosts and `secretName` |

### New ingress TLS modes

1. **Auto mode**
   Enable TLS and provide one secret. The chart uses `ingress.rule.host` automatically.
2. **Multi-host, single-secret mode**
   Perfect for SAN certificates covering multiple domains.
3. **Power-user multi-secret mode**
   Provide `ingress.tls.secrets[]` for true SNI setups where different hosts terminate with different secrets.

This is the practical difference between `0.2.2` and the current prerelease: you no longer need to fork the ingress template just to express real HTTPS topologies.

### Traefik CRD mode (available on `master`, unreleased)

The `master` branch can already render **Traefik CRDs** (`Middleware` + `IngressRoute`, `traefik.io/v1alpha1`, Traefik v3) instead of a standard `Ingress`, selected by nothing more than `ingress.className: traefik`. This capability is currently documented and testable from source, but is not included in the `0.2.3-beta2` release yet. Teams on nginx keep the standard Ingress. See [Traefik CRD mode](#traefik-crd-mode) below.

---

## Feature Set

- **Deployment and CronJob modes** from the same library chart.
- **Ingress, Service, and metrics resources** rendered only when enabled.
- **Ingress TLS support** for single-host, multi-host, and multi-secret/SNI setups.
- **Traefik CRD mode** *(unreleased; available on `master`)* — `Middleware` + `IngressRoute` (`traefik.io/v1alpha1`), selected by `ingress.className: traefik` as an alternative to the standard Ingress.
- **Prometheus-ready observability** with metrics `Service`, optional `ServiceMonitor`, and optional `PrometheusRule`.
- **Probe support everywhere** with `startupProbe`, `livenessProbe`, and `readinessProbe` on both Deployments and CronJobs.
- **`tpl`-aware values** across env vars, metrics configuration, relabelings, ingress hosts, and TLS secret names.
- **Production-oriented defaults** like resource requests/limits, `revisionHistoryLimit: 0`, graceful termination, and metadata injection.
- **Consumer-side naming control** through `templatePrefix`.

## Installation

`helm-serve` is a **library chart**. You consume it from an application chart; you do not install it directly as a standalone release.

Add it to your application's `Chart.yaml`:

```yaml
dependencies:
  - name: helm-serve
    repository: oci://ghcr.io/btungut
    version: 0.2.3-beta2
```

Then update dependencies:

```bash
helm dependency update
```

If you want a clean rebuild of vendored dependencies:

```bash
rm -rf charts/ && helm dependency update .
```

**Requirements:** Helm 3.x. The `ServiceMonitor`/`PrometheusRule` resources additionally require the Prometheus Operator (e.g. `kube-prometheus-stack`); Traefik CRD mode requires Traefik v3 with the Kubernetes CRD provider enabled.

## Quick Start

### Deployment mode

```yaml
deployment:
  replicaCount: 2
  image:
    repository: myrepo/my-app
    tag: v1.0.0
  containerPort: 8080

service:
  enabled: true
  port: 80

ingress:
  enabled: true
  className: nginx
  rule:
    host: api.mydomain.com
    path: /
```

This renders a `Deployment`, a `Service`, and an `Ingress` with the service backend already wired.

### CronJob mode

```yaml
cronJob:
  schedule: "0 2 * * *"
  image:
    repository: myrepo/my-batch-job
    tag: v1.0.0
  env:
    JOB_TYPE: data-processing
```

This renders a `CronJob` with the same resource, probe, env, config, and secret primitives available in Deployment mode.

### Observability in one block

```yaml
deployment:
  containerPort: 8080
  image:
    repository: myrepo/my-app
    tag: v1.0.0

service:
  enabled: true
  port: 80

metrics:
  enabled: true
  metricsPort: 9090
  path: /metrics
  serviceMonitor:
    enabled: true
  prometheusRule:
    rules:
      - alert: HighErrorRate
        expr: 'sum(rate(http_requests_total{status=~"5.."}[5m])) > 0.05'
        for: 10m
```

When enabled, the chart exposes an extra `metrics` container port on the pod, adds a dedicated `<fullname>-metrics` Service, and can emit `ServiceMonitor` and `PrometheusRule` resources for Prometheus Operator based stacks.

### Ingress TLS in three shapes

```yaml
ingress:
  enabled: true
  className: nginx
  rule:
    host: api.mydomain.com
    path: /
  tls:
    enabled: true
    hosts:
      - api.mydomain.com
      - www.mydomain.com
    secretName: my-app-tls
```

For SNI-style setups, switch from `hosts` to `secrets[]` and assign different certificates per host set. Using cert-manager? Just add `cert-manager.io/cluster-issuer` under `ingress.annotations` and it provisions the secret named in `tls.secretName` for you.

### Traefik CRD mode

If your cluster ingress is Traefik, set `ingress.className: traefik` and the library renders Traefik CRDs (`Middleware` and `IngressRoute`, `traefik.io/v1alpha1`) instead of a standard `Ingress`.

```yaml
ingress:
  enabled: true
  className: traefik

traefik:
  middlewares:
    # Rendered as: middleware-<release fullname>-secure-headers
    - name: secure-headers
      spec:
        headers:
          sslRedirect: true
          forceSTSHeader: true
          stsSeconds: 31536000

  ingressRoutes:
    # Rendered as: ingressroute-<release fullname>-web
    - name: web
      entryPoints: [web, websecure]   # optional, this is the default
      routes:
        - match: "Host(`{{ .Values.shared.host }}`)"
          middlewares:
            - secure-headers          # short name → expanded to the rendered full name
          # services omitted → routes to this chart's own Service
```

- `middlewares[].spec` is pass-through with `tpl` support, so any Traefik middleware type (`headers`, `stripPrefix`, `rateLimit`, `forwardAuth`, ...) works.
- Route middleware references accept either a short name (validated against `traefik.middlewares[]` and expanded to the rendered full name) or a `{name, namespace}` map passed through as-is for external or cross-namespace middlewares.
- `entryPoints` takes entry point **names** only; addresses (`:80`/`:443`) belong to the Traefik proxy's own configuration, not to the `IngressRoute`.
- Setting `className: traefik` without defining `traefik.ingressRoutes` fails the render with an explicit error.
- `ingress.enabled: false` disables everything; the class name is irrelevant in that case.

## Architecture and naming

`helm-serve` intentionally keeps naming responsibility in the consumer chart. The library never hardcodes a resource name — it calls helper templates from *your* chart through a configurable prefix:

```yaml
templatePrefix: my-app   # default: "{{ .Chart.Name }}" (tpl is applied)
```

Given the prefix, the library invokes these helpers, which must exist in the consumer chart:

| Helper | Used for |
|---|---|
| `<prefix>.fullname` | Resource names (Deployment, CronJob, Service, Ingress, metrics resources, Traefik CRDs) |
| `<prefix>.labels` | Common `metadata.labels` on every resource |
| `<prefix>.selectorLabels` | Label selectors wiring Deployment ↔ Service ↔ metrics resources |

These are exactly the helpers `helm create` scaffolds into `_helpers.tpl`, so a freshly created chart satisfies the contract out of the box. Every resource also accepts an explicit `name` override (`deployment.name`, `cronJob.name`, `service.name`, `ingress.name`) — all `tpl`-aware.

That allows the library to stay reusable without forcing a naming opinion across teams.

## Example values files

The [test/](test/) directory is effectively a cookbook. Read the files in order if you want to understand the surface area quickly. Each file is self-documenting with inline comments, and every file is guarded by a golden-file regression test in [`test/golden/`](test/golden/) — what you see is exactly what the chart renders.

| File | Focus | What it demonstrates |
|---|---|---|
| [`values-basic.yaml`](test/values-basic.yaml) | Minimal service | Deployment + Service + Ingress |
| [`values-middle.yaml`](test/values-middle.yaml) | Day-2 baseline | Shared values, ConfigMaps, Secrets, NodePort, env vars, metrics Service |
| [`values-full.yaml`](test/values-full.yaml) | Full surface | Labels, annotations, probes, `templatePrefix`, `tpl`, ingress TLS, full metrics stack |
| [`values-metrics.yaml`](test/values-metrics.yaml) | Observability | Dedicated walkthrough of the `metrics:` block |
| [`values-ingress-tls.yaml`](test/values-ingress-tls.yaml) | HTTPS patterns | All supported ingress TLS modes, including cert-manager-friendly examples |
| [`values-traefik.yaml`](test/values-traefik.yaml) | Traefik CRD mode | `Middleware` + `IngressRoute` rendering, short-name middleware wiring, default vs explicit backends |
| [`values-cronjob.yaml`](test/values-cronjob.yaml) | Scheduled workloads | CronJob mode with execution policy and probe examples |

## Workload mode detection

The library selects its primary workload resource from the top-level values you provide:

- `deployment` present: renders a `Deployment`
- `cronJob` present: renders a `CronJob`

Secondary resources such as `Service`, `Ingress`, and observability objects are rendered independently based on their own `enabled` flags. Pick one workload mode per release; defining both keys renders both resources.

## Configuration Reference

### Global and shared

| Parameter | Description | Default |
|---|---|---|
| `templatePrefix` | Prefix used to invoke naming templates from the consumer chart. Supports `tpl`. | `{{ .Chart.Name }}` |
| `shared` | Shared variables that can be consumed from `tpl` expressions elsewhere. | `{}` |

### Deployment

| Parameter | Description | Default |
|---|---|---|
| `deployment.name` | Override the Deployment name. Supports `tpl`. | `<prefix>.fullname` |
| `deployment.replicaCount` | Number of desired pods. | `1` |
| `deployment.revisionHistoryLimit` | Old ReplicaSets to retain. | `0` (GitOps-friendly) |
| `deployment.terminationGracePeriodSeconds` | Graceful termination period. | `10` |
| `deployment.image.repository` | Container image repository. | **Required** |
| `deployment.image.tag` | Container image tag. | **Required** |
| `deployment.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `deployment.imagePullSecrets` | Image pull secrets. Supports `tpl`. | `[]` |
| `deployment.containerPort` | Main application container port, exposed as port name `app`. Number or `tpl` string; render fails if present but empty. | — |
| `deployment.env` | Environment variables (map). Values support `tpl`. | `{}` |
| `deployment.configMaps` | ConfigMaps injected via `envFrom`: `{ name, required }`. `name` supports `tpl`; `required: false` marks the reference optional. | `[]` |
| `deployment.secrets` | Secrets injected via `envFrom`: `{ name, required }`. Same semantics as `configMaps`. | `[]` |
| `deployment.resources` | CPU/memory requests and limits. User values win; missing keys fall back to the defaults. | `cpu: 200m`, `memory: 256Mi` (requests = limits) |
| `deployment.startupProbe` | Startup probe definition. Supports `tpl`. | `{}` |
| `deployment.livenessProbe` | Liveness probe definition. Supports `tpl`. | `{}` |
| `deployment.readinessProbe` | Readiness probe definition. Supports `tpl`. | `{}` |
| `deployment.labels` | Extra Deployment labels. Supports `tpl`. | `{}` |
| `deployment.podAnnotations` | Extra Pod annotations. Supports `tpl`. | `{}` |

### Service

| Parameter | Description | Default |
|---|---|---|
| `service.enabled` | Enable Service creation. | `false` |
| `service.name` | Override the Service name. Supports `tpl`. | `<prefix>.fullname` |
| `service.type` | `ClusterIP`, `NodePort`, or `LoadBalancer`. | `ClusterIP` |
| `service.port` | Service port (single port named `app`, targeting the pod's `app` container port). | **Required if enabled** |
| `service.nodePort` | Fixed NodePort value (only rendered when `type: NodePort`). | `nil` |
| `service.labels` | Extra Service labels. Supports `tpl`. | `{}` |

### Ingress

Standard Ingress mode (`networking.k8s.io/v1`). One rule is rendered; the backend is always this chart's own Service, port name `app` — no manual wiring needed.

| Parameter | Description | Default |
|---|---|---|
| `ingress.enabled` | Enable Ingress creation. | `false` |
| `ingress.className` | Ingress class name. Set to `traefik` (case-insensitive) to switch into Traefik CRD mode. | **Required if enabled** |
| `ingress.name` | Override the Ingress name. Supports `tpl`. | `<prefix>.fullname` |
| `ingress.labels` | Extra Ingress labels. Supports `tpl`. | `{}` |
| `ingress.annotations` | Ingress annotations (e.g. nginx rewrite rules, cert-manager issuer). | `{}` |
| `ingress.rule.host` | Primary host. Supports `tpl`. | **Required if enabled** |
| `ingress.rule.path` | Request path. Supports `tpl`. | **Required if enabled** |
| `ingress.rule.pathType` | `Prefix`, `Exact`, or `ImplementationSpecific`. | `Prefix` |
| `ingress.tls.enabled` | Enable TLS block rendering. | `false` |
| `ingress.tls.secretName` | Secret name for auto or multi-host single-secret mode. Supports `tpl`. | **Required when TLS is enabled and `secrets[]` is not used** |
| `ingress.tls.hosts` | Explicit host list for single-secret mode. Supports `tpl`. | Defaults to `[ingress.rule.host]` |
| `ingress.tls.secrets` | List of `{ hosts, secretName }` pairs for multi-secret/SNI mode. Both fields support `tpl` and are required per item. | `[]` |

### Traefik CRD mode

Active when `ingress.enabled: true` and `ingress.className: traefik`. The standard `Ingress` fields (`rule`, `tls`, `annotations`) are ignored in this mode.

| Parameter | Description | Default |
|---|---|---|
| `traefik.middlewares` | List of `{ name, spec }` Middleware CRDs. Rendered as `middleware-<fullname>-<name>`. `name` and `spec` are required per item; `spec` is pass-through with `tpl`. | `[]` |
| `traefik.middlewares[].labels` | Extra Middleware labels. Supports `tpl`. | `{}` |
| `traefik.ingressRoutes` | List of IngressRoute CRDs. Rendered as `ingressroute-<fullname>-<name>`. At least one route per IngressRoute is enforced. | `[]` |
| `traefik.ingressRoutes[].entryPoints` | Entry point names (no addresses). Supports `tpl`. | `[web, websecure]` |
| `traefik.ingressRoutes[].labels` | Extra IngressRoute labels. Supports `tpl`. | `{}` |
| `traefik.ingressRoutes[].annotations` | Extra IngressRoute annotations. Supports `tpl`. | `{}` |
| `traefik.ingressRoutes[].routes[].match` | Traefik router rule. Supports `tpl`. | **Required** |
| `traefik.ingressRoutes[].routes[].kind` | Router kind. | `Rule` |
| `traefik.ingressRoutes[].routes[].priority` | Router priority. | `nil` |
| `traefik.ingressRoutes[].routes[].middlewares` | Short names of `traefik.middlewares[]` entries (validated, then expanded to rendered names) or `{ name, namespace }` maps passed through as-is. | `[]` |
| `traefik.ingressRoutes[].routes[].services` | Backend services, pass-through with `tpl`. | The chart's own Service on `service.port` |

Resource names are computed as `<prefix>-<fullname>-<name>` with smart 63-character truncation: the `fullname` segment is truncated first so the item `name` always survives and distinct items never collide on one resource name.

### Metrics and observability

The metrics stack is wired into the workload rendered by `library.deployment` (Deployment mode): it adds a `metrics` container port to the pod and renders the resources below.

| Parameter | Description | Default |
|---|---|---|
| `metrics.enabled` | Master switch for the metrics stack. | `false` |
| `metrics.metricsPort` | Container port exposing metrics (port name `metrics`). Number or `tpl` string. | **Required if enabled** |
| `metrics.path` | Path served by the metrics endpoint; forwarded to the ServiceMonitor. Supports `tpl`. | `nil` |
| `metrics.labels` | Extra labels merged onto the metrics Service, ServiceMonitor, and PrometheusRule (use them to match your Prometheus instance's selectors). | `{}` |
| `metrics.serviceMonitor.enabled` | Render a `ServiceMonitor` (selects the metrics Service; `namespaceSelector` pinned to the release namespace). | `false` |
| `metrics.serviceMonitor.interval` | Scrape interval. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout. | `10s` |
| `metrics.serviceMonitor.scheme` | `http` or `https`. | `http` |
| `metrics.serviceMonitor.honorLabels` | Honor target-provided labels. | `nil` |
| `metrics.serviceMonitor.relabelings` | Prometheus relabel rules, with `tpl` support. | `nil` |
| `metrics.serviceMonitor.metricRelabelings` | Metric relabel rules, with `tpl` support. | `nil` |
| `metrics.prometheusRule.rules` | Alerting/recording rules, with `tpl` support. Rendered as a `PrometheusRule` alongside the ServiceMonitor whenever `serviceMonitor.enabled` is true (an empty list renders an empty rule group). | `[]` |

The metrics Service is always named `<fullname>-metrics`, type `ClusterIP`, with a fixed service port `9211` (`http-metrics`) targeting the pod's `metrics` container port.

### CronJob

| Parameter | Description | Default |
|---|---|---|
| `cronJob.name` | Override the CronJob name. Supports `tpl`. | `<prefix>.fullname` |
| `cronJob.schedule` | Cron expression. | **Required** |
| `cronJob.concurrencyPolicy` | `Allow`, `Forbid`, or `Replace`. | `nil` |
| `cronJob.successfulJobsHistoryLimit` | Successful job history retention. | `nil` |
| `cronJob.failedJobsHistoryLimit` | Failed job history retention. | `nil` |
| `cronJob.suspend` | Suspend execution. | `nil` |
| `cronJob.startingDeadlineSeconds` | Deadline for missed schedules. | `nil` |
| `cronJob.backoffLimit` | Retry count before failure. | `nil` |
| `cronJob.activeDeadlineSeconds` | Job timeout. | `nil` |
| `cronJob.ttlSecondsAfterFinished` | Post-completion cleanup TTL. | `nil` |
| `cronJob.restartPolicy` | `OnFailure` or `Never`. | `OnFailure` |
| `cronJob.image.repository` | Container image repository. | **Required** |
| `cronJob.image.tag` | Container image tag. | **Required** |
| `cronJob.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `cronJob.imagePullSecrets` | Image pull secrets. Supports `tpl`. | `[]` |
| `cronJob.env` | Environment variables (map). Values support `tpl`. | `{}` |
| `cronJob.configMaps` | ConfigMaps injected via `envFrom`: `{ name, required }`. | `[]` |
| `cronJob.secrets` | Secrets injected via `envFrom`: `{ name, required }`. | `[]` |
| `cronJob.resources` | CPU/memory requests and limits. User values win; missing keys fall back to the defaults. | `cpu: 200m`, `memory: 256Mi` (requests = limits) |
| `cronJob.startupProbe` | Startup probe definition. Supports `tpl`. | `{}` |
| `cronJob.livenessProbe` | Liveness probe definition. Supports `tpl`. | `{}` |
| `cronJob.readinessProbe` | Readiness probe definition. Supports `tpl`. | `{}` |
| `cronJob.labels` | Extra CronJob labels. Supports `tpl`. | `{}` |
| `cronJob.podAnnotations` | Extra Pod annotations. Supports `tpl`. | `{}` |

## Advanced Usage

### Dynamic value injection with `tpl`

```yaml
shared:
  primaryHost: api.mydomain.com
  metricsPort: "9090"

deployment:
  containerPort: 8080
  env:
    APP_INSTANCE: "{{ .Release.Name }}"

ingress:
  rule:
    host: "{{ .Values.shared.primaryHost }}"
  tls:
    enabled: true
    secretName: "{{ .Release.Name }}-tls"

metrics:
  enabled: true
  metricsPort: "{{ .Values.shared.metricsPort }}"
```

This keeps repeated values centralized while still letting the library render concrete manifests. `tpl` sees the full Helm context (`.Values`, `.Release`, `.Chart`), so `shared` is a convention, not a requirement.

### Auto-injected metadata

Every workload pod receives metadata environment variables that are useful for logs, traces, and self-identification:

| Variable | Source |
|---|---|
| `HELM_Version` | `.Chart.Version` |
| `HELM_AppVersion` | `.Chart.AppVersion` |
| `HELM_Description` | `.Chart.Description` |
| `HELM_Namespace` | `.Release.Namespace` |
| `K8S_Namespace` | Downward API (`metadata.namespace`) |

Your own `env` entries are appended after these, with `tpl` applied to each value.

### Probes on CronJobs

`helm-serve` exposes `startupProbe`, `livenessProbe`, and `readinessProbe` for CronJob pods as well as Deployments. That is useful for long-running jobs, sidecar-style workers, and scheduled tasks that still need health semantics.

## Upgrading from v0.2.2

If you already use `helm-serve` v0.2.2, the upgrade is **backward compatible**. However, you can now **remove custom ingress template overrides** and use the built-in TLS support:

### Before (v0.2.2 workaround)

```yaml
# Custom ingress template needed for HTTPS
ingress:
  enabled: true
  className: nginx
  rule:
    host: api.mydomain.com
# ...then you'd fork templates to add TLS block manually
```

### After (v0.2.3-beta2)

```yaml
# Built-in TLS support — no template fork needed
ingress:
  enabled: true
  className: nginx
  rule:
    host: api.mydomain.com
  tls:
    enabled: true
    secretName: my-tls-secret
```

**Use cases now natively supported:**

- **Single domain + TLS**: Set `ingress.tls.secretName`; the chart auto-uses `ingress.rule.host`.
- **Multiple domains + one cert (SAN)**: Use `ingress.tls.hosts: [api.example.com, www.example.com]` with `secretName`.
- **SNI / per-domain certs**: Use `ingress.tls.secrets[]` for advanced setups.

No migration code needed — old values still work, and you can gradually adopt the new TLS parameters.

## Roadmap / TODO

- **Traefik HTTP TLS** — `spec.tls` (`secretName`, `certResolver`, `options`) on IngressRoute.
- **Traefik TCP routing** — `IngressRouteTCP` support including TLS passthrough (deliberately postponed).

## License

This project is licensed under the [Apache License 2.0](LICENSE.md).

---

**Made with ❤️ by Burak Tungut**  
[GitHub](https://github.com/btungut) | [Email](mailto:buraktungut@gmail.com)
