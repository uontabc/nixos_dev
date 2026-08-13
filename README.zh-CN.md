# uontabc — NixOS 配置

**语言：** [English](README.md) · 中文（当前）

完全基于 NixOS 模块（不使用 home-manager）的声明式桌面配置。合成器采用 [niri](https://github.com/niri-wm/niri)（滚动式平铺），桌面 shell 采用 [Noctalia v5](https://github.com/noctalia-dev/noctalia)，分盘用 [disko](https://github.com/nix-community/disko) 声明 btrfs 布局，根目录通过 [impermanence](https://github.com/nix-community/impermanence) 实现不可变快照回滚，日常维护命令使用 [nh](https://github.com/nix-community/nh)。

## 特性概览

- **滚动平铺合成器** niri，KDL 配置热重载
- **桌面 shell** Noctalia v5 beta（bar / launcher / 通知 / 锁屏 / 控制中心，systemd 用户服务管理）
- **声明式分盘** disko + btrfs，子卷 `root` / `persist` / `nix`
- **不可变根** 每次开机将 root 子卷回滚至 `@root-blank` 基线快照；impermanence 持久化关键状态
- **双系统** GRUB + os-prober 自动探测 Windows Boot Manager；ntfs3 支持挂载 NTFS 数据盘
- **硬件驱动** AMD Ryzen 9 8940HX (Zen 4, Dragon Range) + NVIDIA RTX 5060 Laptop（Blackwell，open 内核模块 + stable 驱动）
- **登录** tuigreet 直接启动 niri 会话，无自制脚本
- **nh** 替代 `nixos-rebuild`，支持 fzf 选择 generation 及每周自动 GC

## 目录结构

```
.
├── flake.nix                       # Flake 入口：inputs + nixosConfiguration
├── hosts/uontabc/
│   ├── default.nix                 # 主机入口
│   ├── hardware.nix                # 留空——disko 接管 fileSystems
│   └── disko.nix                   # 声明式分盘 + btrfs 回滚脚本
└── modules/nixos/                  # 全部为 NixOS 模块（无 home-manager）
    ├── default.nix                 # 汇总 import
    ├── core/                       # boot / networking / locale / users / packages / env / nh
    ├── hardware/                   # cpu-amd / nvidia / graphics / bluetooth / input
    ├── desktop/                    # display / portal / audio / fonts / niri / noctalia / qt / kitty
    └── persistence/               # impermanence
```

用户级配置完全在 `modules/nixos/` 内管理：

- 用户包 → `users.users.onyx.packages`（`core/users.nix`）
- 配置文件（niri KDL、kitty.conf）→ `pkgs.writeText` 生成 nix store 路径，再由 `systemd.tmpfiles.rules` 软链接至 `/home/onyx/.config/...`

## 硬件配置

| 组件 | 假设 | 修改位置 |
|---|---|---|
| CPU | AMD Ryzen 9 8940HX (Zen 4, Dragon Range) | `modules/nixos/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop（Blackwell sm_120） | `modules/nixos/hardware/nvidia.nix` |
| iGPU | 无（HX 系列 iGPU 禁用/极简，dGPU 直接驱动显示器） | 无需 PRIME 配置 |
| 内屏 | eDP-1，2560×1600 @ 240 Hz | `modules/nixos/desktop/niri.nix` 的 `output` 节点 |
| 外屏 | DP-1，2560×1440 @ 210 Hz | 同上 |
| 磁盘 | 单 NVMe，整盘给 NixOS | `hosts/uontabc/disko.nix` 的 `device` |

## 前置条件

1. 支持 UEFI 启动的机器，固件设置中关闭 Secure Boot
2. 至少 8 GB 的 U 盘
3. [NixOS 26.05 ISO](https://nixos.org/download/) — 推荐下载 GNOME 版或 Minimal 版（任何版本都行，本配置会替换桌面）。建议校验 ISO 哈希：

   ```bash
   sha256sum nixos-*.iso
   # 与 nixos.org/download 公布的哈希对照
   ```

4. **目标磁盘数据已完整备份**——disko 的 `destroy` 模式会重写分区表，擦除整盘所有内容
5. 双系统安装：Windows 须位于**独立物理磁盘**（disko 无法保留同盘 Windows）

## 安装步骤

安装分三个阶段——前置（准备 U 盘）、安装（分区+装系统）、后置（首次启动+验证）。

### 阶段一——前置

#### 1.1 确认目标硬件

在目标机器上（Linux live 环境或 Windows 中）确认硬件：

```bash
# Linux live 环境：
lspci -nn | grep -E 'VGA|3D'          # 应看到 NVIDIA RTX 5060
cat /proc/cpuinfo | grep 'model name' # 应看到 AMD Ryzen 9 8940HX
lsblk                                 # 记下目标 NVMe 磁盘
```

若有任何组件不同，请先调整 `modules/nixos/hardware/` 下对应模块再继续。

#### 1.2 烧录 ISO 至 U 盘

在一台可用的电脑上制作启动 U 盘。**U 盘所有数据将被擦除。**

Linux：

```bash
# 确认 U 盘设备（不是分区）——例如 /dev/sdb，不是 /dev/sdb1
lsblk

# 写入 ISO（/dev/sdX 替换为 U 盘设备）
sudo cp nixos-*.iso /dev/sdX
sync
```

Windows 下可使用 [Rufus](https://rufus.ie/)（选择 DD 模式，不要用 ISO 模式）或 [balenaEtcher](https://etcher.balena.io/)。**不要**让 Rufus "添加"额外文件，需要按字节镜像写入。

#### 1.3 配置 UEFI 固件

开机后按下 `F2` / `F12` / `Delete` / `Esc` 进入 UEFI 固件设置：

- **关闭 Secure Boot**——NixOS 可在 Secure Boot 下启动，但 NVIDIA 驱动需要加载未签名内核模块。将 Secure Boot 设为 Disabled。
- **将 USB 设为第一启动项**，或使用一次性启动菜单（`F12`）。
- **SATA/NVMe 模式设为 AHCI**（不要用 RAID 或 Intel RST）。NVIDIA + btrfs 要求 AHCI。
- **关闭 Fast Boot**——避免固件跳过 USB 枚举。
- 保存退出，插入 U 盘。

#### 1.4 启动 Live USB

从 NixOS ISO 启动，在引导菜单选择 "NixOS 26.05 Installer"。TTY（或图形会话，取决于 ISO 版本）下以 `root` 登录（无密码）。

若安装需要拉取包，请连网：

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

### 阶段二——安装

#### 2.1 进入支持 flake 的 shell

Live ISO 默认未启用 flakes：

```bash
nix-shell -p git vim disko --command bash
```

将 `git`（克隆仓库）、`vim`（编辑）、`disko`（分区工具）拉入 shell。

#### 2.2 克隆仓库

```bash
cd /tmp
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

验证 flake 能求值：

```bash
nix flake show
# 应列出：nixosConfigurations.uontabc
```

若 `nix flake show` 报 "experimental feature"，为当前 shell 启用 flakes：

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

#### 2.3 确认目标磁盘的稳定标识

**关键**：使用稳定的 `by-id` 路径，而不是 `/dev/nvme0n1`。设备名重启后可能漂移，`by-id` 不会。

```bash
ls -l /dev/disk/by-id/ | grep -v -E 'part|usb'
```

输出类似：

```
nvme-eui.000000000000000001a4e7b3e1234abc -> ../../nvme0n1
nvme-Samsung_SSD_980_PRO_1TB_S5KXXXXXXXX -> ../../nvme0n1
```

记下最完整、最具体的 `nvme-eui.*` 或 `nvme-<model>_*` 路径。**再次三确认这就是你想擦除的磁盘**：

```bash
# 确认磁盘容量和内容与预期一致
sudo fdisk -l /dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc
smartctl -i /dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc
```

#### 2.4 在 disko 中配置磁盘

用你偏好的编辑器编辑 `hosts/uontabc/disko.nix`：

```bash
vim hosts/uontabc/disko.nix
```

替换占位符：

```nix
device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
```

填入步骤 2.3 记录的路径，例如：

```nix
device = lib.mkDefault "/dev/disk/by-id/nvme-eui.000000000000000001a4e7b3e1234abc";
```

**不要**改 `partlabel`（`disk-main-btrfs`）——`postDeviceCommands` 中的回滚脚本依赖该标签。

#### 2.5 disko 演练（推荐）

执行破坏性操作前，让 disko 只显示将要做什么，不实际写入：

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --dry-run --flake .#uontabc
```

检查打印的分区布局。预期：
- 1 GB ESP（`vfat`，挂载至 `/mnt/boot`）
- 剩余空间为 btrfs（`disk-main-btrfs`），子卷 `root` / `persist` / `nix` 分别挂载至 `/mnt` / `/mnt/persist` / `/mnt/nix`

#### 2.6 执行 disko（破坏性）

**这是目标磁盘的不归路。最后再确认一次：**

```bash
# 确认即将擦除的就是这块磁盘：
cat hosts/uontabc/disko.nix | grep device
```

执行实际分区：

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#uontabc
```

这将：
1. **销毁**现有分区表。
2. **格式化** ESP 为 vfat，其余为 btrfs。
3. **挂载**全部内容至 `/mnt`。

验证挂载：

```bash
mount | grep /mnt
# 预期：
# /mnt on /mnt type btrfs (subvol=root,...)
# /mnt/boot on /mnt/boot type vfat
# /mnt/nix on /mnt/nix type btrfs (subvol=nix,...)
# /mnt/persist on /mnt/persist type btrfs (subvol=persist,...)

ls /mnt
# 应看到：boot  etc  home  nix  persist  root  ...
```

#### 2.7 安装 NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

安装程序将：
- 构建闭包（5–30 分钟，取决于硬件和缓存）。
- 将引导加载程序（GRUB）安装至 ESP。
- 在 `/mnt` 注册新系统。

提示设置 root 密码时，设一个。安装完成后**不要立即重启**——验证：

```bash
# 确认引导加载程序已安装
ls /mnt/boot/EFI/NixOS/
# 应看到：.  ..  bootx64.efi  fwpkg/  grubx64.efi

# 确认回滚快照脚本在 initrd 中
ls /mnt/nix/store/*-nixos-system-*/initrd
```

随后关机：

```bash
poweroff
```

拔掉 U 盘，然后开机。

### 阶段三——后置

#### 3.1 首次启动

系统将进入 GRUB；唯一菜单项应为 "NixOS - Default"。选择之。

initrd 运行回滚脚本：
- **首次启动**：从 `root` 生成 `@root-blank` 基线快照。
- **后续启动**：删除 `root` 并从 `@root-blank` 重新快照为 `root`（回滚至基线）。

随后系统继续引导至 `tuigreet`（登录提示）。

以 `onyx` 登录，初始密码 `changeme`（定义于 `modules/nixos/core/users.nix`）。

#### 3.2 立即修改密码

```bash
# 用户密码
passwd

# root 密码（安装时已设，可在这里改）
sudo passwd root
```

建议将 `modules/nixos/core/users.nix` 的 `initialPassword` 替换为 `hashedPassword`（参见 [NixOS 手册](https://nixos.org/manual/nixos/stable/#sec-user-sha512)）。

#### 3.3 验证桌面会话

登录后，tuigreet 应移交至 niri。应看到：
- 空白 niri 桌面（一个空工作区）
- Noctalia 作为 systemd 用户服务启动（bar / launcher）。若未启动，手动检查：

```bash
systemctl --user status noctalia
# 应为 "active (running)"

# 若失败，查日志：
journalctl --user -u noctalia -b
```

niri 配置位于 `~/.config/niri/config.kdl`（软链接至 nix store）。验证：

```bash
ls -l ~/.config/niri/config.kdl
# 应为指向 /nix/store/<hash>-niri-config.kdl 的软链接

niri validate
# 应输出：Config is valid
```

#### 3.4 验证 NVIDIA 驱动

```bash
nvidia-smi
# 应显示 RTX 5060、驱动版本（570+）和 CUDA 版本。

glxinfo | grep 'OpenGL renderer'
# 应显示：OpenGL renderer string: NVIDIA GeForce RTX 5060 Laptop GPU

# 确认 modesetting 已启用：
cat /sys/module/nvidia_drm/parameters/modeset
# 应输出：Y
```

若 `nvidia-smi` 失败：
- 确认 `modules/nixos/hardware/nvidia.nix` 中 `hardware.nvidia.open = true`（Blackwell 需要 open 模块）。
- 查 `dmesg | grep -i nvidia` 排查模块加载错误。

#### 3.5 验证外屏（DP-1）

接入 DP 显示器。niri 应自动识别。验证：

```bash
niri msg outputs
# 应列出 eDP-1 (2560x1600@240Hz) 与 DP-1 (2560x1440@210Hz)
```

若输出名不同（例如 `DisplayPort-1` 而非 `DP-1`），请相应调整 `modules/nixos/desktop/niri.nix` 中的 `output` 节点。

#### 3.6 将仓库移至永久位置并固定 NH_FLAKE

`nh` 通过 `NH_FLAKE` 知道 flake 位置。本配置在 `modules/nixos/core/nh.nix` 中设为 `/home/onyx/nixos`：

```bash
# 创建规范位置
mkdir -p ~/nixos

# live USB 上的克隆已不在，重新克隆：
cd ~
git clone https://github.com/uontabc/nixos_dev.git nixos
cd nixos
```

验证 `nh` 能找到 flake：

```bash
echo $NH_FLAKE
# 应输出：/home/onyx/nixos

nh os info
# 应打印当前系统信息
```

#### 3.7 通过 nh 应用更新

从现在起通过 `nh` 操作 flake：

```bash
cd ~/nixos
nix flake update        # 更新 flake.lock 至最新 nixpkgs-26.05
nh os switch            # 构建 + 激活
```

### 阶段四——（可选）NVIDIA PRIME Offload

**8940HX + RTX 5060 组合不需要。** HX 系列（Dragon Range）的 iGPU 被禁用或极简；dGPU 直接驱动显示器，这就是本配置中 `prime.offload.enable = false` 的原因。

对于具备功能完整 iGPU + dGPU 的笔记本（非 HX 系列），可以启用 offload 模式——参见下方故障排除中的步骤。

## 日常维护

### 更新 Flake 输入

```bash
cd ~/nixos               # 仓库克隆位置
nix flake update         # 更新 flake.lock
nh os switch             # 构建并激活（自动读取 NH_FLAKE）
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

GRUB 启动菜单列出最近 10 个 generation（`configurationLimit = 10`），选择较早的 generation 即可回滚。回滚仅作用于 ephemeral root 子卷，`/persist` 下的持久化数据不受影响。

### 修改 niri 配置

编辑 `modules/nixos/desktop/niri.nix`。niri 热重载 `config.kdl`，保存即生效。语法错误会输出至日志：

```bash
journalctl --user -u niri -f
```

配置参考：https://niri-wm.github.io/niri/Configuration:-Introduction

## 持久化说明

由于 `/` 为 ephemeral（每次开机回滚）：

- 不要在 `/` 下存放需长期保留的数据——重启后会丢失
- 系统级持久化：添加至 `modules/nixos/persistence/impermanence.nix` 的 `directories` / `files`
- 用户级持久化：添加至同文件 `users.onyx.directories`（已有 `Documents`、`Downloads` 等）
- `~/.config` **未**持久化：niri 与 kitty 配置通过 `systemd.tmpfiles` 软链接至 nix store
- 若需持久化 Noctalia 的 GUI 设置，在 `users.onyx.directories` 中添加 `"noctalia"`

## 故障排除

### GRUB 未检测到 Windows

```bash
efibootmgr                                # 确认 Windows Boot Manager 条目存在
sudo nix-shell -p os-prober -c os-prober  # 测试 os-prober 探测
```

若 os-prober 未找到 Windows，检查 NTFS 支持是否生效——确认 `modules/nixos/core/boot.nix` 中 `boot.supportedFilesystems = ["btrfs" "ntfs"]`。

### NVIDIA 驱动异常

```bash
cat /proc/driver/nvidia/version               # 预期 570+
cat /sys/module/nvidia_drm/parameters/modeset  # 预期 Y
nvidia-smi                                     # dGPU 状态
```

若 Blackwell GPU 运行 `nvidia-smi` 失败，检查 `nvidia.nix` 中 `hardware.nvidia.open = true`——Blackwell 必须使用 open 内核模块。

### 在混合架构笔记本上启用 PRIME offload（不适用于 8940HX）

对于具备功能完整 iGPU + dGPU 的笔记本（HX 系列除外），启用 offload 模式：

```bash
lspci -nn | grep -E 'VGA|3D'
```

将十六进制 PCI 地址转换为 NixOS 格式（十进制 `总线:设备.功能`）：

| PCI 地址 | NixOS BusID |
|---|---|
| `00:02.0` | `PCI:0:2:0` |
| `01:00.0` | `PCI:1:0:0` |

编辑 `modules/nixos/hardware/nvidia.nix`：

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

rebuild 后使用 `nvidia-offload <程序>` 将程序调度至 dGPU 运行。

### disko 擦盘警示（双系统）

disko 的 `--mode destroy,format,mount` 会重写整盘 GPT 分区表，**无法保留同盘 Windows**。两种安全方案：

1. **独立物理磁盘**——将 `disko.nix` 的 `device` 指向 NixOS 所在磁盘，Windows 不受影响
2. **同盘安装**——跳过 disko 的 destroy 模式，手动用 `parted` 缩小 Windows 分区、创建 btrfs 分区，并自行填写 `fileSystems`。从 `disko.nix` 中删除 `disko.devices` 块，并验证 `postDeviceCommands` 回滚脚本与实际分区标签的一致性

### 首次启动卡在 initrd

`hosts/uontabc/disko.nix` 中的回滚脚本依赖分区标签 `disk-main-btrfs`（disko 自动生成）。验证：

```bash
ls -l /dev/disk/by-partlabel/ | grep btrfs
```

### niri 启动失败

```bash
journalctl --user -u niri -b    # 本次启动日志
niri validate                   # 验证配置语法
```

配置路径：`~/.config/niri/config.kdl`（由 `systemd.tmpfiles` 软链接至 nix store）。

### 双系统后时钟偏差

Windows 期望硬件时钟为本地时间；NixOS 期望 UTC。若时钟漂移：

```bash
timedatectl set-local-rtc 0   # NixOS 保持 UTC；在 Windows 端修复：
# Windows 中运行：reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

## 参考

- [niri 文档](https://niri-wm.github.io/niri/)
- [Noctalia 文档](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [disko](https://github.com/nix-community/disko)
- [impermanence](https://github.com/nix-community/impermanence)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)——参考其 niri + Noctalia + impermanence 组合

## 许可证

MIT