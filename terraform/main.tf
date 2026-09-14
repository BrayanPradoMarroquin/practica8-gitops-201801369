terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "docker-desktop"  # Cambia si usas otro contexto
}

# Namespace principal
resource "kubernetes_namespace" "sa_p8" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "practica"                     = "p8"
    }
  }
}

# ResourceQuota
resource "kubernetes_resource_quota" "sa_p8_quota" {
  metadata {
    name      = "sa-p8-quota"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "4Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "8Gi"
      "pods"            = "20"
      "services"        = "10"
      "persistentvolumeclaims" = "5"
    }
  }
}

# LimitRange
resource "kubernetes_limit_range" "sa_p8_limits" {
  metadata {
    name      = "sa-p8-limits"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "200m"
        memory = "256Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = {
        cpu    = "1"
        memory = "1Gi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}

# ServiceAccount para ArgoCD (deployments)
resource "kubernetes_service_account" "argo_deployer" {
  metadata {
    name      = "argo-deployer"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
}

# Role para despliegues
resource "kubernetes_role" "deployer_role" {
  metadata {
    name      = "deployer-role"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
  rule {
    api_groups = ["", "apps", "batch", "autoscaling", "networking.k8s.io", "argoproj.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# RoleBinding
resource "kubernetes_role_binding" "deployer_binding" {
  metadata {
    name      = "deployer-binding"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.deployer_role.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argo_deployer.metadata[0].name
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
}