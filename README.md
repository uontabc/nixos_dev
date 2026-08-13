# uontabc — NixOS 配置

基于 [Nix Flakes](https://nixos.wiki/wiki/Flakes) + [home-manager](https://github.com/nix-community/home-manager) 的 NixOS 配置，桌面用 [niri](https://github.com/niri-wm/niri) + [Noctalia v5](https://github.com/noctalia-dev/noctalia)，盘用 [disko](https://github.com/nix-community/disko) 声明式分 btrfs，根目录靠 [impermanence](https://github.com/nix-community/impermanence) 做不可变回滚。

## 特性

- **滚动式平铺合成器** niri，配置走 KDL 热重载
- **桌面 shell** Noctalia v5 beta（bar/launcher/notification/lock/控制中心一体）
- **声明式分盘** disko + btrfs，子卷 `root`/`persist`/`nix`
- **不可变根** impermanence 持久化关键状态，每次开机把 root 子卷回滚到 `@root-blank` 快照
- **双系统友好** GRUB + os-prober 自动探测 Windows Boot Manager，ntfs3 支持挂载 Windows 数据盘
- **滚动 nixpkgs** 跟 `nixos-26.05` stable 分支
- **硬件驱动** AMD CPU（microcode + amd-pstate）+ NVIDIA RTX 5060 Laptop（Blackwell，open 内核模块 + stable driver）
- **轻 session** tuigreet 登录到 niri，不写自制 session 脚本

## 目录结构

```
.
├── flake.nix                       # 入口，声明 inputs + nixosConfiguration
├── hosts/uontabc/                  # 单台主机
│   ├── default.nix                 #   主机入口
│   ├── hardware.nix                #   留空（disko 接管 fileSystems）
│   └── disko.nix                   #   声明式分盘 + btrfs 回滚脚本
└── modules/
    ├── nixos/
    │   ├── default.nix             # 汇总 import
    │   ├── core/                   #   基础系统：boot/networking/locale/users/packages/env
    │   ├── hardware/               #   硬件：cpu-amd/nvidia/graphics/bluetooth/input
    │   ├── desktop/                #   桌面：display(greetd)/portal/audio/fonts/niri/noctalia
    │   └── persistence/            #   impermanence 持久化
    └── home/                       # home-manager 用户层
        ├── base.nix                #   用户名/home/stateVersion
        ├── default.nix             #   汇总 import
        ├── shell.nix                #   kitty + yazi
        ├── qt.nix                  #   qt6ct
        ├── packages.nix            #   用户级包
        ├── noctalia.nix            #   programs.noctalia.enable
        └── niri/default.nix        #   niri KDL 配置（键位/布局/动画）
```

## 硬件假设

可直接装；如果你的硬件不一样，要改的是这些：

| 硬件 | 我假设 | 你要改的地方 |
|---|---|---|
| CPU | AMD Ryzen（Zen 3+） | `modules/nixos/hardware/cpu-amd.nix`；Intel 就删该 import 换 `microcodeIntel` |
| dGPU | NVIDIA RTX 5060 Laptop（Blackwell sm_120） | `modules/nixos/hardware/nvidia.nix` |
| iGPU | AMD iGPU（hybrid 笔记本） | 双屏 hybrid 才需要设 `prime.amdgpuBusId` |
| 显示器 | eDP-1 1920x1080 | `modules/home/niri/default.nix` 的 `output` 节点 |
| 盘 | 单 NVMe，整盘给 NixOS | `hosts/uontabc/disko.nix` 的 `device` |

## 准备

1. 一台 **UEFI** 启动的机器
2. [nixos-26.05 ISO](https://nixos.org/download/) 烧好的 live USB
3. **硬盘数据已备份**（disko 会擦盘）
4. 双系统的话，**Windows 装在另一块物理盘**（同盘装必然要手动分区，不能用 disko 的 `destroy` 模式）

## 安装步骤

### 1. 启动到 live USB

- UEFI 里关 Secure Boot
- 启动 live USB

### 2. 启用 flakes + 拉 git

```bash
sudo nix-shell -p git vim
```

### 3. 克隆本仓库

```bash
cd /tmp
git clone <your-repo-url> nixos
cd nixos
```

### 4. 找到你的磁盘 stable ID

```bash
ls -l /dev/disk/by-id/ | grep -v -E 'part|usb'
```

记下 NVMe 的 by-id 路径，长这样：`nvme-eui.000000000000000001234567890123`。
**用 by-id 而不是 `/dev/nvme0n1`**，重启后盘符可能变，by-id 不会。

### 5. 改 disko.nix

编辑 `hosts/uontabc/disko.nix`，把：

```nix
device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_YOUR_DISK_ID";
```

换成你上一步记下的路径。

### 6. 跑 disko（会清盘，**这是最后一次确认你的数据已备份**）

```bash
sudo nix run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#uontabc
```

跑完会自动把分区 mount 到 `/mnt`。可以验证：

```bash
mount | grep /mnt
# 应该看到 /mnt /mnt/boot /mnt/nix /mnt/persist
```

### 7. 安装 NixOS

```bash
sudo nixos-install --flake .#uontabc --root /mnt
# 装完问你要 root 密码，设个
```

完了关机、拔 U 盘、开机。

### 8. 首次启动

- 用 `onyx` 用户登录，密码是 `changeme`（`modules/nixos/core/users.nix` 的 `initialPassword`）
- **第一时间改密码**：

  ```bash
  passwd
  ```

- 第一次启动时 btrfs 回滚脚本会从 `root` 快照 seed 一个 `@root-blank` 基线快照，此后每次开机自动回滚到 `@root-blank`。

### 9. （可选）启用 NVIDIA PRIME 双显卡 offload

如果你的笔记本是 **iGPU + dGPU 混合**（不是独显直连），需要给 NVIDIA 设 BusID 才能让 Offload 模式正常工作。

```bash
lspci -nn | grep -E 'VGA|3D'
```

拿到两个 GPU 的 PCI 地址。NixOS 要求把地址转成十进制：
- `00:02.0` → `PCI:0:0:2:0`（其实 NixOS 接受 `PCI:0:2:0`）
- `01:00.0` → `PCI:1:0:0`

然后编辑 `modules/nixos/hardware/nvidia.nix`：

```nix
hardware.nvidia.prime = {
  offload = {
    enable = lib.mkDefault true;            # ← 改成 true
    enableOffloadCmd = lib.mkDefault true;  # ← 改成 true
  };
  amdgpuBusId = "PCI:5:0:0";   # ← 填你的 AMD iGPU BusID
  nvidiaBusId = "PCI:1:0:0";   # ← 填你的 NVIDIA dGPU BusID
};
```

rebuild 后想用 dGPU 跑程序：`nvidia-offload <program>`。

## 日常使用

### 更新整个 flake

```bash
nix flake update                           # 更新 flake.lock
sudo nixos-rebuild switch --flake .#uontabc
```

### 只改配置（不更新 flake）

```bash
sudo nixos-rebuild switch --flake .#uontabc
```

home-manager 单独切：

```bash
home-manager switch --flake .#onyx@uontabc
```

### 回滚到老 generation

GRUB 启动菜单会列最近 10 个 generation（`configurationLimit = 10`），选老的进就行。由于 impermanence 在每次开机时把 root 子卷回滚到 `@root-blank`，**回滚不会影响持久化数据**。

### 改 niri 配置

编辑 `modules/home/niri/default.nix`，`niri` 自带热重载——保存即生效，无需 restart。配置语法错了会在日志报错：

```bash
journalctl --user -u niri -f
```

键位文档：https://niri-wm.github.io/niri/Configuration:-Introduction

### 改 Mango → niri 后的键位映射对照表

原 mango 的键位已经基本搬过来：

| 原 mango | niri | 说明 |
|---|---|---|
| `Super+R` | `Mod+R` reload-config | reload |
| `Super+M` | `Mod+M` quit | 退出 niri |
| `Super+Q` | `Mod+Q` close-focus-requested | 关窗口 |
| `Super+Space` | `Mod+Space` | noctalia launcher |
| `Super+S` | `Mod+S` | noctalia 控制中心 |
| `Super+H/J/K/L` | `Mod+H/J/K/L` | 焦点方向 |
| `Super+Shift+H/J/K/L` | `Mod+Shift+H/J/K/L` | move 窗口 |
| `Super+1~9` | `Mod+1~9` focus-workspace | 切工作区 |
| `Super+Shift+1~9` | `Mod+Shift+1~9` move-to-workspace | 搬窗口到工作区 |
| `Super+F` | `Mod+F` toggle-windowed-fullscreen | 全屏 |
| `Super+Backslash` | `Mod+Backspace` toggle-window-floating | 浮动 |
| `Print` | `Print` action.screenshot-screen | 截屏（niri 内置 UI） |
| `Super,Return` | `Mod+Return` spawn kitty | 终端 |
| `Super+E` | `Mod+E` spawn kitty -e yazi | 文件管理器 |

## 持久化说明

因为 `/` 是 ephemeral（每次开机回滚）：

- **不要**往 `/` 写要长期保留的东西——重启就没了
- 要持久化的系统状态加到 `modules/nixos/persistence/impermanence.nix` 的 `directories`/`files`
- 用户级持久化加到同文件 `users.onyx.directories`（如 `Documents`、`Downloads` 已在）
- 故意**没**把 `~/.config` 全持久化，因为 mango/niri 配置是 home-manager 管的
- Noctalia 的 GUI 设置如果想在重启后保留，在 `users.onyx.directories` 里加一项 `"noctalia"`（即 `.config/noctalia`）

## 故障排除

### GRUB 看不到 Windows

```bash
efibootmgr                      # 看有没有 Windows Boot Manager 条目
sudo nix-shell -p os-prober -c os-prober   # 看探测是否正常
```

如果 `os-prober` 输出里找不到 Windows，多半是 Windows 的 ESP 挂不到——检查 `boot.supportedFilesystems = ["btrfs" "ntfs"]` 是否生效。

### NVIDIA 不工作

```bash
cat /proc/driver/nvidia/version             # 应该看到 570+
cat /sys/module/nvidia_drm/parameters/modeset   # 应该是 Y
nvidia-smi                                   # 看 dGPU 状态
```

如果 Blackwell 型号 `nvidia-smi` 失败，多半是 open kernel modules 没正确加载。检查 `hardware.nvidia.open = true`（Blackwell 必须开）。

### 双系统 disko 擦盘警告

disko 的 `--mode destroy,format,mount` 会重写整盘 GPT 分区表，**无法保留 Windows**。两种安全做法：

1. NixOS 装在**另一块物理盘** → 把 `disko.nix` 的 `device` 指向那盘，Windows 不受影响
2. NixOS 和 Windows **同盘** → 不要用 disko 的 destroy 模式，手动用 `parted` 缩 Windows 分区、建 btrfs 分区，然后填 `fileSystems` 自己，从 `hosts/uontabc/disko.nix` 里删 `disko.devices` 块和 `postDeviceCommands` 回滚脚本（保留回滚脚本时单独验证 partlabel）

### 首次启动卡在 initrd

btrfs 回滚脚本（`hosts/uontabc/disko.nix` 的 `postDeviceCommands`）依赖 `/dev/disk/by-partlabel/disk-main-btrfs` 这个 partlabel，是 disko 自动生成的。如果你手改过分区标签，验证：

```bash
ls -l /dev/disk/by-partlabel/ | grep btrfs
```

### niri 启动失败

```bash
journalctl --user -u niri -b   # 看本次启动日志
niri validate                  # 手动验证配置
```

配置文件路径：`~/.config/niri/config.kdl`（home-manager 生成）。

## 推到 GitHub

本仓库在 Windows 上初始化时没装 git。在 WSL 或者装了 Git for Windows 的 PowerShell 里跑：

```bash
cd C:\Users\onyx\Desktop\mango   # 或 /mnt/c/Users/onyx/Desktop/mango（WSL）

# 1. 初始化本地仓库
git init
git add .
git commit -m "Initial NixOS + niri + noctalia configuration"

# 2. 在 GitHub 网页建一个空仓库（不要勾 README/.gitignore/license）

# 3. 加 remote 并 push
git branch -M main
git remote add origin git@github.com:<your-gh-username>/mango.git
git push -u origin main
```

或者用 `gh` CLI 一把梭：

```bash
gh repo create mango --public --source=. --push
# 想私有就 --private
```

## 参考

- [niri 文档](https://niri-wm.github.io/niri/)
- [Noctalia 文档](https://docs.noctalia.dev)
- [NixOS & Nix Flakes Book](https://nixos-and-flakes.thiscute.world/)
- [Disko 文档](https://github.com/nix-community/disko)
- [Impermanence 文档](https://github.com/nix-community/impermanence)
- 借鉴了 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config) 的 niri + noctalia + impermanence 组合与 tuigreet 用法

## License

MIT