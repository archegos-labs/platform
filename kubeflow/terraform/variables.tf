variable "vpc_id" {
  description = "The Id of the VPC"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block allocated to the VPC"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "private_subnets" {
  description = "The private subnets of the EKS cluster"
  type        = list(string)
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    If `true`, use an `aws_eks_cluster_auth` data source to authenticate to the EKS cluster.
    EOT
  nullable    = false
}
