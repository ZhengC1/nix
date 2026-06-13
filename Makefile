.PHONY: install
install:
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
	nix-channel --update
	nix-shell '<home-manager>' -A install

.PHONY: update
update: 
	home-manager switch --flake .#$(USER)

.PHONY: clean
clean: 
	nix-collect-garbage -d


