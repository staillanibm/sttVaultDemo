DC=docker compose -f ./resources/compose/docker-compose.yml
VAULT_ADDR=https://vault.sttlab.local:8200
VAULT_BOOTSTRAP_DIR=./resources/compose/vault/bootstrap
VAULT_OUT_DIR=./resources/compose/vault/out
VAULT_INIT_JSON=$(VAULT_OUT_DIR)/init.json
VAULT_UNSEAL_KEY=$(VAULT_OUT_DIR)/unseal_key
VAULT_ROOT_TOKEN=$(VAULT_OUT_DIR)/root_token
VAULT_ROLE_ID=$(VAULT_OUT_DIR)/role_id
VAULT_SECRET_ID=$(VAULT_OUT_DIR)/secret_id
VAULT_JSON_FILE=./resources/compose/vault/bootstrap/secrets.json
VAULT_KV_MOUNT=secret
VAULT_KV_PATH=msr
VAULT_TRANSIT_KEY=msr-key

IMAGE_NAME=ghcr.io/staillanibm/msr-vault-demo
TAG=latest
DEPLOYMENT_NAME=msr-vault-demo
DOCKER_ROOT_URL=http://localhost:15555
DOCKER_ADMIN_PASSWORD=Manage123
KUBE_ROOT_URL=https://vault-demo.sttlab.local
KUBE_ADMIN_PASSWORD=Manage12345

.PHONY: vault-up vault-init vault-unseal vault-bootstrap vault-agent-up msr-up all clean-vault

vault-up:
	$(DC) up -d vault
	# Wait until Vault API is reachable (returns 200/429/501/503 even if sealed or uninitialized)
	until curl -s -o /dev/null -w "%{http_code}" $(VAULT_ADDR)/v1/sys/health | grep -Eq "^(200|429|501|503)$$"; do sleep 1; done

vault-chown:
	$(DC) up -d init-perms

vault-init: 
	mkdir -p $(VAULT_OUT_DIR)
	# If not initialized (checked via host CLI against $(VAULT_ADDR)), run operator init once
	if ! VAULT_ADDR=$(VAULT_ADDR) vault status -format=json 2>/dev/null | jq -e '.initialized==true' >/dev/null; then \
	  VAULT_ADDR=$(VAULT_ADDR) vault operator init -key-shares=1 -key-threshold=1 -format=json \
	    | tee $(VAULT_INIT_JSON) >/dev/null ; \
	  jq -r '.unseal_keys_b64[0]' $(VAULT_INIT_JSON) > $(VAULT_UNSEAL_KEY) ; \
	  jq -r '.root_token'          $(VAULT_INIT_JSON) > $(VAULT_ROOT_TOKEN) ; \
	fi
	@echo "Unseal key -> $(VAULT_UNSEAL_KEY) ; Root token -> $(VAULT_ROOT_TOKEN)"


vault-unseal:
	VAULT_ADDR=$(VAULT_ADDR) vault operator unseal "$$(cat $(VAULT_UNSEAL_KEY))" >/dev/null || true
	@echo "Vault unsealed."


vault-bootstrap:
	# Check login with root token (stored on host)
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault token lookup >/dev/null

	# Enable KV v2 at path "secret/" (idempotent)
	@if ! VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault secrets list -format=json | grep -q '"secret/"' ; then \
	  VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault secrets enable -path=secret -version=2 kv >/dev/null ; \
	fi

	# Load policy from file
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault policy write msr $(VAULT_BOOTSTRAP_DIR)/policy.hcl >/dev/null

	# Enable AppRole (idempotent)
	@if ! VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault auth list -format=json | grep -q '"approle/"' ; then \
	  VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault auth enable approle >/dev/null ; \
	fi

	# Create/Update AppRole using env file
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" \
	  bash -c 'ARGS=$$(grep -vE "^\s*#|^\s*$$" $(VAULT_BOOTSTRAP_DIR)/approle.env | tr "\n" " "); \
	  vault write auth/approle/role/msr $$ARGS >/dev/null'

	# Export role_id / secret_id to host files
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault read  -field=role_id  auth/approle/role/msr/role-id  > $(VAULT_ROLE_ID)
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault write -field=secret_id -f auth/approle/role/msr/secret-id > $(VAULT_SECRET_ID)
	@echo "role_id -> $(VAULT_ROLE_ID) ; secret_id -> $(VAULT_SECRET_ID)"

	# Enable Transit (idempotent)
	@if ! VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" \
	  vault secrets list -format=json | grep -q '"transit/"'; then \
	  VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" \
	    vault secrets enable transit >/dev/null; \
	fi

	# Create transit key if missing
	@if ! VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" \
	  vault read -format=json transit/keys/$(VAULT_TRANSIT_KEY) >/dev/null 2>&1; then \
	  VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" \
	    vault write transit/keys/$(VAULT_TRANSIT_KEY) type=aes256-gcm96 >/dev/null; \
	fi

vault-get-token:
	@echo "Generating Vault client token from AppRole credentials..."
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault write -field=secret_id -f auth/approle/role/msr/secret-id > $(VAULT_SECRET_ID)
	VAULT_ADDR=$(VAULT_ADDR) \
	vault write -field=token auth/approle/login \
	  role_id=$$(cat $(VAULT_ROLE_ID)) \
	  secret_id=$$(cat $(VAULT_SECRET_ID)) > $(VAULT_OUT_DIR)/client_token
	@echo "Token saved to $(VAULT_OUT_DIR)/client_token"


vault-load-secrets:
	@echo "Uploading $(VAULT_JSON_FILE) to $(VAULT_KV_MOUNT)/$(VAULT_KV_PATH)"
	@curl -sS -k \
	  -H "X-Vault-Token: $$(cat $(VAULT_ROOT_TOKEN))" \
	  -H "Content-Type: application/json" \
	  -X POST "$(VAULT_ADDR)/v1/$(VAULT_KV_MOUNT)/data/$(VAULT_KV_PATH)" \
	  -d "$$(jq -c '{data:.}' $(VAULT_JSON_FILE))" >/dev/null && \
	echo "Secrets written to $(VAULT_KV_MOUNT)/$(VAULT_KV_PATH)"


vault-agent-up: 
	VAULT_ADDR=$(VAULT_ADDR) VAULT_TOKEN="$$(cat $(VAULT_ROOT_TOKEN))" vault write -field=secret_id -f auth/approle/role/msr/secret-id > $(VAULT_SECRET_ID)
	VAULT_ADDR=http://127.0.0.1:8200 $(DC) up -d vault-agent
	@echo "Vault Agent up"

msr-up: 
	$(DC) up -d msr-vault-demo
	@echo "MSR up"

clean-vault:
	$(DC) down -v
	rm -f $(VAULT_INIT_JSON) $(VAULT_UNSEAL_KEY) $(VAULT_ROOT_TOKEN) $(VAULT_ROLE_ID) $(VAULT_SECRET_ID)



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
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG}	docker compose -f ./resources/compose/docker-compose.yml up -d

docker-stop:
	IMAGE_NAME=${IMAGE_NAME} TAG=${TAG}	docker compose -f ./resources/compose/docker-compose.yml down

docker-logs:
	docker logs $(DEPLOYMENT_NAME)

docker-logs-f:
	docker logs -f $(DEPLOYMENT_NAME)

docker-test:
	echo "TODO"

