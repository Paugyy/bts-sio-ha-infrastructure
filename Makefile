# Makefile — raccourcis pour le poste de développement (pas pour les VM).
# Les cibles reproduisent localement ce que fait la CI GitHub Actions.

SHELL := /usr/bin/env bash
SCRIPTS := $(shell find scripts -type f -name '*.sh')

.PHONY: help check lint lint-md lint-sh docs test-configs

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-14s %s\n", $$1, $$2}'

check: ## Structure du dépôt, secrets, syntaxe shell
	@bash scripts/validation/check-repository.sh

lint: lint-md lint-sh ## Markdown + ShellCheck

lint-md: ## markdownlint (nécessite Node.js)
	@npx --yes markdownlint-cli2 "**/*.md" "#node_modules"

lint-sh: ## ShellCheck (nécessite shellcheck)
	@command -v shellcheck >/dev/null || { echo "shellcheck absent : sudo apt install shellcheck"; exit 1; }
	@shellcheck -x $(SCRIPTS)

test-configs: ## Syntaxe HAProxy / PHP si les outils sont présents localement
	@if command -v haproxy >/dev/null; then haproxy -c -f configs/haproxy/haproxy.cfg.example; else echo "[SKIP] haproxy absent"; fi
	@if command -v php >/dev/null; then php -l configs/wordpress/wp-config.php.example; else echo "[SKIP] php absent"; fi
	@python3 -m json.tool generator/examples/reference-infrastructure.json >/dev/null && echo "[OK] JSON du générateur"

docs: ## Ouvre l'index de la documentation et le générateur
	@echo "Documentation : docs/README.md"
	@echo "Générateur    : generator/index.html (ouvrir dans un navigateur)"
