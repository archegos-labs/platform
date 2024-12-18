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
  eks_admin_user = "archegos-admin"
}

inputs = {
  cluster_name    = "${dependency.account.outputs.resource_prefix}-eks"
  cluster_version = "1.31"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

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
    instance_types = ["t3.small"]
  }

  eks_managed_node_groups = {
    one = {
      name         = "ondemand-cpu-one"
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name         = "ondemand-cpu-two"
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

    gpus = {
      node_group_name = "ondemand-gpu"
      instance_types  = ["g4dn.xlarge"]
      min_size        = 1
      desired_size    = 1
      max_size        = 3
      ami_type        = "AL2_x86_64_GPU"
      disk_size       = 75
      subnet_ids      = dependency.vpc.outputs.private_subnets
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