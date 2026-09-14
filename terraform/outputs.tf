output "namespace_name" {
  value       = kubernetes_namespace.sa_p8.metadata[0].name
  description = "Namespace creado"
}

output "quota_name" {
  value       = kubernetes_resource_quota.sa_p8_quota.metadata[0].name
  description = "ResourceQuota creada"
}

output "service_account" {
  value       = kubernetes_service_account.argo_deployer.metadata[0].name
  description = "ServiceAccount para ArgoCD"
}