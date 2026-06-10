.PHONY: update
update: 
	home-manager switch --flake .#nix-wizheng

.PHONY: clean
clean: 
	nix-collect-garbage -d


