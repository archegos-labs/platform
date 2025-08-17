output "vpc_cni_pod_identity_arn" {
  description = "The EKS Pod Identity ARN for the VPC CNI plugin"
  value = module.aws_vpc_cni_ipv4_pod_identity.iam_role_arn
}