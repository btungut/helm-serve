# Test Fixtures for helm-serve

This directory contains example `values-*.yaml` files that demonstrate every supported feature of the library. Each file is self-documenting with inline comments.

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
    version: 0.2.3-beta1
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
3. Run `./validate.sh --update` to generate the golden output.
4. Commit both files as part of your PR.

This ensures regression tests cover new functionality from day one.
