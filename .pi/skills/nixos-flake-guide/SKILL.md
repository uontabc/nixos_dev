---
name: nixos-flake-guide
description: Guide for working with this NixOS flake repo (uontabc/nixos_dev). Use when editing NixOS config, adding/modifying modules under modules/, understanding the flake layout, rebuilding (nh os switch / nixos-rebuild), hosts (uontabc / wsl), impermanence, or when about to change config that affects the whole system.
---

# NixOS Flake Guide

This repo is a NixOS configuration managed with `flake-parts` + `import-tree`,
organized in the layout of the old codeberg nix-config repo
(core/system/desktop/programs/hosts). Every `.nix` file under `modules/` is
automatically imported; a file's `flake.modules.nixos.<name>` attribute becomes
a named NixOS module that other files reference via
`config.flake.modules.nixos.<name>`. There is NO home-manager — everything is
pure NixOS modules.

## Layout

- `flake.nix` — inputs only (nixpkgs `nixos-unstable`, flake-parts,
  import-tree, disko, impermanence, nixvim, noctalia, nixos-wsl,
  dev-templates). nixpkgs is pinned to `nixos-unstable`; do NOT point
  nixvim's nixpkgs at ours (they pin their own `nixos-26.05` — following
  breaks `vimPlugins`).
- `modules/base.nix` — imports shared by every host profile (users, nix,
  i18n, env, nh, git, neovim, pi, zsh). No desktop/browser packages —
  helium lives in `modules/desktop/default.nix` so the headless WSL host
  doesn't pull it.
- `modules/core/` — flake infra: `nix.nix` (Lix + USTC/SJTU mirrors),
  `systems.nix`.
- `modules/system/` — system services: networking (+ `daed.nix` proxy), boot,
  disko, impermanence, users, audio, bluetooth, graphics, input, zram,
  fonts, i18n, env, printing.
- `modules/desktop/` — GUI: `default.nix` (profile), niri, noctalia, kitty,
  qt, fcitx5, display (greetd), portal, xwayland, audio, thunar.
- `modules/programs/` — per-app config: neovim (nixvim), zsh (+ starship
  theme in `starship-theme.nix` at the repo root), git, pi, nh.
- `modules/hardware/` — CPU/GPU specifics: `cpu-amd.nix`, `nvidia.nix`,
  `default.nix` (bundles both + graphics/bluetooth/input/zram).
- `modules/hosts/common.nix` — host factory (codeberg style):
  `hostProfiles` (desktop / wsl module lists) + `mkHostConfiguration`
  (injects nixvim, sets hostname/platform/stateVersion).
- `modules/hosts/uontabc/configuration.nix` — the bare-metal desktop
  (AMD + NVIDIA, niri Wayland, btrfs + impermanence, GRUB). This is the
  machine you are on. Passes the profile + machine-specific extras
  (initrd kernel modules, @root-blank rollback service) to
  `mkHostConfiguration`.
- `modules/hosts/uontabc/_disko-devices.nix` — NixOS-only partitions on the
  dual-boot disk by **device path** (`/dev/nvme0n1p3` ESP, `/dev/nvme0n1p4`
  btrfs; Windows owns p1/p2, untouched). It calls `mkPartitionConfig` from
  `modules/system/_disko-lib.nix` (codeberg-style factory, also re-exported
  as `flake.lib`). Shared by the NixOS host
  (imported via `extraImports` in configuration.nix, exposed as
  `flake.modules.nixos.uontabc` by `modules/hosts/uontabc/disko.nix`) and the
  `diskoConfigurations.uontabc` output (modules/system/disko.nix). It is
  underscore-prefixed so import-tree does not import it as a flake-parts
  module. The rollback device is hardcoded in configuration.nix — change
  both together.
- `modules/hosts/wsl/configuration.nix` — headless NixOS-WSL guest.
- `modules/devshell.nix` — `nix develop` shell (lix, nh, nixfmt, statix, zsh).

## Conventions

- Repo lives at `~/nixos_dev` (hardcoded in `modules/programs/nh.nix` via
  `programs.nh.flake`). Moving it breaks `nh`.
- Username is `onyx`, wired through `config.my.name`. Home paths in other
  modules are built dynamically from it — never hardcode `/home/onyx`.
- System packages go in `my.packages` (user-level, defined in
  `modules/system/users.nix`) or `environment.systemPackages`. Avoid
  `nix profile`.
- Root filesystem rolls back every boot from `@root-blank`. Edits outside
  `/persist` do not survive unless declared. Declared files under
  `/etc` are recreated by systemd-tmpfiles on boot.
- `~/.ssh` and `~/.gnupg` are persisted with mode `0700`; `.zsh_history` is
  persisted as a user file.
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
2. Add the module name to the matching `hostProfiles` entry in
   `modules/hosts/common.nix` (or import it from a sibling module like
   `modules/desktop/default.nix` / `modules/base.nix`).
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

- WSL host pulls the `wsl` profile (base + wsl modules, `modules/system/wsl.nix`);
  it excludes boot/network/hardware/desktop/impermanence modules.
- `nixvim` keeps its own pinned `nixos-26.05`; its nixpkgs input intentionally
  does NOT follow ours.
- Root rollback runs in the initrd (`boot.initrd.systemd.services.impermanence-rollback`,
  defined in `modules/hosts/uontabc/configuration.nix`): it deletes the `root`
  subvolume and snapshots `@root-blank` over it every boot. `btrfs` is
  symlinked into the initrd `/bin` via `boot.initrd.systemd.extraBin` —
  `storePaths` alone does NOT put it on PATH. The btrfs device
  (`/dev/nvme0n1p4`) is hardcoded there and must match `_disko-devices.nix`.
- `diskoConfigurations.uontabc` is exposed in `modules/system/disko.nix` so
  the disko CLI works (`nix run github:nix-community/disko -- --flake
  .#uontabc --mode format,mount`); when it reports `disko-compat-error`, use
  `nix run .#nixosConfigurations.uontabc.config.system.build.formatMount`
  instead.
