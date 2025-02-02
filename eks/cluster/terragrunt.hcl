include "root" {
  path = find_in_parent_folders()
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.28.0"
}

dependency "account" {
  config_path = "${dirname(find_in_parent_folders())}/account"

  mock_outputs                            = include.mocks.locals.account
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"

  mock_outputs                            = include.mocks.locals.vpc
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

locals {
  eks_admin_user  = "archegos-admin"
  deployment_user = "tf-deployer"
}

inputs = {
  cluster_name    = "${dependency.account.outputs.resource_prefix}-eks"
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

  vpc_id                   = dependency.vpc.outputs.vpc_id
  subnet_ids               = concat(dependency.vpc.outputs.private_subnets, dependency.vpc.outputs.public_subnets)
  control_plane_subnet_ids = dependency.vpc.outputs.private_subnets
  enable_irsa              = false

  create_cloudwatch_log_group = false

  access_entries = {
    archegos-admin = {
      principal_arn = "arn:aws:iam::${dependency.account.outputs.account_id}:user/${local.eks_admin_user}"
      user_name     = local.eks_admin_user
      policy_associations = {
        eks-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }

    deployer = {
      principal_arn = "arn:aws:iam::${dependency.account.outputs.account_id}:role/${local.deployment_user}"
      role_name     = local.deployment_user
      policy_associations = {
        eks-admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # For more, https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
  cluster_addons = {
    eks-pod-identity-agent = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.large"]
    capacity_type  = "SPOT"
  }

  eks_managed_node_groups = {
    cpus_group_one = {
      name         = "ondemand-cpu"
      min_size     = 0
      max_size     = 6
      desired_size = 2

      taints = {
        spotInstance = {
          key    = "spotInstance"
          value  = "true"
          effect = "PREFER_NO_SCHEDULE"
        }
      }
    }

    cpus_group_two = {
      name         = "ondemand-cpu"
      min_size     = 0
      max_size     = 6
      desired_size = 2

      taints = {
        spotInstance = {
          key    = "spotInstance"
          value  = "true"
          effect = "PREFER_NO_SCHEDULE"
        }
      }
    }

    gpus = {
      name           = "ondemand-gpu"
      instance_types = ["g4dn.xlarge"]
      ami_type       = "AL2023_x86_64_NVIDIA"
      subnet_ids     = dependency.vpc.outputs.private_subnets
      min_size       = 1
      max_size       = 3
      desired_size   = 2

      ebs_optimized = true
      /**
       * Best Practice: Use EBS gp3 volumes for GPU workloads
       * https://docs.aws.amazon.com/eks/latest/best-practices/cost-opt-storage.html#_ephemeral_volumes
       *
       * This block device is used only for root volume. Adjust volume according to your size. We need to
       * ensure that the root volume is large enough to accommodate the docker images, GPU drivers and other software.
       */
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            volume_size           = 50
            volume_type           = "gp3"
          }
        }
      }

      labels = {
        "nvidia.com/gpu.present" = "true"
      }

      taints = {
        # Ensure only GPU workloads are scheduled on this node group
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }

        # We read and write training data and models to & from FSx for Lustre so it needs to be ready
        fsx = {
          key    = "fsx.csi.aws.com/agent-not-ready"
          effect = "NO_EXECUTE"
        }
      }
    }
  }


  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
}