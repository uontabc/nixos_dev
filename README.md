# uontabc — NixOS Configuration

**Languages:** English (current) · [中文](README.zh-CN.md)

A declarative NixOS desktop configuration built entirely on NixOS modules (no home-manager). It pairs the [niri](https://github.com/niri-wm/niri) scrollable-tiling compositor with [Noctalia v5](https://github.com/noctalia-dev/noctalia) for the shell layer, [disko](https://github.com/nix-community/disko) for declarative btrfs partitioning, and [impermanence](https://github.com/nix-community/impermanence) for an ephemeral root with snapshot-based rollback. System maintenance is handled through [nh](https://github.com/nix-community/nh).

## Features

- **Scrollable-tiling compositor** — niri with KDL configuration and live reload
- **Desktop shell** — Noctalia v5 (bar, launcher, notifications, lock screen, control center), managed as a systemd user service
- **Declarative disk partitioning** — disko with btrfs subvolumes `root` / `persist` / `nix`
- **Ephemeral root** — impermanence persists critical state; the root subvolume is rolled back to the `@root-blank` snapshot on every boot
- **Dual-boot support** — GRUB with os-prober detects the Windows Boot Manager; NTFS support via ntfs3 for data partitions
- **Hardware drivers** — AMD CPU (microcode + amd-pstate) + NVIDIA RTX 5060 Laptop (Blackwell, open kernel modules + stable driver)
- **Login** — tuigreet launches the niri session directly; no custom session scripts
- **nh** — replaces `nixos-rebuild` with fzf-based generation selection and automatic weekly garbage collection

## Directory Structure

```
.
├── flake.nix                       # Flake entry: inputs + nixosConfiguration
├── hosts/uontabc/
│   ├── default.nix                 # Host entry
│   ├── hardware.nix                # Empty — disko manages fileSystems
│   └── disko.nix                   # Declarative partitioning + btrfs rollback
└── modules/nixos/                  # All NixOS modules (no home-manager)
    ├── default.nix                 # Aggregate import
    ├── core/                       # boot, networking, locale, users, packages, env, nh
    ├── hardware/                   # cpu-amd, nvidia, graphics, bluetooth, input
    ├── desktop/                    # display, portal, audio, fonts, niri, noctalia, qt, kitty
    └── persistence/               # impermanence
```

User-level configuration is managed entirely within `modules/nixos/`:

- User packages → `users.users.onyx.packages` (`core/users.nix`)
- Configuration files (niri KDL, kitty.conf) → `pkgs.writeText` produces a nix-store path, then `systemd.tmpfiles.rules` symlinks it into `/home/onyx/.config/...`

## Hardware Profile

| Component | Assumed | Adjust in |
|---|---|---|
| CPU | AMD Ryzen (Zen 3+) | `modules/nixos/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop (Blackwell sm_120) | `modules/nixos/hardware/nvidia.nix` |
| iGPU | AMD iGPU (hybrid laptop) | Set `prime.amdgpuBusId` in `nvidia.nix` |
| Internal display | eDP-1, 2560×1600 @ 240 Hz | `modules/nixos/desktop/niri.nix` `output` block |
| External display | DP-1, 2560×1440 @ 210 Hz | same |
| Disk | Single NVMe, dedicated to NixOS | `hosts/uontabc/disko.nix` `device` field |

## Prerequisites

1. A UEFI-bootable machine with Secure Boot disabled
2. A [NixOS 26.05 ISO](https://nixos.org/download/) flashed to USB
3. **All disk data backed up** — disko's `destroy` mode wipes the target disk
4. For dual-boot: Windows installed on a **separate physical disk** (disko cannot preserve same-disk Windows)

## Installation

### 1. Boot the live USB

Disable Secure Boot in UEFI firmware settings, then boot the NixOS live ISO.

### 2. Enter a shell with git and an editor

```bash
sudo nix-shell -p git vim
```

### 3. Clone the repository

```bash
cd /tmp
git clone <your-repo-url> nixos
cd nixos
```

### 4. Identify the target disk by stable ID

```bash
ls -l /dev/disk/by-id/ | grep -v -E 'part|usb'
```

Record the `by-id` path of the target NVMe device, e.g. `nvme-eui.000000000000000001234567890123`. Using `by-id` rather than `/dev/nvme0n1` ensures stability across reboots.

### 5. Configure the disk in disko

Edit `hosts/uontabc/disko.nix` and replace the placeholder:

```nix
device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
```

with the path obtained in step 4.

### 6. Partition and format with disko

**This operation destroys all data on the target disk. Verify the disk identifier before proceeding.**

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#uontabc
```

Upon completion the partitions are mounted under `/mnt`:

```bash
mount | grep /mnt
# Expected: /mnt, /mnt/boot, /mnt/nix, /mnt/persist
```

### 7. Install NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

Set the root password when prompted, then power off, remove the USB, and boot.

### 8. First boot

- Log in as `onyx` with the initial password `changeme` (defined in `modules/nixos/core/users.nix`).
- **Immediately change the password:**

  ```bash
  passwd
  ```

- On first boot the btrfs rollback script seeds the `@root-blank` baseline snapshot from the `root` subvolume. Subsequent boots roll `root` back to `@root-blank` automatically.

### 9. (Optional) Enable NVIDIA PRIME offload

For hybrid laptops (iGPU + dGPU), the PCI bus IDs must be configured for offload mode.

Identify the GPU addresses:

```bash
lspci -nn | grep -E 'VGA|3D'
```

Convert the hexadecimal PCI addresses to the NixOS format (decimal `bus:device.function`):

| PCI address | NixOS BusID |
|---|---|
| `00:02.0` | `PCI:0:2:0` |
| `01:00.0` | `PCI:1:0:0` |

Edit `modules/nixos/hardware/nvidia.nix`:

```nix
hardware.nvidia.prime = {
  offload = {
    enable = lib.mkDefault true;
    enableOffloadCmd = lib.mkDefault true;
  };
  amdgpuBusId = "PCI:5:0:0";   # AMD iGPU
  nvidiaBusId = "PCI:1:0:0";   # NVIDIA dGPU
};
```

After rebuilding, offload a program to the dGPU with `nvidia-offload <program>`.

## Maintenance

### Update the flake inputs

```bash
cd ~/nixos               # repository clone location
nix flake update         # update flake.lock
nh os switch             # build and activate (reads NH_FLAKE)
```

### Rebuild after a configuration change

```bash
nh os switch             # build + activate
nh os test               # build + test (no activation)
nh os boot               # set as default for next boot
nh os switch -- -v       # pass verbose to nixos-rebuild
nh clean all            # manual GC (automatic weekly GC configured in core/nh.nix)
```

### Rollback

The GRUB boot menu lists the 10 most recent generations (`configurationLimit = 10`). Select an older generation to boot into it. Rollback operates on the ephemeral root subvolume only; persisted data under `/persist` is unaffected.

### Modify niri configuration

Edit `modules/nixos/desktop/niri.nix`. Niri hot-reloads `config.kdl` on save. Configuration errors surface in the journal:

```bash
journalctl --user -u niri -f
```

Reference: https://niri-wm.github.io/niri/Configuration:-Introduction

## Persistence

Because `/` is ephemeral (rolled back on each boot):

- Do not store long-lived data directly under `/` — it will not survive a reboot.
- System state to persist: add to `modules/nixos/persistence/impermanence.nix` → `directories` / `files`.
- User state to persist: add to the same file → `users.onyx.directories` (`Documents`, `Downloads`, etc. are already listed).
- `~/.config` is intentionally **not** persisted; niri and kitty configs are bind-symlinked to the nix store via `systemd.tmpfiles`.
- To persist Noctalia's GUI settings, add `"noctalia"` to `users.onyx.directories`.

## Troubleshooting

### Windows not detected by GRUB

```bash
efibootmgr                                # verify Windows Boot Manager entry exists
sudo nix-shell -p os-prober -c os-prober  # test os-prober detection
```

If os-prober fails to locate Windows, verify that NTFS support is available — check `boot.supportedFilesystems = ["btrfs" "ntfs"]` in `modules/nixos/core/boot.nix`.

### NVIDIA driver issues

```bash
cat /proc/driver/nvidia/version               # expect 570+
cat /sys/module/nvidia_drm/parameters/modeset  # expect Y
nvidia-smi                                     # dGPU status
```

If `nvidia-smi` fails on a Blackwell GPU, verify `hardware.nvidia.open = true` in `nvidia.nix` — Blackwell requires open kernel modules.

### disko data-loss warning (dual-boot)

disko's `--mode destroy,format,mount` rewrites the entire GPT partition table and **cannot preserve a same-disk Windows installation**. Two safe approaches:

1. **Separate physical disk** — point `disko.nix` `device` at the NixOS disk; Windows remains untouched.
2. **Same disk** — skip disko's destroy mode; manually shrink the Windows partition with `parted`, create btrfs partitions, and populate `fileSystems` directly. Remove the `disko.devices` block from `disko.nix` and verify the `postDeviceCommands` rollback script against the actual partition label.

### Initrd hang on first boot

The rollback script in `hosts/uontabc/disko.nix` relies on the partition label `disk-main-btrfs` (auto-generated by disko). Verify:

```bash
ls -l /dev/disk/by-partlabel/ | grep btrfs
```

### niri fails to start

```bash
journalctl --user -u niri -b    # current boot logs
niri validate                   # validate config syntax
```

Config path: `~/.config/niri/config.kdl` (symlinked to nix store via `systemd.tmpfiles`).

## References

- [niri documentation](https://niri-wm.github.io/niri/)
- [Noctalia documentation](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [disko](https://github.com/nix-community/disko)
- [impermanence](https://github.com/nix-community/impermanence)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) — reference for niri + Noctalia + impermanence composition

## License

MIT