# flake.nix

{
  description = "My home manager configs";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      username = "chunz";
      systems = {
        darwin = "aarch64-darwin";
        linux = "x86_64-linux";
      };
      # Unfree packages must be opted into by name.
      allowedUnfree = [ "claude-code" ];
      mkHome = system: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) allowedUnfree;
        };
        extraSpecialArgs = { inherit username system; };
        modules = [ ./home.nix ];
      };
    in {
      homeConfigurations = {
        "${username}-darwin" = mkHome systems.darwin;
        "${username}-linux" = mkHome systems.linux;
      };
    };
}
