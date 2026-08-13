# uontabc — NixOS Configuration

**Languages:** English (current) · [中文](README.zh-CN.md)

A declarative NixOS desktop configuration built entirely on NixOS modules (no home-manager). It pairs the [niri](https://github.com/niri-wm/niri) scrollable-tiling compositor with [Noctalia v5](https://github.com/noctalia-dev/noctalia) for the shell layer, [disko](https://github.com/nix-community/disko) for declarative btrfs partitioning, and [impermanence](https://github.com/nix-community/impermanence) for an ephemeral root with snapshot-based rollback. System maintenance is handled through [nh](https://github.com/nix-community/nh).

## Features

- **Scrollable-tiling compositor** — niri with KDL configuration and live reload
- **Desktop shell** — Noctalia v5 (bar, launcher, notifications, lock screen, control center), managed as a systemd user service
- **Declarative disk partitioning** — disko with btrfs subvolumes `root` / `persist` / `nix`
- **Ephemeral root** — impermanence persists critical state; the root subvolume is rolled back to the `@root-blank` snapshot on every boot
- **Dual-boot support** — GRUB with os-prober detects the Windows Boot Manager; NTFS support via ntfs3 for data partitions
- **Hardware drivers** — AMD Ryzen 9 8940HX (Zen 4, Dragon Range) + NVIDIA RTX 5060 Laptop (Blackwell, open kernel modules + stable driver)
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
| CPU | AMD Ryzen 9 8940HX (Zen 4, Dragon Range) | `modules/nixos/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop (Blackwell sm_120) | `modules/nixos/hardware/nvidia.nix` |
| iGPU | None (HX series ships with disabled/minimal iGPU; dGPU drives displays directly) | No PRIME config needed |
| Internal display | eDP-1, 2560×1600 @ 240 Hz | `modules/nixos/desktop/niri.nix` `output` block |
| External display | DP-1, 2560×1440 @ 210 Hz | same |
| Disk | Single NVMe, dedicated to NixOS | `hosts/uontabc/disko.nix` `device` field |

## Prerequisites

1. A UEFI-bootable machine with Secure Boot disabled in firmware.
2. A USB flash drive of at least 8 GB.
3. The [NixOS 26.05 ISO](https://nixos.org/download/) — download the "NixOS 26.05 GNOME" or "Minimal" image (any flavour works; this config replaces the desktop anyway). Consider verifying the ISO hash:
   ```bash
   sha256sum nixos-*.iso
   # compare against the hash published on nixos.org/download
   ```
4. **All data on the target disk backed up.** disko's `destroy` mode rewrites the partition table and wipes everything on that disk.
5. For dual-boot: Windows installed on a **separate physical disk**. disko cannot preserve a same-disk Windows installation.

## Installation

The installation proceeds in three phases — pre-installation (prepare the USB), installation (partition + install), and post-installation (first boot + verification).

### Phase 1 — Pre-installation

#### 1.1 Verify the target hardware

On the target machine (or in Windows), confirm the hardware:

```bash
# From a Linux live environment:
lspci -nn | grep -E 'VGA|3D'          # should show the NVIDIA RTX 5060
cat /proc/cpuinfo | grep 'model name' # should show AMD Ryzen 9 8940HX
lsblk                                 # note the target NVMe disk
```

If any component differs, adjust the corresponding module under `modules/nixos/hardware/` before proceeding.

#### 1.2 Flash the ISO to a USB drive

On a working computer, write the ISO to the USB drive. **All data on the USB drive will be erased.**

On Linux:

```bash
# Identify the USB device (not a partition) — e.g. /dev/sdb, not /dev/sdb1
lsblk

# Write the ISO (replace /dev/sdX with the USB device)
sudo cp nixos-*.iso /dev/sdX
sync
```

On Windows, use [Rufus](https://rufus.ie/) (DD mode, not ISO mode) or [balenaEtcher](https://etcher.balena.io/). Do **not** let Rufus "add" extra files — write the ISO image bit-for-bit.

#### 1.3 Configure UEFI firmware

Boot into the UEFI firmware settings (typically by pressing `F2`, `F12`, `Delete`, or `Esc` immediately after power-on):

- **Disable Secure Boot** → NixOS can boot with Secure Boot, but the NVIDIA driver requires unsigned modules. Set "Secure Boot" to Disabled.
- **Set the USB as the first boot device**, or use the one-time boot menu (`F12`).
- **Set SATA/NVMe mode to AHCI** (not "RAID" or "Intel RST"). NVIDIA + btrfs require AHCI.
- **Disable Fast Boot** → prevents the firmware from skipping USB enumeration.
- Save and exit with the USB inserted.

#### 1.4 Boot the live USB

Boot the NixOS ISO. At the bootloader menu, select "NixOS 26.05 Installer". Log in at the TTY (or graphical session — depends on the ISO flavour) as `root` (no password).

Connect to the network if installation needs to fetch packages:

```bash
# Wired: usually automatic. Verify:
ip addr

# Wireless (for the Minimal ISO, use nmtui):
nmtui
# → Activate a connection → select SSID → enter password → Back → Quit
ip addr show | grep inet
```

Synchronize the clock (Nixpkgs reproducibility depends on it):

```bash
timedatectl set-ntp true
timedatectl status
```

### Phase 2 — Installation

#### 2.1 Enter a flake-capable shell

The live ISO does not enable flakes by default:

```bash
nix-shell -p git vim disko --command bash
```

This pulls `git` (for cloning), `vim` (editing), and `disko` (partitioning) into the shell.

#### 2.2 Clone the repository

```bash
cd /tmp
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

Verify the flake evaluates:

```bash
nix flake show
# Should list: nixosConfigurations.uontabc
```

If `nix flake show` fails with "experimental feature", enable flakes for this shell:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

#### 2.3 Identify the target disk by stable ID

**Critical:** use the stable `by-id` path, not `/dev/nvme0n1`. Device names can reorder across reboots; `by-id` is stable.

```bash
ls -l /dev/disk/by-id/ | grep -v -E 'part|usb'
```

You will see entries like:

```
nvme-eui.000000000000000001a4e7b3e1234abc -> ../../nvme0n1
nvme-Samsung_SSD_980_PRO_1TB_S5KXXXXXXXX -> ../../nvme0n1
```

Record the longest, most specific `nvme-eui.*` or `nvme-<model>_*` path. **Triple-check that this is the disk you intend to wipe**:

```bash
# Confirm the disk's size and content match your expectations
sudo fdisk -l /dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc
smartctl -i /dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc
```

#### 2.4 Configure the disk in disko

Edit `hosts/uontabc/disko.nix` with your preferred editor:

```bash
vim hosts/uontabc/disko.nix
```

Replace the placeholder:

```nix
device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
```

with the path obtained in step 2.3, e.g.:

```nix
device = lib.mkDefault "/dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc";
```

Do **not** change the `partlabel` (`disk-main-btrfs`) — the rollback script in `postDeviceCommands` depends on it.

#### 2.5 Dry-run disko (recommended)

Before the destructive run, ask disko to show what it would do without writing anything:

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --dry-run --flake .#uontabc
```

Review the printed partition layout. You should see:
- 1 GB ESP (`vfat`, mounted at `/mnt/boot`)
- Remaining space as btrfs (`disk-main-btrfs`), with subvolumes `root`, `persist`, `nix` mounted at `/mnt`, `/mnt/persist`, `/mnt/nix` respectively.

#### 2.6 Run disko (destructive)

**This is the point of no return for the target disk. Confirm one last time:**

```bash
# Confirm you are about to wipe the correct disk:
cat hosts/uontabc/disko.nix | grep device
```

Run the actual partitioning:

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#uontabc
```

This:
1. **Destroys** the existing partition table.
2. **Formats** the ESP as vfat and the rest as btrfs.
3. **Mounts** everything under `/mnt`.

Verify the mounts:

```bash
mount | grep /mnt
# Expected:
# /mnt on /mnt type btrfs (subvol=root,...)
# /mnt/boot on /mnt/boot type vfat
# /mnt/nix on /mnt/nix type btrfs (subvol=nix,...)
# /mnt/persist on /mnt/persist type btrfs (subvol=persist,...)

ls /mnt
# Should show: boot  etc  home  nix  persist  root  ...
```

#### 2.7 Install NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

The installer will:
- Build the closure (this takes 5–30 minutes depending on hardware and cache).
- Install the bootloader (GRUB) onto the ESP.
- Register the new system at `/mnt`.

When prompted for a root password, set one. After "installation finished", don't reboot just yet — verify the install:

```bash
# Confirm the bootloader was installed
ls /mnt/boot/EFI/NixOS/
# Should show: .  ..  bootx64.efi  fwpkg/  grubx64.efi

# Confirm the rollback snapshot script is in the initrd
ls /mnt/nix/store/*-nixos-system-*/initrd
```

Then power off:

```bash
poweroff
```

Remove the USB, then power on.

### Phase 3 — Post-installation

#### 3.1 First boot

The system will boot into GRUB; the only menu entry should be "NixOS - Default". Select it.

The initrd runs the rollback script:
- On **first boot**: it snapshots `root` → `@root-blank` (the baseline).
- On **subsequent boots**: it deletes `root` and snapshots `@root-blank` → `root` (rollback to the baseline).

Then the system continues booting into `tuigreet` (login prompt).

Log in as `onyx` with the initial password `changeme` (defined in `modules/nixos/core/users.nix`).

#### 3.2 Change passwords immediately

```bash
# User password
passwd

# Root password (you set one during install, but you can change it here)
sudo passwd root
```

Consider replacing `initialPassword` in `modules/nixos/core/users.nix` with `hashedPassword` (see [the NixOS manual](https://nixos.org/manual/nixos/stable/#sec-user-sha512)).

#### 3.3 Verify the desktop session

After login, tuigreet should hand off to niri. You should see:

- A blank niri desktop (a single empty workspace)
- Noctalia starts as a systemd user service (bar/launcher)。 If not, manually check:

```bash
systemctl --user status noctalia
# Should be "active (running)"

# If failed, check the journal:
journalctl --user -u noctalia -b
```

niri config lives at `~/.config/niri/config.kdl` (symlinked to the nix store). Verify it:

```bash
ls -l ~/.config/niri/config.kdl
# Should be a symlink to /nix/store/<hash>-niri-config.kdl

niri validate
# Should print: Config is valid
```

#### 3.4 Verify the NVIDIA driver

```bash
nvidia-smi
# Should show the RTX 5060, driver version (570+), and CUDA version.

glxinfo | grep 'OpenGL renderer'
# Should show: OpenGL renderer string: NVIDIA GeForce RTX 5060 Laptop GPU

# Confirm modesetting is enabled:
cat /sys/module/nvidia_drm/parameters/modeset
# Should print: Y
```

If `nvidia-smi` fails:
- Confirm `hardware.nvidia.open = true` in `modules/nixos/hardware/nvidia.nix` (Blackwell requires open modules).
- Check `dmesg | grep -i nvidia` for module-load errors.

#### 3.5 Verify external display (DP-1)

Plug in the DP display. niri should auto-detect it. Verify:

```bash
niri msg outputs
# Should list both eDP-1 (2560x1600@240Hz) and DP-1 (2560x1440@210Hz)
```

If the output names differ (e.g. `DisplayPort-1` instead of `DP-1`), adjust the `output` blocks in `modules/nixos/desktop/niri.nix` accordingly.

#### 3.6 Move the repo to its permanent location and pin `NH_FLAKE`

`nh` reads `NH_FLAKE` to know where the flake lives. We configured this as `/home/onyx/nixos` in `modules/nixos/core/nh.nix`:

```bash
# Create the canonical location
mkdir -p ~/nixos

# From the live USB clone (now gone), re-clone:
cd ~
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

Verify `nh` finds the flake:

```bash
echo $NH_FLAKE
# Should print: /home/onyx/nixos

nh os info
# Should print info about the current system
```

#### 3.7 Apply updates via nh

From now on, operate on the flake via `nh`:

```bash
cd ~/nixos
nix flake update        # update flake.lock to latest nixpkgs-26.05
nh os switch            # build + activate
```

### Phase 4 — (Optional) NVIDIA PRIME offload

**Not needed for the 8940HX + RTX 5060 combination.** The HX series (Dragon Range) ships with a disabled or minimal iGPU; the dGPU drives the displays directly, which is why this config leaves `prime.offload.enable = false`.

For laptops with functional hybrid graphics (iGPU + dGPU), offload mode can be enabled — see the troubleshooting section below for the procedure.

## Maintenance

### Update the flake inputs

```bash
cd ~/nixos
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

### Enabling PRIME offload on a hybrid laptop (not the 8940HX)

For laptops with a functional iGPU + dGPU combo (HX series excluded), enable offload mode:

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
  amdgpuBusId = "PCI:5:0:0";
  nvidiaBusId = "PCI:1:0:0";
};
```

After rebuilding, offload a program to the dGPU with `nvidia-offload <program>`.

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

### Clock skew after dual-booting with Windows

Windows expects the hardware clock to be local time; NixOS expects UTC. If clocks drift:

```bash
timedatectl set-local-rtc 0   # NixOS stays UTC; fix Windows instead with:
# In Windows: reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

## References

- [niri documentation](https://niri-wm.github.io/niri/)
- [Noctalia documentation](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [disko](https://github.com/nix-community/disko)
- [impermanence](https://github.com/nix-community/impermanence)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) — reference for niri + Noctalia + impermanence composition

## License

MIT