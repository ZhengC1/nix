{ pkgs, ... }:

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

    # Build & misc
    d2              # diagram scripting language
    gnumake
    cmake
  ];

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
  '';

  programs.zsh.initExtra = ''
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
  '';
}
