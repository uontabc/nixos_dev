# uontabc — NixOS 配置

**语言：** [English](README.md) · 中文（当前）

完全基于 NixOS 模块（不使用 home-manager）的声明式桌面配置。合成器采用 [niri](https://github.com/niri-wm/niri)（滚动式平铺），桌面 shell 采用 [Noctalia v5](https://github.com/noctalia-dev/noctalia)，分盘用 [disko](https://github.com/nix-community/disko) 声明 btrfs 布局，根目录通过 [impermanence](https://github.com/nix-community/impermanence) 实现不可变快照回滚，日常维护命令使用 [nh](https://github.com/nix-community/nh)。

## 特性概览

- **滚动平铺合成器** niri，KDL 配置热重载
- **桌面 shell** Noctalia v5 beta（bar / launcher / 通知 / 锁屏 / 控制中心，systemd 用户服务管理）
- **声明式分盘** disko + btrfs，子卷 `root` / `persist` / `nix`
- **不可变根** 每次开机将 root 子卷回滚至 `@root-blank` 基线快照；impermanence 持久化关键状态
- **双系统** GRUB + os-prober 自动探测 Windows Boot Manager；ntfs3 支持挂载 NTFS 数据盘
- **硬件驱动** AMD CPU（microcode + amd-pstate）+ NVIDIA RTX 5060 Laptop（Blackwell，open 内核模块 + stable 驱动）
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
| CPU | AMD Ryzen（Zen 3+） | `modules/nixos/hardware/cpu-amd.nix` |
| dGPU | NVIDIA RTX 5060 Laptop（Blackwell sm_120） | `modules/nixos/hardware/nvidia.nix` |
| iGPU | AMD iGPU（混合架构笔记本） | 在 `nvidia.nix` 中设置 `prime.amdgpuBusId` |
| 内屏 | eDP-1，2560×1600 @ 240 Hz | `modules/nixos/desktop/niri.nix` 的 `output` 节点 |
| 外屏 | DP-1，2560×1440 @ 210 Hz | 同上 |
| 磁盘 | 单 NVMe，整盘给 NixOS | `hosts/uontabc/disko.nix` 的 `device` |

## 前置条件

1. 支持 UEFI 启动的机器，Secure Boot 已关闭
2. 已烧录 [NixOS 26.05 ISO](https://nixos.org/download/) 的 USB 启动盘
3. **目标磁盘数据已完整备份**——disko 的 `destroy` 模式会擦除整盘
4. 双系统安装：Windows 须位于**独立物理磁盘**（disko 无法保留同盘 Windows）

## 安装步骤

### 1. 启动 Live USB

在 UEFI 固件设置中关闭 Secure Boot，从 NixOS Live ISO 启动。

### 2. 进入含 git 和编辑器的 shell

```bash
sudo nix-shell -p git vim
```

### 3. 克隆仓库

```bash
cd /tmp
git clone <your-repo-url> nixos
cd nixos
```

### 4. 确认目标磁盘的稳定标识

```bash
ls -l /dev/disk/by-id/ | grep -v -E 'part|usb'
```

记下目标 NVMe 设备的 `by-id` 路径，例如 `nvme-eui.000000000000000001234567890123`。使用 `by-id` 而非 `/dev/nvme0n1` 可避免重启后盘符漂移。

### 5. 在 disko 中配置磁盘

编辑 `hosts/uontabc/disko.nix`，替换占位符：

```nix
device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
```

填入步骤 4 记录的路径。

### 6. 执行 disko 分区与格式化

**此操作将清除目标磁盘上的所有数据。执行前务必再次确认磁盘标识。**

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#uontabc
```

完成后分区将挂载至 `/mnt`：

```bash
mount | grep /mnt
# 预期输出：/mnt、/mnt/boot、/mnt/nix、/mnt/persist
```

### 7. 安装 NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
```

按提示设置 root 密码，安装完成后关机、拔除 USB、重启。

### 8. 首次启动

- 以 `onyx` 用户登录，初始密码 `changeme`（定义于 `modules/nixos/core/users.nix`）。
- **立即修改密码：**

  ```bash
  passwd
  ```

- 首次启动时 btrfs 回滚脚本从 `root` 子卷生成 `@root-blank` 基线快照，此后每次开机自动将 `root` 回滚至 `@root-blank`。

### 9.（可选）启用 NVIDIA PRIME Offload 模式

混合架构笔记本（iGPU + dGPU）需配置 PCI BusID 以启用 Offload 模式。

获取 GPU 地址：

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
  amdgpuBusId = "PCI:5:0:0";   # AMD iGPU
  nvidiaBusId = "PCI:1:0:0";   # NVIDIA dGPU
};
```

rebuild 后使用 `nvidia-offload <程序>` 将程序调度至 dGPU 运行。

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

## 参考

- [niri 文档](https://niri-wm.github.io/niri/)
- [Noctalia 文档](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [disko](https://github.com/nix-community/disko)
- [impermanence](https://github.com/nix-community/impermanence)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)——参考其 niri + Noctalia + impermanence 组合

## 许可证

MIT