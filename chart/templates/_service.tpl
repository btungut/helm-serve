{{- define "library.service.name" }}
{{- (tpl (.Values.service.name | default (include (printf "%s.fullname" (include "library.templatePrefix" $)) $)) $) }}
{{- end }}

{{- define "library.service.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.service.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
{{- end }}
{{- end }}

{{- define "library.service" }}
{{- if (hasKey .Values "service") }}
{{- $svc := .Values.service }}
{{- if $svc.enabled }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "library.service.name" $ }}
  labels: 
    {{- include "library.service.labels" $ | nindent 4 }}
spec:
  type: {{ $svc.type | default "ClusterIP" }}
  ports:
    - port: {{ $svc.port | required "port is required" }}
      targetPort: "app"
      name: "app"
      {{- if and (eq $svc.type "NodePort") ($svc.nodePort) }}
      nodePort: {{ $svc.nodePort }}
      {{- end }}
  selector:
    {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}