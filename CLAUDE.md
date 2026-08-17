# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal [Nix](https://nix.dev/) + [home-manager](https://nix-community.github.io/home-manager/) configuration that declaratively manages the user's home directory (shell, git, editor, CLI tooling) on both macOS (`aarch64-darwin`) and Linux (`x86_64-linux`) from a single flake. There is no application code here — every change is a Nix module edit followed by a rebuild.

## Commands

All workflows go through the `Makefile`, which sources the Nix profile at recipe time (Nix may not be on PATH yet):

```bash
make install_nix   # install Nix (idempotent; skips if already present)
make install       # enable flakes in ~/.config/nix/nix.conf (run once after install_nix)
make home          # build + activate the home-manager config for this machine
make clean         # nix-collect-garbage -d (remove old generations)
```

`make home` is the core loop: edit a `.nix` file, run it, start a new shell. It builds `.#homeConfigurations.<user>-<os>.activationPackage` with `--impure` and activates it with `HOME_MANAGER_BACKUP_EXT=backup` (existing files are backed up, not clobbered).

Note: the README refers to `make update`, but the actual target is `make home`.

Build without activating (useful to check that a change evaluates):

```bash
nix --extra-experimental-features 'nix-command flakes' build --impure \
  '.#homeConfigurations.chunz-darwin.activationPackage'
nix flake update    # bump input versions in flake.lock, then `make home`
```

## Architecture

**Username and system are resolved dynamically, not hardcoded.** `flake.nix` reads `$USER` via `builtins.getEnv` (hence `--impure`) and generates two configs per user: `<user>-darwin` and `<user>-linux`. The `Makefile` picks the target by combining `$USER` with `uname -s`. This is why the same repo works on any machine without editing. Override the user with `make home HM_USER=x`.

**`home.nix` is the entry point** and imports every module from `config/`. Shared modules are always imported; `config/macos.nix` and `config/linux.nix` are conditionally imported via `lib.optionals isDarwin/isLinux`. The `isDarwin`/`isLinux` booleans are derived from the `system` string suffix and threaded through `extraSpecialArgs`.

**Module layout (`config/`):**
- `shell_config.nix` — bash **and** zsh (kept in sync by hand), plus starship, zoxide, fzf, direnv. Both shells auto-`exec tmux` on interactive start (skipped under VSCode to avoid breaking PATH capture).
- `programming_lang.nix` — language servers/formatters/build tools installed via Nix. Language *runtimes* are deliberately NOT managed by Nix — pyenv/nvm/rustup/ghcup own those, and the shell init sources them.
- `utilities.nix` — CLI tools (ripgrep, bat, eza, fd, jq, gh, `claude-code`, etc.) plus container tooling (`docker-client`, `docker-compose`, `podman`).
- `gitconfig.nix`, `tmux.nix`, `neovim.nix`, `macos.nix`, `linux.nix`.

**Two shells are maintained in parallel.** Any shell alias, env var, or init snippet must be added to *both* the bash and zsh blocks in `shell_config.nix` (and the language-runtime `initExtra`/`initContent` in `programming_lang.nix`). They are not DRY — this is intentional given home-manager's separate `programs.bash`/`programs.zsh` schemas.

## Conventions and gotchas

- **Generated files are read-only symlinks into the Nix store.** `~/.bashrc`, `~/.zshrc`, `~/.config/git/config`, `~/.tmux.conf` are all produced from Nix modules. Editing them in `$HOME` does nothing — change the module and re-run `make home`.
- **Unfree packages** must be whitelisted by name in `flake.nix`'s `allowedUnfree` list (currently only `claude-code`).
- **`programs.tmux` is intentionally disabled** in `tmux.nix` — enabling it generates a config that overrides `dotfiles/.tmux.conf`. The package is installed directly and `dotfiles/.tmux.conf` is the single source of truth. tpm is cloned via an activation script.
- **Docker/Podman on macOS needs a Linux VM.** Nix installs only the clients (`docker-client` is the `docker` CLI without a daemon — `dockerd` is Linux-only). The engine + VM come from podman: `podman machine init && podman machine start`. podman exposes a Docker-compatible API socket, so the `docker` CLI can drive it (via `DOCKER_HOST` / `docker context`). On Linux the daemon is a system service and is not managed by home-manager.
- **Neovim config is linked per-file** (`neovim.nix` reads `dotfiles/nvim/` and maps each entry into `xdg.configFile`), NOT as one wholesale symlink, so the directory stays writable for lazy.nvim's plugin state. `lazy-lock.json` is the one exception: it is seeded on first activation then left writable so `:Lazy update` works. To re-pin plugins, copy the updated lock file back into `dotfiles/nvim/`.
- **Adding a new config module:** create `config/foo.nix` and add it to the `imports` list in `home.nix` (only newly-added files under `dotfiles/nvim/` are auto-discovered; top-level modules are not).
- **State version** is pinned to `23.11` in `home.nix`; the flake tracks nixpkgs/home-manager `26.05`.

## MCP

`.mcp.json` configures a `nixos` MCP server (`github:utensils/mcp-nixos`) — use it for looking up nixpkgs packages and NixOS/home-manager options.
