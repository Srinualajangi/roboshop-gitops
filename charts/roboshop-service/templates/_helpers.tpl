{{/* Name = release name unless overridden. Used as object name, DNS name and "app" label. */}}
{{- define "svc.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Labels on every object. "app" and "tier" are what Services, PDBs and NetworkPolicies select on. */}}
{{- define "svc.labels" -}}
app: {{ include "svc.name" . }}
tier: {{ .Values.tier }}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: roboshop
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Selector labels: small and NEVER changed after the first install (selectors are immutable). */}}
{{- define "svc.selector" -}}
app: {{ include "svc.name" . }}
{{- end -}}

{{/* registry/repository@digest, or registry/repository:tag */}}
{{- define "svc.image" -}}
{{- $repo := .Values.image.repository -}}
{{- if .Values.image.registry -}}{{- $repo = printf "%s/%s" .Values.image.registry .Values.image.repository -}}{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repo (required "set image.tag or image.digest" .Values.image.tag) -}}
{{- end -}}
{{- end -}}

{{- define "svc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "svc.name" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* The pod template shared by Deployment and StatefulSet */}}
{{- define "svc.podTemplate" -}}
metadata:
  labels:
    {{- include "svc.labels" . | nindent 4 }}
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  serviceAccountName: {{ include "svc.serviceAccountName" . }}
  automountServiceAccountToken: {{ .Values.serviceAccount.automountToken }}
  terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- range . }}
    - name: {{ . }}
    {{- end }}
  {{- end }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: {{ include "svc.name" . }}
      image: {{ include "svc.image" . }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- with .Values.args }}
      args:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.containerPort }}
      ports:
        - name: {{ .Values.portName }}
          containerPort: {{ .Values.containerPort }}
        {{- range .Values.extraPorts }}
        - name: {{ .name }}
          containerPort: {{ .containerPort }}
        {{- end }}
      {{- end }}
      {{- if and .Values.externalSecret.enabled .Values.externalSecret.envFrom }}
      envFrom:                      # every key of the ExternalSecret-created Secret becomes an env var
        - secretRef:
            name: {{ .Values.externalSecret.targetName }}
      {{- end }}
      {{- if or .Values.env .Values.secretEnv }}
      env:
        {{- range $k, $v := .Values.env }}
        - name: {{ $k }}
          value: {{ $v | quote }}
        {{- end }}
        {{- range .Values.secretEnv }}
        - name: {{ .name }}
          valueFrom:
            secretKeyRef:
              name: {{ .secretName }}
              key: {{ .key }}
        {{- end }}
      {{- end }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.startupProbe }}
      startupProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.readinessProbe }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.livenessProbe }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        {{- if .Values.tmpDir }}
        - name: tmp
          mountPath: /tmp
        {{- end }}
        {{- if and .Values.persistence.enabled (eq .Values.workload "StatefulSet") }}
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        {{- end }}
        {{- with .Values.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
  volumes:
    {{- if .Values.tmpDir }}
    - name: tmp
      emptyDir:
        sizeLimit: 64Mi
    {{- end }}
    {{- with .Values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
