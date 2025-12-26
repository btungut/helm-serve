{{- define "library.ingress.name" }}
{{- (tpl (.Values.ingress.name | default (include (printf "%s.fullname" (include "library.templatePrefix" $)) $)) $) }}
{{- end }}

{{- define "library.ingress.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.ingress.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
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