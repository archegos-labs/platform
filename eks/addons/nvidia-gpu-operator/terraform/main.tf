locals {
  namespace  = "gpu-operator"
  addon_name = "gpu-operator"
}

/**
  Code: https://github.com/NVIDIA/gpu-operator
  Docs: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html
*/
module "nvidia_gpu_operator" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name             = "nvidia-${local.addon_name}"
  description      = "A Helm chart to deploy nvidia-gpu-operator"
  namespace        = local.namespace
  create_namespace = true
  chart            = local.addon_name
  chart_version    = "v25.3.2"
  repository       = "https://helm.ngc.nvidia.com/nvidia"

  wait          = true
  wait_for_jobs = true
}
