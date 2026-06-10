{ lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [
      hello
    ];
    username = "wizheng";
    homeDirectory = "/home/wizheng";
    stateVersion = "23.11";
  };

}
