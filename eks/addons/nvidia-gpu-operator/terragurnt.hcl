include "root" {
  path = find_in_parent_folders()
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/eks/cluster",
  ]
}

terraform {
  source = "tfr:///aws-ia/eks-data-addons/aws?version=1.35.0"
}

inputs = {
  /**
    Code: https://github.com/NVIDIA/gpu-operator
    Docs: https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html
  */
  enable_nvidia_gpu_operator = true

  nvidia_gpu_operator_helm_config = {
    version = "24.6.2"
  }
}
