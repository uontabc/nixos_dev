# uontabc — NixOS 配置

**语言：** [English](README.md) · 中文（当前）

完全基于 NixOS 模块（不使用 home-manager）的声明式桌面配置。flake 由 [flake-parts](https://github.com/hercules-ci/flake-parts) 组织。合成器采用 [niri](https://github.com/niri-wm/niri)（滚动式平铺），桌面 shell 采用 [Noctalia v5](https://github.com/noctalia-dev/noctalia)，持久化由 [impermanence](https://github.com/nix-community/impermanence) 配合 btrfs 快照回滚实现，日常维护命令使用 [nh](https://github.com/nix-community/nh)。目标主机为 **Windows + NixOS 同盘共存**——磁盘准备走手动 `cfdisk`；`fileSystems` 与回滚脚本通过稳定的 *partlabel*（`nixos-esp`、`nixos-btrfs`）引用分区。

## 特性概览

- **滚动平铺合成器** niri，KDL 配置热重载
- **桌面 shell** Noctalia v5 beta（bar / launcher / 通知 / 锁屏 / 控制中心，systemd 用户服务管理）
- **同盘双系统** NixOS 通过独立 ESP + btrfs 分区与 Windows 共享单 NVMe；GRUB + os-prober 把 Windows Boot Manager 加入菜单
- **不可变根** 每次开机将 root 子卷回滚至 `@root-blank` 基线快照；impermanence 持久化关键状态
- **btrfs 子卷** `root` / `persist` / `nix`，compress=zstd, ssd, noatime
- **硬件驱动** AMD Ryzen 9 8940HX（Zen 4, Dragon Range）+ NVIDIA RTX 5060 Laptop（Blackwell，open 内核模块 + stable 驱动）
- **登录** tuigreet 直接启动 niri 会话，无自制脚本
- **nh** 替代 `nixos-rebuild`，支持 fzf 选择 generation 及每周自动 GC

## disko 如何与同盘双系统共存

[disko](https://github.com/nix-community/disko) 负责声明式**文件系统**层（mkfs + btrfs 子卷 + 挂载），但**分区表仍由 `cfdisk` 手动创建**。这样划分是有意的：disko 的 `gpt` content type 在设备识别不到分区表时会调 `sgdisk --clear`，但对已有 Windows 分区的磁盘用 `sgdisk --new` 重建分区有分区号冲突和丢数据风险。所以：

1. 在空闲空间里用 `cfdisk` 手动建两个 NixOS 分区（`nixos-esp`、`nixos-btrfs`），Windows 分区号不动。
2. disko 的 `disko.devices.<name>` 块指向**已存在的分区**（`device = "/dev/disk/by-partlabel/..."`），`content.type` 是 `"filesystem"` / `"btrfs"`——disko 只跑 `mkfs` 与 `btrfs subvolume create`，二者**幂等**（`blkid`/`btrfs subvolume show` 检测到已有则跳过）。
3. 每个 disko disk 块都设 `destroy = false`，即便误跑 `--mode destroy,...` 也不会擦这些分区。
4. disko 从设备声明**自动注入 `fileSystems.*`**——仓库无需手写 `fileSystems`，但 `boot.initrd.postDeviceCommands`（回滚脚本）仍留在 `modules/hosts/uontabc/default.nix` 里，引用同一个 `by-partlabel/nixos-btrfs` 路径。

跑 `disko --mode format,mount`（永不要 `--mode destroy,...`）。它一步替代 mkfs + 子卷创建 + 挂载，且安全可重跑。

## 目录结构

```
.
├── flake.nix                       # 最小入口：import-tree 自动导入 ./modules/
└── modules/                        # 所有 flake-parts + NixOS 模块（无 home-manager）
    ├── systems.nix                 #   systems 列表
    ├── flake-parts.nix             #   perSystem 配置（unfree）
    ├── lib/nixos.nix               #   主机工厂：options.hosts → nixosConfigurations
    ├── users.nix                   #   my.name / my.packages 选项 + 用户创建
    ├── base.nix                    #   base：users, nix, i18n, env, nh, git
    ├── boot.nix                    #   GRUB + os-prober + btrfs/ntfs
    ├── network.nix                 #   NetworkManager + openssh
    ├── env.nix                     #   XDG 会话变量
    ├── nh.nix                      #   nh CLI + 每周 GC
    ├── impermanence.nix            #   通过 /persist bind-mount 持久化状态
    ├── disko.nix                   #   disko 模块 wrapper
    ├── hardware/                   #   硬件驱动
    │   ├── default.nix             #     聚合：cpu-amd, nvidia, graphics, bluetooth, input
    │   └── cpu-amd.nix  nvidia.nix  graphics.nix  bluetooth.nix  input.nix
    ├── desktop/                    #   桌面服务
    │   ├── default.nix             #     聚合：audio, display, portal, noctalia, xwayland + config 应用
    │   └── audio.nix  display.nix  portal.nix  noctalia.nix  xwayland.nix
    ├── config/                     #   各应用配置（每个为具名 nixos 模块）
    │   └── i18n.nix  nix.nix  git.nix  fonts.nix  niri.nix  kitty.nix  qt.nix  opencode.nix
    ├── wsl.nix                     #   NixOS-WSL 模块（终端型 WSL 发行版）
    └── hosts/
        ├── uontabc/
        │   ├── default.nix         #   hosts.uontabc = { system, stateVersion, module }
        │   └── disko.nix           #   flake.modules.nixos.uontabc.disko.devices
        └── wsl/default.nix         #   hosts.wsl（自动挂载 wsl 模块）
```

基于 [flake-parts](https://flake.parts) + [import-tree](https://github.com/vic/import-tree)：`modules/` 下的每个 `.nix` 文件自动导入——无需 `default.nix` 汇总。各模块声明 `flake.modules.nixos.<name>`，按名称引用其他模块而非路径。参考 [ocfox/island](https://github.com/ocfox/island)。

用户级配置完全由 NixOS 模块管理：

- 用户包 → `my.packages` 选项（汇入 `users.users.${my.name}.packages`）
- 配置文件（niri KDL、kitty.conf）→ `pkgs.writeText` 生成 nix store 路径，再由 `systemd.tmpfiles.rules` 软链接至 `/home/<user>/.config/...`

## 硬件配置

| 组件 | 假设 | 修改位置 |
|---|---|---|
| CPU | AMD Ryzen 9 8940HX (Zen 4, Dragon Range) | `modules/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop（Blackwell sm_120） | `modules/hardware/nvidia.nix` |
| iGPU | 无（HX 系列 iGPU 禁用/极简，dGPU 直接驱动显示器） | 无需 PRIME 配置 |
| 内屏 | eDP-1，2560×1600 @ 240 Hz | `modules/config/niri.nix` 的 `output` 节点 |
| 外屏 | DP-1，2560×1440 @ 210 Hz | 同上 |
| 目标磁盘 | 单 NVMe，Windows + NixOS 共存 | `modules/hosts/uontabc/default.nix`（`fileSystems`） |
| NixOS 分区大小 | 512 GB | 由你 `cfdisk` 时确定 |

## 目标分区布局

**NixOS 使用自己独立的 ESP**——不与 Windows 共用。Windows 保留自己的 ~100 MB ESP（`nvme0n1p1`）不动；NixOS 用全新的 1 GB ESP（`nixos-esp`）放 GRUB，两个系统的引导文件互不干扰。

安装前需用 `sgdisk` 在 `/dev/nvme0n1` 上建好以下布局：

| 分区 | Name (partlabel) | 类型 | 大小 | fsType | 挂载 |
|---|---|---|---|---|---|
| `nvme0n1p1` | *(Windows，已有)* | `EF00` (ESP) | ~100 MB | fat32 | Windows ESP（不动） |
| `nvme0n1p2` | *(Windows，已有)* | 保留 | ~16 MB | ― | 不动 |
| `nvme0n1p3` | *(Windows，已有)* | NTFS | 你缩完后 | ntfs | Windows C:（不动） |
| `nvme0n1p4` | **`nixos-esp`** | `EF00` (ESP) | 1 GB | fat32 | `/boot` |
| `nvme0n1p5` | **`nixos-btrfs`** | Linux fs | 511 GB | btrfs | `/`、`/nix`、`/persist`（按子卷） |

表中分区号假设 Windows 占 `p1–p3`；`sgdisk -n 0` 会自动选择下一个可用分区号，实际编号可能不同。partlabel 名 `nixos-esp` 与 `nixos-btrfs` **至关重要**——`disko.nix` 按名字挂载，回滚脚本打开 `by-partlabel/nixos-btrfs`。忘设将无法启动。

## 前置条件

1. 支持 UEFI 启动的机器，固件中 Secure Boot 已关闭。
2. 至少 8 GB 的 U 盘。
3. [NixOS 26.05 ISO](https://nixos.org/download/)——推荐 Minimal 版（手动从 TTY 分区，图形 ISO 浪费内存）。校验哈希：

   ```bash
   sha256sum nixos-*.iso
   # 与 nixos.org/download 公布的哈希对照
   ```

4. **磁盘数据备份**。虽然本指南保守对待 Windows，但分区工具误操作仍能毁分区——贵重的 Windows 文件先备份到外置盘。
5. **Windows 允许缩卷**。C: 启用了 BitLocker 时必须先在 Windows 内挂起保护（或在 live USB 上 `ntfsfix` + `ntfsresize`）。
6. **Windows 卷当前至少有 512 GB 未用空间**。不足则更激进地缩，或参考"故障排除"中的"无回滚"绕过方案。

## 安装步骤

安装分五个阶段。

### 阶段一——前置

#### 1.1 在 Windows 内腾出 512 GB 空间

从 Windows 内缩卷最安全——Windows 能挪自己的文件。

1. 正常启动 Windows。
2. 若 C: 启用 BitLocker，先挂起保护：*设置 → 隐私和安全性 → 设备加密 → BitLocker → 挂起保护*（装完 NixOS 后再恢复；NixOS 不解锁 BitLocker）。
3. 打开 `diskmgmt.msc`（磁盘管理）。右键 C: 分区 → **压缩卷**。输入 **524288 MB**（即 512 GiB）。Windows 可能因为不可移动文件拒绝缩到该值，可尝试：
   - 关闭系统还原、休眠（`powercfg /h off`）、页面文件，再重试。
   - 用第三方工具如 [DiskGenius](https://www.diskgenius.com/) 或 [AOMEI 分区助手](https://www.aomeitech.com/)（能挪 MFT）。
4. 确认 C: 分区后面出现 512 GB "未分配"空间。
5. **完全关机** Windows（不要用快速启动 / 混合关机——在控制面板 → 电源选项 → 选择电源按钮的功能 中关闭）。

#### 1.2 烧录 ISO 至 U 盘

在一台可用的电脑上制作启动 U 盘。**U 盘所有数据将被擦除**。

Linux：

```bash
lsblk                                   # 确认 U 盘设备，例如 /dev/sdb
sudo cp nixos-*.iso /dev/sdX
sync
```

Windows 下可使用 [Rufus](https://rufus.ie/) 的 **DD 模式**（不要用 ISO 模式）或 [balenaEtcher](https://etcher.balena.io/)。

#### 1.3 配置 UEFI 固件

开机后按 `F2` / `F12` / `Delete` / `Esc` 进入 UEFI 固件：

- **关闭 Secure Boot**——NVIDIA 驱动要加载未签名内核模块。
- **将 USB 设为第一启动项**，或用一次性启动菜单（典型 `F12`）。
- **NVMe/SATA 模式 = AHCI**（不要 RAID / Intel RST）。
- **关闭 Fast Boot**——让固件枚举 USB。
- 保存退出，插 U 盘。

#### 1.4 启动 Live USB

启动 NixOS ISO，在引导菜单选 **NixOS 26.05 Installer**，TTY 下以 `root` 登录（无密码）。

拉取网络（包要从网上下）：

```bash
# 有线：通常自动。验证：
ip addr

# 无线（Minimal ISO 用 nmtui）：
nmtui
# → Activate a connection → 选 SSID → 输入密码 → Back → Quit
ip addr show | grep inet
```

同步时钟（Nixpkgs 可复现性依赖于此）：

```bash
timedatectl set-ntp true
timedatectl status
```

### 阶段二——在释放出的空间里分区

本阶段只在 512 GB 未分配空间里创建分区。**其余分区完全不动**。写入前**再三确认**。

#### 2.1 进入支持 flake 的 shell

```bash
nix-shell -p git vim btrfs-progs --command bash
```

（`cfdisk` 属于 util-linux，live ISO 自带，无需安装；`dosfstools` 由 disko 自己的脚本在格式化 ESP 时引入。）

#### 2.2 克隆仓库（disko 需要 flake）

```bash
cd /tmp
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

若 `nix flake` 报 experimental features，为本 shell 启用 flakes：

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

验证 flake：

```bash
nix flake show
# 应列出：nixosConfigurations.uontabc
```

#### 2.3 用 cfdisk 创建两个 NixOS 分区

打开交互式分区编辑器：

```bash
sudo cfdisk /dev/nvme0n1
```

若提示选择标签类型，选 **gpt**（磁盘已有 GPT 表则保持不动）。用方向键移动、回车/空格确认：

1. 移到 **Free space** → **New** → 大小 **1G** → 类型 **EFI System**。这就是 `nixos-esp`。
2. 移到剩下的 **Free space** → **New** → 大小保持默认（磁盘剩余全部）→ 类型 **Linux filesystem**。这就是 `nixos-btrfs`。
3. 选中新建的 1G 分区 → **Rename** → 输入 **nixos-esp**（此处写入的 GPT 分区名即 partlabel）。
4. 选中新建的 btrfs 分区 → **Rename** → 输入 **nixos-btrfs**。
5. 选 **Write** → 确认 `yes` → **Quit**。

> cfdisk 的 *Rename* 写入的是 GPT 分区名，udev 会把它暴露为 `/dev/disk/by-partlabel/<名字>`。两个分区**都必须改名**——挂载配置与回滚脚本依赖 `nixos-esp` 和 `nixos-btrfs` 这两个精确的 partlabel。

让内核重读分区表（cfdisk 通常已自动完成，下面命令是无害的兜底）：

```bash
sudo partprobe /dev/nvme0n1
sudo udevadm settle
```

#### 2.4 验证 partlabel

```bash
ls -l /dev/disk/by-partlabel/
# 预期：nixos-esp -> ../../nvme0n1p4（实际编号可能不同）
#       nixos-btrfs -> ../../nvme0n1p5
```

同时确认 Windows 分区未被改动：

```bash
lsblk
# Windows 的 p1/p2/p3 仍在，外加 nixos-esp 和 nixos-btrfs
```

#### 2.5 跑 disko（format + mount）

分区就位后交给 disko。disko **幂等**——`blkid` 检测已有文件系统就跳过 `mkfs`；`btrfs subvolume show` 检测已存在子卷就跳过创建。所以重跑也不会破坏任何东西。disko 还会**自动把 `fileSystems.*` 注入 NixOS 配置**——仓库里无需手写 `fileSystems`。

```bash
sudo nix run .#nixosConfigurations.uontabc.config.system.build.formatMount
```

> 使用 flake 自带的 `formatMount` 脚本（而不是 `nix run github:nix-community/disko`）可保证执行的 disko 版本与 `flake.nix` 中锁定的完全一致——无版本漂移，重跑不会报 hard error。

这将：
1. `mkfs.fat` 格式化 `nixos-esp`（已是 fat32 则跳过）。
2. `mkfs.btrfs` 格式化 `nixos-btrfs`（已是 btrfs 则跳过）。
3. 创建 btrfs 子卷 `root`、`nix`、`persist`（已存在则跳过）。
4. 全部挂载到 `/mnt` 下：`/mnt`（subvol=root）、`/mnt/boot`（vfat）、`/mnt/nix`（subvol=nix）、`/mnt/persist`（subvol=persist）。

验证：

```bash
mount | grep /mnt
# 预期四条：/mnt (subvol=root)、/mnt/boot (vfat)、
#           /mnt/nix (subvol=nix)、/mnt/persist (subvol=persist)

df -h /mnt /mnt/boot /mnt/nix /mnt/persist
```

> **注意**：disko 只对你指定的分区操作（`/dev/disk/by-partlabel/nixos-*`），**完全不碰** Windows 分区。`modules/hosts/uontabc/default.nix` 中每个 disko disk 块都设了 `destroy = false`，即使有人误跑 `--mode destroy,...`，disko 也不会擦除已配置的分区。

### 阶段三——安装

#### 3.1（可选演练）Dry-evaluate 系统

若你调整过任何模块，先只求值不激活：

```bash
nix build .#nixosConfigurations.uontabc.config.system.build.toplevel --dry-run
```

#### 3.2 安装 NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

安装程序将：
- 构建闭包（5–30 分钟，取决于硬件和缓存）。
- 将 GRUB 安装至 **NixOS ESP**（`/boot`）——`boot.loader.efi.efiSysMountPoint = "/boot"` 保证 GRUB 写到 `nixos-esp`，绝不碰 Windows ESP。
- 在 `/mnt` 注册新系统。

提示设 root 密码时设一个。装完**不要立即重启**——验证：

```bash
# GRUB 装在 NixOS 自己的 ESP 里
ls /mnt/boot/EFI/NixOS/
# 预期：.  ..  bootx64.efi  fwpkg/  grubx64.efi

# initrd 含回滚脚本
ls /mnt/nix/store/*-nixos-system-*/initrd

# UEFI 启动菜单新增 "NixOS" 条目
efibootmgr
```

随后关机：

```bash
poweroff
```

拔 U 盘，开机。

### 阶段四——后置

#### 4.1 首次启动

进入 UEFI 一次性启动菜单（典型 `F12`）。应看到**两个**条目：

- **Windows Boot Manager**（在 Windows ESP）
- **NixOS**（在 `nixos-esp`）

选 **NixOS**。initrd 回滚脚本运行：
- **首次启动**：因为 `@root-blank` 已存在（步骤 2.5 已建），它删除 `root` 并重新快照。语义上无副作用，仅验证回滚路径可用。
- **后续启动**：同样操作——把 `/` 上的任何 imperative 改动回滚回去。

随后系统启动进入 `tuigreet`（登录提示）。以 `onyx` 登录，初始密码 `changeme`（定义于 `modules/users.nix`）。

#### 4.2 立即修改密码

```bash
passwd                # 用户密码
sudo passwd root      # root 密码
```

更稳妥的是将 `modules/users.nix` 中的 `initialPassword` 替换为 `hashedPassword`（参见 [NixOS 手册](https://nixos.org/manual/nixos/stable/#sec-user-sha512)）。

#### 4.3 验证桌面会话

登录后 tuigreet 应移交至 niri。应看到：
- 空白 niri 桌面（一个空工作区）
- Noctalia 作为 systemd 用户服务启动——bar/launcher 可见

若 Noctalia 缺失，检查：

```bash
systemctl --user status noctalia
journalctl --user -u noctalia -b
```

验证 niri 配置：

```bash
ls -l ~/.config/niri/config.kdl      # 应为指向 /nix/store/<hash>-niri-config.kdl 的软链接
niri validate                         # 应输出：Config is valid
```

#### 4.4 验证 NVIDIA 驱动

```bash
nvidia-smi
# 预期：RTX 5060、驱动版本 570+、CUDA 版本

glxinfo | grep 'OpenGL renderer'
# 预期：OpenGL renderer string: NVIDIA GeForce RTX 5060 Laptop GPU

cat /sys/module/nvidia_drm/parameters/modeset
# 预期：Y
```

若 `nvidia-smi` 失败，确认 `modules/hardware/nvidia.nix` 中 `hardware.nvidia.open = true`，并查 `dmesg | grep -i nvidia`。

#### 4.5 验证外屏（DP-1）

接入 DP 显示器。niri 应自动识别：

```bash
niri msg outputs
# 预期：eDP-1 (2560×1600@240 Hz) 与 DP-1 (2560×1440@210 Hz) 均列出
```

若输出名不同（如 `DisplayPort-1` 而非 `DP-1`），调整 `modules/config/niri.nix` 的 `output` 节点。

#### 4.6 验证 Windows 仍可启动

重启。在 UEFI 一次性启动菜单选 **Windows Boot Manager**。Windows 应正常启动。

如果 GRUB 也通过 os-prober 自动检测到 Windows，你会在 GRUB 菜单看到 "Windows" 条目，可直接选。要触发 os-prober 重新检测：

```bash
sudo nix-shell -p os-prober -c os-prober
# 应输出：Found Windows Boot Manager on /dev/nvme0n1p1@/EFI/Microsoft/Boot/bootmgfw.efi
```

然后 `nh os switch`，让 GRUB 重新生成并 baked-in Windows 条目（前提：`efibootmgr` 中存在 Windows Boot Manager 条目，通常由 Windows 安装器创建）。

#### 4.7 把仓库搬到永久位置并固定 NH_FLAKE

`nh` 通过 `NH_FLAKE` 找 flake（`modules/nh.nix` 中设为 `/home/onyx/nixos`）：

```bash
cd ~
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos

echo $NH_FLAKE           # 应输出：/home/onyx/nixos
nh os info               # 应打印当前系统信息
```

#### 4.8 通过 nh 应用更新

```bash
cd ~/nixos
nix flake update          # 更新 flake.lock 至最新 nixpkgs-26.05
nh os switch              # 构建 + 激活
```

### 阶段五——（可选）删除 `@root-blank` 以关闭回滚

有人偏好"挂载即清"的 impermanence 但不要回滚。回滚由 `host/uontabc/hardware.nix` 的 `postDeviceCommands` 控制。要关闭它：注释掉整个 `boot.initrd.postDeviceCommands` 块，并删除已存在的 `@root-blank`：

```bash
sudo mount /dev/disk/by-partlabel/nixos-btrfs /mnt
sudo btrfs subvolume delete /mnt/@root-blank
sudo umount /mnt
```

无脚本重建；impermanence 的 `/persist` bind-mount 仍工作。

## 日常维护

### 更新 Flake 输入

```bash
cd ~/nixos               # 仓库克隆位置
nix flake update         # 更新 flake.lock
nh os switch             # 构建并激活
```

### 修改后重建

```bash
nh os switch             # 构建 + 激活
nh os test               # 构建 + 测试（不激活）
nh os boot               # 设为下次启动默认
nh os switch -- -v       # 向 nixos-rebuild 传递 verbose
nh clean all            # 手动 GC（每周自动 GC 已在 core/nh.nix 配置）
```

### 回滚

GRUB 启动菜单列出最近 10 个 generation（`configurationLimit = 10`），选较老的 generation 即可回滚。回滚仅作用于 ephemeral root 子卷，`/persist` 下持久化数据不受影响。

### 修改 niri 配置

编辑 `modules/config/niri.nix`。niri 热重载 `config.kdl`，保存即生效。语法错误输出至日志：

```bash
journalctl --user -u niri -f
```

配置参考：https://niri-wm.github.io/niri/Configuration:-Introduction

## 持久化说明

由于 `/` 为 ephemeral（每次开机回滚）：

- 不要在 `/` 下存放需长期保留的数据——重启后会丢失
- 系统级持久化：添加至 `modules/impermanence.nix` 的 `directories` / `files`
- 用户级持久化：添加至同文件 `users.onyx.directories`（已有 `Documents`、`Downloads` 等）
- `~/.config` **未**持久化：niri 与 kitty 配置通过 `systemd.tmpfiles` 软链接至 nix store
- 若需持久化 Noctalia 的 GUI 设置，在 `users.onyx.directories` 中添加 `"noctalia"`

## 故障排除

### GRUB / efibootmgr 里看不到 Windows

```bash
efibootmgr                                # 确认 Windows Boot Manager 条目
sudo nix-shell -p os-prober -c os-prober  # 测试 os-prober 探测
```

若 `efibootmgr` 无 Windows 条目（罕见——通常 Windows 安装器会创建），手动重建：

```bash
sudo efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --label "Windows Boot Manager" \
  --loader '\\EFI\\Microsoft\\Boot\\bootmgfw.efi'
```

然后再 `os-prober` → `nh os switch`。

### Windows 休眠中无法缩卷

Windows 的"快速启动"是一种半休眠。在 Windows 内关闭：*控制面板 → 电源选项 → 选择电源按钮的功能 → 取消勾选"启用快速启动"*。然后**完全关机**（不是重启）。

### 缩卷后 BitLocker 把我锁外了

若改分区后 Windows 启动要求 BitLocker 恢复密钥——你 BitLocker 没挂起就改了分区。**事前**从 Windows 内挂起（见 1.1 第 2 步）。当前恢复：用恢复密钥启动 Windows，登录，挂起 BitLocker，如果还有未建的分区就再改一次分区。

### `nixos-install` 报 `/mnt` 无空间

多半是不小心把子卷建到 ESP（fat32，1 GB）里去了。重挂并校验子卷在 btrfs 分区里：

```bash
mount | grep /mnt
# /mnt 必须在 subvol=root 的 nixos-btrfs 上，不在 fat32 ESP 上
```

### NVIDIA 驱动异常

```bash
cat /proc/driver/nvidia/version               # 预期 570+
cat /sys/module/nvidia_drm/parameters/modeset  # 预期 Y
nvidia-smi                                     # dGPU 状态
```

若 Blackwell 上 `nvidia-smi` 失败，确认 `nvidia.nix` 中 `hardware.nvidia.open = true`——Blackwell 必须 open 模块。

### disko 擦盘警示（双系统——历史）

早期 README 用 `disko --mode destroy,format,mount`，会擦 Windows。该模式已彻底删除。如果你看到旧版 README 提到 disko，忽略——当前布局是手动 `cfdisk` + disko `formatMount`，正是为了支持同盘双系统。

### 在混合架构笔记本上启用 PRIME offload（不适用于 8940HX）

8940HX（Dragon Range）无可用 iGPU——dGPU 直接驱动显示器，PRIME offload **不需要**，默认禁用。

对其他具备功能完整 iGPU + dGPU 的笔记本：

```bash
lspci -nn | grep -E 'VGA|3D'
```

将十六进制 PCI 地址转为 NixOS 格式（十进制 `总线:设备.功能`）：

| PCI 地址 | NixOS BusID |
|---|---|
| `00:02.0` | `PCI:0:2:0` |
| `01:00.0` | `PCI:1:0:0` |

编辑 `modules/hardware/nvidia.nix`：

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

rebuild 后用 `nvidia-offload <程序>` 调度至 dGPU。

### Initrd 卡住——回滚脚本找不到 `nixos-btrfs`

```bash
ls -l /dev/disk/by-partlabel/ | grep nixos
# 预期：nixos-esp 与 nixos-btrfs
```

若缺失，cfdisk 里忘改名了。再进 live USB 重开 `cfdisk` 把两个分区改名（或用非交互命令补设）：

```bash
parted /dev/nvme0n1 name 4 nixos-esp
parted /dev/nvme0n1 name 5 nixos-btrfs
```

### niri 启动失败

```bash
journalctl --user -u niri -b    # 本次启动日志
niri validate                   # 验证配置语法
```

配置路径：`~/.config/niri/config.kdl`（由 `systemd.tmpfiles` 软链接至 nix store）。

### 双系统后时钟偏差

Windows 期望硬件时钟为本地时间；NixOS 期望 UTC。**从 Windows 端修**（使 NixOS 保持正确）：

```bat
:: Windows 以管理员运行：
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

这使 Windows 把硬件时钟视为 UTC，与 NixOS 一致。**不要**在 NixOS 端用 `timedatectl set-local-rtc 1`——systemd 上游不推荐。

## WSL

第二个主机配置 `nixosConfigurations.wsl` 通过 [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) 将本配置作为 **Windows Subsystem for Linux** 发行版运行。它是纯终端环境：复用 `base`（用户 `onyx`、nix、i18n、env、nh、git），但**刻意排除** boot/hardware/desktop/impermanence——WSL 自带内核、网络与显示（WSLg）。

`wsl` 模块（`modules/wsl.nix`）由主机工厂自动挂载到 `wsl` 主机（模块名 == 主机名）。关键设置：

- `wsl.defaultUser = "onyx"`——与 `modules/users.nix` 的主用户一致
- `wsl.useWindowsDriver = true`——使用 Windows 主机的 OpenGL/Vulkan 驱动（WSLg）
- `wsl.startMenuLaunchers = true`——Windows 开始菜单的 GUI 快捷方式

### 构建 WSL 压缩包

在任何 NixOS 机器上（或 WSL 发行版内）：

```bash
nix build .#nixosConfigurations.wsl.config.system.build.tarball -o wsl-result
# 输出：wsl-result/nixos-wsl.tar.gz
```

### 安装到 WSL

PowerShell 中：

```powershell
wsl --install --no-distribution        # 一次性：启用 WSL（如未启用）
wsl --import NixOS $env:USERPROFILE\NixOS wsl-result\nixos-wsl.tar.gz --version 2
wsl -d NixOS
```

首次以 `onyx` 登录，密码 `changeme`（与主主机相同初始密码——立即 `passwd` 修改）。然后拉取 flake 照常用 `nh` 管理。

### 在 WSL 内重建

```bash
cd ~/nixos
git clone https://github.com/uontabc/nixos_dev.git .   # 首次
nh os switch        # 读取 NH_FLAKE；自动识别主机名 "wsl"
```

## opencode

[opencode](https://opencode.ai)（AI 编程代理）通过 `base`（`modules/config/opencode.nix`）安装到每个主机：`pkgs.opencode` 进入 `my.packages`，最小化的 `~/.config/opencode/opencode.json` 由 `systemd.tmpfiles` 从 nix store 软链接——与 niri/kitty 配置同款模式。

生成的配置设置 `username`、`autoupdate = false`（版本由 nix 管理）、`share = "manual"`。刻意**不含模型或 API key**——首次运行时交互式认证：

```bash
opencode auth login
```

然后在 TUI 里选模型（`Shift+Tab` 切换代理，`/model` 切换模型）。nixpkgs 包已用 `OPENCODE_DISABLE_AUTOUPDATE` 包装二进制。

## 参考

- [niri 文档](https://niri-wm.github.io/niri/)
- [Noctalia 文档](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [impermanence](https://github.com/nix-community/impermanence)
- [flake-parts](https://flake.parts)——组织 flake 输出的模块系统
- [btrfs subvolumes — Arch Wiki](https://wiki.archlinux.org/title/Btrfs#Subvolumes)（回滚模式借鉴自此）
- [ocfox/island](https://github.com/ocfox/island)——架构参考：flake-parts + import-tree、`flake.modules.nixos.<name>` 具名模块、`lib/nixos.nix` 主机工厂
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)——niri + Noctalia + impermanence 组合、nh 用法
- [Misterio77/Foundry](https://github.com/Misterio77/Foundry)——impermanence + disko + btrfs 空快照回滚模式、模块组织
- [viperML/dotfiles](https://github.com/viperML/dotfiles)——按主题组织模块、nh 用法

## 许可证

MIT