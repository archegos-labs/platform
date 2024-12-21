locals {
  account = {
    account_id      = "123456789012"
    resource_prefix = "mock-resource-prefix"
    available_azs   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  vpc = {
    vpc_id          = "mock-vpc-1234567890abcdef0"
    private_subnets = ["mock-subnet-1234567890abcdef0", "mock-subnet-1234567890abcdef1", "mock-subnet-1234567890abcdef2"]
    public_subnets  = ["mock-subnet-1234567890abcdef3", "mock-subnet-1234567890abcdef4", "mock-subnet-1234567890abcdef5"]
  }

  eks = {
    cluster_name                       = "mock-cluster-name"
    cluster_version                    = "1.31"
    cluster_endpoint                   = "mock-cluster-endpoint"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg=="
  }

  prometheus = {
    namespace = "mock-namespace"
  }

  commands = ["init", "validate", "plan"]
}