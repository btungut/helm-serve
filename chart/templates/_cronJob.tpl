{{- define "default.library.cronJob" }}
{{- $job := . }}
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 200m
    memory: 256Mi
{{- end }}

{{- define "library.cronJob.name" }}
{{- (tpl (.Values.cronJob.name | default (include (printf "%s.fullname" (include "library.templatePrefix" $)) $)) $) }}
{{- end }}

{{- define "library.cronJob.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.cronJob.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
{{- end }}
{{- end }}


{{- define "library.cronJob" }}
{{- if (hasKey .Values "cronJob") }}
{{- $job := .Values.cronJob }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
{{- $jobDefault := (include "default.library.cronJob" $job) | fromYaml }}

apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "library.cronJob.name" $ }}
  labels:
    {{- include "library.cronJob.labels" $ | nindent 4 }}
spec:
  schedule: {{ $job.schedule | required "cronJob.schedule is required" | quote }}
  {{- with $job.concurrencyPolicy }}
  concurrencyPolicy: {{ . }}
  {{- end }}
  {{- with $job.successfulJobsHistoryLimit }}
  successfulJobsHistoryLimit: {{ . }}
  {{- end }}
  {{- with $job.failedJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ . }}
  {{- end }}
  {{- with $job.suspend }}
  suspend: {{ . }}
  {{- end }}
  {{- with $job.startingDeadlineSeconds }}
  startingDeadlineSeconds: {{ . }}
  {{- end }}
  jobTemplate:
    metadata:
      labels:
        {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 8 }}
    spec:
      {{- with $job.backoffLimit }}
      backoffLimit: {{ . }}
      {{- end }}
      {{- with $job.activeDeadlineSeconds }}
      activeDeadlineSeconds: {{ . }}
      {{- end }}
      {{- with $job.ttlSecondsAfterFinished }}
      ttlSecondsAfterFinished: {{ . }}
      {{- end }}
      template:
        metadata:
          {{- with $job.podAnnotations }}
          annotations:
            {{- tpl (toYaml . | nindent 12 ) $ }}
          {{- end }}
          labels:
            {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 12 }}
        spec:
          restartPolicy: {{ $job.restartPolicy | default "OnFailure" }}
          {{- with $job.imagePullSecrets }}
          imagePullSecrets:
            {{- tpl (toYaml . | nindent 12 ) $ }}
          {{- end }}
        {{- $cnt := $job }}
          containers:
            - name: app
              image: "{{ $cnt.image.repository | required "image is required" }}:{{ $cnt.image.tag | required "tag is required" }}"
              imagePullPolicy: {{ $cnt.image.pullPolicy | default "IfNotPresent" }}
              {{- if or ($cnt.configMaps) ($cnt.secrets) }}
              envFrom:
              {{- range $i, $configMap := $cnt.configMaps }}
                - configMapRef:
                    name: {{ tpl $configMap.name $ | quote }}
                    optional: {{ ($configMap.required ) | not }}
              {{- end }}
              {{- range $i, $secret := $cnt.secrets }}
                - secretRef:
                    name: {{ tpl $secret.name $ | quote }}
                    optional: {{ ($secret.required ) | not }}
              {{- end }}
              {{- end }}
              env:
                - name: HELM_Version
                  value: {{ $.Chart.Version | quote }}
                - name: HELM_AppVersion
                  value: {{ $.Chart.AppVersion | quote }}
                - name: HELM_Description
                  value: {{ $.Chart.Description | quote }}
                - name: HELM_Namespace
                  value: {{ $.Release.Namespace | quote }}
                - name: K8S_Namespace
                  valueFrom:
                    fieldRef:
                      fieldPath: metadata.namespace
              {{- range $key, $val := $cnt.env }}
                - name:  {{ $key | quote }}
                  value: {{ tpl $val $ | quote }}
              {{- end }}
              {{- with $cnt.startupProbe }}
              startupProbe:
                {{- tpl (toYaml .) $ | nindent 16 }}
              {{- end }}
              {{- with $cnt.livenessProbe }}
              livenessProbe:
                {{- tpl (toYaml .) $ | nindent 16 }}
              {{- end }}
              {{- with $cnt.readinessProbe }}
              readinessProbe:
                {{- tpl (toYaml .) $ | nindent 16 }}
              {{- end }}
              {{- with (merge ($cnt.resources | default dict) $jobDefault.resources) }}
              resources:
                {{- tpl (toYaml .) $ | nindent 16 }}
              {{- end }}
{{- end }}
{{- end }}
