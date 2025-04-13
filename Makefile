all: lint build

build:
	DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker-compose build

clean:
	terraform -chdir=terraform/azure apply -auto-approve -destroy -input=false
	terraform -chdir=terraform/kafka apply -auto-approve -destroy -input=false
	docker compose down -t 0
	rm -rf certs

lint:
	yamllint -s .
	terraform -chdir=terraform/azure fmt -diff -check -recursive
	terraform -chdir=terraform/kafka fmt -diff -check -recursive
	terraform -chdir=terraform/azure init
	terraform -chdir=terraform/kafka init
	terraform -chdir=terraform/azure validate
	terraform -chdir=terraform/kafka validate
	tflint --chdir=terraform/azure --recursive
	tflint --chdir=terraform/kafka --recursive
