{{- define "books-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "books-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "books-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "books-service.labels" -}}
app.kubernetes.io/name: {{ include "books-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}