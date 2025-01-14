.SILENT:

region ?= us-east-1
platform_env ?= dev
org_name ?= Archegos

export ORG_NAME=$(shell echo $(org_name) | tr '[:upper:]' '[:lower:]')
export DEPLOYMENT=$(platform_env)-$(region)
export TF_VAR_kube_data_auth_enabled=true

default:
	aws --version
	kubectl version --client
	docker --version
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

apply-all:
	echo "Apply all resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive

destroy-all:
	echo "Destroying all resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive

deploy-vpc:
	echo "Applying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir vpc

destroy-vpc:
	echo "Destroying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir vpc

deploy-eks:
	echo "Applying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir eks/cluster --terragrunt-strict-include

destroy-eks:
	echo "Destroying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir eks/cluster --terragrunt-strict-include

addons ?=
deploy-eks-addons:
	echo "Applying EKS addons for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	@if [ -z "$(addons)" ]; then \
		echo "Error: Please specify addons. Example: make apply addons='folder1 folder2'"; \
		exit 1; \
	fi
	@for a in $(addons); do \
	  echo "Applying Terragrunt in directory: $$a" ; \
	  terragrunt run-all apply \
	    --terragrunt-non-interactive \
	    --terragrunt-include-dir eks/addons/$$a \
	    --terragrunt-strict-include ; \
	done

destroy-eks-addons:
	echo "Destroying EKS addons for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	@if [ -z "$(addons)" ]; then \
		echo "Error: Please specify addons. Example: make apply addons='folder1 folder2'"; \
		exit 1; \
	fi
	@for a in $(addons); do \
	  echo "Destorying Terragrunt in directory: $$a" ; \
	  terragrunt run-all destroy \
	    --terragrunt-non-interactive \
	    --terragrunt-include-dir eks/addons/$$a \
	    --terragrunt-strict-include ; \
	done

deploy-prometheus:
	echo "Applying Prometheus to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir prometheus --terragrunt-strict-include

destroy-prometheus:
	echo "Destroying Prometheus to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir prometheus --terragrunt-strict-include

deploy-istio:
	echo "Applying Istio to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir istio/system --terragrunt-strict-include

destroy-istio:
	echo "Destroying Istio to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir istio/system --terragrunt-strict-include

deploy-kiali:
	echo "Applying Kiali to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir istio/kiali --terragrunt-strict-include

destroy-kiali:
	echo "Destroying Kiali to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all destroy --terragrunt-non-interactive --terragrunt-include-dir istio/kiali --terragrunt-strict-include

deploy-kubeflow:
	echo "Applying Kubeflow to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt run-all apply --terragrunt-non-interactive --terragrunt-include-dir kubeflow
