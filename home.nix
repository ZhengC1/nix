{ lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      cowsay lolcat
    ];
    username = "wizheng";
    homeDirectory = "/home/wizheng";
    stateVersion = "23.11";
    programs.home-manager.enable = true;
  };

}
