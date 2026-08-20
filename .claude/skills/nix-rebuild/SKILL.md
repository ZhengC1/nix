---
name: nix-rebuild
description: Edit and rebuild this Nix + home-manager config. Use when asked to add/remove/change a package, shell alias, env var, git/tmux/neovim setting, or otherwise modify this repo, then apply it. Handles the edit → build-check → `make home` loop and the repo's gotchas (dual shells, unfree whitelist, read-only symlinks).
---

# nix-rebuild

Make a change to this personal Nix + home-manager flake and apply it. There is no application code — every change is a `.nix` module edit followed by a rebuild.

## The loop

1. **Edit** the right module under `config/` (see map below), or `home.nix` / `flake.nix`.
2. **Build-check** without activating (fast feedback that it evaluates):
   ```bash
   nix --extra-experimental-features 'nix-command flakes' build --impure \
     '.#homeConfigurations.'"$USER"'-darwin.activationPackage'
   ```
   Use `-linux` on Linux. This is the same target `make home` builds.
3. **Activate** with the core loop:
   ```bash
   make home
   ```
   Then tell the user to start a new shell for shell/env changes to take effect.

## Where things live (`config/`)

- `utilities.nix` — CLI tools (ripgrep, bat, eza, fd, jq, gh, claude-code) + container tooling.
- `programming_lang.nix` — language servers/formatters/build tools. Language *runtimes* are NOT here (pyenv/nvm/rustup/ghcup own those).
- `shell_config.nix` — bash **and** zsh, starship, zoxide, fzf, direnv.
- `gitconfig.nix`, `tmux.nix`, `neovim.nix`, `macos.nix` (darwin-only), `linux.nix` (linux-only).

Adding a new module: create `config/foo.nix` and add it to the `imports` list in `home.nix`.

## Must-remember gotchas

- **Two shells in parallel.** Any alias, env var, or init snippet must be added to *both* the bash and zsh blocks in `shell_config.nix` (and both runtime blocks in `programming_lang.nix`). They are intentionally not DRY.
- **Unfree packages** must be added by name to the `allowedUnfree` list in `flake.nix`, or the build fails.
- **Generated dotfiles are read-only symlinks** into the Nix store (`~/.bashrc`, `~/.zshrc`, `~/.config/git/config`, `~/.tmux.conf`). Editing them in `$HOME` does nothing — change the module and rebuild.
- **`programs.tmux` stays disabled** in `tmux.nix`; `dotfiles/.tmux.conf` is the source of truth.
- **Neovim** is linked per-file; don't wholesale-symlink the dir. Re-pin plugins by copying the updated `lazy-lock.json` back into `dotfiles/nvim/`.

## Finding packages / options

Use the **nixos** MCP server (`nix` / `nix_versions` tools) to confirm a package attribute path or a home-manager option exists before editing — it's live and more current than training data. Use **context7** for upstream tool/library docs when configuring a program.
