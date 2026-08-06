UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  HM_TARGET := $(USER)-darwin
else
  HM_TARGET := $(USER)-linux
endif

NIX_BIN := $(shell command -v nix 2>/dev/null || find /nix/store -name nix -type f -path "*/bin/nix" 2>/dev/null | head -1)
NIX_BIN_DIR := $(shell find /nix/store -name nix -type f -path "*/bin/nix" 2>/dev/null | head -1 | xargs dirname)

.PHONY: install_nix
install_nix:
	curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh

.PHONY: install
install: install_nix
	@mkdir -p ~/.config/nix
	@echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf 2>/dev/null || true
	@echo ""
	@echo "✓ Nix installed! Close this terminal and open a new one, then run:"
	@echo "  make setup-home"

.PHONY: home
home:
	@echo "Setting up home-manager..."
	@export PATH="$$HOME/.nix-profile/bin:$(NIX_BIN_DIR):$$PATH" && $$HOME/.nix-profile/bin/home-manager switch --flake .#$(HM_TARGET) -b backup
	@echo ""
	@echo "✓ Home manager configured! Reloading shell..."
	@exec $$SHELL

.PHONY: update
update:
	home-manager switch --flake .#$(HM_TARGET) -b backup

.PHONY: clean
clean:
	nix-collect-garbage -d

SHELL_RC := $(shell basename $$SHELL)rc

.PHONY: deploy
deploy:
	@for f in dotfiles/.*; do \
	  [ -f "$$f" ] || continue; \
	  [ "$$f" != "dotfiles/.bashrc" ] && [ "$$f" != "dotfiles/.zshrc" ] || continue; \
	  cp "$$f" "$(HOME)/"; \
	  echo "copied $$f -> $(HOME)/"; \
	done
	@cp dotfiles/.$(SHELL_RC) "$(HOME)/.$(SHELL_RC)" && echo "copied dotfiles/.$(SHELL_RC) -> $(HOME)/.$(SHELL_RC)" || echo "warning: .$(SHELL_RC) not found"
	@mkdir -p "$(HOME)/.config/nvim"
	@rsync -a --exclude='.git' dotfiles/nvim/ "$(HOME)/.config/nvim/"
	@echo "copied dotfiles/nvim/ -> $(HOME)/.config/nvim/"
	@echo ""
	@echo "Done. Run: source ~/.$(SHELL_RC)"


