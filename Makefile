# roboshop-gitops/Makefile — deploy RoboShop with Helm until Argo CD takes over (Phase 5). Run on the workstation.
ENV   ?= dev
NS    := roboshop-$(ENV)
CHART := charts/roboshop-service
DATA  := mongodb mysql redis rabbitmq
APPS  := catalogue user cart shipping ratings payment dispatch web
SVCS  := $(DATA) $(APPS)
VALUES = -f envs/$(ENV)/_common.yaml -f envs/$(ENV)/$$s.yaml

.PHONY: help lint template secrets deploy deploy-all status undeploy
help: ## list targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-11s %s\n",$$1,$$2}'
lint: ## helm lint the chart with every values file of ENV
	@for s in $(SVCS); do helm lint $(CHART) $(VALUES) --quiet >/dev/null || { echo "lint failed: $$s"; exit 1; }; done; echo "lint ok ($(ENV))"
template: ## render one service: make template ENV=dev SVC=catalogue
	@s=$(SVC); helm template $$s $(CHART) -n $(NS) $(VALUES)
secrets: ## mysql-root Secret from SSM /roboshop/ENV/mysql-root-password (replaced by External Secrets in Phase 5)
	@pw=$$(aws ssm get-parameter --name /roboshop/$(ENV)/mysql-root-password --with-decryption --query Parameter.Value --output text) && \
	kubectl -n $(NS) create secret generic mysql-root --from-literal=MYSQL_ROOT_PASSWORD="$$pw" --dry-run=client -o yaml | kubectl apply -f -
deploy: secrets ## helm upgrade --install every service into roboshop-ENV
	@for s in $(SVCS); do echo "==> $$s -> $(NS)"; helm upgrade --install $$s $(CHART) -n $(NS) --create-namespace $(VALUES) >/dev/null || exit 1; done
	@kubectl -n $(NS) get pods
deploy-all: ## deploy dev, qa and prod
	@for e in dev qa prod; do $(MAKE) --no-print-directory deploy ENV=$$e || exit 1; done
status: ## pods, services and routes in ENV
	kubectl -n $(NS) get pods,svc,httproute -o wide
undeploy: ## uninstall every release in ENV
	-@for s in $(SVCS); do helm uninstall $$s -n $(NS); done

