# Test Fixtures for helm-serve

This directory is both a **test harness** and a **cookbook**: a minimal consumer chart (`testing-api`) that depends on the library via `file://../chart`, plus a set of self-documenting `values-*.yaml` examples that exercise every supported feature of `helm-serve`.

These fixtures also demonstrate the project's intended boundary: the application owns its Docker image, while `helm-serve` owns the reusable Kubernetes runtime configuration around that image. The examples are therefore values for rendering manifests, not Dockerfiles or image-build recipes.

## How the harness is wired

```
test/
├── Chart.yaml                    # application chart; depends on helm-serve via file://../chart
├── Chart.lock                    # locked dependency metadata
├── charts/                       # vendored library (helm dependency update)
├── templates/
│   ├── deployment.yaml           # {{- include "library.deployment" . }}
│   ├── cronJob.yaml              # {{- include "library.cronJob" . }}
│   ├── service.yaml              # {{- include "library.service" . }}
│   ├── ingress.yaml              # {{- include "library.ingress" . }}
│   ├── _helpers.tpl              # testing-api.* helpers (default templatePrefix)
│   └── _helpers_overriden_tpl.tpl# overriden-tpl-prefix.* helpers (templatePrefix override tests)
├── values-*.yaml                 # example configurations (see below)
├── golden/                       # expected render output per values file
└── validate.sh                   # golden-file regression suite
```

The workload templates are intentionally one-liners — exactly how a real consumer chart calls the library. The two `_helpers` files provide the naming helpers the library requires (`<prefix>.fullname`, `<prefix>.labels`, `<prefix>.selectorLabels`): `testing-api.*` covers the default prefix derived from the chart name, while `overriden-tpl-prefix.*` is exercised by `values-full.yaml` through `templatePrefix: "overriden-tpl-prefix"`.

## Files

| File | Focus | What it demonstrates |
|---|---|---|
| `values-basic.yaml` | Minimal service | Deployment + Service + Ingress |
| `values-middle.yaml` | Day-2 baseline | Shared values, ConfigMaps, Secrets, NodePort, env vars, metrics Service |
| `values-full.yaml` | Full surface | Labels, annotations, probes, `templatePrefix`, `tpl`, ingress TLS, full metrics stack |
| `values-metrics.yaml` | Observability | Dedicated walkthrough of the `metrics:` block |
| `values-ingress-tls.yaml` | HTTPS patterns | All supported ingress TLS modes, including cert-manager-friendly examples |
| `values-traefik.yaml` | Traefik CRD mode | `Middleware` + `IngressRoute` rendering, short-name middleware wiring, default vs explicit backends |
| `values-cronjob.yaml` | Scheduled workloads | CronJob mode with execution policy and probe examples |

## Testing and Validation

### Refreshing the vendored library

After changing anything under `../chart`, update the vendored dependency so renders pick it up:

```bash
helm dependency update .
```

### Rendering Templates

Render any example with:

```bash
helm template smoke . -f values-basic.yaml
```

Or render all examples quickly:

```bash
for f in values-*.yaml; do
  echo "=== $f ===" && helm template smoke . -f "$f" > /dev/null && echo "✓"
done
```

### Regression Testing

The `validate.sh` script compares current template renders against golden outputs stored in `golden/`. This catches unintended changes to ingress, metrics, probes, and other rendered resources.

**First run (generate golden outputs):**

```bash
./validate.sh --update
```

This creates `golden/*.golden.yaml` files that represent the expected output for each example.

**Normal runs (check for regressions):**

```bash
./validate.sh
```

If the output matches golden files, all tests pass. If you make intentional template changes, update the golden files:

```bash
./validate.sh --update
git add golden/
git commit -m "Update golden outputs for <feature>"
```

## Using Test Charts

To test `helm-serve` as a dependency in your application chart:

1. Add it to your chart's `Chart.yaml`:

```yaml
dependencies:
  - name: helm-serve
    repository: oci://ghcr.io/btungut
    version: 0.2.3-beta2
```

2. Copy one of the `values-*.yaml` examples as your starting point.

3. Render and inspect:

```bash
helm dependency update
helm template <release-name> .
```

## Contributing New Tests

When adding features or fixing bugs, include an example `values-*.yaml` that demonstrates the change:

1. Create `test/values-descriptive-name.yaml` with your example.
2. Document it inline with comments.
3. Run `helm dependency update .` so the harness uses your local library changes.
4. Run `./validate.sh --update` to generate the golden output.
5. Commit both files as part of your PR.

This ensures regression tests cover new functionality from day one.
