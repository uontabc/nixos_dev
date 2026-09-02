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
pure NixOS modules; user files under `$HOME` are managed declaratively by
**hjem** (see Layout, `modules/hjem.nix`).

## Layout

- `flake.nix` — inputs only (nixpkgs `nixos-unstable`, flake-parts,
  import-tree, disko, impermanence, noctalia, helium, nixos-wsl,
  dev-templates, hjem, tokyo-night-grub [plain repo, `flake = false`, GRUB
  theme]). disko/noctalia/helium/nixos-wsl/dev-templates follow nixpkgs.
  nixpkgs is pinned to `nixos-unstable`. Also carries `nixConfig` (mirrors +
  trusted key, honored via `accept-flake-config`).
- `modules/base.nix` — imports shared by every host profile (users, hjem,
  nix, i18n, env, nh, git, neovim, pi, fish) + unfree whitelist
  (qq/helium/nvidia*). No desktop/browser packages — helium lives in
  `modules/desktop/default.nix` so the headless WSL host doesn't pull it.
- Root-level infra files (auto-imported by import-tree): `flake-parts.nix`
  (pkgs construction, keep its allowUnfreePredicate in sync with base.nix),
  `hjem.nix`, `devshell.nix`, `templates.nix` (re-exports dev-templates),
  `_starship-theme.nix` (`_`-prefix: skipped as a module; `host` theme for
  login shells, `devshell` theme = no-empty-icons preset).
- `modules/core/` — flake infra: `nix.nix` (Lix + USTC/SJTU mirrors),
  `systems.nix`.
- `modules/system/` — system services: networking (+ `daed.nix` proxy), boot,
  disko, impermanence (persistence lists + the initrd rollback service,
  option-driven via `impermanence.rollbackDevice`), users, wsl, audio,
  bluetooth, graphics, input, zram, fonts, i18n, env, printing.
- `modules/desktop/` — GUI: `default.nix` (profile), niri, noctalia, kitty,
  qt, fcitx5, display (greetd), portal, xwayland, audio, pcmanfm.
- `modules/hjem.nix` — wires up hjem (`inputs.hjem`), `hjem.users.<user>`
  enabled for `my.name`. Other modules declare their user files under
  `hjem.users.<user>.files` (plain files/dirs, e.g. `~/.config/fish/config.fish`, nvim state
  dirs) or `xdg.config.files` (e.g. `~/.config/starship.toml`), usually with
  `clobber = true`. A `hjem-activate@.service` run as the user links/creates
  them at boot, replacing the old per-module systemd-tmpfiles rules (commit
  6c2b03c).
- `modules/programs/` — per-app config: neovim (pure NixOS via
  `programs.neovim` + `vimPlugins`, init.lua in
  `modules/programs/neovim/init.lua` read via `builtins.readFile`; LSP is
  wired with nvim-lspconfig ≥0.11 style `vim.lsp.config`/`vim.lsp.enable` —
  no `require('lspconfig')`), fish (login shell via programs.fish; config.fish in
  `modules/programs/fish.nix` + starship themes from
  `modules/_starship-theme.nix`), git, pi, nh.
- `modules/overlays/` — nixpkgs overlay forcing QQ to Wayland (desktop only).
- `modules/hardware/` — CPU/GPU specifics: `cpu-amd.nix`, `nvidia.nix`,
  `default.nix` (bundles both + graphics/bluetooth/input/zram).
- `modules/hosts/common.nix` — host factory (codeberg style):
  `hostProfiles` (`desktop` = base boot network hardware desktop overlays
  impermanence disko; `wsl` = base wsl) + `mkHostConfiguration`
  (sets hostname/platform/stateVersion).
- `modules/hosts/uontabc/configuration.nix` — the bare-metal desktop
  (AMD + NVIDIA, niri Wayland, btrfs + impermanence, GRUB). This is the
  machine you are on. Passes the profile + machine-specific extras
  (initrd kernel modules, disko layout, `impermanence.rollbackDevice`) to
  `mkHostConfiguration`.
- `modules/system/disko.nix` — the single disko file (codeberg style):
  `flake.lib.mkDiskConfig` (whole disk) + `flake.lib.mkPartitionConfig`
  (dual-boot by device path), the NixOS module wrapper, and
  `diskoConfigurations.uontabc`. uontabc builds its layout inline in
  configuration.nix via `extraImports = [ (config.flake.lib.mkPartitionConfig
  { esp = "/dev/nvme0n1p3"; root = "/dev/nvme0n1p4"; }) ]` (Windows keeps
  p1/p2 untouched). `flake.lib` is declared mergeable in hosts/common.nix
  (flake-parts freeform attrs would otherwise not merge).
- `modules/hosts/wsl/configuration.nix` — headless NixOS-WSL guest.
- `modules/devshell.nix` — `nix develop` shell (lix, nh, nixfmt, statix,
  git, fish + lockfile-pinned disko CLI; STARSHIP_CONFIG = devshell theme).

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
- `$HOME` files are declarative: each module declares its user files in
  `hjem.users.<user>` (files / xdg.config.files, usually `clobber = true`).
  Edit the module, not `~` — hjem re-links on boot and overwrites manual
  edits. Runtime credentials (`~/.pi/agent/auth.json`, `~/.ssh/...`) are NOT
  hjem-managed and persist freely (impermanence keeps the dirs).
- `~/.ssh` and `~/.gnupg` are persisted with mode `0700`; fish history
  (`~/.local/share/fish/fish_history`) is persisted via `~/.local/share`
  (the old `.zsh_history` entry is gone — no zsh anymore).
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
- Home-dir ownership: systemd-tmpfiles refuses to touch paths whose parent
  is owned by a different user than the target ("Detected unsafe path
  transition", exit 73) — a root-owned `~/.local` created by `sudo mkdir`
  silently defeated the old tmpfiles rules on WSL and blocked nvim's state
  dirs (E739). Since hjem (commit 6c2b03c) creates declared dirs *as the
  user*, this class of bug is gone; if it recurs, fix with
  `sudo chown -R <user>:users ~/.local`.
- Root rollback runs in the initrd (`boot.initrd.systemd.services.impermanence-rollback`,
  defined in `modules/system/impermanence.nix`, enabled by the
  `impermanence.rollbackDevice` option that hosts set in
  `modules/hosts/uontabc/configuration.nix`): it deletes the `root`
  subvolume and snapshots `@root-blank` over it every boot. `btrfs` is
  symlinked into the initrd `/bin` via `boot.initrd.systemd.extraBin` —
  `storePaths` alone does NOT put it on PATH. The btrfs device
  (`/dev/nvme0n1p4`) is declared via `impermanence.rollbackDevice` and must
  match the `mkPartitionConfig` call in `modules/system/disko.nix`.
- `diskoConfigurations.uontabc` is exposed in `modules/system/disko.nix` so
  the disko CLI works. Use the lockfile-pinned CLI (`nix run .#disko --
  --flake .#uontabc --mode format,mount`, or `disko` in the devshell) — NOT
  `nix run github:nix-community/disko`, which fetches GitHub and fails with
  Connection error in CN; when it reports `disko-compat-error`, use
  `nix run .#nixosConfigurations.uontabc.config.system.build.formatMount`
  instead.
