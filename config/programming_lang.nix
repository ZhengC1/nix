{ pkgs, config, ... }:

{
  # Language tooling managed by nix (formatters, linters, LSPs, build tools).
  # Runtime versions are managed by their own version managers:
  #   Python  → pyenv    Node → nvm    Rust → rustup    Haskell → ghcup
  home.packages = with pkgs; [
    # Python tooling (pyenv manages the interpreter)
    ruff            # fast linter + formatter
    black           # formatter
    pyright         # language server

    # Node/JS tooling (nvm manages node and npm packages)

    # Rust tooling (rustup manages the compiler)
    rust-analyzer

    # Go (system go is 1.20; override with a nix-managed version)
    go
    gopls           # language server
    gotools         # goimports, godoc, etc.
    delve           # debugger

    # Lua (used heavily in neovim config)
    lua54Packages.lua
    luarocks
    lua-language-server

    # .NET (SDK includes the runtime, MSBuild, and dotnet CLI)
    dotnet-sdk_9
    csharprepl      # C# REPL

    # Build & misc
    d2              # diagram scripting language
    gnumake
    cmake
  ];

  # Bootstrap nvm (Node version manager) into ~/.nvm, checking out its latest
  # release tag. Like tpm, nvm owns the Node runtime and lives outside Nix; this
  # just clones it idempotently so the shell init below has something to source.
  home.activation.installNvm = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.nvm" ]; then
      ${pkgs.git}/bin/git clone https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
      export PATH="${pkgs.git}/bin:$PATH"
      ${pkgs.git}/bin/git -C "$HOME/.nvm" checkout \
        "$(${pkgs.git}/bin/git -C "$HOME/.nvm" describe --abbrev=0 --tags --match "v[0-9]*" "$(${pkgs.git}/bin/git -C "$HOME/.nvm" rev-list --tags --max-count=1)")"
    fi
  '';

  programs.bash.initExtra = ''
    # pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    # nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

    # Rust/cargo
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

    # Haskell/ghcup
    [ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

    # Go
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"

    # .NET — the nix dotnet-sdk is a wrapper; the C# tooling needs DOTNET_ROOT
    # to find the SDK/runtime under the profile.
    export DOTNET_ROOT="$HOME/.nix-profile/share/dotnet"
    # .NET global tools (dotnet-ef, etc.) install under ~/.dotnet/tools.
    export PATH="$PATH:$HOME/.dotnet/tools"
  '';

  # initExtra is deprecated in favour of initContent; both are line-merged, so
  # this composes with the definition in shell_config.nix.
  programs.zsh.initContent = ''
    # pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    # nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

    # Rust/cargo
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

    # Haskell/ghcup
    [ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"

    # Go
    export GOPATH="$HOME/go"
    export PATH="$PATH:$GOPATH/bin"

    # .NET — the nix dotnet-sdk is a wrapper; the C# tooling needs DOTNET_ROOT
    # to find the SDK/runtime under the profile.
    export DOTNET_ROOT="$HOME/.nix-profile/share/dotnet"
    # .NET global tools (dotnet-ef, etc.) install under ~/.dotnet/tools.
    export PATH="$PATH:$HOME/.dotnet/tools"
  '';
}
