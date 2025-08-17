module "aws_vpc_cni_ipv4_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.0.0"

  name = "aws-vpc-cni-ip4-sa"

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true
}
