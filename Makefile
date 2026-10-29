# better-rm 常用任務 / Common tasks for better-rm
#
# 用法 (Usage):
#   make            顯示可用目標 / Show available targets
#   make test       執行全部測試 / Run all test suites
#   make lint       語法與靜態檢查 / Syntax and static checks

SHELL := /bin/bash

SH_SCRIPTS := better-rm install.sh install-hooks.sh test-better-rm.sh test-install-hooks.sh

# 要設定的 Coding Agent (Coding agent to configure), 例如 (e.g.) make hooks AGENT=claude
AGENT ?=

# 本機安裝目錄，與 install.sh 相同 (Local install dir, same as install.sh)
INSTALL_DIR ?= $(HOME)/.better-rm

.DEFAULT_GOAL := help
.PHONY: help test test-core test-hooks test-install-hooks lint check-clean ci hooks install-local

help: ## 顯示可用目標 / Show available targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[0;34m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: test-core test-hooks test-install-hooks ## 執行全部測試 / Run all test suites

test-core: ## 測試 better-rm 主程式 / Test the better-rm script
	./test-better-rm.sh

test-hooks: ## 測試 Node.js hooks / Test Node.js hooks
	node ./test-hooks.js

test-install-hooks: ## 測試 hooks 安裝程式 / Test the hooks installer
	./test-install-hooks.sh

lint: ## bash -n、node --check，並在有安裝時執行 shellcheck（僅 error）/ Syntax checks, plus shellcheck errors if installed
	@for f in $(SH_SCRIPTS); do bash -n "$$f" || exit 1; done
	node --check test-hooks.js
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S error $(SH_SCRIPTS); \
	else \
		echo "略過 shellcheck（未安裝）/ shellcheck not installed, skipping"; \
	fi

check-clean: ## 確認測試未修改工作目錄 / Verify the working tree is untouched by tests
	git diff --exit-code
	@test -z "$$(git status --porcelain)" || { echo "工作目錄不乾淨 / Working tree is dirty" >&2; exit 1; }

ci: lint test ## 與 CI 相同的檢查 / Run the same checks as CI

hooks: ## 安裝 agent hooks：make hooks AGENT=claude / Install agent hooks
	@test -n "$(AGENT)" || { echo "請指定 AGENT，例如 make hooks AGENT=claude / Set AGENT, e.g. make hooks AGENT=claude" >&2; exit 1; }
	./install-hooks.sh -a "$(AGENT)"

install-local: ## 將目前工作目錄的版本安裝到本機 / Install the current working-tree version locally
	@mkdir -p "$(INSTALL_DIR)"
	install -m 755 better-rm "$(INSTALL_DIR)/better-rm"
	@echo "已安裝 / Installed: $$("$(INSTALL_DIR)/better-rm" --version | head -n 1) -> $(INSTALL_DIR)/better-rm"
	@if [ -d "$(INSTALL_DIR)/.git" ]; then \
		echo "注意：$(INSTALL_DIR) 是 git 儲存庫，執行 install.sh 更新前請先 git -C $(INSTALL_DIR) checkout -- better-rm" >&2; \
		echo "Note: $(INSTALL_DIR) is a git checkout; run git -C $(INSTALL_DIR) checkout -- better-rm before updating via install.sh" >&2; \
	fi
	@grep -qs "alias rm='$(INSTALL_DIR)/better-rm'" "$$HOME/.zshrc" "$$HOME/.bashrc" "$$HOME/.bash_profile" || \
		echo "尚未設定別名，請執行 / Alias not set, run: alias rm='$(INSTALL_DIR)/better-rm'"
