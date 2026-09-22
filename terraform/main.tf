terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# ------------------------------------------------------------------
# Provider de Google Cloud
# ------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ------------------------------------------------------------------
# Cluster GKE
# ------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # Elimina el node pool por defecto para definirlo aparte
  remove_default_node_pool = true
  initial_node_count       = 1

  # Evita que terraform bloquee el destroy por protección
  deletion_protection = false

  # Desactiva la red autorizada para el master (más simple para prácticas)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    }
  }

  # Canal de release estable
  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "primary-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 20

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      "practica" = "p8"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# ------------------------------------------------------------------
# Provider de Kubernetes apuntando al cluster GKE recién creado
# ------------------------------------------------------------------
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# ------------------------------------------------------------------
# Namespace principal
# ------------------------------------------------------------------
resource "kubernetes_namespace" "sa_p8" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "practica"                     = "p8"
    }
  }
}

# ------------------------------------------------------------------
# ResourceQuota
# ------------------------------------------------------------------
resource "kubernetes_resource_quota" "sa_p8_quota" {
  metadata {
    name      = "sa-p8-quota"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"           = "2"
      "requests.memory"        = "4Gi"
      "limits.cpu"             = "4"
      "limits.memory"          = "8Gi"
      "pods"                   = "20"
      "services"               = "10"
      "persistentvolumeclaims" = "5"
    }
  }
}

# ------------------------------------------------------------------
# LimitRange
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# ServiceAccount para ArgoCD (deployments)
# ------------------------------------------------------------------
resource "kubernetes_service_account" "argo_deployer" {
  metadata {
    name      = "argo-deployer"
    namespace = kubernetes_namespace.sa_p8.metadata[0].name
  }
}

# ------------------------------------------------------------------
# Role para despliegues
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
# RoleBinding
# ------------------------------------------------------------------
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