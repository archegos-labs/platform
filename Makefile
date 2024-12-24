.SILENT:

region ?= us-east-1
platform_env ?= dev
org_name ?= Archegos

export ORG_NAME=$(shell echo $(org_name) | tr '[:upper:]' '[:lower:]')
export DEPLOYMENT=$(platform_env)-$(region)

default:
	aws --version
	gh version
	terraform -v
	terragrunt -v

add-cluster:
	echo "Adding Kube cluster for ORG: $(org_name), REGION: $(region), ENV: $(platform_env)"
	aws eks --region $(region) update-kubeconfig --name $(ORG_NAME)-$(platform_env)-eks

plan-all:
	echo "Planning all resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	TF_VAR_kube_data_auth_enabled=false \
		terragrunt run-all plan --terragrunt-non-interactive

deploy-vpc:
	echo "Applying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir vpc

destroy-vpc:
	echo "Destroying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir vpc

deploy-eks:
	echo "Applying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir eks/cluster

destroy-eks:
	echo "Destroying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir eks/cluster
