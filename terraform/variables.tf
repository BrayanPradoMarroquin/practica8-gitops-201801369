variable "project_id" {
  description = "ID del proyecto de GCP"
  type        = string
  default     = "practica6-sa-201801369"
}

variable "region" {
  description = "Región de GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona de GCP donde se crea el cluster"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Nombre del cluster GKE"
  type        = string
  default     = "practica8-gke-cluster"
}

variable "namespace" {
  description = "Namespace principal de la practica 8"
  type        = string
  default     = "sa-p8"
}