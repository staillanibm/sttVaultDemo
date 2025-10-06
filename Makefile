IMAGE_NAME=ghcr.io/staillanibm/msr-vault-demo
TAG=latest
DOCKER_ROOT_URL=http://localhost:15555
DOCKER_ADMIN_PASSWORD=Manage123
KUBE_ROOT_URL=https://vault-demo.sttlab.local
KUBE_ADMIN_PASSWORD=Manage12345

docker-build:
	DOCKER_BUILDKIT=1 docker build -t $(IMAGE_NAME):$(TAG) --platform=linux/amd64 \
		--build-arg WPM_TOKEN=${WPM_TOKEN} --build-arg GIT_TOKEN=${GIT_TOKEN} .

docker-login-whi:
	@echo ${WHI_CR_PASSWORD} | docker login ${WHI_CR_SERVER} -u ${WHI_CR_USERNAME} --password-stdin

docker-login-gh:
	@echo ${GH_CR_PASSWORD} | docker login ${GH_CR_SERVER} -u ${GH_CR_USERNAME} --password-stdin

docker-push:
	docker push $(IMAGE_NAME):$(TAG)

docker-run:
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG}	docker-compose -f ./resources/docker-compose/docker-compose.yml up -d

docker-stop:
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG}	docker-compose -f ./resources/docker-compose/docker-compose.yml down

docker-logs:
	docker logs msr-contact-management

docker-logs-f:
	docker logs -f msr-contact-management

docker-test:
	echo "TODO"


