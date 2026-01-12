# helm-serve

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%3E%3D%201.19-326ce5.svg)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-v3-orange.svg)](https://helm.sh/)

**Bootstrap stateless Web & API workloads and scheduled jobs in seconds.**

`helm-serve` is a DRY (Don't Repeat Yourself) **Helm Library Chart** designed to act as a standardized foundation for microservices and scheduled tasks. It abstracts away the complexity of defining repetitive `Deployment`, `Service`, `Ingress`, and `CronJob` manifests, allowing developers to focus on configuration rather than boilerplate YAML.

## 🚀 Features

* **Zero Boilerplate:** Define your app with just a few lines of YAML.
* **Multi-Mode Support:** Switch between Deployment and CronJob modes using Chart annotations.
* **Inversion of Control:** Supports custom naming conventions via `templatePrefix` injection.
* **Dynamic Values:** Supports Go Template syntax (`tpl`) directly within `values.yaml`.
* **Production Ready:** Includes secure defaults (non-root users, resource limits), probes, and metadata injection.
* **Standardized Networking:** Auto-wired Ingress and Service configuration.

## 📦 Installation

Since this is a **Library Chart**, it is not meant to be installed directly (`helm install`). Instead, add it as a dependency to your application chart.

1. Add it to your application's `Chart.yaml`:

```yaml
dependencies:
  - name: helm-serve
    repository: oci://ghcr.io/btungut
    version: 0.0.1
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

In your application chart's `values.yaml`, simply define the essentials. The library handles the rest.

```yaml
# values.yaml (Minimal Example for Deployment Mode)

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

Running `helm template .` with this config will automatically generate:

* A **Deployment** with 2 replicas and resource limits enabled.
* A **Service** pointing to the pods.
* An **Ingress** routing traffic to that service.

### CronJob Mode (Scheduled/Batch Jobs)

For scheduled tasks, add the annotation to your `Chart.yaml` and configure the CronJob in `values.yaml`:

```yaml
# Chart.yaml
annotations:
  "buraktungut.com/chart-type": "job"
```

```yaml
# values.yaml (Minimal Example for CronJob Mode)

cronJob:
  schedule: "0 2 * * *"  # Daily at 2am
  image:
    repository: myrepo/my-batch-job
    tag: v1.0.0
  env:
    JOB_TYPE: "data-processing"
```

This will generate a **CronJob** resource with secure defaults and resource limits.

## 🔧 Architecture & Naming Conventions

`helm-serve` is agnostic to naming conventions. It delegates the responsibility of naming resources to the **Consumer Chart**.

To use your own naming logic (e.g., `my-app-fullname`), define a helper template in your chart and pass the prefix:

```yaml
# values.yaml
templatePrefix: "my-custom-naming-prefix"
```

The library will then call `{{ include "my-custom-naming-prefix.fullname" . }}` to name resources.

## Example Values YAML files

You can find example `values.yaml` files demonstrating various configurations in the [test/](test/) directory.

### values-basic.yaml

Minimal configuration with just deployment, service, and ingress basics.
Visit [test/values-basic.yaml](test/values-basic.yaml) for details.

### values-middle.yaml

Intermediate configuration with shared values, ConfigMaps, Secrets, NodePort service, and environment variables.
Visit [test/values-middle.yaml](test/values-middle.yaml) for details.

### values-full.yaml

Comprehensive configuration showcasing all features including custom labels, annotations, probes, template prefix override, and dynamic value injection via `tpl`.
Visit [test/values-full.yaml](test/values-full.yaml) for details.

### values-cronjob.yaml

CronJob configuration for scheduled tasks with cron schedule, concurrency policies, job history limits, and resource management.
Visit [test/values-cronjob.yaml](test/values-cronjob.yaml) for details.

## 🔀 Chart Type Annotation

The library supports two modes: **Deployment** (default) and **CronJob**. You control which resources are rendered using a Chart annotation in your application's `Chart.yaml`:

```yaml
# Chart.yaml
annotations:
  "buraktungut.com/chart-type": "job"  # Use "job" for CronJob mode
```

### Behavior

* **No annotation or `"deployment"`**: Renders Deployment, Service, and Ingress resources (default behavior)
* **`"job"`**: Renders CronJob resource only (Service and Ingress are skipped)

This allows you to use the same library chart for both long-running services and scheduled batch jobs.


## ⚙️ Configuration Reference

The following table lists the configurable parameters of the `helm-serve` chart and their default values.

### Global & Shared
| Parameter | Description | Default |
|-----------|-------------|---------|
| `templatePrefix` | **Critical:** The prefix used to invoke naming templates from the consumer chart. | `{{ .Chart.Name }}` |
| `shared` | A map for defining shared variables accessible via `tpl` elsewhere. | `{}` |

### Deployment
| Parameter | Description | Default |
|-----------|-------------|---------|
| `deployment.replicaCount` | Number of desired pods. | `1` |
| `deployment.revisionHistoryLimit` | Number of old ReplicaSets to retain. | `0` (GitOps friendly) |
| `deployment.terminationGracePeriodSeconds` | Duration the pod needs to terminate gracefully. | `10` |
| `deployment.image.repository` | Container image repository. | `""` |
| `deployment.image.tag` | Container image tag. | `""` |
| `deployment.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `deployment.imagePullSecrets` | List of image pull secrets. | `[]` |
| `deployment.containerPort` | The port the container exposes. | **Required** |
| `deployment.env` | Key-value pairs for environment variables. Supports `tpl` string interpolation. | `{}` |
| `deployment.configMaps` | List of ConfigMaps to mount/inject (`{name: "", required: bool}`). | `[]` |
| `deployment.secrets` | List of Secrets to mount/inject (`{name: "", required: bool}`). | `[]` |
| `deployment.resources` | CPU/Memory requests and limits. | `requests/limits: cpu: 200m, memory: 256Mi` |
| `deployment.startupProbe` | Kubernetes Startup Probe configuration. | `{}` |
| `deployment.livenessProbe` | Kubernetes Liveness Probe configuration. | `{}` |
| `deployment.readinessProbe` | Kubernetes Readiness Probe configuration. | `{}` |
| `deployment.labels` | Custom labels added to Deployment metadata. | `{}` |
| `deployment.podAnnotations` | Custom annotations added to Pod metadata. | `{}` |

### Service
| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.enabled` | Enable or disable Service creation. | `false` |
| `service.name` | Override the default service name (Use with caution). | `""` |
| `service.type` | Service type (ClusterIP, NodePort, LoadBalancer). | `ClusterIP` |
| `service.port` | The port exposed by the service. | **Required if enabled** |
| `service.nodePort` | Fixed NodePort (only if type is NodePort). | `nil` |
| `service.labels` | Custom labels for the Service. | `{}` |

### Ingress
| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable or disable Ingress creation. | `false` |
| `ingress.className` | Ingress controller class name (e.g., `nginx`). | **Required if enabled** |
| `ingress.annotations` | Annotations for Ingress (e.g., rewrite rules). | `{}` |
| `ingress.rule.host` | The hostname for the ingress rule. | **Required if enabled** |
| `ingress.rule.path` | The path for the ingress rule. | **Required if enabled** |
| `ingress.rule.pathType` | Path match type (Prefix, Exact). | `Prefix` |

### CronJob
| Parameter | Description | Default |
|-----------|-------------|---------|
| `cronJob.schedule` | Cron schedule expression (e.g., `"*/5 * * * *"`). | **Required** |
| `cronJob.concurrencyPolicy` | How to handle concurrent executions (Allow, Forbid, Replace). | `nil` |
| `cronJob.successfulJobsHistoryLimit` | Number of successful jobs to keep. | `nil` |
| `cronJob.failedJobsHistoryLimit` | Number of failed jobs to keep. | `nil` |
| `cronJob.suspend` | Suspend the CronJob (true/false). | `nil` |
| `cronJob.backoffLimit` | Number of retries before marking job as failed. | `nil` |
| `cronJob.activeDeadlineSeconds` | Job timeout in seconds. | `nil` |
| `cronJob.ttlSecondsAfterFinished` | Clean up finished jobs after this duration. | `nil` |
| `cronJob.restartPolicy` | Pod restart policy (OnFailure or Never). | `OnFailure` |
| `cronJob.image.repository` | Container image repository. | `""` |
| `cronJob.image.tag` | Container image tag. | `""` |
| `cronJob.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `cronJob.imagePullSecrets` | List of image pull secrets. | `[]` |
| `cronJob.env` | Key-value pairs for environment variables. Supports `tpl`. | `{}` |
| `cronJob.configMaps` | List of ConfigMaps to inject (`{name: "", required: bool}`). | `[]` |
| `cronJob.secrets` | List of Secrets to inject (`{name: "", required: bool}`). | `[]` |
| `cronJob.resources` | CPU/Memory requests and limits. | `requests/limits: cpu: 200m, memory: 256Mi` |
| `cronJob.labels` | Custom labels added to CronJob metadata. | `{}` |
| `cronJob.podAnnotations` | Custom annotations added to Pod metadata. | `{}` |

## 💡 Advanced Usage

### 1. Dynamic Value Injection (TPL)
You can reference values from other parts of your `values.yaml` or Helm context directly in your environment variables.

```yaml
shared:
  commonSecret: "my-org-secret"

deployment:
  env:
    # Injects the release name dynamically
    APP_INSTANCE: "{{ .Release.Name }}"
    # References the shared value defined above
    API_KEY_REF: "{{ .Values.shared.commonSecret }}"
```

### 2. Auto-Injected Metadata
The chart automatically injects the following environment variables into the container for observability:
* `HELM_Version`: The chart version.
* `HELM_AppVersion`: The application version.
* `HELM_Description`: The chart description.
* `HELM_Namespace`: The release namespace.
* `K8S_Namespace`: The actual Kubernetes namespace (via Downward API).

# License

This project is released under the **Lexis Non-Commercial Source License (NCSL) v1.0**.

### You are allowed to

- Pull and run the official Docker image
- Use the software for personal, educational, or internal evaluation purposes
- Clone, modify, and build your own Docker images
- Self-host the software for non-commercial use only

### You are NOT allowed to

- Use this software in any commercial or revenue-generating product or service
- Offer the software as part of a paid platform or subscription
- Provide the software as a hosted or managed service (SaaS)
- Monetize the software directly or indirectly
- Sell access to the software or its functionality

Commercial use requires a separate commercial license.

For commercial licensing inquiries, contact: **[burak.tungut@tungops.com.tr](mailto:burak.tungut@tungops.com.tr)**
