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

icons.tar.gz:
	@echo -e "\033[0;36mCreating icons.tar.gz archive...\033[0m"
	@if [ ! -d icons ]; then \
		echo -e "Generating icons..."; \
		make icons; \
	fi
	@tar -czf icons.tar.gz -C icons .
	@echo -e "\033[0;32mDone\033[0m"
	@echo

icons: icons/servo_16.png icons/servo_32.png icons/servo_48.png icons/servo_64.png icons/servo_128.png icons/servo_256.png icons/servo_512.png
	@echo -e "\033[0;32mAll icons generated successfully.\033[0m"
	@echo

icons/servo_1024.png: temp/servo-x86_64-linux-gnu.tar.gz
	@if [ ! -d icons ]; then \
		echo -e "Creating icons directory..."; \
		mkdir -p icons; \
	fi
	@if [ ! -f icons/servo_1024.png ]; then \
		echo -e "\033[0;36mGet the latest servo_1024.png\033[0m"; \
		cp -pdf temp/servo/resources/servo_1024.png icons/servo_1024.png; \
	fi

icons/servo_%.png: icons/servo_1024.png check-magick
	@size=$*; \
	echo -e "\033[0;36mGenerated icon size: $${size}x$${size}\033[0m"; \
	magick icons/servo_1024.png -resize $${size}x$${size} icons/servo_$${size}.png && \
	echo -e "\033[0;32m✓\033[0m success"

temp/servo/resources/servo_1024.png: temp/servo-x86_64-linux-gnu.tar.gz
	@echo -e "\033[0;36mExtracting Servo resources...\033[0m"
	cd temp && tar -xzf servo-x86_64-linux-gnu.tar.gz

temp/servo-x86_64-linux-gnu.tar.gz:
	@echo -e "\033[0;36mDownloading and extracting Servo icons...\033[0m"
	@mkdir -p temp
	cd temp && curl -Ls ${SERVO_LATEST_TAR} -o servo-x86_64-linux-gnu.tar.gz

check-magick:
	@echo -e "\033[0;36mCheck if \"magick\" command from ImageMagick is available...\033[0m"
	@if ! command -v magick &> /dev/null; then \
		@echo -e "\033[0;31m\"magick\" command not found. Please install ImageMagick to proceed.\033[0m"; \
		exit 1; \
	else \
		echo -e "\"magick\" command found."; \
	fi

clean-icons:
	@echo -e "\033[0;36mCleaning up icons...\033[0m"
	@rm -Rf icons/*

clean:
	@echo -e "\033[0;36mCleaning up...\033[0m"
	@rm -f .servo.github.json
	@rm -f org.servo.Servo.yml
	@rm -f temp/
	@echo

.PHONY: all clean clean-icons check-magick icons install install-runtime install-flathub
