# uontabc — NixOS Configuration

**Languages:** English (current) · [中文](README.zh-CN.md)

A declarative NixOS desktop configuration built entirely on NixOS modules (no home-manager). The flake is structured with [flake-parts](https://github.com/hercules-ci/flake-parts). It pairs the [niri](https://github.com/niri-wm/niri) scrollable-tiling compositor with [Noctalia v5](https://github.com/noctalia-dev/noctalia) for the shell layer, [impermanence](https://github.com/nix-community/impermanence) for an ephemeral root with snapshot-based rollback, and [nh](https://github.com/nix-community/nh) for maintenance. The target host runs Windows + NixOS on the **same physical disk** — disk preparation is manual `cfdisk`; `fileSystems` and the rollback script reference partitions by a stable *partlabel* (`nixos-esp`, `nixos-btrfs`).

## Features

- **Scrollable-tiling compositor** — niri with KDL configuration and live reload
- **Desktop shell** — Noctalia v5 (bar, launcher, notifications, lock screen, control center), managed as a systemd user service
- **Same-disk dual-boot with Windows** — NixOS shares a single NVMe with Windows via a separate ESP + btrfs partition; GRUB + os-prober adds Windows Boot Manager to its menu
- **Ephemeral root** — impermanence persists critical state; the root subvolume is rolled back to the `@root-blank` snapshot on every boot
- **btrfs subvolumes** `root` / `persist` / `nix` — compress=zstd, ssd, noatime
- **Hardware drivers** — AMD Ryzen 9 8940HX (Zen 4, Dragon Range) + NVIDIA RTX 5060 Laptop (Blackwell, open kernel modules + stable driver)
- **Login** — tuigreet launches the niri session directly; no custom session scripts
- **nh** — replaces `nixos-rebuild` with fzf-based generation selection and automatic weekly garbage collection

## How disko coexists with same-disk dual-boot

[disko](https://github.com/nix-community/disko) is used for declarative **filesystem** setup (mkfs + btrfs subvolumes + mounts), but the **partition table is created manually** with `cfdisk`. This split is deliberate: disko's `gpt` content type runs `sgdisk --clear` when the disk has no recognizable partition table, but using `sgdisk --new` to recreate partitions on a disk that already has Windows partitions risks partition-number collisions and data loss. Instead:

1. You create the two NixOS partitions (`nixos-esp`, `nixos-btrfs`) with `cfdisk` in the free space — Windows partitions stay at their existing numbers.
2. disko's `disk.devices.<name>` blocks point at **existing partitions** (`device = "/dev/disk/by-partlabel/..."`) with `content.type = "filesystem"` / `"btrfs"` — disko only runs `mkfs` and `btrfs subvolume create`, which are **idempotent** (skipped if `blkid`/`btrfs subvolume show` detects an existing fs/subvolume).
3. Every disko disk block has `destroy = false`, so even `--mode destroy,...` refuses to wipe those partitions.
4. disko **auto-injects `fileSystems.*`** into the NixOS config from its own device declarations — no manual `fileSystems` in the repo, but `boot.initrd.postDeviceCommands` (the rollback script) stays in `modules/hosts/uontabc/default.nix` and references the same `by-partlabel/nixos-btrfs` path.

Run `disko --mode format,mount` (never `--mode destroy,...`). It is the single step that replaces mkfs + subvolume create + mount, and it is safe to re-run.

## Directory Structure

```
.
├── flake.nix                       # Minimal entry: import-tree auto-imports ./modules/
└── modules/                        # All flake-parts + NixOS modules (no home-manager)
    ├── systems.nix                 #   systems list
    ├── flake-parts.nix             #   perSystem config (unfree)
    ├── lib/nixos.nix               #   host factory: options.hosts → nixosConfigurations
    ├── users.nix                   #   my.name / my.packages options + user creation
    ├── base.nix                    #   base: users, nix, i18n, env, nh, git
    ├── boot.nix                    #   GRUB + os-prober + btrfs/ntfs
    ├── network.nix                 #   NetworkManager + openssh
    ├── env.nix                     #   XDG session variables
    ├── nh.nix                      #   nh CLI + weekly GC
    ├── impermanence.nix            #   persistent state via /persist bind-mounts
    ├── disko.nix                   #   disko module wrapper
    ├── hardware/                   #   hardware drivers
    │   ├── default.nix             #     aggregator: cpu-amd, nvidia, graphics, bluetooth, input
    │   └── cpu-amd.nix  nvidia.nix  graphics.nix  bluetooth.nix  input.nix
    ├── desktop/                    #   desktop services
    │   ├── default.nix             #     aggregator: audio, display, portal, noctalia, xwayland + config apps
    │   └── audio.nix  display.nix  portal.nix  noctalia.nix  xwayland.nix
    ├── config/                     #   per-app configs (each a named nixos module)
    │   └── i18n.nix  nix.nix  git.nix  fonts.nix  niri.nix  kitty.nix  qt.nix  opencode.nix
    ├── wsl.nix                     #   NixOS-WSL module (terminal-only WSL distro)
    └── hosts/
        ├── uontabc/
        │   ├── default.nix         #   hosts.uontabc = { system, stateVersion, module }
        │   └── disko.nix           #   flake.modules.nixos.uontabc.disko.devices
        └── wsl/default.nix         #   hosts.wsl (auto-attaches the wsl module)
```

Built with [flake-parts](https://flake.parts) + [import-tree](https://github.com/vic/import-tree): every `.nix` file under `modules/` is auto-imported — no `default.nix` aggregates. Each module declares `flake.modules.nixos.<name>` and references others by name, not by path. Inspired by [ocfox/island](https://github.com/ocfox/island).

User-level configuration is managed entirely within NixOS modules:

- User packages → `my.packages` option (collected into `users.users.${my.name}.packages`)
- Configuration files (niri KDL, kitty.conf) → `pkgs.writeText` produces a nix-store path, then `systemd.tmpfiles.rules` symlinks it into `/home/<user>/.config/...`

## Hardware Profile

| Component | Assumed | Adjust in |
|---|---|---|
| CPU | AMD Ryzen 9 8940HX (Zen 4, Dragon Range) | `modules/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop (Blackwell sm_120) | `modules/hardware/nvidia.nix` |
| iGPU | None (HX series ships with disabled/minimal iGPU; dGPU drives displays) | No PRIME config needed |
| Internal display | eDP-1, 2560×1600 @ 240 Hz | `modules/config/niri.nix` `output` block |
| External display | DP-1, 2560×1440 @ 210 Hz | same |
| Target disk | Single NVMe, Windows + NixOS coexisting | `modules/hosts/uontabc/default.nix` (`fileSystems`) |
| NixOS partition size | 512 GB | determined by your `sgdisk` step |

## Target Partition Layout

**NixOS gets its own dedicated ESP** — it is *not* shared with Windows. Windows keeps its own `~100 MB` ESP (`nvme0n1p1`) untouched; NixOS uses a fresh 1 GB ESP (`nixos-esp`) for GRUB, so neither OS can interfere with the other's boot files.

You will build this layout with `sgdisk` on `/dev/nvme0n1` before installing:

| Partition | Name (partlabel) | Type | Size | fsType | Mount |
|---|---|---|---|---|---|
| `nvme0n1p1` | *(Windows, existing)* | `EF00` (ESP) | ~100 MB | fat32 | Windows's ESP (untouched) |
| `nvme0n1p2` | *(Windows, existing)* | reserved | ~16 MB | ― | untouched |
| `nvme0n1p3` | *(Windows, existing)* | NTFS | shrunk by you | ntfs | Windows C: (untouched) |
| `nvme0n1p4` | **`nixos-esp`** | `EF00` (ESP) | 1 GB | fat32 | `/boot` |
| `nvme0n1p5` | **`nixos-btrfs`** | Linux fs | 511 GB | btrfs | `/`, `/nix`, `/persist` (via subvols) |

The partition numbers shown assume Windows occupies `p1–p3`; `sgdisk -n 0` picks the next free number automatically, so your actual numbers may differ. The partlabels `nixos-esp` and `nixos-btrfs` are critical — `disko.nix` mounts by these names, and the rollback script opens `by-partlabel/nixos-btrfs`. If you forget to set them, the system will not boot.

## Prerequisites

1. A UEFI-bootable machine with Secure Boot disabled in firmware.
2. A USB flash drive of at least 8 GB.
3. The [NixOS 26.05 ISO](https://nixos.org/download/) — Minimal is recommended (you'll partition manually from a TTY; the graphical ISO wastes RAM). Verify the hash:
   ```bash
   sha256sum nixos-*.iso
   # compare against the hash published on nixos.org/download
   ```
4. **Important disk-data backup.** Although this guide is conservative about Windows, a partition-editor mistake can still destroy partitions — back up irreplaceable Windows files to an external drive before starting.
5. **Windows enabled for shrinking.** BitLocker must be suspended or disabled on C: before the volume can be shrunk from inside Windows (or from the live USB with `ntfsresize` after `ntfsfix`).
6. **At least 512 GB of free space currently unused on the Windows volume.** If less, shrink Windows more aggressively, or use the "no-rollback" workaround in Troubleshooting.

## Installation

The installation proceeds in four phases.

### Phase 1 — Pre-installation

#### 1.1 Free up 512 GB from inside Windows

Shrinking from inside Windows is safest, since Windows can relocate its own files.

1. Boot Windows normally.
2. If BitLocker is enabled on C:, suspend it: *Settings → Privacy and security → Device encryption → BitLocker → Suspend protection* (resume after install in NixOS; NixOS does not unlock BitLocker at boot).
3. Open `diskmgmt.msc` (Disk Management). Right-click the C: partition → **Shrink Volume**. Enter **524288 MB** (512 GiB). Windows may refuse to shrink past a certain point due to unmovable files. Workarounds:
   - Disable System Restore, hibernation (`powercfg /h off`), and the page file, then retry.
   - Use a third-party tool such as [DiskGenius](https://www.diskgenius.com/) or [AOMEI Partition Assistant](https://www.aomeitech.com/) that can move the MFT.
4. Verify 512 GB of "Unallocated" space now appears after the C: partition.
5. Shut down Windows completely (do **not** use Fast Startup / hybrid shutdown — disable it in Control Panel → Power Options → Choose what the power buttons do).

#### 1.2 Flash the ISO to a USB drive

On a working computer, write the ISO to USB. **All data on the USB drive will be erased.**

On Linux:

```bash
lsblk                                   # identify USB device, e.g. /dev/sdb
sudo cp nixos-*.iso /dev/sdX
sync
```

On Windows, use [Rufus](https://rufus.ie/) in **DD mode** (not ISO mode), or [balenaEtcher](https://etcher.balena.io/).

#### 1.3 Configure UEFI firmware

Reboot into the UEFI firmware settings (commonly `F2`, `F12`, `Delete`, or `Esc` immediately after power-on):

- **Disable Secure Boot** — the NVIDIA driver loads unsigned kernel modules.
- **Set the USB as first boot device** (or use the one-time boot menu, typically `F12`).
- **NVMe/SATA mode = AHCI** (not RAID / Intel RST).
- **Disable Fast Boot** — so firmware enumerates USB devices.
- Save and exit; the USB should already be plugged in.

#### 1.4 Boot the live USB

Boot the NixOS ISO, select **NixOS 26.05 Installer** at the menu, and log in at the TTY as `root` (no password).

Bring up the network (packages must be fetched over the internet):

```bash
# Wired — usually automatic. Verify with:
ip addr

# Wireless — for the Minimal ISO:
nmtui
# → Activate a connection → choose SSID → enter password → Back → Quit
ip addr show | grep inet
```

Synchronize the clock (Nixpkgs reproducibility depends on it):

```bash
timedatectl set-ntp true
timedatectl status
```

### Phase 2 — Partitioning the freed space

This phase creates partitions **only in the 512 GB of unallocated space**. Everything else on the disk stays untouched. **Double-check every command** — partition editors will not ask twice.

#### 2.1 Enter a flake-capable shell

```bash
nix-shell -p git vim btrfs-progs --command bash
```

(`cfdisk` ships with util-linux and is already present on the live ISO; `dosfstools` is pulled in by disko's own script when it formats the ESP.)

#### 2.2 Clone the repository (disko needs the flake)

```bash
cd /tmp
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

If `nix flake` complains about experimental features, enable flakes for this shell:

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

Verify the flake:

```bash
nix flake show
# Should list: nixosConfigurations.uontabc
```

#### 2.3 Create the two NixOS partitions (cfdisk)

Open the interactive partition editor:

```bash
sudo cfdisk /dev/nvme0n1
```

If asked for a label type, select **gpt** (keep the existing one if the disk already has a GPT table). Use the arrow keys and enter/spacebar:

1. Move to the **Free space** entry → **New** → size **1G** → type **EFI System**. This is `nixos-esp`.
2. Move to the remaining **Free space** → **New** → accept the default size (the rest of the disk) → type **Linux filesystem**. This is `nixos-btrfs`.
3. Select the new 1G partition → **Rename** → enter **nixos-esp** (this sets the GPT partition name = partlabel).
4. Select the new btrfs partition → **Rename** → enter **nixos-btrfs**.
5. Select **Write** → confirm with `yes`, then **Quit**.

> In cfdisk, *Rename* writes the GPT partition name, which is what udev exposes as `/dev/disk/by-partlabel/<name>`. Both partitions must be renamed — the mount config and rollback script depend on the exact partlabels `nixos-esp` and `nixos-btrfs`.

Make the kernel re-read the partition table (cfdisk usually does this itself; the commands are a no-op fallback):

```bash
sudo partprobe /dev/nvme0n1
sudo udevadm settle
```

#### 2.4 Verify the partlabels

```bash
ls -l /dev/disk/by-partlabel/
# Expect: nixos-esp  -> ../../nvme0n1p4   (numbers may differ)
#         nixos-btrfs -> ../../nvme0n1p5
```

Also confirm the Windows partitions are untouched:

```bash
lsblk
# Windows p1/p2/p3 still present, plus nixos-esp and nixos-btrfs
```

#### 2.5 Run disko (format + mount)

With the partitions in place, disko takes over. It is **idempotent** — `blkid` detects any existing filesystem and skips `mkfs`; `btrfs subvolume show` detects any existing subvolume and skips create. So even on a re-run nothing gets destroyed. disko also **injects `fileSystems.*` into the NixOS config automatically** — no manual `fileSystems` declarations in the repo.

```bash
sudo nix run .#nixosConfigurations.uontabc.config.system.build.formatMount
```

> Using the flake's own `formatMount` script (rather than `nix run github:nix-community/disko`) guarantees the executed disko revision matches the one pinned in `flake.nix` — no version drift, no hard error on re-runs.

This:
1. `mkfs.fat` the `nixos-esp` partition (skipped if already fat32).
2. `mkfs.btrfs` the `nixos-btrfs` partition (skipped if already btrfs).
3. Creates btrfs subvolumes `root`, `nix`, `persist` (each skipped if already present).
4. Mounts everything under `/mnt`: `/mnt` (subvol=root), `/mnt/boot` (vfat), `/mnt/nix` (subvol=nix), `/mnt/persist` (subvol=persist).

Verify:

```bash
mount | grep /mnt
# Expected four lines: /mnt (subvol=root), /mnt/boot (vfat),
#                     /mnt/nix (subvol=nix), /mnt/persist (subvol=persist)

df -h /mnt /mnt/boot /mnt/nix /mnt/persist
```

> **Note**: disko only targets the partitions you point it at (`/dev/disk/by-partlabel/nixos-*`). It does **not** touch Windows partitions. Every disko disk block in `modules/hosts/uontabc/disko.nix` has `destroy = false`, so even if someone accidentally runs `--mode destroy,...`, disko refuses to wipe the configured partitions.

### Phase 3 — Installation

#### 3.1 (Optional sanity check) Dry-evaluate the system

If you've adjusted any modules, evaluate the configuration without activating:

```bash
nix build .#nixosConfigurations.uontabc.config.system.build.toplevel --dry-run
```

#### 3.2 Install NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

The installer will:
- Build the closure (5–30 minutes depending on hardware and cache).
- Install GRUB onto the **NixOS ESP** (`/boot`) — `boot.loader.efi.efiSysMountPoint = "/boot"` ensures GRUB writes to `nixos-esp`, never Windows's ESP.
- Register the system at `/mnt`.

When prompted, set a root password. Then **do not reboot yet** — verify:

```bash
# GRUB installed into NixOS's own ESP, not Windows's
ls /mnt/boot/EFI/NixOS/
# Expect: .  ..  bootx64.efi  fwpkg/  grubx64.efi

# initrd includes the rollback script
ls /mnt/nix/store/*-nixos-system-*/initrd

# A new UEFI boot entry for "NixOS" exists
efibootmgr
```

Then power off:

```bash
poweroff
```

Remove the USB and boot.

### Phase 4 — Post-installation

#### 4.1 First boot

Boot into the UEFI one-time boot menu (typically `F12`). You should see **two** entries:

- **Windows Boot Manager** (on the Windows ESP)
- **NixOS** (on the `nixos-esp` partition)

Select **NixOS**. The initrd rollback script runs:
- On **first boot**: since the `@root-blank` snapshot already exists (we created it in step 2.5), it deletes `root` and re-snapshots from `@root-blank`. This is a no-op semantically but validates the rollback path.
- On **subsequent boots**: same operation — rolls back any imperative changes to `/`.

Then the system continues into `tuigreet` (the login prompt). Log in as `onyx` with initial password `changeme` (defined in `modules/users.nix`).

#### 4.2 Change passwords immediately

```bash
passwd                # user password
sudo passwd root      # root password
```

For better hygiene, replace `initialPassword` in `modules/users.nix` with `hashedPassword` (see [the NixOS manual](https://nixos.org/manual/nixos/stable/#sec-user-sha512)).

#### 4.3 Verify the desktop session

After login, tuigreet hands off to niri. You should see:

- An empty niri desktop (a single empty workspace)
- Noctalia started as a systemd user service — bar/launcher visible

If Noctalia is missing, check:

```bash
systemctl --user status noctalia
journalctl --user -u noctalia -b
```

Verify the niri config:

```bash
ls -l ~/.config/niri/config.kdl      # symlink to /nix/store/<hash>-niri-config.kdl
niri validate                         # should print: Config is valid
```

#### 4.4 Verify the NVIDIA driver

```bash
nvidia-smi
# Expect: RTX 5060, driver version 570+, CUDA version

glxinfo | grep 'OpenGL renderer'
# Expect: OpenGL renderer string: NVIDIA GeForce RTX 5060 Laptop GPU

cat /sys/module/nvidia_drm/parameters/modeset
# Expect: Y
```

If `nvidia-smi` fails, confirm `hardware.nvidia.open = true` in `modules/hardware/nvidia.nix` and check `dmesg | grep -i nvidia`.

#### 4.5 Verify external display (DP-1)

Plug in the DP display. niri should auto-detect it:

```bash
niri msg outputs
# Expect both eDP-1 (2560×1600@240 Hz) and DP-1 (2560×1440@210 Hz)
```

If the output names differ (e.g. `DisplayPort-1` instead of `DP-1`), adjust the `output` blocks in `modules/config/niri.nix`.

#### 4.6 Verify Windows is still bootable

Reboot. At the UEFI one-time boot menu, select **Windows Boot Manager**. Windows should boot normally.

If GRUB also detected Windows automatically (os-prober), you will see a "Windows" entry in the GRUB menu you can select directly without going through the UEFI menu. To trigger os-prober re-detection:

```bash
sudo nix-shell -p os-prober -c os-prober
# Should print: Found Windows Boot Manager on /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi
```

Re-run `nh os switch` so GRUB regenerates with the Windows entry baked in (you must have **Windows Boot Manager** entry in `efibootmgr` for os-prober to find it: usually Windows installer creates it).

#### 4.7 Move the repo to its permanent location and pin NH_FLAKE

`nh` reads `NH_FLAKE` (set to `/home/onyx/nixos_dev` in `modules/nh.nix`, matching the repo name). Clone the repo to that exact path so `nh os switch` works with no arguments:

```bash
cd ~
git clone https://github.com/uontabc/nixos_dev.git nixos_dev
cd nixos_dev

echo $NH_FLAKE           # Should print: /home/onyx/nixos_dev
nh os info               # Should print info about the current system
```

#### 4.8 Apply updates via nh

```bash
cd ~/nixos_dev
nix flake update          # update flake.lock to latest nixpkgs-26.05
nh os switch              # build + activate
```

### Phase 5 — (Optional) delete `@root-blank` to opt out of rollback

Some users prefer impermanence-on-mount (state wiped on `/` each boot) without rollback behaviour. The rollback is controlled by `host/uontabc/hardware.nix`'s `postDeviceCommands`. To disable it, comment out the entire `boot.initrd.postDeviceCommands` block and delete the existing `@root-blank`:

```bash
sudo mount /dev/disk/by-partlabel/nixos-btrfs /mnt
sudo btrfs subvolume delete /mnt/@root-blank
sudo umount /mnt
```

Rebuild without the script; impermanence's bind-mounts from `/persist` still work.

## Maintenance

### Update the flake inputs

```bash
cd ~/nixos_dev
nix flake update         # update flake.lock
nh os switch             # build and activate
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

Edit `modules/config/niri.nix`. Niri hot-reloads `config.kdl` on save. Configuration errors surface in the journal:

```bash
journalctl --user -u niri -f
```

Reference: https://niri-wm.github.io/niri/Configuration:-Introduction

## Persistence

Because `/` is ephemeral (rolled back on each boot):

- Do not store long-lived data directly under `/` — it will not survive a reboot.
- System state to persist: add to `modules/impermanence.nix` → `directories` / `files`.
- User state to persist: add to the same file → `users.onyx.directories` (`Documents`, `Downloads`, etc. are already listed).
- `~/.config` is intentionally **not** persisted; niri and kitty configs are bind-symlinked to the nix store via `systemd.tmpfiles`.
- To persist Noctalia's GUI settings, add `"noctalia"` to `users.onyx.directories`.

## Troubleshooting

### Windows didn't show up in GRUB / efibootmgr

```bash
efibootmgr                                # verify Windows Boot Manager entry exists
sudo nix-shell -p os-prober -c os-prober  # test os-prober detection
```

If `efibootmgr` has no Windows entry, it was lost (rare — usually the Windows installer creates it). Recreate it manually:

```bash
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\\EFI\\Microsoft\\Boot\\bootmgfw.efi'
```

Then re-run `os-prober` and `nh os switch`.

### Can't shrink the Windows volume while Windows hibernated

Windows's "Fast Startup" is a partial hibernation. Disable it in Windows: *Control Panel → Power Options → Choose what the power buttons do → uncheck "Turn on fast startup"*. Then shut down Windows fully (not restart).

### BitLocker locked me out after resizing

If Windows refuses to boot with a BitLocker recovery key prompt after a partition-table operation, you booted with BitLocker active. Suspend BitLocker from inside Windows **before** the partition-table operation (see step 1.1, item 2). To recover now: boot Windows with the recovery key, sign in, then suspend BitLocker and re-run the operation if any partition was not yet created.

### `nixos-install` fails with "no space left on /mnt"

You probably created subvolumes inside the ESP (fat32, 1 GB) by mistake. Remount and verify the subvolumes live in the btrfs partition:

```bash
mount | grep /mnt
# /mnt must be on subvol=root of nixos-btrfs, not on the fat32 ESP
```

### NVIDIA driver issues

```bash
cat /proc/driver/nvidia/version               # expect 570+
cat /sys/module/nvidia_drm/parameters/modeset  # expect Y
nvidia-smi                                     # dGPU status
```

If `nvidia-smi` fails on a Blackwell GPU, verify `hardware.nvidia.open = true` in `nvidia.nix` — Blackwell requires open kernel modules.

### disko data-loss warning (dual-boot — historical)

Previous versions of this guide used `disko --mode destroy,format,mount`, which wipes Windows. That mode is now removed. If you find an older copy of the README mentioning disko, ignore it — the current layout is manual `cfdisk` + disko `formatMount` exactly to support same-disk dual-boot.

### Enabling PRIME offload on a hybrid laptop (not the 8940HX)

The 8940HX (Dragon Range) ships without a usable iGPU — the dGPU drives the displays directly. PRIME offload is **not needed** and left disabled by default.

For other laptops with a functional iGPU + dGPU combo:

```bash
lspci -nn | grep -E 'VGA|3D'
```

Convert the hexadecimal PCI addresses to NixOS format (decimal `bus:device.function`):

| PCI address | NixOS BusID |
|---|---|
| `00:02.0` | `PCI:0:2:0` |
| `01:00.0` | `PCI:1:0:0` |

Edit `modules/hardware/nvidia.nix`:

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

### Initrd hang — rollback script can't find `nixos-btrfs`

```bash
ls -l /dev/disk/by-partlabel/ | grep nixos
# Expect: nixos-esp and nixos-btrfs
```

If missing, you forgot to rename the partitions in cfdisk. Drop into the live USB again, re-run `cfdisk`, and rename the two partitions to `nixos-esp` and `nixos-btrfs` (or set the names non-interactively):

```bash
parted /dev/nvme0n1 name 4 nixos-esp
parted /dev/nvme0n1 name 5 nixos-btrfs
```

### niri fails to start

```bash
journalctl --user -u niri -b    # current boot logs
niri validate                   # validate config syntax
```

Config path: `~/.config/niri/config.kdl` (symlinked to nix store via `systemd.tmpfiles`).

### Clock skew after dual-booting with Windows

Windows expects the hardware clock to be local time; NixOS expects UTC. Fix this **from Windows** (so NixOS stays correct):

```bat
:: Run in Windows as Administrator:
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

This makes Windows treat the hardware clock as UTC, matching NixOS. Do **not** use `timedatectl set-local-rtc 1` on the NixOS side — it is discouraged by systemd upstream.

## WSL

A second host, `nixosConfigurations.wsl`, runs this configuration as a **Windows Subsystem for Linux** distribution via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). It is a terminal-only environment: it shares `base` (user `onyx`, nix, i18n, env, nh, git) but deliberately **excludes** boot/hardware/desktop/impermanence — WSL provides its own kernel, network and display (WSLg).

The `wsl` module (`modules/wsl.nix`) is auto-attached to the `wsl` host by the host factory (module name == hostname). Key settings:

- `wsl.defaultUser = "onyx"` — matches the primary user from `modules/users.nix`
- `wsl.useWindowsDriver = true` — use the Windows host's OpenGL/Vulkan drivers (WSLg)
- `wsl.startMenuLaunchers = true` — GUI shortcuts in the Windows Start menu

### Build the WSL tarball

On any NixOS machine (or inside the WSL distro itself):

```bash
nix build .#nixosConfigurations.wsl.config.system.build.tarball -o wsl-result
# output: wsl-result/nixos-wsl.tar.gz
```

The tarball **bakes in this entire repository** at `/etc/nixos` (`wsl.tarball.configPath = ../.` in `modules/wsl.nix`), so the full configuration is available right after import — no manual cloning needed.

### Install into WSL

From PowerShell:

```powershell
wsl --install --no-distribution        # one-time: enable WSL if not already
wsl --import NixOS $env:USERPROFILE\NixOS wsl-result\nixos-wsl.tar.gz --version 2
wsl -d NixOS
```

First login is as `onyx` with password `changeme` (same initial password as the main host — change it with `passwd` right away).

### Activate the configuration inside WSL

The imported system only runs a minimal bootstrap; the full config is at `/etc/nixos` but is not yet the active system. Activate it with:

```bash
# The baked-in repo lives at /etc/nixos (hostname "wsl" auto-detected from NH_FLAKE not needed here)
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

This enables the complete `base` profile (user onyx, nix settings, nh, git, etc.) on top of the WSL environment.

> **First rebuild only** — Nix will warn `ignoring untrusted flake configuration setting 'substituters'` because the flake's `nixConfig` is untrusted until this repo is listed in `trusted-flakes`. Accept it once:
>
> ```bash
> sudo nixos-rebuild switch --flake /etc/nixos#wsl --accept-flake-config
> # or: echo 'trusted-flakes = path:/home/onyx/nixos_dev' | sudo tee -a /etc/nix/nix.conf
> ```
>
> After that rebuild, `modules/config/nix.nix` sets `nix.settings.trusted-flakes` itself and the warning never comes back.

### Manage updates from inside WSL

For day-to-day use, keep a working clone in your home directory (the baked-in copy at `/etc/nixos` is a static snapshot and not a git repo):

```bash
mkdir -p ~/nixos_dev
git clone https://github.com/uontabc/nixos_dev.git ~/nixos_dev

# NH_FLAKE is already set to ~/nixos_dev by the nh module — switch with nh:
nh os switch        # builds & activates hostname "wsl"

# or without nh:
sudo nixos-rebuild switch --flake ~/nixos_dev#wsl
```

Rebuilds take effect immediately; restart the distro with `wsl --shutdown` if systemd units are stuck.

### WSL: nvim icons are missing in Windows Terminal

When you run nvim inside WSL from **Windows Terminal**, glyphs (lualine/nvim-tree icons) come from the *Windows* side font, not from NixOS. Install a patched font on Windows (e.g. [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads)) and set it in Windows Terminal: *Settings → your profile → Appearance → Font face → `JetBrainsMono Nerd Font`*.

(The NixOS side already ships `nerd-fonts.jetbrains-mono` in `base`, so GUI apps under WSLg — e.g. kitty — render correctly.)

### Troubleshooting: root access / forgotten password

NixOS-WSL builds the root filesystem with `--no-root-passwd`, so **root has no password** and `sudo` asks for the *user's* password (onyx / `changeme` until you change it). If you forgot the user password, or need root without sudo:

```powershell
# From Windows PowerShell — enter the distro as root, no password needed:
wsl -d NixOS -u root
```

Then, in the root shell:

```bash
passwd root          # set a root password (optional)
passwd onyx          # reset the onyx password
nixos-rebuild switch --flake /home/onyx/nixos_dev#wsl
```

Note that `nixos-rebuild switch` must run as root: the store is written by the nix daemon (user builds work), but the final `nix-env --set` to `/nix/var/nix/profiles/system` requires root (`sudo nixos-rebuild switch` or the root shell above).

## opencode

[opencode](https://opencode.ai) (the AI coding agent) is installed on every host via `base` (`modules/config/opencode.nix`): `pkgs.opencode` goes into `my.packages`, and a minimal `~/.config/opencode/opencode.json` is symlinked from the nix store with `systemd.tmpfiles` — same pattern as the niri/kitty configs.

The generated config sets `username`, `autoupdate = false` (nix owns the version) and `share = "manual"`. It intentionally contains **no model or API key** — authenticate interactively on first run:

```bash
opencode auth login
```

Then pick a model in the TUI (`Shift+Tab` to cycle agents, `/model` to switch). The nixpkgs package wraps the binary with `OPENCODE_DISABLE_AUTOUPDATE` already set.

## References

- [niri documentation](https://niri-wm.github.io/niri/)
- [Noctalia documentation](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [impermanence](https://github.com/nix-community/impermanence)
- [flake-parts](https://flake.parts) — module system for organizing flake outputs
- [btrfs subvolumes — Arch Wiki](https://wiki.archlinux.org/title/Btrfs#Subvolumes) (the rollback pattern is borrowed from here)
- [ocfox/island](https://github.com/ocfox/island) — architecture reference: flake-parts + import-tree, `flake.modules.nixos.<name>` named modules, host factory in `lib/nixos.nix`
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) — niri + Noctalia + impermanence composition, nh usage
- [Misterio77/Foundry](https://github.com/Misterio77/Foundry) — impermanence + disko + btrfs blank-snapshot rollback pattern, module organization
- [viperML/dotfiles](https://github.com/viperML/dotfiles) — module-by-topic organization, nh usage

## License

MIT