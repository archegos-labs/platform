variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "prometheus_namespace" {
  description = "Prometheus name space"
  type        = string
  default     = "monitoring"
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    If `true`, use an `aws_eks_cluster_auth` data source to authenticate to the EKS cluster.
    EOT
  nullable    = false
}
