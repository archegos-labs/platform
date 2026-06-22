# Platform - Under Development
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

This repository serves as a playground and exercise in how to build out an ML focused application platform 
from scratch on top of AWS EKS that adheres to Infrastructure as Code (IaC) and GitOps practices using tools like Terraform,
Terragrunt, Kubernetes, GitHub Actions and Kubeflow. 

<!-- toc-begin -->
* [Pre-requisites](#pre-requisites)
* [Setup](#setup)
* [Account & Domain](#account--domain)
* [Networking](#networking)
* [EKS](#eks)
* [Authentication (Dex)](#authentication-dex)
* [Monitoring](#monitoring)
* [Service Mesh](#service-mesh)
* [Kubeflow](#kubeflow)
* [Teardown](#teardown)
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
2. A **registered domain with a public [Route 53](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)
   hosted zone** in the same AWS account. The hosted-zone name must match the `ROOT_DOMAIN` you deploy with — the
   `account` module looks it up, and every admin UI is published at `*.admin.<ROOT_DOMAIN>` with ACM certificates and
   Route 53 records created automatically (via `external-dns`).
3. [Docker](https://docs.docker.com/get-started/get-docker/) - for containerization.

I manage tool installations using [asdf](https://asdf-vm.com/), but to each their own. If you do use
asdf, there is a `.tool-versions` file in the root of the project, which can be used to
install everything listed below by running `asdf install`. After doing this refresh your shell by running `exec $SHELL`.

4. [AWS CLI](https://aws.amazon.com/cli/) - setup with administrative access to make demonstration easy. 
5. [Github CLI](https://cli.github.com/) - for managing GitHub resources.
6. [Terraform](https://www.terraform.io) - for infrastructure as code.
7. [Terragrunt](https://terragrunt.gruntwork.io/) - for managing multiple Terraform modules.
8. [Kubectl](https://kubernetes.io/docs/tasks/tools/) - for managing Kubernetes clusters.


Verify you have the pre-requisites installed by running the following,

```shell
make
```

You should see version output for each of the tools listed above.

## Setup 

Let's first fork and clone the repo,

```shell
gh repo fork archegos-labs/platform --clone ~/projects/platform; cd ~/projects/platform
```

Every `make` target that touches infrastructure requires the three inputs below. Each can be passed on the command
line (`name=value`) or set as the matching environment variable:

| Make param | Env var | Required | Description |
|---|---|---|---|
| `org_name` | `ORG_NAME` | **yes** | Organization name; used to prefix resources and the cluster name. |
| `root_domain` | `ROOT_DOMAIN` | **yes** | Your Route 53 hosted-zone domain (e.g. `example.com`). Admin UIs live at `*.admin.<root_domain>`. |
| `admin_email` | `ADMIN_EMAIL` | **yes** | Email of the initial platform admin (the Dex static-password user / Grafana admin). |

> Targets fail fast with a clear error if any of `ORG_NAME`, `ROOT_DOMAIN`, or `ADMIN_EMAIL` is missing.

The walkthrough below uses bare `make deploy-*` commands, so the simplest approach is to **export the three values
once** and reuse them throughout your shell session:

```shell
export ORG_NAME="ExampleOrg" ROOT_DOMAIN="example.com" ADMIN_EMAIL="admin@example.com"
```

Next validate that the IaC setup will run with,

```shell
make plan-all
```

This runs Terragrunt / Terraform plan on all the modules in the repository.

### Quickstart

To stand up the entire stack in one shot (Terragrunt resolves the dependency order automatically), with the three
values exported as above:

```shell
make deploy-all
```

Or follow the detailed, per-component walkthrough below. The components must be applied in this order
(each `make deploy-*` applies only its own module, so earlier layers must already exist):

```
account → vpc → eks (+ add-cluster) → core addons (cert-manager, awslb-controller, external-dns)
        → dex → prometheus → istio → kiali → kubeflow addons (ebs/efs/fsx/nvidia) → kubeflow
```

## Account & Domain

The `account` module establishes account-wide values the rest of the platform depends on — the resource prefix,
account id, and the **Route 53 hosted zone** for your `ROOT_DOMAIN`. Apply it first,

```shell
make deploy-account
```

Every admin-facing UI in this platform is published on an internet-facing ALB at `*.admin.<ROOT_DOMAIN>`
(e.g. `dex.admin.example.com`, `grafana.admin.example.com`, `kiali.admin.example.com`,
`dashboard.admin.example.com`) and is gated behind single sign-on (see [Authentication](#authentication-dex)).

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
 * A default set of addons fundamental to the operation of the cluster.
   * [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-how-it-works.html) -
     Allows you to assign IAM roles to Kubernetes service accounts. And is the preferred way to manage security.
   * [VPC CNI](https://docs.aws.amazon.com/eks/latest/best-practices/vpc-cni.html) - 
     Provides native integration with AWS VPC and works in underlay mode. In underlay mode, Pods and hosts are located 
     at the same network layer and share the network namespace. The IP address of the Pod is consistent from the cluster and VPC perspective.
   * [Kube Proxy](https://aws-quickstart.github.io/cdk-eks-blueprints/addons/kube-proxy/) - 
     Provides network proxy and load balancing between a service and its pods on a single worker node.
   * [CoreDNS](https://aws-quickstart.github.io/cdk-eks-blueprints/addons/coredns/) - 
     Provides service discovery and DNS resolution for Kubernetes.

### Deployment

1. To deploy the EKS cluster run the following,
    
```shell
make deploy-eks
```

2. Configure `kubectl` for access to the cluster by running,
```shell
make add-cluster
```
3. Lastly, let's verify that we can access the cluster by running `kubectl cluster-info`. You should see output similiar to,

```
Kubernetes control plane is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://7D3A825AA8E29A730955A485709E89D2.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Congratulations! You've successfully deployed an EKS cluster on AWS.

### Addons

In addition to the barebones EKS cluster, we'll need additional functionality in the form of addons on our
road to getting Kubeflow up and running. The first set are the **core** addons that everything else builds on,

* [Cert Manager](https://cert-manager.io/docs/) -
  Cert-manager creates TLS certificates for workloads in your Kubernetes or OpenShift cluster and renews the certificates before they expire.
* [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/) -
  Help manage Elastic Load Balancers for a Kubernetes cluster.
* [External DNS](https://kubernetes-sigs.github.io/external-dns/latest/) -
  Makes Kubernetes resources discoverable via public DNS servers. Unlike KubeDNS, however, it’s not a DNS server 
  itself, but merely configures other DNS providers accordingly—e.g. AWS Route 53 or Google Cloud DNS.

```shell
make deploy-eks-addons addons='cert-manager awslb-controller external-dns'
```

> The Kubeflow-specific addons (EBS/EFS/FSx CSI drivers and the NVIDIA GPU operator) are deployed later, in the
> [Kubeflow](#kubeflow) section.

### References
* [Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
* [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)

## Authentication (Dex)

All admin UIs (Grafana, Kiali, the Kubeflow Central Dashboard) sit behind single sign-on rather than being exposed
directly. [Dex](https://dexidp.io/) is the OpenID Connect (OIDC) identity provider, and an
[oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) reverse-proxy in front of each service authenticates
requests against it. Deploy Dex after the core addons (it needs cert-manager, the load balancer controller, and
external-dns):

```shell
make deploy-dex
```

Dex is published at `https://dex.admin.<ROOT_DOMAIN>`. A single static admin user is seeded from `ADMIN_EMAIL`; its
initial password is generated and stored in state. Retrieve it with,

```shell
cd auth/dex && terragrunt output -raw dex_admin_password
```

Use `ADMIN_EMAIL` + that password to sign in at any of the admin UIs below.

## Monitoring

A number of components we install depend on [Prometheus](https://prometheus.io/) for monitoring, with
[Grafana](https://grafana.com/) for visualization. Deploy them with,

```shell
make deploy-prometheus
```

The stack is installed into the `monitoring` namespace. Verify the pods are running,

```shell
kubectl -n monitoring get pods
```

Grafana is published at `https://grafana.admin.<ROOT_DOMAIN>` and signs in through Dex (basic auth is disabled — Dex
is the only credential path). The `ADMIN_EMAIL` user is granted the Grafana admin role.

* [Prometheus](https://prometheus.io/) - an open-source systems monitoring and alerting toolkit.

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

To deploy Istio to our EKS cluster run,

```shell
make deploy-istio
``` 

After the installation is complete, you can verify that the Istio control plane is up with, 

```shell
kubectl get pods -n istio-system
```

#### References
* [Why Kubeflow Needs Istio](https://www.kubeflow.org/docs/concepts/multi-tenancy/istio/#why-kubeflow-needs-istio)
* [Istio](https://istio.io/latest/docs/overview/what-is-istio/)

### Tools

In addition to the Istio control plane, the following tools are installed to support the service mesh,

* [Kiali](https://kiali.io/) - Configure, visualize, validate and troubleshoot your mesh! Kiali is a console for Istio service mesh.

#### Kiali
To deploy Kiali run the following,

```shell
make deploy-kiali
```
Kiali is installed in the `istio-system` namespace and published at `https://kiali.admin.<ROOT_DOMAIN>` (sign in via
Dex). Alternatively, for quick local access without going through the ingress, port-forward it,

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

In addition to the addons installed for the baseline EKS cluster above, [Kubeflow](https://www.kubeflow.org/) needs a
few storage and GPU addons. Deploy them first,

* [EBS-CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver) - Provides a CSI interface used by Container 
  Orchestrators to manage the lifecycle of Amazon EBS volumes.
* [EFS-CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver) - Provides a CSI interface used by Container 
  Orchestrators to manage the lifecycle of Amazon EFS volumes.
* [FSx-CSI Driver](https://github.com/kubernetes-sigs/aws-fsx-csi-driver) - Provides a CSI specification for container 
  orchestrators (CO) to manage lifecycle of Amazon FSx for Lustre filesystems.
* [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/amazon-eks.html) - 
  The NVIDIA GPU Operator simplifies the deployment and management of GPU-accelerated applications on Kubernetes.

```shell
make deploy-eks-addons addons='ebs-csi efs-csi fsx-csi nvidia-gpu-operator'
```

Then deploy Kubeflow (this requires the core addons, Dex, and Istio to already be in place):

```shell
make deploy-kubeflow
```

This installs the Kubeflow Central Dashboard, profiles, pipelines, an oauth2-proxy front door, and the Training
Operator. The dashboard is published at `https://dashboard.admin.<ROOT_DOMAIN>` (sign in via Dex). The platform
deploys the dashboard from the published `ghcr.io/kubeflow/dashboard/dashboard` image — the `dashboard/` directory in
the repo root is just a local clone of the upstream source and is gitignored (it is not part of any deploy).

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


## Teardown

To avoid ongoing AWS charges, tear the stack down when you're done. Each component has a `destroy-*` counterpart
(`destroy-kubeflow`, `destroy-kiali`, `destroy-istio`, `destroy-prometheus`, `destroy-dex`, `destroy-eks-addons`,
`destroy-eks`, `destroy-vpc`, `destroy-account`), or remove everything at once with,

```shell
make destroy-all
```

> ⚠️ Destroy using the **same** `ORG_NAME`, `ROOT_DOMAIN`, and `ADMIN_EMAIL` you deployed with — `ORG_NAME` is part of
> the Terragrunt remote-state bucket name (`terraform-state-<org>-<region>`), so a mismatch targets a different state
> and won't tear down your resources.

## Github Actions

We're using the familiar good ole PR based workflow. This means IaC changes are validated and planned in the PR and
once approved the infrastructure is deployed/applied on merge to main. The workflow is as follows:

1. Infrastructure changes are made on a branch and a PR is created against main
1. Terragrunt validate and plan are run on any changes.
1. Validation and planning are run on every push to a branch
1. Reviews and approvals are applied. Once the PR is approved, the PR is merged into main
1. IaC changes from the PR merge are then applied.

### Configuration

The workflows read the same deployment inputs from GitHub repository **variables** and **secrets**. Configure these
under *Settings → Secrets and variables → Actions* (and per-environment where applicable):

| Type | Name | Purpose |
|---|---|---|
| Variable | `ORG_NAME` | Organization name (resource prefix / cluster name). |
| Variable | `ROOT_DOMAIN` | Route 53 hosted-zone domain. |
| Variable | `ADMIN_EMAIL` | Initial platform admin email. |
| Secret | `AWS_ROLE_ARN` | IAM role assumed via OIDC (must be created out-of-band). |
| Secret | `SCORECARD_TOKEN` | Token used by the supply-chain (Scorecard) workflow. |

### Authentication & Authorization

AWS is accessed from GitHub Actions using OpenID Connect. GitHub acts as an Identity Provider (IDP) and AWS as a Service Provider (SP).
Authentication happens on GitHub, and then GitHub “passes” our user to an AWS account, saying that “this is really John Smith”,
and AWS performs the “authorization“, that is, AWS checks whether this John Smith can create new resources. 