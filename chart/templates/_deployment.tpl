{{- define "default.library.deployment" }}
{{- $dep := . }}
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 200m
    memory: 256Mi
{{- end }}

{{- define "library.templatePrefix" }}
{{- tpl (.Values.templatePrefix | default "{{ .Chart.Name }}") $ }}
{{- end }}

{{- define "library.deployment.name" }}
{{- (tpl (.Values.deployment.name | default (include (printf "%s.fullname" (include "library.templatePrefix" $)) $)) $) }}
{{- end }}

{{- define "library.deployment.labels" }}
{{- include (printf "%s.labels" (include "library.templatePrefix" $)) $ }}
{{- with $.Values.deployment.labels }}
{{- tpl (toYaml . | nindent 0) $ }}
{{- end }}
{{- end }}


{{- define "library.deployment" }}
{{- $dep := .Values.deployment }}
{{- $templatePrefix := include "library.templatePrefix" $ }}
{{- $depDefault := (include "default.library.deployment" $dep) | fromYaml }}

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "library.deployment.name" $ }}
  labels: 
    {{- include "library.deployment.labels" $ | nindent 4 }}
spec:
  revisionHistoryLimit: {{ $dep.revisionHistoryLimit | default 0 }}
  replicas: {{ $dep.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 6 }}
  template:
    metadata:
      {{- with $dep.podAnnotations }}
      annotations:
        {{- tpl (toYaml . | nindent 8 ) $ }}
      {{- end }}
      labels:
        {{- include (printf "%s.selectorLabels" $templatePrefix) $ | nindent 8 }}
    spec:
      terminationGracePeriodSeconds: {{ $dep.terminationGracePeriodSeconds | default 10 }}
      {{- with $dep.imagePullSecrets }}
      imagePullSecrets:
        {{- tpl (toYaml . | nindent 8 ) $ }}
      {{- end }}
    {{- $cnt := $dep }}
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
          {{- if hasKey $cnt "containerPort" }}
          ports:
            - name: app
              containerPort: {{ $cnt.containerPort | required "containerPort is required" }}
              protocol: TCP
          {{- end }}
          {{- with $cnt.startupProbe }}
          startupProbe:
            {{- tpl (toYaml .) $ | nindent 12 }}
          {{- end }}
          {{- with $cnt.livenessProbe }}
          livenessProbe:
            {{- tpl (toYaml .) $ | nindent 12 }}
          {{- end }}
          {{- with $cnt.readinessProbe }}
          readinessProbe:
            {{- tpl (toYaml .) $ | nindent 12 }}
          {{- end }}
          {{- with (merge ($cnt.resources | default dict) $depDefault.resources) }}
          resources:
            {{- tpl (toYaml .) $ | nindent 12 }}
          {{- end }}
{{- end }}