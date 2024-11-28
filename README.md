# Platform (In Progress)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

## Pre-Requisites
1. AWS Account & [AWS CLI](https://aws.amazon.com/cli/) - for managing AWS resources.
2. [Terraform](https://www.terraform.io) - for infrastructure as code.
3. [Terragrunt](https://terragrunt.gruntwork.io/) - for managing multiple Terraform environments.
 
## VPC

## EKS

### Accessing EKS

Run the following command to retrieve the access credentials for your cluster and configure `kubectl`, 
```shell
awsd eks --region us-east-1 update-kubeconfig --name archegos-dev-eks
```

Let's verify that we can access the cluster by running `kubectl cluster-info`. You should see output similiar to,

```
Kubernetes control plane is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```


## Flux


## Kubeflow