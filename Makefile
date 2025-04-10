all: lint build

build:
	DOCKER_BUILDKIT=0 COMPOSE_DOCKER_CLI_BUILD=0 docker-compose build
	docker compose up -d connect --wait
	terraform -chdir=terraform plan -out=tfplan

clean:
	terraform -chdir=terraform/azure apply -auto-approve -destroy -input=false
	terraform -chdir=terraform/kafka apply -auto-approve -destroy -input=false
	docker compose down -t 0
	rm -rf certs

deploy:
	docker compose up -d kafka --wait
	terraform -chdir=terraform apply -auto-approve -input=false tfplan

initiate-traffic:
	docker compose run --rm kccinit
	./data_gen.py

lint:
	yamllint -s .
	terraform -chdir=terraform fmt -diff -check -recursive
	terraform -chdir=terraform init
	terraform -chdir=terraform validate
	tflint --chdir=terraform --recursive
