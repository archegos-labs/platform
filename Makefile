.SILENT:

platform_env ?= dev
region ?= us-east-1
org_name ?= Archegos
root_domain ?= $(ROOT_DOMAIN)
admin_email ?= $(ADMIN_EMAIL)

export ORG_NAME=$(shell echo $(org_name) | tr '[:upper:]' '[:lower:]')
export DEPLOYMENT=$(platform_env)-$(region)
export ROOT_DOMAIN := $(root_domain)
export ADMIN_EMAIL := $(admin_email)

require-deploy-vars:
	@if [ -z "$(ROOT_DOMAIN)" ]; then \
		echo "Error: ROOT_DOMAIN is not set. Pass 'root_domain=<domain>' or export ROOT_DOMAIN."; \
		exit 1; \
	fi
	@if [ -z "$(ADMIN_EMAIL)" ]; then \
		echo "Error: ADMIN_EMAIL is not set. Pass 'admin_email=<email>' or export ADMIN_EMAIL."; \
		exit 1; \
	fi

plan-all deploy-all destroy-all \
deploy-account destroy-account \
deploy-vpc destroy-vpc \
deploy-dex destroy-dex \
deploy-eks destroy-eks \
deploy-eks-addons destroy-eks-addons \
deploy-prometheus destroy-prometheus \
deploy-istio destroy-istio \
deploy-kiali destroy-kiali \
deploy-kubeflow destroy-kubeflow: require-deploy-vars

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
	terragrunt plan --all --non-interactive

deploy-all:
	echo "Apply all resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive

destroy-all:
	echo "Destroying all resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive

deploy-account:
	echo "Applying Account resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir account --queue-strict-include

destroy-account:
	echo "Destroying Account resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir account --queue-strict-include

deploy-dex:
	echo "Applying Dex (auth) to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir auth/dex --queue-strict-include

destroy-dex:
	echo "Destroying Dex (auth) from EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir auth/dex --queue-strict-include

deploy-vpc:
	echo "Applying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir vpc

destroy-vpc:
	echo "Destroying all VPC resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir vpc

deploy-eks:
	echo "Applying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir eks/setup --queue-include-dir eks/cluster --queue-strict-include

destroy-eks:
	echo "Destroying all EKS resources for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir eks/setup --queue-include-dir eks/cluster --queue-strict-include

addons ?=
deploy-eks-addons:
	echo "Applying EKS addons for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	@if [ -z "$(addons)" ]; then \
		echo "Error: Please specify addons. Example: make apply addons='folder1 folder2'"; \
		exit 1; \
	fi
	@for a in $(addons); do \
	  echo "Applying Terragrunt in directory: $$a" ; \
	  terragrunt apply --all \
	    --non-interactive \
	    --queue-include-dir eks/addons/$$a \
	    --queue-strict-include ; \
	done

destroy-eks-addons:
	echo "Destroying EKS addons for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	@if [ -z "$(addons)" ]; then \
		echo "Error: Please specify addons. Example: make apply addons='folder1 folder2'"; \
		exit 1; \
	fi
	@for a in $(addons); do \
	  echo "Destorying Terragrunt in directory: $$a" ; \
	  terragrunt destroy --all \
	    --non-interactive \
	    --queue-include-dir eks/addons/$$a \
	    --queue-strict-include ; \
	done

deploy-prometheus:
	echo "Applying Prometheus to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir prometheus --queue-strict-include

destroy-prometheus:
	echo "Destroying Prometheus to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir prometheus --queue-strict-include

deploy-istio:
	echo "Applying Istio to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir istio/system --queue-strict-include

destroy-istio:
	echo "Destroying Istio to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir istio/system --queue-strict-include

deploy-kiali:
	echo "Applying Kiali to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir istio/kiali --queue-strict-include

destroy-kiali:
	echo "Destroying Kiali to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir istio/kiali --queue-strict-include

deploy-kubeflow:
	echo "Applying Kubeflow to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt apply --all --non-interactive --queue-include-dir kubeflow --queue-strict-include

destroy-kubeflow:
	echo "Destroying Kubeflow to EKS for ORG: $(org_name), DEPLOYMENT: $(DEPLOYMENT)"
	terragrunt destroy --all --non-interactive --queue-include-dir kubeflow --queue-strict-include
