{ lib, pkgs, username, ... }:

{
    imports = [
      config/gitconfig.nix
      config/shell_config.nix
      config/utilities.nix
      config/programming_lang.nix
    ];


  home = {
    packages = with pkgs; [
      cowsay 
      lolcat 
      home-manager 
      pyenv 
      neovim
    ];
    homeDirectory = "/home/${username}";
    username = username;
    stateVersion = "23.11";
  };

}
