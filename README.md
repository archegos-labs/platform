# Platform (In Progress)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](http://www.opensource.org/licenses/MIT)

## Overview

Historically, I've been an end user of Kubernetes and IAC. Meaning I'm on an application team that uses those tools,
but doesn't setup the platform itself. This repository is a learning exercise in how to build out an application platform 
from scratch on top of AWS EKS that adheres to Infrastructure as Code (IaC) and GitOps practices using tools like Terraform, 
Terragrunt, Kubernetes, Flux and GitHub Actions.

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