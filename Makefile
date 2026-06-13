.PHONY: install
install:
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
	nix-channel --update
	nix-shell '<home-manager>' -A install

.PHONY: update
update:
	home-manager switch --flake .#$(USER) -b backup

.PHONY: clean
clean:
	nix-collect-garbage -d

.PHONY: deploy
deploy:
	@for f in dotfiles/.*; do \
	  [ -f "$$f" ] || continue; \
	  cp "$$f" "$(HOME)/"; \
	  echo "copied $$f -> $(HOME)/"; \
	done
	@mkdir -p "$(HOME)/.config/nvim"
	@rsync -a --exclude='.git' dotfiles/nvim/ "$(HOME)/.config/nvim/"
	@echo "copied dotfiles/nvim/ -> $(HOME)/.config/nvim/"
	@echo ""
	@echo "Done. Run: source ~/.bashrc"


