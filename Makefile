SHELL := /bin/bash

# Lazy evaluated latest version informations
FREEDESKTOP_LATEST_VERSION = $(shell flatpak --user remote-ls flathub | grep "org.freedesktop.Platform\s" | grep -v "\.Locale\|\.Debug\|\.Var" | cut -f 4 | tail -1)
SERVO_LATEST_TAR = $(shell grep "browser_download_url.*servo-x86_64-linux-gnu.tar.gz\"" .servo.github.json | cut -d '"' -f 4 | head -1)
SERVO_LATEST_SHA256_URL = $(shell grep "browser_download_url.*servo-x86_64-linux-gnu.tar.gz.sha256\"" .servo.github.json | cut -d '"' -f 4 | head -1 )
SERVO_LATEST_SHA256 = $(shell curl -Ls $(SERVO_LATEST_SHA256_URL) | cut -d' ' -f1)

all: install

install-flathub:
	@echo -e "\033[0;36mSetup flathub ...\033[0m"
	@flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	@echo -e "\033[0;32mDone\033[0m"
	@echo

install-runtime: install-flathub
	@echo -e "\033[0;36mInstalling Freedesktop Platform runtime and sdk (version: $(FREEDESKTOP_LATEST_VERSION))...\033[0m"
	@flatpak install --user --noninteractive -y flathub org.freedesktop.Platform//$(FREEDESKTOP_LATEST_VERSION) org.freedesktop.Sdk//$(FREEDESKTOP_LATEST_VERSION)
	@echo -e "\033[0;32mDone\033[0m"
	@echo

install: org.servo.Servo.yml
	@echo -e "\033[0;36mBuilding and installing the Flatpak package...\033[0m"
	@flatpak-builder --user --install --force-clean build-dir org.servo.Servo.yml
	@echo -e "\033[0;32mDone\033[0m"
	@echo

.servo.github.json:
	@echo -e "\033[0;36mCaching latest Servo release information from GitHub...\033[0m"
	@if [ -f .env ]; then \
		source .env; \
		if [ -z "$$GITHUB_CLIENT_ID" ] || [ -z "$$GITHUB_CLIENT_SECRET" ]; then \
			echo -e "\033[0;31mGITHUB_CLIENT_ID or GITHUB_CLIENT_SECRET is not set in .env file.\033[0m"; \
			exit 1; \
		fi; \
		echo -e "\033[0;33mUsing GitHub API credentials from .env file.\033[0m"; \
		curl -u $$GITHUB_CLIENT_ID:$$GITHUB_CLIENT_SECRET -o .servo.github.json -Ls https://api.github.com/repos/servo/servo/releases/latest; \
	else \
		RATE_LIMIT=$$(curl -sI https://api.github.com | grep -i "^X-RateLimit-Remaining" | awk '{print $$2}' | tr -d '\r'); \
		if [ "$$RATE_LIMIT" -eq "0" ]; then \
			echo -e "\033[0;31mGitHub API rate limit exceeded. Please wait and try again later.\033[0m"; \
			exit 1; \
		else \
			echo -e "\033[0;32mGitHub API rate limit remaining: $$RATE_LIMIT\033[0m"; \
		fi; \
		curl -o .servo.github.json -Ls https://api.github.com/repos/servo/servo/releases/latest; \
	fi
	@echo -e "\033[0;32mDone\033[0m"
	@echo

org.servo.Servo.yml: .servo.github.json install-runtime
	@echo -e "\033[0;36mGenerating org.servo.Servo.yml from template...\033[0m"
	@cp org.servo.Servo.template.yml org.servo.Servo.yml
	@echo Fill in org.servo.Servo.yml with latest versions: $(FREEDESKTOP_LATEST_VERSION) ...
	@sed -i "s/\[RUNTIME_VERSION\]/$(FREEDESKTOP_LATEST_VERSION)/g" org.servo.Servo.yml
	@echo Servo latest tarball URL: $(SERVO_LATEST_TAR) ...
	@sed -i "s|\[SERVO_TAR_URL\]|$(SERVO_LATEST_TAR)|g" org.servo.Servo.yml
	@echo Servo latest sha256: $(SERVO_LATEST_SHA256) ...
	@sed -i "s|\[SERVO_TAR_SHA256\]|$(SERVO_LATEST_SHA256)|g" org.servo.Servo.yml
	@echo -e "\033[0;32mDone\033[0m"
	@echo

clean:
	@echo -e "\033[0;36mCleaning up...\033[0m"
	@rm -f .servo.github.json
	@rm -f org.servo.Servo.yml
	@echo

.PHONY: all clean install install-runtime install-flathub
