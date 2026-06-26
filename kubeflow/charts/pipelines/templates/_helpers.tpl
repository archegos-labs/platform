{{/*
Single source of truth for the SeaweedFS S3-compatible endpoint (host:port).
Consumed by the central kfp-launcher and workflow-controller configmaps, and
passed to the profile-controller via OBJECT_STORE_ENDPOINT so the per-namespace
launcher / artifact-repositories configmaps it generates resolve the same
endpoint. Port 9000 is the Service's MinIO-compat port (it targets SeaweedFS :8333).
*/}}
{{- define "kubeflow-pipelines.s3Endpoint" -}}
seaweedfs.{{ .Values.kubeflow.namespace }}:9000
{{- end -}}
