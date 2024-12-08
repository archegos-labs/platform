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
 
## Github Actions

### Authentication & Authorization

AWS is accessed from GitHub Actions using OpenID Connect. GitHub acts as an Identity Provider (IDP) and AWS as a Service Provider (SP).
Authentication happens on GitHub, and then GitHub “passes” our user to an AWS account, saying that “this is really John Smith”, 
and AWS performs the “authorization“, that is, AWS checks whether this John Smith can create new resources. 