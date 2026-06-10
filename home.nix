{ lib, pkgs, ... }:

{
    imports = [
      config/gitconfig.nix 
    ];


  home = {
    packages = with pkgs; [
      cowsay 
      lolcat 
      home-manager 
      pyenv 
      neovim
    ];
    homeDirectory = "/home/wizheng";
    username = "wizheng";
    stateVersion = "23.11";
  };

}
