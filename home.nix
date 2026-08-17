{ lib, pkgs, username, system, ... }:

let
  isDarwin = lib.strings.hasSuffix "-darwin" system;
  isLinux = lib.strings.hasSuffix "-linux" system;
in
{
    imports = [
      config/gitconfig.nix
      config/shell_config.nix
      config/tmux.nix
      config/utilities.nix
      config/programming_lang.nix
      config/neovim.nix
      config/claude.nix
    ] ++ lib.optionals isDarwin [
      config/macos.nix
    ] ++ lib.optionals isLinux [
      config/linux.nix
    ];

  home = {
    packages = with pkgs; [
      cowsay
      lolcat
      home-manager
      pyenv
    ];
    homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
    username = username;
    stateVersion = "23.11";
  };

}
