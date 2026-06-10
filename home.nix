{ lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      cowsay lolcat homemanager
    ];
    username = "wizheng";
    homeDirectory = "/home/wizheng";
    stateVersion = "23.11";
  };

}
