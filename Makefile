.SILENT:

default:
	java -version
	docker -v
	terraform -v
	terragrunt -v

add-dev-cluster:
	aws eks --region us-east-1 update-kubeconfig --name archegos-dev-eks