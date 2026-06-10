{ lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      cowsay lolcat
    ];
    username = "wizheng";
    homeDirectory = "/home/wizheng";
    stateVersion = "25.11";
    programs.home-manager.enable = true;
  };

}
