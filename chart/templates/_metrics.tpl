{{- define "library.metrics.name" }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
{{- (tpl (include (printf "%s.fullname" $templatePrefix) $) $) }}-metrics
{{- end }}

{{- define "library.metrics.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.metrics.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
{{- end }}
{{- end }}

{{- define "library.metrics" }}
{{- $metrics := .Values.metrics }}
{{- if $metrics.enabled }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "library.metrics.name" $ }}
  labels:
    {{- include "library.metrics.labels" $ | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: 9211
      targetPort: metrics
      name: http-metrics
      protocol: TCP
  selector:
    {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 4 }}
{{- if $metrics.serviceMonitor.enabled }}
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "library.metrics.name" $ }}
  labels:
    {{- include "library.metrics.labels" $ | nindent 4 }}
spec:
  endpoints:
    - port: http-metrics
      {{- if $metrics.path }}
      path: {{ tpl $metrics.path $ }}
      {{- end }}
      {{- if $metrics.serviceMonitor.honorLabels }}
      honorLabels: {{ $metrics.serviceMonitor.honorLabels }}
      {{- end }}
      interval: {{ $metrics.serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ $metrics.serviceMonitor.scrapeTimeout | default "10s" }}
      scheme: {{ $metrics.serviceMonitor.scheme | default "http" }}
      {{- if $metrics.serviceMonitor.relabelings }}
      relabelings:
        {{- tpl (toYaml $metrics.serviceMonitor.relabelings | nindent 8) $ }}
      {{- end }}
      {{- if $metrics.serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- tpl (toYaml $metrics.serviceMonitor.metricRelabelings | nindent 8) $ }}
      {{- end }}
  selector:
    matchLabels:
      {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 6 }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
{{- end }}
{{- end }}
{{- end }}
