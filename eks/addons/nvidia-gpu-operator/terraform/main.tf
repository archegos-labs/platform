locals {
  namespace = "gpu-operator"
  addon_name = "nvidia-gpu-operator"
}

/**
  Code: https://github.com/NVIDIA/gpu-operator
  Docs: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html
*/
module "nvidia-gpu-operator" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name             = local.addon_name
  description      = "A Helm chart to deploy nvidia-gpu-operator"
  namespace        = local.namespace
  create_namespace = true
  chart            = local.addon_name
  chart_version    = "24.6.2"
  repository       = "https://helm.ngc.nvidia.com/nvidia"

  wait                       = true
  wait_for_jobs              = true
}
