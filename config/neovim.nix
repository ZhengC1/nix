{ pkgs, lib, config, ... }:

let
  nvimSrc = ../dotfiles/nvim;

  # lazy.nvim rewrites lazy-lock.json on :Lazy update/sync, so it is the one
  # file that cannot be a read-only symlink into the store — it is seeded by the
  # activation script below instead. Everything else is linked declaratively,
  # and reading the directory means a newly added file is picked up without
  # having to remember to list it here.
  linked = lib.filterAttrs (name: _: name != "lazy-lock.json")
    (builtins.readDir nvimSrc);
in
{
  home.packages = with pkgs; [
    neovim
  ];

  # Each entry links per-file (recursive = true for subdirectories) rather than
  # symlinking ~/.config/nvim wholesale, so the directory itself stays writable
  # for the plugin state lazy.nvim puts there.
  xdg.configFile = lib.mapAttrs' (name: type:
    lib.nameValuePair "nvim/${name}" (
      { source = nvimSrc + "/${name}"; }
      // lib.optionalAttrs (type == "directory") { recursive = true; }
    )) linked;

  # Seed the lock file when it is missing; leave an existing one alone so :Lazy
  # can manage it. Copy it back into dotfiles/nvim to re-pin plugin versions.
  home.activation.nvimLazyLock =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      lock="${config.xdg.configHome}/nvim/lazy-lock.json"
      if [ ! -e "$lock" ]; then
        run install -m644 ${nvimSrc + "/lazy-lock.json"} "$lock"
      fi
    '';
}
