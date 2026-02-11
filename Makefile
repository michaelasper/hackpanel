SHELL := /bin/bash
.DEFAULT_GOAL := help

SWIFT ?= swift
SANITY_SCRIPT ?= ./Scripts/spm_sanity_check.sh

.PHONY: help build test test-app test-gateway run sanity clean format-check

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build all package products
	$(SWIFT) build

test: ## Run all tests
	$(SWIFT) test

test-app: ## Run app-focused tests only
	$(SWIFT) test --filter HackPanelAppTests

test-gateway: ## Run gateway-focused tests only
	$(SWIFT) test --filter HackPanelGatewayTests

run: ## Run the HackPanel app executable
	$(SWIFT) run HackPanelApp

sanity: ## Run CI-parity build/test script
	bash $(SANITY_SCRIPT)

clean: ## Clean SwiftPM build artifacts
	$(SWIFT) package clean

format-check: ## Placeholder formatting check (no-op for now)
	@echo "No formatter configured in-repo; skipping format check."
