TAG=latest
DEPLOYMENT_NAME=msr-vault-demo
DOCKER_ROOT_URL=http://localhost:15555

docker-build:
	@docker build -t $(IMAGE_NAME):$(TAG) --platform=linux/amd64 \
		--build-arg WPM_TOKEN=${WPM_TOKEN} --build-arg GIT_TOKEN=${GIT_TOKEN} .

docker-login-whi:
	@echo ${WHI_CR_PASSWORD} | docker login ${WHI_CR_SERVER} -u ${WHI_CR_USERNAME} --password-stdin

docker-login-gh:
	@echo ${GH_CR_PASSWORD} | docker login ${GH_CR_SERVER} -u ${GH_CR_USERNAME} --password-stdin

docker-push:
	docker push $(IMAGE_NAME):$(TAG)

docker-run:
	TAG=${TAG}	docker compose -f ./resources/compose/docker-compose.yml up -d

docker-stop:
	TAG=${TAG}	docker compose -f ./resources/compose/docker-compose.yml down

docker-clean:
	docker volume rm compose_vault-data compose_vault-token

docker-logs:
	docker logs $(DEPLOYMENT_NAME)

docker-logs-f:
	docker logs -f $(DEPLOYMENT_NAME)


