.SILENT:

ORG_NAME := "Archegos"
DEPLOYMENT := "dev-us-east-1"

default:
	aws --version
	gh version
	terraform -v
	terragrunt -v

add-dev-cluster:
	aws eks --region us-east-1 update-kubeconfig --name $(ORG_NAME)-dev-eks

plan-all:
	ORG_NAME=$(ORG_NAME) \
	DEPLOYMENT=$(DEPLOYMENT) \
	TF_VAR_kube_data_auth_enabled=false \
		terragrunt run-all plan --terragrunt-non-interactive

deploy-vpc:
	ORG_NAME=$(ORG_NAME) \
	DEPLOYMENT=$(DEPLOYMENT) \
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir vpc

destroy-vpc:
	ORG_NAME=$(ORG_NAME) \
	DEPLOYMENT=$(DEPLOYMENT) \
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir vpc

deploy-eks:
	ORG_NAME=$(ORG_NAME) \
	DEPLOYMENT=$(DEPLOYMENT) \
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir eks/cluster

destroy-eks:
	ORG_NAME=$(ORG_NAME) \
	DEPLOYMENT=$(DEPLOYMENT) \
	TF_VAR_kube_data_auth_enabled=true \
		terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir eks/cluster
