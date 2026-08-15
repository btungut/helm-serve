# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Traefik CRD Mode

`helm-serve` now supports **Traefik** as an alternative ingress path, selected by `ingress.className: traefik`. This replaces the hand-written Traefik templates teams had been maintaining per project.

When active, the library renders [`Middleware`](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/http/middleware/) and [`IngressRoute`](https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/http/ingressroute/) CRDs (`traefik.io/v1alpha1`) instead of a standard `Ingress`. The nginx path is unchanged.

**Highlights:**

- **Predictable naming** — resources render as `middleware-<fullname>-<name>` and `ingressroute-<fullname>-<name>`.
- **Short-name middleware wiring** — routes reference middlewares by their short name; the chart expands them to the rendered full names. `{ name, namespace }` maps pass through for external middlewares.
- **Pass-through specs with `tpl`** — middleware specs and route services accept any Traefik CRD field.
- **Sensible defaults** — `entryPoints` defaults to `[web, websecure]`; routes without explicit `services` target the chart's own Service.

**New parameters:** the top-level `traefik:` block (`traefik.middlewares[]`, `traefik.ingressRoutes[]`).

**New example:** [`test/values-traefik.yaml`](test/values-traefik.yaml)

**Postponed (TODO):** HTTP TLS (`spec.tls`: `secretName` / `certResolver` / `options`) and TCP routing (`IngressRouteTCP` with TLS passthrough).

## [0.2.3-beta1] – 2026-05-09

### Added

#### Ingress TLS Support (Primary Feature)

`helm-serve` now includes **first-class Ingress TLS modeling** to replace hand-written ingress templates. This closes a real production gap where teams had to fork or override the ingress template just to express HTTPS configurations.

**Three TLS modes** are now supported:

1. **Auto mode** — Simplest: provide `secretName` and the chart uses `ingress.rule.host` automatically.
2. **Multi-host, single-secret mode** — Perfect for SAN certificates covering multiple domains via `ingress.tls.hosts[]`.
3. **Power-user multi-secret mode** — True SNI with different secrets per host set via `ingress.tls.secrets[]`.

All three modes support `tpl` interpolation on hostnames and secret names, enabling dynamic TLS configurations from shared values.

**New parameters:**
- `ingress.tls.enabled` — Master switch for the TLS block.
- `ingress.tls.secretName` — Secret name (for auto and multi-host modes).
- `ingress.tls.hosts` — Explicit host list (defaults to `[ingress.rule.host]`).
- `ingress.tls.secrets` — List of `{ hosts, secretName }` pairs (for SNI setups).

**New example:** [`test/values-ingress-tls.yaml`](test/values-ingress-tls.yaml)  
Demonstrates all three TLS modes with cert-manager-friendly annotations.

**Template changes:**
- Added `library.ingress.tls` template function to `chart/templates/_ingress.tpl`.
- Updated `library.ingress` to invoke the TLS block when enabled.

### Changed

- Updated [`chart/README.md`](chart/README.md) and [`README.md`](README.md) to:
  - Highlight Ingress TLS as the primary delta between v0.2.2 and v0.2.3-beta1.
  - Add "What's New" comparison table showing TLS capability gaps in 0.2.2.
  - Document all three TLS modes with code examples.
  - Expand Ingress configuration reference with new `ingress.tls.*` parameters.
  - Improve overall messaging to reflect production-focused day-2 operations.

- Updated [`test/values-full.yaml`](test/values-full.yaml) to:
  - Add a comprehensive `ingress.tls` example showing multi-host, single-secret mode.
  - Include inline comments explaining all three TLS patterns and cert-manager integration.

- Improved README tone and structure for better clarity and professional appeal.

### Preserved

- **Observability layer** (from v0.2.2) remains unchanged:
  - Metrics Service on port 9211.
  - `ServiceMonitor` and `PrometheusRule` support.
  - All metrics configuration parameters and examples fully functional.

- All other features (Deployment/CronJob modes, probes, dynamic values, resource defaults) intact.

---

## [0.2.2] – Previous Release

### Added

- **Prometheus observability** as a first-class capability.
  - Dedicated metrics Service (`<release>-metrics`, port 9211).
  - Optional `ServiceMonitor` for Prometheus Operator discovery.
  - Optional `PrometheusRule` for alerting and recording rules.
  - Single `metrics.enabled: true` switch wires the full stack.

- Example values file [`test/values-metrics.yaml`](test/values-metrics.yaml) showing observability patterns.

---

## Earlier Versions

For information on earlier releases, see [GitHub Releases](https://github.com/btungut/helm-serve/releases).
