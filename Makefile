SHELL := /bin/bash
.DEFAULT_GOAL := help

TF        ?= terraform
TF_DIRS   := $(sort $(dir $(wildcard modules/*/main.tf))) examples/complete/
CHARTS    := $(wildcard modules/*/charts/*)

.PHONY: help fmt fmt-check validate lint charts rules security check clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Format Terraform files in place
	$(TF) fmt -recursive

fmt-check: ## Fail if any file is not formatted
	$(TF) fmt -check -recursive

validate: ## terraform init -backend=false + validate for every module and example
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d validate; \
	done

lint: ## Run tflint against every module and example
	tflint --init --config=$(CURDIR)/.tflint.hcl
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		tflint --chdir=$$d --config=$(CURDIR)/.tflint.hcl; \
	done

charts: ## helm lint + render every local chart (scale-to-zero path included)
	@set -e; for c in $(CHARTS); do \
		echo "==> $$c"; \
		helm lint $$c --set clusterName=ci --set nodeRole=ci-node-role; \
	done
	helm template ci modules/inference/charts/vllm-service \
		--set autoscaling.minReplicas=0 --set 'autoscaling.wakeQuery=sum(rate(x[1m]))' >/dev/null
	helm template ci modules/gpu-nodepools/charts/gpu-nodepools \
		--set clusterName=ci --set nodeRole=ci-node-role --set nodeClass.os=bottlerocket >/dev/null

rules: ## Render the GPU PrometheusRule and check it with promtool
	@tmp=$$(mktemp -d); \
	helm template ci modules/gpu-stack/charts/gpu-alerts \
		| awk '/^spec:/{f=1; next} f' | sed 's/^  //' > $$tmp/rules.yaml; \
	promtool check rules $$tmp/rules.yaml; rc=$$?; rm -rf $$tmp; exit $$rc

security: ## Static security scan with trivy
	trivy config --severity HIGH,CRITICAL --exit-code 1 --skip-dirs '**/.terraform' .

check: fmt-check validate lint charts rules security ## Everything CI runs

clean: ## Remove local Terraform caches
	find . -type d -name .terraform -prune -exec rm -rf {} +
	find . -name .terraform.lock.hcl -delete
