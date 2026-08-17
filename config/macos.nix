{ lib, pkgs, ... }:

{
  # macOS-specific configuration
  home.packages = with pkgs; [
    # Required for Python to build lzma support
    xz
  ];

  # Homebrew is not managed by Nix (it installs to /opt/homebrew, a system
  # location needing sudo). home-manager can't own it declaratively, so we
  # ensure it's present with an idempotent activation script that runs the
  # official installer only when `brew` is missing. NONINTERACTIVE=1 skips the
  # confirmation prompt; the installer still asks for a sudo password once.
  home.activation.installHomebrew = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! /usr/bin/env command -v brew >/dev/null 2>&1 \
       && [ ! -x /opt/homebrew/bin/brew ] \
       && [ ! -x /usr/local/bin/brew ]; then
      $DRY_RUN_CMD echo "Homebrew not found — installing…"
      $DRY_RUN_CMD NONINTERACTIVE=1 /bin/bash -c \
        "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  '';
}
