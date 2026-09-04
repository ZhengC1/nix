UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  HM_OS := darwin
else
  HM_OS := linux
endif

# The flake resolves its username from $USER (see flake.nix), so the target
# name and the evaluated config must agree. Override with `make home HM_USER=x`.
HM_USER ?= $(shell echo $${USER:-$$(id -un)})
HM_TARGET := $(HM_USER)-$(HM_OS)

NIX_FLAGS := --extra-experimental-features 'nix-command flakes'

# Nix may have been installed by an earlier target in this same run, so its
# profile has to be sourced at recipe time rather than at parse time.
NIX_ENV := if [ -e "$$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$$HOME/.nix-profile/etc/profile.d/nix.sh"; fi; \
	if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; fi; \
	export PATH="$$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$$PATH"; \
	command -v nix >/dev/null 2>&1 || { echo "error: nix not on PATH. Run 'make install', then open a new shell."; exit 1; }

.PHONY: install_nix
install_nix:
	@if command -v nix >/dev/null 2>&1 || [ -e "$$HOME/.nix-profile/bin/nix" ]; then \
	  echo "✓ Nix already installed, skipping."; \
	else \
	  curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh; \
	fi

.PHONY: install
install: install_nix
	@mkdir -p "$$HOME/.config/nix"
	@touch "$$HOME/.config/nix/nix.conf"
	@grep -q '^experimental-features' "$$HOME/.config/nix/nix.conf" \
	  || echo "experimental-features = nix-command flakes" >> "$$HOME/.config/nix/nix.conf"
	@echo ""
	@echo "✓ Nix installed! Close this terminal and open a new one, then run:"
	@echo "  make home"

# One-shot new-machine setup: install Nix, enable flakes, and activate the home
# config in a single run. NIX_ENV (used by `home`) sources the freshly-installed
# daemon profile at recipe time, so no intermediate shell restart is needed.
.PHONY: bootstrap
bootstrap: install home
	@echo ""
	@echo "✓ Bootstrap complete. Start a new shell (or: exec $$SHELL)."

# Bootstraps home-manager: builds the activation package straight from the
# flake (using the home-manager pinned in flake.lock) and activates it, so no
# home-manager CLI needs to exist beforehand. home.nix installs the CLI itself.
.PHONY: home
home:
	@echo "Activating home-manager config: $(HM_TARGET)"
	@$(NIX_ENV); \
	out=$$(USER="$(HM_USER)" nix $(NIX_FLAGS) build --impure --no-link --print-out-paths \
	       ".#homeConfigurations.$(HM_TARGET).activationPackage") \
	  && HOME_MANAGER_BACKUP_EXT=backup "$$out/activate" \
	  && echo "" \
	  && echo "✓ Home manager configured! Start a new shell (or: exec \$$SHELL)."

.PHONY: clean
clean:
	@$(NIX_ENV); nix-collect-garbage -d
