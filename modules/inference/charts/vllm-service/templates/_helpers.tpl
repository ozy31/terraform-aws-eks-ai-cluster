{{- define "vllm.labels" -}}
app.kubernetes.io/name: vllm
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
ai.platform/model: {{ .Values.model.servedName | quote }}
{{- end -}}

{{- define "vllm.selectorLabels" -}}
app.kubernetes.io/name: vllm
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* PersistentVolumes are cluster-scoped, so include the namespace in the name. */}}
{{- define "vllm.pvName" -}}
{{- printf "%s-%s-models" .Release.Namespace .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
