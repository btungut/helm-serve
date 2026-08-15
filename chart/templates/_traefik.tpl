{{/*
Traefik CRD support (traefik.io/v1alpha1, Traefik v3).

Rendered instead of the standard Ingress when `ingress.enabled` is true and
`ingress.className == "traefik"`. Produces `Middleware` and `IngressRoute`
resources from the top-level `traefik:` values block.

Naming convention (project name comes from the consumer via `templatePrefix`):
  Middleware   → middleware-<fullname>-<name>
  IngressRoute → ingressroute-<fullname>-<name>

Out of scope (deliberately postponed): HTTP TLS (`spec.tls`), TLSOption /
TLSStore, and TCP routing (IngressRouteTCP).
*/}}

{{/*
Compute a traefik resource name as `<prefix>-<fullname>-<name>`.

The `fullname` segment is truncated first so the item `<name>` always
survives the 63-char limit — truncating the whole string instead could eat
the item name entirely and make distinct items collide on one resource name.
*/}}
{{- define "library.traefik.resourceName" }}
{{- $fullname := include (printf "%s.fullname" (include "library.templatePrefix" .root)) .root }}
{{- $budget := sub 63 (add (len .prefix) (len .name) 2) }}
{{- printf "%s-%s-%s" .prefix (trunc (max 0 $budget | int) $fullname | trimSuffix "-") .name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "library.traefik.middlewareName" }}
{{- include "library.traefik.resourceName" (dict "root" .root "prefix" "middleware" "name" .name) }}
{{- end }}

{{- define "library.traefik.ingressRouteName" }}
{{- include "library.traefik.resourceName" (dict "root" .root "prefix" "ingressroute" "name" .name) }}
{{- end }}

{{- define "library.traefik.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" .root)) .root }}
{{- with .extra }}
{{- tpl (toYaml . | nindent 0) $.root }}
{{- end }}
{{- end }}

{{/*
Render all `traefik.middlewares[]` entries as Middleware CRDs.

`spec` is pass-through (the Middleware spec is a union type — headers,
stripPrefix, rateLimit, forwardAuth, ...) with `tpl` applied so values may
reference `.Values.shared`, `.Release.*`, etc.
*/}}
{{- define "library.traefik.middlewares" }}
{{- $ := . }}
{{- range .Values.traefik.middlewares }}
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: {{ include "library.traefik.middlewareName" (dict "root" $ "name" (.name | required "traefik.middlewares[].name is required")) }}
  labels:
    {{- include "library.traefik.labels" (dict "root" $ "extra" .labels) | nindent 4 }}
spec:
  {{- tpl (toYaml (.spec | required "traefik.middlewares[].spec is required")) $ | nindent 2 }}
---
{{- end }}
{{- end }}

{{/*
Render all `traefik.ingressRoutes[]` entries as IngressRoute CRDs.

  - `entryPoints` is a plain list of entry point names (default
    [web, websecure]). Addresses belong to the Traefik proxy itself, not here.
  - `routes[].match` is required and `tpl`-aware.
  - `routes[].middlewares[]` items given as plain strings are treated as short
    names of `traefik.middlewares[]` entries and expanded to their rendered
    full names. The map form `{name, namespace}` is passed through as-is for
    referencing external middlewares.
  - `routes[].services` is optional; when omitted the route targets the
    chart's own Service. When given, it is passed through with `tpl`.
*/}}
{{- define "library.traefik.ingressRoutes" }}
{{- $ := . }}
{{- $definedMiddlewares := list }}
{{- range ($.Values.traefik.middlewares | default (list)) }}
{{- $definedMiddlewares = append $definedMiddlewares .name }}
{{- end }}
{{- range .Values.traefik.ingressRoutes }}
{{- $ir := . }}
{{- if not $ir.routes }}
{{- fail (printf "traefik.ingressRoutes[%s].routes is required and must contain at least one route" ($ir.name | default "?")) }}
{{- end }}
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ include "library.traefik.ingressRouteName" (dict "root" $ "name" (.name | required "traefik.ingressRoutes[].name is required")) }}
  labels:
    {{- include "library.traefik.labels" (dict "root" $ "extra" .labels) | nindent 4 }}
  {{- with .annotations }}
  annotations:
    {{- tpl (toYaml .) $ | nindent 4 }}
  {{- end }}
spec:
  entryPoints:
    {{- range ($ir.entryPoints | default (list "web" "websecure")) }}
    - {{ tpl . $ | quote }}
    {{- end }}
  routes:
    {{- range $ir.routes }}
    - match: {{ tpl (.match | required "traefik.ingressRoutes[].routes[].match is required") $ | quote }}
      kind: {{ .kind | default "Rule" }}
      {{- with .priority }}
      priority: {{ . }}
      {{- end }}
      {{- with .middlewares }}
      middlewares:
        {{- range . }}
        {{- if kindIs "string" . }}
        {{- if not (has . $definedMiddlewares) }}
        {{- fail (printf "traefik.ingressRoutes[%s]: middleware '%s' is not defined in traefik.middlewares (use the map form {name, namespace} for external middlewares)" ($ir.name | default "?") .) }}
        {{- end }}
        - name: {{ include "library.traefik.middlewareName" (dict "root" $ "name" .) | quote }}
        {{- else }}
        - name: {{ tpl (.name | required "traefik.ingressRoutes[].routes[].middlewares[].name is required") $ | quote }}
          {{- with .namespace }}
          namespace: {{ tpl . $ | quote }}
          {{- end }}
        {{- end }}
        {{- end }}
      {{- end }}
      services:
        {{- if .services }}
        {{- tpl (toYaml .services) $ | nindent 8 }}
        {{- else }}
        - name: {{ include "library.service.name" $ }}
          port: {{ $.Values.service.port | required "service.port is required when traefik.ingressRoutes[].routes[].services is omitted" }}
        {{- end }}
    {{- end }}
---
{{- end }}
{{- end }}

{{- define "library.traefik" }}
{{- if not (and .Values.traefik .Values.traefik.ingressRoutes) }}
{{- fail "ingress.className is 'traefik' but traefik.ingressRoutes is empty; define at least one ingress route or set ingress.enabled: false" }}
{{- end }}
{{- include "library.traefik.middlewares" . }}
{{- include "library.traefik.ingressRoutes" . }}
{{- end }}
