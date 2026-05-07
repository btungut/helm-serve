{{- define "library.ingress.name" }}
{{- (tpl (.Values.ingress.name | default (include (printf "%s.fullname" (include "library.templatePrefix" $)) $)) $) }}
{{- end }}

{{- define "library.ingress.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.ingress.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
{{- end }}
{{- end }}

{{/*
Render the `tls:` block of an Ingress spec.

Three usage modes (evaluated in order, first match wins):

  1. `ingress.tls.secrets` (list)  — power-user mode: pass-through array of
                                     { hosts: [...], secretName: ... } items.
                                     Use this for SNI with multiple certs.
  2. `ingress.tls.hosts`   (list)  — multi-host single-secret mode. All hosts
                                     are placed under `ingress.tls.secretName`.
  3. (default)                     — auto mode. Uses `[ingress.rule.host]`
                                     under `ingress.tls.secretName`.

`tpl` is applied to every host and secretName so they may reference values
from `.Values.shared`, `.Release.*`, etc. `secretName` is required whenever
the secrets-list mode is not used; this is enforced via `required`.
*/}}
{{- define "library.ingress.tls" }}
{{- $ing := .Values.ingress }}
{{- $tls := $ing.tls }}
{{- if and $tls $tls.enabled }}
tls:
{{- if $tls.secrets }}
  {{- range $tls.secrets }}
  - hosts:
      {{- range .hosts | required "ingress.tls.secrets[].hosts is required and must contain at least one host" }}
      - {{ tpl . $ | quote }}
      {{- end }}
    secretName: {{ tpl (.secretName | required "ingress.tls.secrets[].secretName is required") $ | quote }}
  {{- end }}
{{- else }}
  - hosts:
    {{- $hosts := $tls.hosts | default (list $ing.rule.host) }}
    {{- range $hosts }}
      - {{ tpl . $ | quote }}
    {{- end }}
    secretName: {{ tpl ($tls.secretName | required "ingress.tls.secretName is required when ingress.tls.enabled is true (or use ingress.tls.secrets[] for per-host secrets)") $ | quote }}
{{- end }}
{{- end }}
{{- end }}

{{- define "library.ingress" }}
{{- $ing := .Values.ingress }}
{{- if $ing.enabled }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "library.ingress.name" $ }}
  labels:
    {{- include "library.ingress.labels" $ | nindent 4 }}
  {{- with $ing.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ $ing.className | required "ingress.className is required" | quote }}
  {{- include "library.ingress.tls" $ | nindent 2 }}
  rules:
    - host: {{ (tpl $ing.rule.host $) | required "ingress.rule.host is required" }}
      http:
        paths:
          - path: {{ (tpl $ing.rule.path $) | required "ingres.rule.path is required" }}
            pathType: {{ $ing.rule.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ include "library.service.name" $ }}
                port:
                  name: "app"
{{- end }}
{{- end }}