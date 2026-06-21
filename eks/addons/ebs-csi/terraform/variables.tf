variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "service_account" {
  description = "The name of the serivce account to use for the controller"
  type        = string
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-eot
    If `true`, authenticate to the EKS cluster via the `aws_eks_cluster` data source
    (endpoint/CA) plus an `aws eks get-token` exec credential. If `false`, fall back to
    the local kubeconfig context (the `make plan-all` path).
    eot
  nullable    = false
}
