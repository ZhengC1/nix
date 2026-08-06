# Nix Home Manager Configuration

A declarative home directory configuration using Nix and home-manager, optimized for macOS with support for multiple programming languages and development tools.

## Prerequisites

### macOS (Recommended)
- **OS Version**: macOS 12+ (Monterey or newer)
- **Architecture**: Apple Silicon (aarch64-darwin) or Intel (x86_64-darwin)
- **Nix**: Not yet installed (setup script will install it)

### Linux
- **Distribution**: NixOS or other Linux distributions with Nix support
- **Architecture**: x86_64-linux or aarch64-linux
- **Nix**: Not yet installed (setup script will install it)

## Installation

### 1. Install Nix

```bash
make install_nix
```

This will install Nix using the official installer. You'll be prompted to allow the installation.

### 2. Set Up Home Manager

```bash
make install
```

This will:
- Add the home-manager channel
- Update channels
- Run the home-manager installer

### 3. Apply Configuration

```bash
make update
```

This switches to the home-manager configuration and creates a backup of any existing files.

## Environment Variables & Configuration

### Shell Environment

The configuration automatically sets up the following environment variables in `~/.bashrc`:

#### Python Development
- **PYENV_ROOT**: Set to `$HOME/.pyenv`
- **PATH**: Includes `$PYENV_ROOT/bin` for pyenv commands
- **Requires**: [pyenv](https://github.com/pyenv/pyenv) installation

#### Node.js Development
- **NVM_DIR**: Set to `$HOME/.nvm`
- **Requires**: [nvm](https://github.com/nvm-community/nvm) installation (manual)

#### Rust Development
- **Requires**: [rustup](https://rustup.rs/) installation (manual)
- **Auto-sourced**: `~/.cargo/env` if present

#### Haskell Development
- **Requires**: [ghcup](https://www.haskell.org/ghcup/) installation (manual)
- **Auto-sourced**: `~/.ghcup/env` if present

#### Go Development
- **GOPATH**: Set to `$HOME/go`
- **PATH**: Includes `$GOPATH/bin` for compiled binaries

### Manual Version Manager Setup

Before using the configuration, install your required version managers:

```bash
# Python
curl https://pyenv.io/installation/linux-prerequisites.sh | bash
git clone https://github.com/pyenv/pyenv.git ~/.pyenv
git clone https://github.com/pyenv/pyenv-virtualenv.git ~/.pyenv/plugins/pyenv-virtualenv

# Node.js
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# Rust
curl --proto '=https' --tlsv1.2 -L https://sh.rustup.rs | sh

# Haskell
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

## OS-Specific Configuration

The configuration automatically supports both **macOS** and **Linux** with separate home manager configurations:

- **macOS (Apple Silicon)**: `chunz-darwin` — uses `/Users/chunz` as home directory
- **Linux (x86_64)**: `chunz-linux` — uses `/home/chunz` as home directory

### Adding OS-Specific Settings

**For macOS-only settings:** Add to `config/macos.nix`
- Example: defaults write commands, Homebrew setup, macOS-specific defaults

**For Linux-only settings:** Add to `config/linux.nix`
- Example: systemd units, Linux-specific packages, mount points

**For OS-aware settings in shared files:** Use conditional expressions:
```nix
{ pkgs, ... }:
{
  setting = if pkgs.stdenv.isDarwin then "macOS value" else "Linux value";
}
```

### Supporting Additional Systems

To add support for Intel Macs or other architectures, edit `flake.nix`:

```nix
systems = {
  darwin = "aarch64-darwin";      # Apple Silicon
  darwin-intel = "x86_64-darwin"; # Intel Mac
  linux = "x86_64-linux";
};
```

Then `make update` will automatically detect your system and apply the correct configuration.

## Git Configuration

The configuration includes pre-configured git settings:

- **User Name**: Chun Zheng
- **User Email**: zhengc42@gmail.com
- **Editor**: vim (change in `config/gitconfig.nix` if needed)

Modify `config/gitconfig.nix` to customize:
```nix
userName = "Your Name";
userEmail = "your.email@example.com";
```

## Development Tools Included

### Installed via Nix
- **Python**: pyright (LSP), ruff, black
- **Node.js**: typescript-language-server, prettier
- **Rust**: rust-analyzer
- **Go**: go, gopls, gotools, delve
- **Haskell**: haskell-language-server
- **Lua**: lua54, luarocks, lua-language-server
- **Build Tools**: make, cmake
- **Utilities**: neovim, pyenv, home-manager, cowsay, lolcat

### Shell Features
- **Bash** with history (10K lines in memory, 20K on disk)
- **Starship** prompt
- **Zoxide** fast directory jumping
- **FZF** fuzzy finder
- **Direnv** environment management
- **Tmux** auto-attach (if installed)

### Shell Aliases
```bash
ll   = ls -alF
la   = ls -A
l    = ls -CF
grep = grep --color=auto
vim/vi = nvim
..   = cd ..
...  = cd ../..
```

## Usage

### Apply Changes

After modifying configuration files:
```bash
make update
```

The Makefile automatically detects your OS and applies the correct configuration:
- **macOS**: Applies `chunz-darwin` configuration
- **Linux**: Applies `chunz-linux` configuration

This creates a timestamped backup before switching.

### Build Specific Configuration

To build a configuration without activating it:

**macOS:**
```bash
nix flake show  # Lists available configurations
nix build .#homeConfigurations.chunz-darwin.activationPackage
```

**Linux:**
```bash
nix build .#homeConfigurations.chunz-linux.activationPackage
```

### Update Nix Flake

To update package versions:
```bash
nix flake update
```

Then apply:
```bash
make update
```

### Clean Up

Remove old generations:
```bash
make clean
```

### Dotfiles

There is no separate deploy step. Everything under `dotfiles/` is applied by
`make home` through home-manager:

- `dotfiles/.tmux.conf` → `~/.tmux.conf` (`config/tmux.nix`)
- `dotfiles/nvim/` → `~/.config/nvim/` (`config/neovim.nix`)

Shell and git configuration are generated from `config/shell_config.nix` and
`config/gitconfig.nix` rather than copied from a checked-in dotfile, so
`~/.bashrc`, `~/.zshrc`, and `~/.config/git/config` are home-manager symlinks.
Editing those files in `$HOME` has no effect — change the Nix module and re-run
`make home`.

`~/.config/nvim/lazy-lock.json` is the one exception: it is seeded on first
activation and then left writable so `:Lazy update` works. Copy it back into
`dotfiles/nvim/` to re-pin plugin versions.

## Directory Structure

```
.
├── flake.nix                 # Flake configuration (inputs/outputs)
├── flake.lock                # Lock file (versions)
├── home.nix                  # Home manager configuration
├── Makefile                  # Installation & management commands
├── config/
│   ├── gitconfig.nix         # Git configuration
│   ├── shell_config.nix      # Bash, starship, fzf, direnv
│   ├── programming_lang.nix  # Language tooling
│   ├── utilities.nix         # Utility packages
│   ├── macos.nix             # macOS-specific (empty)
│   ├── linux.nix             # Linux-specific
│   ├── tmux.nix              # tmux + tpm
│   └── neovim.nix            # Neovim package + config deployment
└── dotfiles/
    ├── nvim/                 # Neovim configuration (linked by neovim.nix)
    └── .tmux.conf            # tmux configuration (linked by tmux.nix)
```

## Troubleshooting

### Nix Not Found
Ensure nix is installed and sourced:
```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### Home Manager Not Working
Ensure you've run `make install` first, then:
```bash
nix flake update
make update
```

### Python/Node/Rust Not Found
Install the required version manager (see Manual Version Manager Setup section).

### Custom Environment Variables

Add custom variables to `config/shell_config.nix` in the `sessionVariables` section:
```nix
sessionVariables = {
  EDITOR = "nvim";
  VISUAL = "nvim";
  CUSTOM_VAR = "value";
};
```

Or in `initExtra` for complex setup:
```nix
initExtra = ''
  export CUSTOM_VAR="value"
  # more setup...
'';
```

## State Version

Current state version: `23.11`

Update this in `home.nix` when upgrading to a newer home-manager version.

## Additional Resources

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [NixOS & Nix Flakes Documentation](https://nix.dev/)
- [Nixpkgs Reference](https://search.nixos.org/packages)
