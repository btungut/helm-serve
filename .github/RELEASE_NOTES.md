<!-- 
  GitHub Release Notes Template for helm-serve
  
  Usage: Copy this template when creating a new release on GitHub.
  Replace the placeholders with version-specific details.
  Keep the structure consistent across releases.
-->

# helm-serve v0.2.3-beta1

**A Helm library chart for shipping stateless services, scheduled jobs, observability, and ingress TLS without repeating Kubernetes boilerplate.**

## 🎯 What's New

### Primary Feature: Ingress TLS Support

This release closes a real production gap by bringing **Ingress TLS modeling into the library**. Previously, teams had to fork or override templates just to express HTTPS configurations. Now, three TLS modes are built-in:

1. **Auto mode** — Simplest: provide `secretName` and the chart uses `ingress.rule.host` automatically.
2. **Multi-host, single-secret mode** — Perfect for SAN certificates covering multiple domains via `ingress.tls.hosts[]`.
3. **Power-user multi-secret mode** — True SNI with different secrets per host set via `ingress.tls.secrets[]`.

All three modes support `tpl` interpolation on hostnames and secret names.

**Example:**

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
    secretName: my-tls-secret
```

Learn more in the [Upgrading from v0.2.2](https://github.com/btungut/helm-serve#upgrading-from-v022) section of the README.

## 📋 New Parameters

| Parameter | Purpose | Default |
|---|---|---|
| `ingress.tls.enabled` | Master switch for the TLS block | `false` |
| `ingress.tls.secretName` | Secret name (for auto and multi-host modes) | Required if enabled |
| `ingress.tls.hosts` | Explicit host list (defaults to `[ingress.rule.host]`) | `[]` |
| `ingress.tls.secrets` | List of `{ hosts, secretName }` pairs (for SNI setups) | `[]` |

See the full [Configuration Reference](https://github.com/btungut/helm-serve#configuration-reference) for all parameters.

## 📚 New Examples

- **[test/values-ingress-tls.yaml](https://github.com/btungut/helm-serve/blob/release/v0.2.3-beta1/test/values-ingress-tls.yaml)** — All three TLS modes with cert-manager integration examples.
- **Updated [test/values-full.yaml](https://github.com/btungut/helm-serve/blob/release/v0.2.3-beta1/test/values-full.yaml)** — Now includes comprehensive ingress TLS documentation.

## ♻️ Backward Compatibility

This release is **fully backward compatible** with v0.2.2. All observability features (metrics, ServiceMonitor, PrometheusRule) remain unchanged. If you're using v0.2.2 without custom ingress overrides, no action is required.

## 📦 Installation

```yaml
dependencies:
  - name: helm-serve
    repository: oci://ghcr.io/btungut
    version: 0.2.3-beta1
```

Then run:

```bash
helm dependency update
```

## 🔍 What's Preserved from v0.2.2

- ✅ Prometheus observability stack (metrics Service, ServiceMonitor, PrometheusRule)
- ✅ Deployment and CronJob workload modes
- ✅ Probes on both Deployments and CronJobs
- ✅ Dynamic value injection with `tpl`
- ✅ Consumer-side naming control via `templatePrefix`
- ✅ Auto-injected metadata environment variables
- ✅ Production-oriented defaults (resource requests/limits, GitOps mode, graceful termination)

## 🤝 Contributing

Found a bug or have a feature request? Please [open an issue](https://github.com/btungut/helm-serve/issues) or [submit a pull request](https://github.com/btungut/helm-serve/pulls).

## 📄 License

[Apache License 2.0](https://github.com/btungut/helm-serve/blob/master/LICENSE.md)

---

**Made with ❤️ by Burak Tungut**
