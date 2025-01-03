# Platform - Under Development
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

This repository serves as a playground and exercise in how to build out an ML focused application platform 
from scratch on top of AWS EKS that adheres to Infrastructure as Code (IaC) and GitOps practices using tools like Terraform,
Terragrunt, Kubernetes, GitHub Actions and Kubeflow. 

<!-- toc-begin -->
* [Pre-requisites](#pre-requisites)
* [Setup](#setup)
* [Networking](#networking)
* [EKS](#eks)
* [Service Mesh](#service-mesh)
* [Kubeflow](#kubeflow)
* [Github Actions](#github-actions)
<!-- toc-end -->

### Donations

Should you find any of this project useful, please consider donating through,

<a href="https://www.buymeacoffee.com/aeden" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

At a minimum it helps with the AWS bill.


## Pre-Requisites
If you're following along, at a minimum you'll need the following,
 
1. [AWS Account](https://aws.amazon.com/resources/create-account/) with the following service quotas,
   * Amazon EC2 Instances - Running On-Demand G and VT instances = 32
   * Amazon EC2 Instances - All Demand G and VT Spot Instance Requests = 32
2. [Docker](https://docs.docker.com/get-started/get-docker/) - for containerization.

I manage tool installations using [asdf](https://asdf-vm.com/), but to each their own. If you do use,
asdf, there is a `.tool-versions` file in the root of the project, which can be used to
install all the listed below by running `asdf install`. After doing this refresh your shell by running `exec $SHELL`.

3. [AWS CLI](https://aws.amazon.com/cli/) - setup with administrative access to make demonstration easy. 
4. [Github CLI](https://cli.github.com/) - for managing GitHub resources.
5. [Terraform](https://www.terraform.io) - for infrastructure as code.
6. [Terragrunt](https://terragrunt.gruntwork.io/) - for managing multiple Terraform environments.
7. [Kubectl](https://kubernetes.io/docs/tasks/tools/) - for managing Kubernetes clusters.


Verify you have the pre-requisites installed by running the following,

```shell
make
````

You should see version output for each of the tools listed above.

## Setup 

Let's first fork and clone the repo,

```shell
gh repo fork archegos-labs/platform --clone ~/projects/platform; cd ~/projects/platform
```

Next validate that the IaC setup will run with,

```shell
make plan-all org_name="ExampleOrg"
```
This runs Terragrunt / Terraform plan on all the modules in the repository. 

## Networking

Our first step is to set up a Virtual Private Cloud (VPC) and its subnets where our EKS cluster will live. The VPC will
look like the following,

![eks-ready-vpc.drawio.svg](vpc/docs/eks-ready-vpc.drawio.svg)

The notable features of the VPC setup are,

* There are sufficient IP addresses for the cluster and apps on it. The IP CIDR block is `10.0.0.0 / 16`.
* Subnets in multiple availability zones (AZ) for high availability. 
* There are private and public subnets in each availability zone for granular control of inbound and outbound traffic. 
  Private subnets are for the EKS nodes with no direct internet access and public subnets for receiving and managing 
  internet traffic. 
* NAT Gateways in each public subnet of each availability zone to ensure zone-independent architecture 
  and reduce cross AZ expenditures.
* The default NACL is associated with each subnet in the VPC.

If your AWS account and CLI are setup, you can run the following to create the VPC and subnets,

```shell 
make deploy-vpc
```
After the VPC is created, you can view many of its components as illustrated in the diagram above by running,

```shell
aws resourcegroupstaggingapi get-resources \
  --resource-type-filters \
      ec2:vpc \
      ec2:subnet \
      ec2:natgateway \
      ec2:internet-gateway \
      ec2:route-table \
      ec2:elastic-ip \
      ec2:network-interface \
      ec2:security-group \
      ec2:network-acl \
  --query 'ResourceTagMappingList[].{ARN:ResourceARN,Name:Tags[?Key==`Name`].Value | [0]}' \
  --output table
```

#### References
 
* [EKS Network Requirements](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)
* [EKS VPC & Subnet Considerations](https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html)
* [AWS VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
* [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
* [Route Tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)

## EKS

Next we'll setup an EKS cluster within the VPC laid out above. The basics of the setup will look like,

![eks-cluster.drawio.svg](eks/docs/eks-cluster.drawio.svg)

The most notable features of the EKS cluster setup are,
 * Two node groups, one for general purpose workloads and one for GPU workloads.
 * API server endpoint access is public and private.
 * Appropriate security groups attached to network interfaces.

In addition to node and security layout above, the following addons are installed,

* [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-how-it-works.html) is used where applicable and possible.
* In addition to the default addons (kube-proxy, core-dns), the following are installed all using EKS Pod Identity:
    * [VPC CNI](https://docs.aws.amazon.com/eks/latest/best-practices/vpc-cni.html)
    * [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/)
    * [External DNS](https://kubernetes-sigs.github.io/external-dns/latest/)
    * [Cert Manager](https://cert-manager.io/docs/)

To deploy the EKS cluster run the following,
    
```shell
make deploy-eks
```

### Access

Run the following to retrieve credentials for your cluster and configure `kubectl`,
```shell
make add-cluster
```
Let's verify that we can access the cluster by running `kubectl cluster-info`. You should see output similiar to,

```
Kubernetes control plane is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

#### References
* [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
* [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)



## Service Mesh

Our next step on the journey of getting Kubeflow up on AWS is setting up [Istio.](https://istio.io/latest/docs/overview/what-is-istio/) 
Istio’s powerful features provide a uniform and efficient way to secure, connect, and monitor services. Kubeflow
is a collection of tools, frameworks and services that are stiched together to provide a seamless ML platform under
Istio. Below are some of the features Kubeflow leverages, 

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

#### References
* [Why Kubeflow Needs Istio](https://www.kubeflow.org/docs/concepts/multi-tenancy/istio/#why-kubeflow-needs-istio)
* [Istio](https://istio.io/latest/docs/overview/what-is-istio/)

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
* [FsX-CSI Driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) - Provides a CSI specification for container 
  orchestrators (CO) to manage lifecycle of Amazon FSx for Lustre filesystems.
* [NVida GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html) - 
  The NVIDIA GPU Operator simplifies the deployment and management of GPU-accelerated applications on Kubernetes.

### Training Operator

The [Kubeflow Training Operator](https://www.kubeflow.org/docs/components/training/overview/) allows you to use
Kubernetes workloads to train large models with Kubernetes Custom Resources APIs or using the Training Operator Python SDK.
The operators primary use case is the ability to run *distributed training and fine-tuning*. After installing the operator 
we'll demonstrate how to run a training job.

Before running the example you'll need to,

* Have Kubectl installed. 
* Run `make add-cluster` to add the dev cluster created above to your kubeconfig.
* Have Docker installed. 

With the above in place let's go through a few examples. 

#### Example 1: Distributed Training Using Python SDK

We're going to run a Jupyter notebook through Docker locally to submit and monitor 
a distributed Pytorch training job. To run the Jupyter notebook,

1. Run the following at the root of the project,
```shell
docker run --rm -p 8888:8888 -e JUPYTER_ENABLE_LAB=yes -e GRANT_SUDO=yes \
  --user root \
  -v ~/.kube:/home/jovyan/.kube \
  -v ~/.aws:/home/jovyan/.aws \
  -v ./examples:/home/jovyan/work \
  quay.io/jupyter/pytorch-notebook 
```

2. Navigate to the URL provided in the output of the command above. For example,

```
...
Or copy and paste one of these URLs:
        http://e16d3018c90e:8888/lab?token=161c548d8a560266b0e76323276322a1f3ecaf8da32d1de2
        http://127.0.0.1:8888/lab?token=161c548d8a560266b0e76323276322a1f3ecaf8da32d1de2
```

3. Open the notebook at `work/training-operator/pytorchjobs/python-sdk-distributed-training.ipynb` and follow the instructions.
 
That's it! You've run your first distributed training job using the Kubeflow Training Operator.

#### Example 2: Fine-Tune an LLM



### Pipelines

Coming Soon


### FSx for Lustre (Coming Soon)

We make use of FSx for Lustre to provide a high-performance file system for Kubeflow. This supports the performance of
loading large datasets for model training.

TODO: How does this get leveraged in jobs?

#### References


* [Kubeflow Training Operator](https://www.kubeflow.org/docs/components/training/overview/)



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

