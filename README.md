# Platform - Under Development
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

This repository serves a playground and exercise in how to build out an ML focused application platform
from scratch on top of AWS EKS that adheres to Infrastructure as Code (IaC) and GitOps practices using tools like Terraform,
Terragrunt, Kubernetes, GitHub Actions and Kubeflow.

<!-- toc-begin -->
* [Pre-requisites](#pre-requisites)
* [VPC & Networking](#vpc--networking)
* [Github Actions](#github-actions)
* [AWS EKS](#eks)
* [Service Mesh](#service-mesh)
* [Kubeflow](#kubeflow)
<!-- toc-end -->

### Donations

Should you find any of this project useful, please consider donating through,

<a href="https://www.buymeacoffee.com/aeden" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

At a minimum it helps with the AWS bill.


## Pre-Requisites
If you're following along, at a minimum you'll need the following,
 
1. AWS Account 
2. [AWS CLI](https://aws.amazon.com/cli/) setup locally - for managing AWS resources.
3. [Github CLI](https://cli.github.com/) - for managing GitHub resources.
4. [Terraform](https://www.terraform.io) - for infrastructure as code.
5. [Terragrunt](https://terragrunt.gruntwork.io/) - for managing multiple Terraform environments.

I typically manage installations using [asdf](https://asdf-vm.com/), but to each their own. If you do use,
asdf, there is a `.tool-versions` file in the root of the project that you can use for installing.

## Up & Running

```shell

```

## VPC & Networking

Our first step is to set up a Virtual Private Cloud (VPC) and subnets where our EKS cluster will live. The VPC will
look like the following,

![eks-ready-vpc.drawio.svg](vpc/docs/eks-ready-vpc.drawio.svg)

The notable features of the VPC setup are,

* There are sufficient IP addresses for the cluster and apps on it. The IP CIDR block is `10.0.0.0 / 16`.
* Subnets in multiple availability zones (AZ) for high availability. 
* There are private and public subnets in each availability zone for granular control inbound and outbound traffic. 
  Private subnets are for the EKS nodes with no direct internet access and public subnets for receiving and managing 
  internet traffic. 
* NAT Gateways in each public subnet of each availability zone to ensure zone-independent architecture 
  and reduce cross AZ expenditures.
* The default NACL is associated with each subnet in the VPC.
 
#### References
* [EKS Network Requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)
* [EKS VPC & Subnet Considerations](https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html)
* [AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
* [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
* [Route Tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
 
## Github Actions

We're using the familiar good ole PR based workflow. This means IaC changes are validated and planned in the PR and
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

#### References
1. [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)


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

This installation of Istio has been setup in [ambient mode](https://istio.io/latest/docs/ambient/overview/).

### Installation

Installation is done via Terraform and Terragrunt. After the EKS cluster is setup and Istio is installed on the cluster. 
The following needs to be run,

```shell
kubectl rollout restart deployment istio-ingress -n istio-ingress
```

### Tools

In addition to the Istio control plane, the following tools are installed to support the service mesh,

* [Kiali](https://kiali.io/) - Configure, visualize, validate and troubleshoot your mesh! Kiali is a console for Istio service mesh.
* [Prometheus](https://prometheus.io/) - Prometheus is an open-source systems monitoring and alerting toolkit.

#### Kiali

To access the Kiali dashboard, run the following,

```shell
kubectl port-forward svc/kiali 20001:20001 -n istio-system
```
Then navigate to `http://localhost:20001/` in your preferred web browser. Learn more accessing the Kiali dashboard [here](https://kiali.io/docs/installation/installation-guide/accessing-kiali/).

If you want the operator to re-process the Kiali CR (called “reconciliation”) without having to change the Kiali CR’s 
spec fields, you can modify any annotation on the Kiali CR itself. This will trigger the operator to reconcile the 
current state of the cluster with the desired state defined in the Kiali CR, modifying cluster resources if necessary 
to get them into their desired state. Here is an example illustrating how you can modify an annotation on a Kiali CR:

```shell
kubectl annotate kiali my-kiali -n istio-system --overwrite kiali.io/reconcile="$(date)"
```

For more details on the CR see [Kiali CR](https://kiali.io/docs/installation/installation-guide/creating-updating-kiali-cr/)

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

### Training Operator