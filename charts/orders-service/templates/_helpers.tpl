{{- define "orders-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "orders-service.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "orders-service.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "orders-service.labels" -}}
app.kubernetes.io/name: {{ include "orders-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}