---
name: nixos-flake-guide
description: Guide for working with this NixOS flake repo (uontabc/nixos_dev). Use when editing NixOS config, adding/modifying modules under modules/, understanding the flake layout, rebuilding (nh os switch / nixos-rebuild), hosts (uontabc / wsl), impermanence, or when about to change config that affects the whole system.
---

# NixOS Flake Guide

This repo is a NixOS configuration managed with `flake-parts` + `import-tree`.
Every `.nix` file under `modules/` is automatically imported; a file's
`flake.modules.nixos.<name>` attribute becomes a named NixOS module that other
files reference via `config.flake.modules.nixos.<name>`.

## Layout

- `flake.nix` — inputs only (nixpkgs `nixos-26.05`, flake-parts, import-tree,
  disko, impermanence, nixvim, noctalia, nixos-wsl, dev-templates).
  nixpkgs is pinned to `nixos-26.05`; do NOT point nixvim's nixpkgs at ours
  (they pin their own — following breaks `vimPlugins`).
- `modules/base.nix` — imports shared by every host (users, nix, i18n, env,
  nh, git, neovim, opencode, fastfetch, zsh).
- `modules/lib/nixos.nix` — host factory: auto-generates
  `nixosConfigurations.<name>` from `modules/hosts/<name>/`.
- `modules/hosts/uontabc/` — bare-metal desktop (AMD + NVIDIA, niri Wayland,
  btrfs + impermanence, GRUB). This is the machine you are on.
- `modules/hosts/wsl/` — headless NixOS-WSL guest.
- `modules/config/` — per-app config (niri, kitty, neovim, opencode, zsh,
  git, fonts, qt, i18n, nix).
- `modules/desktop/`, `modules/hardware/`, `modules/network/` — feature areas.
- `modules/impermanence.nix` — what survives a reboot under `/persist`.
- `modules/devshell.nix` — `nix develop` shell (lix, nh, nixfmt, statix, zsh).

## Conventions

- Repo lives at `~/nixos_dev` (hardcoded in `modules/nh.nix` via
  `programs.nh.flake`). Moving it breaks `nh`.
- Username is `onyx`, wired through `config.my.name`. Home paths in other
  modules are built dynamically from it — never hardcode `/home/onyx`.
- System packages go in `my.packages` (user-level, defined in `modules/users.nix`)
  or `environment.systemPackages`. Avoid `nix profile`.
- Root filesystem rolls back every boot from `@root-blank`. Edits outside
  `/persist` do not survive unless declared. Declared files under
  `/etc` are recreated by systemd-tmpfiles on boot.
- Chinese mirrors (USTC/SJTU) are configured globally; don't add more.

## Adding a module

1. Create `modules/<area>/<name>.nix` (or reuse an existing area):
   ```nix
   {
     flake.modules.nixos.<name> = { pkgs, config, ... }: {
       # ... options / config ...
     };
   }
   ```
2. If it belongs to a shared area, import it where siblings are imported
   (e.g. `modules/base.nix` or `modules/network.nix` imports).
3. Rebuild and check the result (below).

## Rebuilding / testing

```bash
nh os switch                 # build + activate on the current host (uontabc)
sudo nixos-rebuild switch --flake ~/nixos_dev#uontabc   # explicit
nh os build                  # build without switching, to validate config
nh clean all                 # prune old generations (auto-run weekly)
```

Lint the flake with `nix develop -c nixfmt` (format) and `statix` (static
analysis). Always run at least a config evaluation before asking the user to
switch, e.g. `nh os build`.

## Gotchas

- WSL host is configured from `modules/wsl.nix`; it excludes boot/network/
  hardware/desktop/impermanence modules.
- `nixvim` keeps its own pinned `nixos-26.05`; its nixpkgs input intentionally
  does NOT follow ours.
