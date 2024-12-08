include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=20.28.0"
}

dependency "account" {
  config_path = "${dirname(find_in_parent_folders())}/account"

  mock_outputs = {
    account_id      = "123456789012"
    resource_prefix = "mock-resource-prefix"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"

  mock_outputs = {
    vpc_id = "mock-vpc-1234567890abcdef0"
    private_subnets = ["mock-subnet-1234567890abcdef0", "mock-subnet-1234567890abcdef1", "mock-subnet-1234567890abcdef2"]
    public_subnets = ["mock-subnet-1234567890abcdef3", "mock-subnet-1234567890abcdef4", "mock-subnet-1234567890abcdef5"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
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
    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.small"]
  }

  eks_managed_node_groups = {
    one = {
      name         = "node-group-1"
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name         = "node-group-2"
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}