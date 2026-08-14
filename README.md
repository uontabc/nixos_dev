# uontabc — NixOS Configuration

**Languages:** English (current) · [中文](README.zh-CN.md)

A declarative NixOS desktop configuration built entirely on NixOS modules (no home-manager). The flake is structured with [flake-parts](https://github.com/hercules-ci/flake-parts). It pairs the [niri](https://github.com/niri-wm/niri) scrollable-tiling compositor with [Noctalia v5](https://github.com/noctalia-dev/noctalia) for the shell layer, [impermanence](https://github.com/nix-community/impermanence) for an ephemeral root with snapshot-based rollback, and [nh](https://github.com/nix-community/nh) for maintenance. The target host runs Windows + NixOS on the **same physical disk** — disk preparation is manual `parted`; `fileSystems` and the rollback script reference partitions by a stable *partlabel* (`nixos-esp`, `nixos-btrfs`).

## Features

- **Scrollable-tiling compositor** — niri with KDL configuration and live reload
- **Desktop shell** — Noctalia v5 (bar, launcher, notifications, lock screen, control center), managed as a systemd user service
- **Same-disk dual-boot with Windows** — NixOS shares a single NVMe with Windows via a separate ESP + btrfs partition; GRUB + os-prober adds Windows Boot Manager to its menu
- **Ephemeral root** — impermanence persists critical state; the root subvolume is rolled back to the `@root-blank` snapshot on every boot
- **btrfs subvolumes** `root` / `persist` / `nix` — compress=zstd, ssd, noatime
- **Hardware drivers** — AMD Ryzen 9 8940HX (Zen 4, Dragon Range) + NVIDIA RTX 5060 Laptop (Blackwell, open kernel modules + stable driver)
- **Login** — tuigreet launches the niri session directly; no custom session scripts
- **nh** — replaces `nixos-rebuild` with fzf-based generation selection and automatic weekly garbage collection

## Why disk preparation is manual (not disko)

An earlier version used [disko](https://github.com/nix-community/disko) for declarative partitioning. disko's disk module calls `parted mklabel gpt`, which rewrites the entire GPT — destroying every existing partition including Windows. For a same-disk dual-boot setup, this is unacceptable, so disko was dropped entirely. This configuration instead declares `fileSystems` directly and references partitions by `by-partlabel`, which `parted` sets explicitly. The rollback script and GRUB are entirely partition-table-agnostic.

## Directory Structure

```
.
├── flake.nix                       # Flake entry: inputs + flake-parts mkFlake
├── flake-modules/
│   └── nixos.nix                   # nixosConfigurations.uontabc (under flake-parts)
├── hosts/uontabc/
│   ├── default.nix                 # Host entry
│   └── hardware.nix                # fileSystems, rollback script, kernel modules
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
| iGPU | None (HX series ships with disabled/minimal iGPU; dGPU drives displays) | No PRIME config needed |
| Internal display | eDP-1, 2560×1600 @ 240 Hz | `modules/nixos/desktop/niri.nix` `output` block |
| External display | DP-1, 2560×1440 @ 210 Hz | same |
| Target disk | Single NVMe, Windows + NixOS coexisting | `hosts/uontabc/hardware.nix` (`device` paths) |
| NixOS partition size | 512 GB | determined by your `parted mkpart` step |

## Target Partition Layout

You will build this layout with `parted` on `/dev/nvme0n1` before installing:

| Partition | Name (partlabel) | Type | Size | fsType | Mount |
|---|---|---|---|---|---|
| `nvme0n1p1` | *(Windows, existing)* | `EF00` (ESP) | ~100 MB | fat32 | Windows's ESP (untouched) |
| `nvme0n1p2` | *(Windows, existing)* | reserved | ~16 MB | ― | untouched |
| `nvme0n1p3` | *(Windows, existing)* | NTFS | shrunk by you | ntfs | Windows C: (untouched) |
| `nvme0n1p4` | **`nixos-esp`** | `EF00` (ESP) | 1 GB | fat32 | `/boot` |
| `nvme0n1p5` | **`nixos-btrfs`** | Linux fs | 511 GB | btrfs | `/`, `/nix`, `/persist` (via subvols) |

The partlabels `nixos-esp` and `nixos-btrfs` are critical — `hardware.nix` mounts by these names, and the rollback script opens `by-partlabel/nixos-btrfs`. If you forget to set them, the system will not boot.

## Prerequisites

1. A UEFI-bootable machine with Secure Boot disabled in firmware.
2. A USB flash drive of at least 8 GB.
3. The [NixOS 26.05 ISO](https://nixos.org/download/) — Minimal is recommended (you'll partition manually from a TTY; the graphical ISO wastes RAM). Verify the hash:
   ```bash
   sha256sum nixos-*.iso
   # compare against the hash published on nixos.org/download
   ```
4. **Important disk-data backup.** Although this guide is conservative about Windows, `parted` mistakes can still destroy partitions — back up irreplaceable Windows files to an external drive before starting.
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

This phase creates partitions **only in the 512 GB of unallocated space**. Everything else on the disk stays untouched. **Double-check every command** — `parted` will not ask twice.

#### 2.1 Enter a flake-capable shell

```bash
nix-shell -p git vim parted btrfs-progs dosfstools --command bash
```

#### 2.2 Identify the target disk and free space

```bash
lsblk
# Confirm the NVMe is /dev/nvme0n1 and the Windows partition is, e.g., nvme0n1p3

# Show the free-space map in MiB
parted /dev/nvme0n1 unit MiB print free
```

The output will end with something like:

```
Number  Start    End      Size     Type      File system  Flags
 1      0.02MiB  100MiB   100MiB   primary   fat32        boot, esp
 2      100MiB   116MiB   16MiB    primary   ntfs         msftdata
 3      116MiB   950GiB   950GiB   primary   ntfs         msftdata
        950GiB   1462GiB  512GiB   Free Space
```

Record the Start (in MiB) and End of the Free Space block — call them `$FREE_START_MIB` and `$DISK_END_MIB`. For the example above: `971776` MiB (= 950 × 1024) and `1497088` MiB (= 1462 × 1024). The exact numbers depend on your disk.

#### 2.3 Create the NixOS ESP and btrfs partitions

Compute the ESP end first (ESP = 1024 MiB):

```bash
ESP_START=971776                       # replace with your $FREE_START_MIB
ESP_END=$((ESP_START + 1024))          # ESP_END = ESP_START + 1024 MiB
DISK_END=1497088                       # replace with your $DISK_END_MIB
```

Create the partitions with explicit **partlabels** (`nixos-esp`, `nixos-btrfs`):

```bash
parted ---pretend-input-tty /dev/nvme0n1 <<EOF
unit MiB
mkpart "nixos-esp" fat32 $ESP_START $ESP_END
set ${num_esp} esp on
mkpart "nixos-btrfs" btrfs $ESP_END $DISK_END
print
quit
EOF
```

**Important:** `${num_esp}` is the partition number of the just-created ESP. parted prints the partition table after each command; read the printout and substitute the actual number (usually `4`). Re-run only the `set 4 esp on` line if needed:

```bash
parted /dev/nvme0n1 set 4 esp on
```

Verify the partlabels were written (they appear as `Name` in the parted printout and under `/dev/disk/by-partlabel/`):

```bash
parted /dev/nvme0n1 print
ls -l /dev/disk/by-partlabel/
# Expect: nixos-esp -> ../../nvme0n1p4, nixos-btrfs -> ../../nvme0n1p5
```

#### 2.4 Create file systems

```bash
# NixOS ESP (fat32)
mkfs.fat -F32 -n NIXOS-ESP /dev/disk/by-partlabel/nixos-esp

# NixOS btrfs
mkfs.btrfs -L nixos /dev/disk/by-partlabel/nixos-btrfs
```

#### 2.5 Create btrfs subvolumes

Mount the new btrfs partition at its toplevel (`subvolid=5`) and create three subvolumes:

```bash
mkdir -p /mnt
mount /dev/disk/by-partlabel/nixos-btrfs /mnt

btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/persist
btrfs subvolume create /mnt/nix

# snapshot root as the rollback baseline; rollback deletes+re-snapshots this,
# but seeding it now lets the first boot detect "already exists" and validates
# that btrfs tooling works on this disk.
btrfs subvolume snapshot /mnt/root /mnt/@root-blank

umount /mnt
```

### Phase 3 — Installation

#### 3.1 Mount the partitions under /mnt

The mount options mirror what `hardware.nix` will eventually declare (compress=zstd, noatime, ssd) so that runtime behaviour matches the install-time behaviour:

```bash
mount -o subvol=root,compress=zstd,noatime,ssd /dev/disk/by-partlabel/nixos-btrfs /mnt

mkdir -p /mnt/{boot,nix,persist}

mount /dev/disk/by-partlabel/nixos-esp /mnt/boot
mount -o subvol=nix,compress=zstd,noatime,ssd /dev/disk/by-partlabel/nixos-btrfs /mnt/nix
mount -o subvol=persist,compress=zstd,noatime,ssd /dev/disk/by-partlabel/nixos-btrfs /mnt/persist
```

Verify:

```bash
mount | grep /mnt
# Expected four lines: /mnt (subvol=root), /mnt/boot (vfat),
#                     /mnt/nix (subvol=nix), /mnt/persist (subvol=persist)

df -h /mnt /mnt/boot /mnt/nix /mnt/persist
```

#### 3.2 Clone the repository

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

#### 3.3 (Optional sanity check) Dry-evaluate the system

If you've adjusted any modules, evaluate the configuration without activating:

```bash
nix build .#nixosConfigurations.uontabc.config.system.build.toplevel --dry-run
```

#### 3.4 Install NixOS

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

Then the system continues into `tuigreet` (the login prompt). Log in as `onyx` with initial password `changeme` (defined in `modules/nixos/core/users.nix`).

#### 4.2 Change passwords immediately

```bash
passwd                # user password
sudo passwd root      # root password
```

For better hygiene, replace `initialPassword` in `modules/nixos/core/users.nix` with `hashedPassword` (see [the NixOS manual](https://nixos.org/manual/nixos/stable/#sec-user-sha512)).

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

If `nvidia-smi` fails, confirm `hardware.nvidia.open = true` in `modules/nixos/hardware/nvidia.nix` and check `dmesg | grep -i nvidia`.

#### 4.5 Verify external display (DP-1)

Plug in the DP display. niri should auto-detect it:

```bash
niri msg outputs
# Expect both eDP-1 (2560×1600@240 Hz) and DP-1 (2560×1440@210 Hz)
```

If the output names differ (e.g. `DisplayPort-1` instead of `DP-1`), adjust the `output` blocks in `modules/nixos/desktop/niri.nix`.

#### 4.6 Verify Windows is still bootable

Reboot. At the UEFI one-time boot menu, select **Windows Boot Manager**. Windows should boot normally.

If GRUB also detected Windows automatically (os-prober), you will see a "Windows" entry in the GRUB menu you can select directly without going through the UEFI menu. To trigger os-prober re-detection:

```bash
sudo nix-shell -p os-prober -c os-prober
# Should print: Found Windows Boot Manager on /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi
```

Re-run `nh os switch` so GRUB regenerates with the Windows entry baked in (you must have **Windows Boot Manager** entry in `efibootmgr` for os-prober to find it: usually Windows installer creates it).

#### 4.7 Move the repo to its permanent location and pin NH_FLAKE

`nh` reads `NH_FLAKE` (set to `/home/onyx/nixos` in `modules/nixos/core/nh.nix`):

```bash
cd ~
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos

echo $NH_FLAKE           # Should print: /home/onyx/nixos
nh os info               # Should print info about the current system
```

#### 4.8 Apply updates via nh

```bash
cd ~/nixos
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
cd ~/nixos
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

### parted complained it can't shrink while Windows hibernated

Windows's "Fast Startup" is a partial hibernation. Disable it in Windows: *Control Panel → Power Options → Choose what the power buttons do → uncheck "Turn on fast startup"*. Then shut down Windows fully (not restart).

### BitLocker locked me out after resizing

If Windows refuses to boot with a BitLocker recovery key prompt after a parted operation, you booted with BitLocker active. Suspend BitLocker from inside Windows **before** the parted operation (see step 1.1, item 2). To recover now: boot Windows with the recovery key, sign in, then suspend BitLocker and re-run parted if any partition was not yet created.

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

Previous versions of this guide used `disko --mode destroy,format,mount`, which wipes Windows. That mode is now removed. If you find an older copy of the README mentioning disko, ignore it — the current layout is manual `parted` + `fileSystems` exactly to support same-disk dual-boot.

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

### Initrd hang — rollback script can't find `nixos-btrfs`

```bash
ls -l /dev/disk/by-partlabel/ | grep nixos
# Expect: nixos-esp and nixos-btrfs
```

If missing, you forgot to name the partitions in parted. Drop into the live USB again and:

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

## References

- [niri documentation](https://niri-wm.github.io/niri/)
- [Noctalia documentation](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [impermanence](https://github.com/nix-community/impermanence)
- [flake-parts](https://flake.parts) — module system for organizing flake outputs
- [btrfs subvolumes — Arch Wiki](https://wiki.archlinux.org/title/Btrfs#Subvolumes) (the rollback pattern is borrowed from here)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) — reference for niri + Noctalia + impermanence composition

## License

MIT