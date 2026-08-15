# helm-serve

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/btungut)](https://artifacthub.io/packages/helm/btungut/helm-serve)
[![Release](https://img.shields.io/github/v/release/btungut/helm-serve?include_prereleases&style=plastic)](https://github.com/btungut/helm-serve/releases)
[![LICENSE](https://img.shields.io/github/license/btungut/helm-serve?style=plastic)](https://github.com/btungut/helm-serve/blob/master/LICENSE)

**A Helm library chart for shipping stateless services, scheduled jobs, observability, and ingress TLS without repeating Kubernetes boilerplate.**

`helm-serve` is a DRY Helm library chart that standardizes how teams render `Deployment`, `CronJob`, `Service`, `Ingress`, `ServiceMonitor`, and `PrometheusRule` resources. You describe the workload once in `values.yaml`; the chart expands that into production-ready manifests with sane defaults, `tpl` support, and a clean extension model.

---

## Why teams use it

- **One library, two workload modes**: run long-lived web/API services and scheduled jobs with the same abstraction.
- **Low YAML surface area**: keep application charts small while still producing full Kubernetes resources.
- **Built for day-2 operations**: probes, resources, metadata injection, metrics wiring, and ingress are already modeled.
- **Consumer-owned naming**: keep your own helper conventions through `templatePrefix` instead of adopting someone else's naming scheme.

---

## What's New in v0.2.3-beta1

`v0.2.2` introduced the observability layer. `v0.2.3-beta1` builds on top of that and closes a real production gap: **Ingress TLS is now a first-class capability instead of a hand-written add-on.**

| Area | v0.2.2 | v0.2.3-beta1 |
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

---

## Feature Set

- **Deployment and CronJob modes** from the same library chart.
- **Ingress, Service, and metrics resources** rendered only when enabled.
- **Ingress TLS support** for single-host, multi-host, and multi-secret/SNI setups.
- **Traefik CRD mode** (`Middleware` + `IngressRoute`, `traefik.io/v1alpha1`) selected by `ingress.className: traefik`, as an alternative to the standard Ingress.
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
    version: 0.2.3-beta1
```

Then update dependencies:

```bash
helm dependency update
```

If you want a clean rebuild of vendored dependencies:

```bash
rm -rf charts/ && helm dependency update .
```

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

When enabled, the chart adds a dedicated metrics Service and can optionally emit `ServiceMonitor` and `PrometheusRule` resources for Prometheus Operator based stacks.

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

For SNI-style setups, switch from `hosts` to `secrets[]` and assign different certificates per host set.

### Traefik CRD mode

If your cluster ingress is Traefik, set `ingress.className: traefik` and the library renders Traefik CRDs (`Middleware` and `IngressRoute`, `traefik.io/v1alpha1`) instead of a standard `Ingress`. Teams on nginx keep the short standard Ingress — nothing changes for them.

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
- Route middleware references accept either a short name (expanded to `middleware-<fullname>-<name>`) or a `{name, namespace}` map passed through as-is for external or cross-namespace middlewares.
- `entryPoints` takes entry point **names** only; addresses (`:80`/`:443`) belong to the Traefik proxy's own configuration, not to the `IngressRoute`.
- `ingress.enabled: false` disables everything; the class name is irrelevant in that case.

## Architecture and naming

`helm-serve` intentionally keeps naming responsibility in the consumer chart.

If your chart exposes helpers such as `my-app.fullname`, pass the prefix below and the library will call your templates instead of hardcoding names:

```yaml
templatePrefix: my-app
```

That allows the library to stay reusable without forcing a naming opinion across teams.

## Example values files

The [test/](test/) directory is effectively a cookbook. Read the files in order if you want to understand the surface area quickly.

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

Secondary resources such as `Service`, `Ingress`, and observability objects are rendered independently based on their own `enabled` flags.

## Configuration Reference

### Global and shared

| Parameter | Description | Default |
|---|---|---|
| `templatePrefix` | Prefix used to invoke naming templates from the consumer chart. | `{{ .Chart.Name }}` |
| `shared` | Shared variables that can be consumed from `tpl` expressions elsewhere. | `{}` |

### Deployment

| Parameter | Description | Default |
|---|---|---|
| `deployment.replicaCount` | Number of desired pods. | `1` |
| `deployment.revisionHistoryLimit` | Old ReplicaSets to retain. | `0` |
| `deployment.terminationGracePeriodSeconds` | Graceful termination period. | `10` |
| `deployment.image.repository` | Container image repository. | `""` |
| `deployment.image.tag` | Container image tag. | `""` |
| `deployment.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `deployment.imagePullSecrets` | Image pull secrets. | `[]` |
| `deployment.containerPort` | Main application container port. | Required |
| `deployment.env` | Environment variables, with `tpl` support. | `{}` |
| `deployment.configMaps` | ConfigMaps to inject. | `[]` |
| `deployment.secrets` | Secrets to inject. | `[]` |
| `deployment.resources` | CPU and memory requests/limits. | `cpu: 200m / memory: 256Mi` |
| `deployment.startupProbe` | Startup probe definition. | `{}` |
| `deployment.livenessProbe` | Liveness probe definition. | `{}` |
| `deployment.readinessProbe` | Readiness probe definition. | `{}` |
| `deployment.labels` | Extra Deployment labels. | `{}` |
| `deployment.podAnnotations` | Extra Pod annotations. | `{}` |

### Service

| Parameter | Description | Default |
|---|---|---|
| `service.enabled` | Enable Service creation. | `false` |
| `service.name` | Override the default service name. | `""` |
| `service.type` | `ClusterIP`, `NodePort`, or `LoadBalancer`. | `ClusterIP` |
| `service.port` | Service port. | Required if enabled |
| `service.nodePort` | Fixed NodePort value. | `nil` |
| `service.labels` | Extra Service labels. | `{}` |

### Ingress

| Parameter | Description | Default |
|---|---|---|
| `ingress.enabled` | Enable Ingress creation. | `false` |
| `ingress.className` | Ingress class name. Set to `traefik` to switch into Traefik CRD mode (see below). | Required if enabled |
| `ingress.annotations` | Ingress annotations. | `{}` |
| `ingress.rule.host` | Primary host. | Required if enabled |
| `ingress.rule.path` | Request path. | Required if enabled |
| `ingress.rule.pathType` | `Prefix`, `Exact`, or `ImplementationSpecific`. | `Prefix` |
| `ingress.tls.enabled` | Enable TLS block rendering. | `false` |
| `ingress.tls.secretName` | Secret name for auto or multi-host single-secret mode. Supports `tpl`. | Required when TLS is enabled and `secrets[]` is not used |
| `ingress.tls.hosts` | Explicit host list for single-secret mode. Supports `tpl`. | Defaults to `[ingress.rule.host]` |
| `ingress.tls.secrets` | List of `{ hosts, secretName }` pairs for multi-secret/SNI mode. Supports `tpl`. | `[]` |

### Traefik CRD mode

Active when `ingress.enabled: true` and `ingress.className: traefik`. The standard `Ingress` fields (`rule`, `tls`, `annotations`) are ignored in this mode.

| Parameter | Description | Default |
|---|---|---|
| `traefik.middlewares` | List of `{ name, spec }` Middleware CRDs. Rendered as `middleware-<fullname>-<name>`. `spec` is pass-through with `tpl`. | `[]` |
| `traefik.middlewares[].labels` | Extra Middleware labels. | `{}` |
| `traefik.ingressRoutes` | List of IngressRoute CRDs. Rendered as `ingressroute-<fullname>-<name>`. | `[]` |
| `traefik.ingressRoutes[].entryPoints` | Entry point names (no addresses). | `[web, websecure]` |
| `traefik.ingressRoutes[].labels` | Extra IngressRoute labels. | `{}` |
| `traefik.ingressRoutes[].annotations` | Extra IngressRoute annotations. Supports `tpl`. | `{}` |
| `traefik.ingressRoutes[].routes[].match` | Traefik router rule. Supports `tpl`. | Required |
| `traefik.ingressRoutes[].routes[].kind` | Router kind. | `Rule` |
| `traefik.ingressRoutes[].routes[].priority` | Router priority. | `nil` |
| `traefik.ingressRoutes[].routes[].middlewares` | Short names of `traefik.middlewares[]` entries (expanded to rendered names) or `{ name, namespace }` maps passed through as-is. | `[]` |
| `traefik.ingressRoutes[].routes[].services` | Backend services, pass-through with `tpl`. | The chart's own Service |

### Metrics and observability

| Parameter | Description | Default |
|---|---|---|
| `metrics.enabled` | Master switch for the metrics stack. | `false` |
| `metrics.metricsPort` | Container port exposing `/metrics`. Supports `tpl`. | Required if enabled |
| `metrics.path` | Path served by the metrics endpoint. | `nil` |
| `metrics.labels` | Extra labels for metrics resources. | `{}` |
| `metrics.serviceMonitor.enabled` | Render a `ServiceMonitor`. | `false` |
| `metrics.serviceMonitor.interval` | Scrape interval. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout. | `10s` |
| `metrics.serviceMonitor.scheme` | `http` or `https`. | `http` |
| `metrics.serviceMonitor.honorLabels` | Honor target-provided labels. | `nil` |
| `metrics.serviceMonitor.relabelings` | Prometheus relabel rules, with `tpl` support. | `nil` |
| `metrics.serviceMonitor.metricRelabelings` | Metric relabel rules, with `tpl` support. | `nil` |
| `metrics.prometheusRule.rules` | Alerting or recording rules. | `[]` |

### CronJob

| Parameter | Description | Default |
|---|---|---|
| `cronJob.schedule` | Cron expression. | Required |
| `cronJob.concurrencyPolicy` | `Allow`, `Forbid`, or `Replace`. | `nil` |
| `cronJob.successfulJobsHistoryLimit` | Successful job history retention. | `nil` |
| `cronJob.failedJobsHistoryLimit` | Failed job history retention. | `nil` |
| `cronJob.suspend` | Suspend execution. | `nil` |
| `cronJob.startingDeadlineSeconds` | Deadline for missed schedules. | `nil` |
| `cronJob.backoffLimit` | Retry count before failure. | `nil` |
| `cronJob.activeDeadlineSeconds` | Job timeout. | `nil` |
| `cronJob.ttlSecondsAfterFinished` | Post-completion cleanup TTL. | `nil` |
| `cronJob.restartPolicy` | `OnFailure` or `Never`. | `OnFailure` |
| `cronJob.image.repository` | Container image repository. | `""` |
| `cronJob.image.tag` | Container image tag. | `""` |
| `cronJob.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `cronJob.imagePullSecrets` | Image pull secrets. | `[]` |
| `cronJob.env` | Environment variables, with `tpl` support. | `{}` |
| `cronJob.configMaps` | ConfigMaps to inject. | `[]` |
| `cronJob.secrets` | Secrets to inject. | `[]` |
| `cronJob.resources` | CPU and memory requests/limits. | `cpu: 200m / memory: 256Mi` |
| `cronJob.startupProbe` | Startup probe definition. | `{}` |
| `cronJob.livenessProbe` | Liveness probe definition. | `{}` |
| `cronJob.readinessProbe` | Readiness probe definition. | `{}` |
| `cronJob.labels` | Extra CronJob labels. | `{}` |
| `cronJob.podAnnotations` | Extra Pod annotations. | `{}` |

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

This keeps repeated values centralized while still letting the library render concrete manifests.

### Auto-injected metadata

Every workload receives metadata environment variables that are useful for logs, traces, and self-identification:

| Variable | Source |
|---|---|
| `HELM_Version` | `.Chart.Version` |
| `HELM_AppVersion` | `.Chart.AppVersion` |
| `HELM_Description` | `.Chart.Description` |
| `HELM_Namespace` | `.Release.Namespace` |
| `K8S_Namespace` | Downward API (`metadata.namespace`) |

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

### After (v0.2.3-beta1)

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
