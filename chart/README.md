# helm-serve

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/btungut)](https://artifacthub.io/packages/helm/btungut/helm-serve)
[![Release](https://img.shields.io/github/v/release/btungut/helm-serve?include_prereleases&style=plastic)](https://github.com/btungut/helm-serve/releases)
[![LICENSE](https://img.shields.io/github/license/btungut/helm-serve?style=plastic)](https://github.com/btungut/helm-serve/blob/master/LICENSE)

**Bootstrap stateless Web & API workloads, scheduled jobs, and a full Prometheus observability stack — in seconds.**

`helm-serve` is a DRY (Don't Repeat Yourself) **Helm Library Chart** that acts as a standardized foundation for microservices and scheduled tasks. It abstracts away the boilerplate of writing `Deployment`, `Service`, `Ingress`, `CronJob`, `ServiceMonitor`, and `PrometheusRule` manifests by hand, letting you describe a workload in 10 lines of YAML instead of 200.

---

## ✨ What's New in v0.2.2

> 🔭 **First-class Prometheus observability — out of the box.**
>
> A single switch (`metrics.enabled: true`) now wires your workload into a full Prometheus stack:
>
> | Resource | Created when… | Purpose |
> |---|---|---|
> | `metrics` containerPort on the Pod | `metrics.enabled: true` | exposes `/metrics` to the cluster |
> | **Service** `<release>-metrics` (port 9211) | `metrics.enabled: true` | dedicated scrape target, isolated from app traffic |
> | **ServiceMonitor** | `metrics.serviceMonitor.enabled: true` | Prometheus Operator picks the workload up automatically |
> | **PrometheusRule** | `metrics.prometheusRule.rules` is non-empty | alerting & recording rules deployed alongside the app |
>
> No new templates to write. No copy-pasting alert YAML between services. Flip one flag and your workload becomes observable, alertable, and SRE-ready.
>
> 👉 See it end-to-end in [test/values-metrics.yaml](test/values-metrics.yaml).

---

## 🚀 Features

* **Zero Boilerplate** — Define your app with a few lines of YAML; the library writes the manifests.
* **Multi-Mode Workloads** — Switch between **Deployment** and **CronJob** by toggling a single key.
* **Built-in Observability (NEW)** — Auto-render `Service`, `ServiceMonitor`, and `PrometheusRule` from a single `metrics:` block.
* **Probes Everywhere** — `startupProbe`, `livenessProbe`, and `readinessProbe` on both Deployments **and** CronJobs.
* **Inversion of Control** — Plug in your own naming conventions via the `templatePrefix` hook.
* **Dynamic Values** — Native Go template (`tpl`) support inside `values.yaml`, including environment variables and relabel rules.
* **Production Defaults** — Resource requests/limits, GitOps-friendly `revisionHistoryLimit: 0`, graceful termination, and metadata injection — all preconfigured.
* **Standardized Networking** — Auto-wired Ingress, Service, and metrics Service.

## 📦 Installation

`helm-serve` is a **Library Chart** — it is *not* installed directly. Add it as a dependency to your application chart.

1. Add it to your application's `Chart.yaml`:

```yaml
dependencies:
  - name: helm-serve
    repository: oci://ghcr.io/btungut
    version: 0.2.2 # <-- check for the latest release
```

2. Update dependencies:

```bash
helm dependency update
```

2.a. Clean your `charts/` directory if needed:

```bash
rm -rf charts/ && helm dependency update .
```

## ⚡ Quick Start

### Deployment Mode (API/Web Applications)

In your application chart's `values.yaml`, define the essentials. The library handles the rest.

```yaml
# values.yaml — minimal Deployment mode

deployment:
  replicaCount: 2
  image:
    repository: myrepo/my-app
    tag: v1.0.0
  containerPort: 80

service:
  enabled: true
  port: 80

ingress:
  enabled: true
  className: "nginx"
  rule:
    host: "api.mydomain.com"
    path: /
```

`helm template .` will generate:

* A **Deployment** with 2 replicas and resource limits.
* A **Service** pointing to the pods.
* An **Ingress** routing traffic to that service.

### CronJob Mode (Scheduled / Batch Jobs)

```yaml
# values.yaml — minimal CronJob mode

cronJob:
  schedule: "0 2 * * *"  # daily at 2am
  image:
    repository: myrepo/my-batch-job
    tag: v1.0.0
  env:
    JOB_TYPE: "data-processing"
```

This emits a **CronJob** with secure defaults, resource limits, and optional probes.

### 🔭 Add Observability — One Block, Three Resources (NEW)

Enable Prometheus scraping, alerts, and recording rules without leaving your `values.yaml`:

```yaml
# values.yaml — Deployment + full observability

deployment:
  containerPort: 8080
  image: { repository: myrepo/my-app, tag: v1.0.0 }

service:
  enabled: true
  port: 80

metrics:
  enabled: true
  metricsPort: 9090          # the port your /metrics handler listens on
  path: /metrics

  serviceMonitor:
    enabled: true            # requires Prometheus Operator CRDs
    interval: 30s
    scrapeTimeout: 10s

  prometheusRule:
    rules:
      - alert: HighErrorRate
        expr: 'sum(rate(http_requests_total{status=~"5.."}[5m])) > 0.05'
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "High 5xx rate on {{ .Release.Name }}"
```

`helm template .` now additionally generates a **metrics Service** (`<release>-metrics`, port 9211), a **ServiceMonitor**, and a **PrometheusRule** — all selecting the workload's pods.

> ℹ️ ServiceMonitor and PrometheusRule are CRDs from the **Prometheus Operator** (kube-prometheus-stack). They render unconditionally — install the Operator first if you want them applied to the cluster.

## 🔧 Architecture & Naming Conventions

`helm-serve` is agnostic to naming conventions. It delegates the responsibility of naming resources to the **Consumer Chart**.

To use your own naming logic (e.g., `my-app-fullname`), define a helper template in your chart and pass the prefix:

```yaml
# values.yaml
templatePrefix: "my-custom-naming-prefix"
```

The library will then call `{{ include "my-custom-naming-prefix.fullname" . }}` to name resources.

## 📚 Example `values.yaml` files

The [test/](test/) directory ships a graduated set of examples — read them in order and you'll see every supported feature.

| File | Scope | What it demonstrates |
|---|---|---|
| [`values-basic.yaml`](test/values-basic.yaml) | **Hello-world** | Minimal Deployment + Service + Ingress. |
| [`values-middle.yaml`](test/values-middle.yaml) | **Day-2 ready** | Adds `shared` values, ConfigMaps, Secrets, NodePort, env vars, **basic metrics Service**. |
| [`values-full.yaml`](test/values-full.yaml) | **Everything, kitchen sink** | All metadata, probes, custom labels/annotations, `templatePrefix` override, `tpl` injection, **full metrics stack with ServiceMonitor + PrometheusRule**. |
| [`values-metrics.yaml`](test/values-metrics.yaml) ⭐ **NEW** | **Observability deep-dive** | Focused walkthrough of the `metrics:` block — every knob, with annotations. |
| [`values-cronjob.yaml`](test/values-cronjob.yaml) | **Scheduled jobs** | CronJob mode with concurrency, history, deadlines, restart policy, and **all three probes (startup/liveness/readiness)**. |

## 🔀 Resource Mode Detection

The library supports two workload modes — **Deployment** and **CronJob** — selected automatically based on which top-level key is present in your values:

* **`deployment` key present** → renders `Deployment`. `Service`, `Ingress`, and `metrics.*` resources are also rendered when their `enabled` flags are `true`.
* **`cronJob` key present** → renders `CronJob`.

The same library powers long-running services and scheduled batch jobs without extra configuration.

## ⚙️ Configuration Reference

### Global & Shared

| Parameter | Description | Default |
|---|---|---|
| `templatePrefix` | **Critical:** prefix used to invoke naming templates from the consumer chart. | `{{ .Chart.Name }}` |
| `shared` | Map of shared variables, accessible elsewhere via `tpl`. | `{}` |

### Deployment

| Parameter | Description | Default |
|---|---|---|
| `deployment.replicaCount` | Number of desired pods. | `1` |
| `deployment.revisionHistoryLimit` | Number of old ReplicaSets to retain. | `0` (GitOps friendly) |
| `deployment.terminationGracePeriodSeconds` | Graceful termination duration. | `10` |
| `deployment.image.repository` | Container image repository. | `""` |
| `deployment.image.tag` | Container image tag. | `""` |
| `deployment.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `deployment.imagePullSecrets` | List of image pull secrets. | `[]` |
| `deployment.containerPort` | Port the container exposes. | **Required** |
| `deployment.env` | Environment variables. Supports `tpl` interpolation. | `{}` |
| `deployment.configMaps` | ConfigMaps to inject (`{name, required}`). | `[]` |
| `deployment.secrets` | Secrets to inject (`{name, required}`). | `[]` |
| `deployment.resources` | CPU/Memory requests and limits. | `cpu: 200m / memory: 256Mi` |
| `deployment.startupProbe` | Kubernetes Startup Probe. | `{}` |
| `deployment.livenessProbe` | Kubernetes Liveness Probe. | `{}` |
| `deployment.readinessProbe` | Kubernetes Readiness Probe. | `{}` |
| `deployment.labels` | Custom labels on Deployment metadata. | `{}` |
| `deployment.podAnnotations` | Custom annotations on Pod metadata. | `{}` |

### Service

| Parameter | Description | Default |
|---|---|---|
| `service.enabled` | Enable Service creation. | `false` |
| `service.name` | Override default service name (use with caution). | `""` |
| `service.type` | `ClusterIP`, `NodePort`, `LoadBalancer`. | `ClusterIP` |
| `service.port` | Service port. | **Required if enabled** |
| `service.nodePort` | Fixed NodePort (only when `type: NodePort`). | `nil` |
| `service.labels` | Custom labels for the Service. | `{}` |

### Ingress

| Parameter | Description | Default |
|---|---|---|
| `ingress.enabled` | Enable Ingress creation. | `false` |
| `ingress.className` | Ingress controller class name (e.g., `nginx`). | **Required if enabled** |
| `ingress.annotations` | Annotations (e.g., rewrite rules). | `{}` |
| `ingress.rule.host` | Hostname for the ingress rule. | **Required if enabled** |
| `ingress.rule.path` | Path for the ingress rule. | **Required if enabled** |
| `ingress.rule.pathType` | `Prefix`, `Exact`, `ImplementationSpecific`. | `Prefix` |

### 🔭 Metrics & Observability (NEW in v0.2.2)

> When `metrics.enabled: true`, the chart additionally exposes a **`metrics` containerPort** on the Pod and renders a dedicated **`<release>-metrics` ClusterIP Service on port 9211**. ServiceMonitor and PrometheusRule are opt-in on top of that.

| Parameter | Description | Default |
|---|---|---|
| `metrics.enabled` | Master switch for the entire metrics stack. | `false` |
| `metrics.metricsPort` | Container port that exposes `/metrics`. Supports `tpl`. | **Required if enabled** |
| `metrics.path` | Path served by your `/metrics` handler (forwarded to ServiceMonitor). | `nil` |
| `metrics.labels` | Extra labels merged onto the metrics Service, ServiceMonitor and PrometheusRule. | `{}` |
| `metrics.serviceMonitor.enabled` | Render a `ServiceMonitor` (requires Prometheus Operator). | `false` |
| `metrics.serviceMonitor.interval` | Scrape interval. | `30s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout. | `10s` |
| `metrics.serviceMonitor.scheme` | `http` or `https`. | `http` |
| `metrics.serviceMonitor.honorLabels` | Honor labels reported by the target. | `nil` |
| `metrics.serviceMonitor.relabelings` | Standard Prometheus relabel rules (`tpl`-aware). | `nil` |
| `metrics.serviceMonitor.metricRelabelings` | Per-metric relabel rules (`tpl`-aware). | `nil` |
| `metrics.prometheusRule.rules` | Alert and/or recording rules. Omit or pass `[]` to skip the resource. | `[]` |

### CronJob

| Parameter | Description | Default |
|---|---|---|
| `cronJob.schedule` | Cron expression (e.g., `"*/5 * * * *"`). | **Required** |
| `cronJob.concurrencyPolicy` | `Allow`, `Forbid`, `Replace`. | `nil` |
| `cronJob.successfulJobsHistoryLimit` | Successful job history. | `nil` |
| `cronJob.failedJobsHistoryLimit` | Failed job history. | `nil` |
| `cronJob.suspend` | Suspend the CronJob. | `nil` |
| `cronJob.startingDeadlineSeconds` | Deadline for missed schedules. | `nil` |
| `cronJob.backoffLimit` | Retries before failing. | `nil` |
| `cronJob.activeDeadlineSeconds` | Job timeout. | `nil` |
| `cronJob.ttlSecondsAfterFinished` | Cleanup after completion. | `nil` |
| `cronJob.restartPolicy` | `OnFailure` or `Never`. | `OnFailure` |
| `cronJob.image.repository` | Container image repository. | `""` |
| `cronJob.image.tag` | Container image tag. | `""` |
| `cronJob.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `cronJob.imagePullSecrets` | List of image pull secrets. | `[]` |
| `cronJob.env` | Environment variables. Supports `tpl`. | `{}` |
| `cronJob.configMaps` | ConfigMaps to inject (`{name, required}`). | `[]` |
| `cronJob.secrets` | Secrets to inject (`{name, required}`). | `[]` |
| `cronJob.resources` | CPU/Memory requests and limits. | `cpu: 200m / memory: 256Mi` |
| `cronJob.startupProbe` | Kubernetes Startup Probe. | `{}` |
| `cronJob.livenessProbe` | Kubernetes Liveness Probe. | `{}` |
| `cronJob.readinessProbe` | Kubernetes Readiness Probe. | `{}` |
| `cronJob.labels` | Custom labels on CronJob metadata. | `{}` |
| `cronJob.podAnnotations` | Custom annotations on Pod metadata. | `{}` |

## 💡 Advanced Usage

### 1. Dynamic Value Injection (`tpl`)

Reference values from elsewhere in `values.yaml` or the Helm context directly inside environment variables, ports, labels, or relabel rules:

```yaml
shared:
  commonSecret: "my-org-secret"
  metricsPort: "9090"

deployment:
  containerPort: 8080
  env:
    APP_INSTANCE: "{{ .Release.Name }}"
    API_KEY_REF: "{{ .Values.shared.commonSecret }}"

metrics:
  enabled: true
  metricsPort: "{{ .Values.shared.metricsPort }}"
```

### 2. Auto-Injected Metadata

Every workload (Deployment **and** CronJob) automatically receives these environment variables — useful for logs, traces, and self-reported metrics:

| Variable | Source |
|---|---|
| `HELM_Version` | `.Chart.Version` |
| `HELM_AppVersion` | `.Chart.AppVersion` |
| `HELM_Description` | `.Chart.Description` |
| `HELM_Namespace` | `.Release.Namespace` |
| `K8S_Namespace` | Downward API (`metadata.namespace`) |

### 3. Probes on CronJobs

Yes — Kubernetes supports probes on CronJob pods, and `helm-serve` exposes all three (`startupProbe`, `livenessProbe`, `readinessProbe`) for both modes. Useful for long-running batch jobs that ship a `/healthz` endpoint or sidecar-style scheduled workers. See [`values-cronjob.yaml`](test/values-cronjob.yaml).

# License

This project is licensed under the [Apache License 2.0](LICENSE.md).
