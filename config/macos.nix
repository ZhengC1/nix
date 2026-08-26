{ lib, pkgs, config, ... }:

let
  # Stable ~/.nix-profile symlinks (they survive rebuilds; never hardcode a
  # /nix/store/... path — that changes every generation).
  dotnetRoot = "${config.home.homeDirectory}/.nix-profile/share/dotnet";
  nixBin     = "${config.home.homeDirectory}/.nix-profile/bin";

  # macOS GUI apps (Rider launched from Toolbox/Dock, Spotlight, etc.) inherit
  # their environment from launchd, NOT from the interactive shell — so the
  # DOTNET_ROOT / PATH we export in the shell modules are invisible to them.
  # This script pushes them into the launchd (GUI) session via `launchctl
  # setenv`, prepending to PATH without clobbering what's already there.
  guiEnvScript = pkgs.writeShellScript "gui-env" ''
    /bin/launchctl setenv DOTNET_ROOT "${dotnetRoot}"

    current="$(/bin/launchctl getenv PATH || true)"
    [ -z "$current" ] && current="/usr/bin:/bin:/usr/sbin:/sbin"
    case ":$current:" in
      *":${nixBin}:"*) ;;
      *) /bin/launchctl setenv PATH "${nixBin}:$current" ;;
    esac
  '';
in
{
  # macOS-specific configuration
  home.packages = with pkgs; [
    # Required for Python to build lzma support
    xz
  ];

  # Expose the nix-installed .NET SDK to GUI-launched apps (JetBrains Rider).
  # Runs once at login; RunAtLoad fires it when the agent is loaded on activation.
  launchd.agents.gui-env = {
    enable = true;
    config = {
      ProgramArguments = [ "${guiEnvScript}" ];
      RunAtLoad = true;
      # One-shot: no KeepAlive, so it exits after setting the env.
    };
  };

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
