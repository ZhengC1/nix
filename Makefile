.PHONY: update
update: 
	home-manager switch --flake .#wizheng

.PHONY: clean
clean: 
	nix-collect-garbage -d


