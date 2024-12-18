# Platform (In Progress)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

This repository serves a playground and exercise in how to build out an ML focused application platform 
from scratch on top of AWS EKS that adheres to Infrastructure as Code (IaC) and GitOps practices using tools like Terraform, 
Terragrunt, Kubernetes, GitHub Actions and Kubeflow.

## Pre-Requisites
1. AWS Account & [AWS CLI](https://aws.amazon.com/cli/) - for managing AWS resources.
2. [Terraform](https://www.terraform.io) - for infrastructure as code.
3. [Terragrunt](https://terragrunt.gruntwork.io/) - for managing multiple Terraform environments.

I typically manage installations using [asdf](https://asdf-vm.com/), but to each their own. If you do use,
asdf, there is a `.tool-versions` file in the root of the project that you can use for installing.

## Github Actions

We're using the familiar good ole PR based workflow. This means IaC changes are validated and planeed in the PR and
once approved the infrastructure is deployed/applied on merge to main. The workflow is as follows:

1. Infrastructure changes are made on a branch and a PR is created against main
1. Terragrunt validate and plan are run on any changes. 
1. Validation and planning are run on every push to a branch 
1. Reviews and approvals are applied. Once the PR is approved, the PR is merged into main
1. IaC changes from the PR merge are then applied.

### Authentication & Authorization

AWS is accessed from GitHub Actions using OpenID Connect. GitHub acts as an Identity Provider (IDP) and AWS as a Service Provider (SP).
Authentication happens on GitHub, and then GitHub “passes” our user to an AWS account, saying that “this is really John Smith”, 
and AWS performs the “authorization“, that is, AWS checks whether this John Smith can create new resources. 

## EKS

The EKS cluster is setup using Terraform and Terragrunt. The cluster is setup with the following features:

* [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-how-it-works.html) is used where applicable and possible. 
* In addition to the default addons (kube-proxy, core-dns), the following are installed all using EKS Pod Identity:
  * [VPC CNI](https://docs.aws.amazon.com/eks/latest/best-practices/vpc-cni.html) 
  * [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/)
  * [External DNS](https://kubernetes-sigs.github.io/external-dns/latest/)
  * [Cert Manager](https://cert-manager.io/docs/)
   
### Access

Run the following to retrieve credentials for your cluster and configure `kubectl`,
```shell
make add-dev-cluster
```
Let's verify that we can access the cluster by running `kubectl cluster-info`. You should see output similiar to,

```
Kubernetes control plane is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Service Mesh

[Istio](https://istio.io/latest/docs/overview/what-is-istio/) is used for the service mesh layer. Istio’s powerful 
features provide a uniform and efficient way to secure, connect, and monitor services. Istio is the path to 
load balancing, service-to-service authentication, and monitoring – with few or no service code changes. It gives you:

1. Secure service-to-service communication in a cluster with mutual TLS encryption, strong identity-based authentication 
   and authorization
2. Automatic load balancing for HTTP, gRPC, WebSocket, and TCP traffic
3. Fine-grained control of traffic behavior with rich routing rules, retries, failovers, and fault injection
4. A pluggable policy layer and configuration API supporting access controls, rate limits and quotas
5. Automatic metrics, logs, and traces for all traffic within a cluster, including cluster ingress and egress

### Installation

Installation is done via Terraform and Terragrunt. After the EKS cluster is setup and Istio is installed on the cluster. 
The following needs to be run,

```shell
kubectl rollout restart deployment istio-ingress -n istio-ingress
```

## Kubeflow

The installation of kubeflow is done leveraging the [Terraform](https://github.com/awslabs/kubeflow-manifests/tree/main/deployments/vanilla/terraform) 
provided by AWS Labs on the [Kubeflow for AWS](https://awslabs.github.io/kubeflow-manifests/docs/deployment/vanilla/guide-terraform/) project.
In addition to the addons installed for the baseline EKS cluster above, we're also setting up the following addons
to support [Kubeflow](https://www.kubeflow.org/),

* [EBS-CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver) - Provides a CSI interface used by Container 
   Orchestrators to manage the lifecycle of Amazon EBS volumes.
* [EFS-CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver) - Provides a CSI interface used by Container 
   Orchestrators to manage the lifecycle of Amazon EFS volumes.
* [FsX-CSI Driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) - Provides a CSI specification for container orchestrators (CO) to manage lifecycle of Amazon FSx for Lustre filesystems.
* [NVida GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html) - The NVIDIA GPU Operator simplifies the deployment and management of GPU-accelerated applications on Kubernetes.