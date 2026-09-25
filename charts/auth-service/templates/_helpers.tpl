{{- define "auth-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth-service.fullname" -}}
{{- default .Chart.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "auth-service.labels" -}}
app.kubernetes.io/name: {{ include "auth-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "auth-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "auth-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}