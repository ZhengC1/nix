{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Haskell tooling (ghcup manages GHC/cabal/stack)
    # Linux-only: GHC on aarch64-darwin requires LLVM backend which is heavy
    haskellPackages.haskell-language-server
  ];

  home.file."mount.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      mount /dev/md/0 /mnt
    '';
  };
}
