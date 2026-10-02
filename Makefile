# GuildRecruitmentBuddy development tasks. Run `make` for the list of targets.
#
# Needs GNU make plus a POSIX sh with git, cp, sed and awk (Git for Windows provides them).
# Personal settings (WoW location, luacheck path) go into the untracked local.mk, e.g.
#   WOW_DIR  = D:/Games/World of Warcraft
#   LUACHECK = C:/Users/me/bin/luacheck.exe
-include local.mk

ADDON     := GuildRecruitmentBuddy
WOW_DIR   ?= C:/Program Files (x86)/Blizzard/World of Warcraft
ADDON_DIR ?= $(WOW_DIR)/_classic_era_/Interface/AddOns
LUACHECK  ?= luacheck
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)

DEST          := $(ADDON_DIR)/$(ADDON)
INSTALL_FILES := $(ADDON).toc embeds.xml Bindings.xml Core.lua LICENSE Locales Media Modules UI Libs

# PowerShell snippets (the path comes in through the T / S environment variables to survive spaces)
PS_EXIT_IF_LINK  = if ((Test-Path -LiteralPath $$env:T) -and ((Get-Item -LiteralPath $$env:T -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { exit 1 }
PS_EXIT_IF_EXIST = if (Test-Path -LiteralPath $$env:T) { exit 1 }
PS_MAKE_LINK     = New-Item -ItemType Junction -Path $$env:T -Target (Resolve-Path -LiteralPath $$env:S).Path | Out-Null
PS_REMOVE        = if (Test-Path -LiteralPath $$env:T) { $$i = Get-Item -LiteralPath $$env:T -Force; if ($$i.Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($$i.FullName) } else { Remove-Item -LiteralPath $$i.FullName -Recurse -Force } }

.DEFAULT_GOAL := help
.PHONY: help libs lint install link uninstall clean check-addon-dir

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'
	@echo ""
	@echo "AddOns folder: $(ADDON_DIR)"

libs: Libs/.fetched ## Fetch the embedded libraries into Libs/ (needs git)

# Mirrors the externals of .pkgmeta from GitHub (the packager uses wowace SVN in CI).
Libs/.fetched: Makefile
	@echo "Fetching libraries into Libs/ ..."
	@rm -rf Libs .libs-tmp
	@mkdir -p Libs .libs-tmp
	@git clone --quiet --depth 1 https://github.com/WoWUIDev/Ace3.git .libs-tmp/ace3
	@for lib in LibStub CallbackHandler-1.0 AceAddon-3.0 AceDB-3.0 AceDBOptions-3.0 AceConsole-3.0 \
	    AceEvent-3.0 AceTimer-3.0 AceComm-3.0 AceSerializer-3.0 AceConfig-3.0 AceGUI-3.0 AceLocale-3.0; do \
	  cp -r ".libs-tmp/ace3/$$lib" "Libs/$$lib" || exit 1; \
	done
	@git clone --quiet --depth 1 https://github.com/tekkub/libdatabroker-1-1.git .libs-tmp/ldb
	@mkdir -p Libs/LibDataBroker-1.1
	@cp .libs-tmp/ldb/LibDataBroker-1.1.lua Libs/LibDataBroker-1.1/
	@git clone --quiet --depth 1 https://github.com/wowace-clone/LibDBIcon-1.0.git .libs-tmp/dbicon
	@cp -r .libs-tmp/dbicon/LibDBIcon-1.0 Libs/LibDBIcon-1.0
	@rm -rf .libs-tmp
	@touch $@
	@echo "Libraries written to Libs/"

lint: ## Run luacheck
	$(LUACHECK) .

check-addon-dir:
	@test -d "$(ADDON_DIR)" || { \
	  echo "AddOns folder not found: $(ADDON_DIR)"; \
	  echo "Set WOW_DIR (or ADDON_DIR) on the command line or in local.mk."; \
	  exit 1; }

install: libs check-addon-dir ## Copy the addon into the WoW AddOns folder
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_EXIT_IF_LINK)' || { \
	  echo "$(DEST) is a link created by 'make link'. Run 'make uninstall' first."; exit 1; }
	@rm -rf "$(DEST)"
	@mkdir -p "$(DEST)"
	@cp -r $(INSTALL_FILES) "$(DEST)/"
	@sed -i "s/@project-version@/$(VERSION)/" "$(DEST)/$(ADDON).toc"
	@echo "Installed $(ADDON) $(VERSION) to $(DEST). Use /reload (or restart) in game."

link: libs check-addon-dir ## Junction the repo into AddOns for live development (/reload picks up edits)
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_EXIT_IF_EXIST)' || { \
	  echo "$(DEST) already exists. Run 'make uninstall' first."; exit 1; }
	@T="$(DEST)" S="$(CURDIR)" powershell -NoProfile -Command '$(PS_MAKE_LINK)'
	@echo "Linked $(DEST) -> $(CURDIR). Use /reload in game after editing."

uninstall: check-addon-dir ## Remove the installed addon or the link (never touches the repo)
	@T="$(DEST)" powershell -NoProfile -Command '$(PS_REMOVE)'
	@echo "Removed $(DEST)"

clean: ## Remove the fetched libraries
	rm -rf Libs .libs-tmp
