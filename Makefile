all: lint build

build:
	docker compose up -d kafka --wait
	terraform -chdir=terraform plan -out=tfplan

clean:
	terraform -chdir=terraform apply -auto-approve -destroy -input=false
	docker compose down -t 0

deploy:
	docker compose up -d kafka --wait
	terraform -chdir=terraform apply -auto-approve -input=false tfplan

lint:
	yamllint -s .
	terraform -chdir=terraform fmt -diff -check -recursive
	terraform -chdir=terraform init
	terraform -chdir=terraform validate
	tflint --chdir=terraform --recursive
