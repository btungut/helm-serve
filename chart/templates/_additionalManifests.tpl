{{- define "library.additionalManifests" }}
{{- with .Values.additionalManifests }}
{{- $root := $ }}
{{- $templatePrefix := include "library.templatePrefix" $root }}
{{- $standardLabels := include (printf "%s.labels" $templatePrefix) $root | fromYaml }}
{{- $manifestsYaml := ternary . (toYaml .) (kindIs "string" .) }}
{{- range $manifest := (tpl $manifestsYaml $root | fromYamlArray) }}
{{- $metadata := $manifest.metadata | default dict }}
{{- $labels := merge ($metadata.labels | default dict) $standardLabels }}
{{- $_ := set $metadata "labels" $labels }}
{{- $_ := set $manifest "metadata" $metadata }}
---
{{- toYaml $manifest | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}
