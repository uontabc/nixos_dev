# NixOS Flake 安装文档

本仓库是一套基于 **Flake** 的 NixOS 配置，使用 `flake-parts` + `import-tree` 组织成模块化的目录结构，内置两个主机（host）：

| 主机名 | 用途 | 说明 |
|--------|------|------|
| `uontabc` | 裸机桌面 | AMD CPU + NVIDIA 显卡，niri Wayland 合成器，btrfs + impermanence（不可变根），GRUB 引导 |
| `wsl` | Windows WSL2 | 纯终端发行版（NixOS-WSL），无桌面，使用 Windows 宿主 GPU 驱动（WSLg） |

- nixpkgs 分支：`nixos-26.05`
- 系统 Nix：**Lix**（来自 nixpkgs）
- 包管理辅助：**nh**（`nh os switch` / `nh clean`）
- 开发环境：**microvm**（QEMU/KVM 微虚拟机，内置 `docker-dev` 沙箱）+ **dev-templates**（the-nix-way 多语言开发模板，见第 7 节）

---

## 1. 目录结构

```
nixos_dev/
├── flake.nix              # Flake 入口：输入源定义（nixpkgs、flake-parts、disko、impermanence、nixvim、noctalia、nixos-wsl、microvm、dev-templates）
├── flake.lock             # 依赖锁定文件
├── templates/             # 自带的 flake 模板（microvm-docker；其余语言模板来自 the-nix-way/dev-templates 重导出）
└── modules/
    ├── base.nix           # 所有主机共用的基础模块（用户、Nix、i18n、nh、编辑器、shell 等）
    ├── users.nix          # 用户定义（默认用户名 onyx），含 my.name / my.packages 自定义选项
    ├── nix.nix            # Lix、国内镜像源（USTC/SJTU）、Flake 实验特性
    ├── env.nix             # 全局环境变量（Wayland、XDG）
    ├── nh.nix              # nh 配置：flake 路径硬编码为 ~/nixos_dev，每周自动清理
    ├── boot.nix            # GRUB + EFI + os-prober，btrfs/ntfs 支持，/tmp 用 tmpfs
    ├── network.nix         # NetworkManager、防火墙、SSH（仅密钥登录）
    ├── impermanence.nix    # /persist 持久化目录/文件清单
    ├── disko.nix           # 引入 disko 的 NixOS 模块（分区/文件系统定义）
    ├── wsl.nix             # NixOS-WSL 模块（host: wsl 专用）
    ├── microvm.nix         # microvm.nix 接入：docker-dev 微虚拟机定义（仅 uontabc 启用，见第 7 节）
    ├── templates.nix       # flake 模板：重导出 dev-templates + 自带 microvm-docker
    ├── flake-parts.nix     # flake-parts 接入、pkgs 构造（允许 unfree）
    ├── systems.nix         # 支持的平台（x86_64-linux）
    ├── lib/nixos.nix       # host 工厂：由 modules/hosts/* 自动生成 nixosConfigurations
    ├── config/             # 各软件配置：niri、kitty、neovim、opencode、zsh、fastfetch、git、fonts、qt、i18n、nix
    ├── desktop/            # 桌面相关：niri、greetd、pipewire、xdg-portal、noctalia、xwayland、字体
    ├── hardware/           # 硬件相关：AMD CPU、NVIDIA、显卡、蓝牙、输入
    └── hosts/
        ├── uontabc/        # 裸机主机定义 + 专属 disko 分区方案
        └── wsl/            # WSL 主机定义
```

### 关键约定

- **仓库路径固定为 `~/nixos_dev`**：`nh.nix` 中 `programs.nh.flake` 硬编码了 `/home/<用户>/nixos_dev`，克隆时请保持这个路径，否则 `nh` 会失效。
- **用户名默认 `onyx`**：如需修改，改 `modules/users.nix` 里的 `my.name`（同时注意 `impermanence.nix`、`zsh.nix`、`niri.nix` 等模块中用 `config.my.name` 动态生成路径，改一处即可全局生效）。
- **密码为声明式 `hashedPassword`**：密码以 sha-512 hash 形式写在 `modules/users.nix`（当前为 `uontabc` 的 hash）。改密码只需更新该 hash 后 `nh os switch`，无需在系统里跑 `passwd`（`/` 每次开机回滚，非声明式的改动会丢失）。
- **国内镜像源**已内置：`mirrors.ustc.edu.cn` 和 `mirror.sjtu.edu.cn` 优先，`cache.nixos.org` 兜底（已配置对应的 trusted public key，无需手动信任）。

---

## 2. 前置条件

### 2.1 裸机（uontabc）

- x86_64 机器，UEFI 引导（本配置不使用 legacy BIOS）
- 磁盘至少 ~64GB（推荐 NVMe/SSD，btrfs 挂载参数带 `ssd`）
- 可用的网络连接（安装时需要拉取 nixpkgs 和二进制缓存）
- 准备一个 NixOS 安装镜像（`nixos-minimal-26.05` 即可），写入 U 盘
- 注意：`uontabc` 的硬件模块固定为 **AMD CPU + NVIDIA 显卡**（含 `amd-pstate`、NVIDIA 开源内核驱动、prime offload 可配），不是这两者的机器需要自行调整 `modules/hardware/`

### 2.2 WSL

- Windows 10 22H2 / Windows 11，已启用 **WSL2**（`wsl --version` 可查）
- 一台能构建该 flake 的 NixOS 机器（用于生成 tarball），或直接用本项目配置好的系统构建

---

## 3. 裸机安装（host: uontabc）

### 3.1 启动安装镜像

插入 U 盘启动，选择 "NixOS minimal" 进入 live 环境。默认用户是 `nixos`，root 无密码（`sudo` 可用）。

### 3.2 （可选）安装时换源提速

首次构建要拉取 flake 源码和 nixpkgs，国内网络下建议先配好 Nix 的 GitHub 镜像与二进制缓存。live 环境里编辑（或新建）`/etc/nixos/nix.conf`：

```nix
# /etc/nixos/nix.conf
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
experimental-features = nix-command flakes
```

> 系统装好后，`modules/nix.nix` 已经把这些源写死在配置里，无需重复配置。

### 3.3 克隆配置仓库

```bash
# live 环境里先装 git（minimal 镜像自带）
git clone https://github.com/uontabc/nixos_dev.git /home/onyx/nixos_dev
```

> 用 https 克隆即可；SSH 克隆需要先把你的部署公钥加到 GitHub。仓库路径必须是 `/home/onyx/nixos_dev`（见「关键约定」）。

### 3.4 磁盘分区（只需手动分一次）

本配置的 disko 方案（`modules/hosts/uontabc/disko.nix`）按 **partlabel** 识别分区，且设置了 `destroy = false`——**不会清空整个磁盘**，所以分区和 partlabel 需要你提前手动建好。建议布局：

| 分区 | partlabel | 文件系统 | 挂载点 | 大小 |
|------|-----------|----------|--------|------|
| 1 | `nixos-esp` | vfat | `/boot` | 1GiB（UEFI ESP） |
| 2 | `nixos-btrfs` | btrfs | `/`（含子卷） | 剩余全部 |

以 `/dev/nvme0n1` 为例（**警告：以下命令会清空该盘，请确认盘符！**）：

```bash
sudo -i

# 1. 重新建立 GPT 分区表
parted /dev/nvme0n1 -- mklabel gpt

# 2. ESP 分区（1GiB），分区名即 partlabel
parted /dev/nvme0n1 -- mkpart "nixos-esp" fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on

# 3. btrfs 数据分区，占满剩余空间
parted /dev/nvme0n1 -- mkpart "nixos-btrfs" 1GiB 100%
```

验证：

```bash
ls /dev/disk/by-partlabel/
# 应能看到 nixos-esp 和 nixos-btrfs
```

> 如果是多盘 / 已有其他系统，记得先确认 `esp on` 的分区号是否正确（`parted /dev/nvme0n1 print` 查看）。

### 3.5 创建文件系统（两种方式任选）

#### 方式 A：直接用 disko（推荐，与配置保持一致）

disko 会按配置创建文件系统、btrfs 子卷并挂载到 `/mnt`：

```bash
nix run github:nix-community/disko -- \
  --flake /home/onyx/nixos_dev#uontabc
```

跑完后直接跳到 3.6。

#### 方式 B：手动

```bash
# ESP
mkfs.fat -F 32 -n BOOT /dev/disk/by-partlabel/nixos-esp

# btrfs 顶层 + 子卷
mkfs.btrfs -L nixos /dev/disk/by-partlabel/nixos-btrfs

mount /dev/disk/by-partlabel/nixos-btrfs /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/persist
umount /mnt

# 挂载子卷（挂载参数与 disko.nix 保持一致）
mount -o subvol=root,compress=zstd,noatime,ssd /dev/disk/by-partlabel/nixos-btrfs /mnt
mkdir -p /mnt/{boot,nix,persist}
mount /dev/disk/by-partlabel/nixos-esp /mnt/boot
mount -o subvol=nix,compress=zstd,noatime,ssd  /dev/disk/by-partlabel/nixos-btrfs /mnt/nix
mount -o subvol=persist,compress=zstd,noatime,ssd /dev/disk/by-partlabel/nixos-btrfs /mnt/persist
```

> 三个子卷 `root`（/）、`nix`（/nix）、`persist`（/persist）缺一不可；`@root-blank` 模板子卷由系统首次启动时的 initrd 脚本自动创建，**不要**手动建。

### 3.6 安装系统

```bash
nixos-install --flake /home/onyx/nixos_dev#uontabc
```

- 分区/挂载信息来自 disko 模块生成的 `fileSystems`，`nixos-install` 会直接读取，无需再写 hardware-configuration.nix。
- 构建期间会从 USTC/SJTU 镜像下载大量二进制缓存，等待即可。
- 安装完成后：

```bash
reboot
```

### 3.7 首次启动

1. GRUB 菜单出现，选择 NixOS 进入。
2. **根文件系统回滚**：initrd 中有一个 `impermanence-rollback` systemd 服务（`modules/hosts/uontabc/default.nix`），首次启动时若不存在 `@root-blank`，会把当前 `root` 子卷快照为 `@root-blank` 作为"出厂模板"；此后每次开机都会把 `/` 回滚到该模板。**这意味着 `/` 上的一切改动（除非在 /persist）都会在重启后消失**——这是设计使然。
3. 通过 greetd + tuigreet 的 TUI 登录界面登录用户 `onyx`，密码即 `modules/users.nix` 中 `hashedPassword` 对应的密码（当前为 `uontabc`）。

**首次登录后必做：**

```bash
# 1. 配置 SSH 公钥（SSH 已禁用密码登录）
mkdir -p ~/.ssh && chmod 700 ~/.ssh
vim ~/.ssh/authorized_keys   # 粘贴你的公钥，保存后会自动持久化

# 2. （可选）确认挂载
findmnt / /nix /persist
```

> 想改密码：在任意机器上运行 `mkpasswd -m sha-512` 生成新 hash，替换 `modules/users.nix` 中的 `hashedPassword` 后 `nh os switch`，用新密码登录验证即可。

持久化清单见 `modules/impermanence.nix`：`/var/lib/nixos`、`/var/lib/systemd`、`/var/lib/NetworkManager`、`/var/log`、`/etc/ssh/ssh_host_*_key`、`/etc/machine-id`，以及用户目录下的 `Documents`、`Downloads`、`.ssh`、`.gnupg`、`.local/share`、`dev`（microvm 共享目录）、`Projects` 等，另有 `.zsh_history` 文件持久化。

---

## 4. WSL 安装（host: wsl）

`wsl` 主机是一个纯终端发行版，构建时通过 `wsl.tarball.configPath = self.outPath` 把整个 flake 源码烘焙进 tarball 的 `/etc/nixos`，导入后即可脱离构建机直接重装。

### 4.1 在 NixOS 上构建 WSL tarball

```bash
cd ~/nixos_dev
nix build .#nixosConfigurations.wsl.config.system.build.tarball

ls result/tarball/
# 产物：nixos-wsl.tar.gz（或类似文件名）
```

### 4.2 导入到 Windows

把 `result/tarball/` 里的 tarball 拷到 Windows（如 `C:\NixOS\`），然后在 **管理员 PowerShell** 中：

```powershell
# 确认 WSL2 可用
wsl --version

# 导入
wsl --import NixOS C:\NixOS C:\NixOS\nixos-wsl.tar.gz

# 进入系统
wsl -d NixOS
```

首次登录用户为 `onyx`，密码即配置中的 `hashedPassword` 对应密码（当前为 `uontabc`）。

### 4.3 在 WSL 内更新配置

tarball 已内置 flake 源码，可直接用它重装/切换：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#wsl
```

特点说明（`modules/wsl.nix`）：

- `defaultUser = onyx`，自动以该用户登录
- `useWindowsDriver = true`：图形使用 Windows 宿主的 OpenGL/Vulkan 驱动（WSLg），不装 Linux 显卡驱动
- `startMenuLaunchers = true`：在 Windows 开始菜单生成入口
- 不引入 boot/network/hardware/desktop/impermanence 模块——WSL 用自己的内核、网络和显示

---

## 5. 日常使用

```bash
# 更新并切换系统（自动读取 ~/nixos_dev 的 flake）
nh os switch

# 等价于
sudo nixos-rebuild switch --flake /home/onyx/nixos_dev#uontabc

# 手动清理旧生成物（系统已配置每周自动清理：保留 5 份 / 7 天）
nh clean all

# 查看当前生成物
nh list --generation

# 回滚上一次切换
sudo nixos-rebuild switch --flake /home/onyx/nixos_dev#uontabc --rollback
```

- 桌面快捷键参考：`niri` 窗口键为 **Mod**（默认 `Mod4`/Super）。`Mod+Return` 开终端，`Mod+Space` 打开 noctalia 启动器，`Mod+S` 控制中心，音量/亮度用多媒体键（见 `modules/config/niri.nix` 完整键位表）。
- 更新 flake 依赖：`nix flake update`（注意：`nixvim` 使用自己锁定的 nixos-26.05 分支，**不要**改它的 nixpkgs 跟随，否则会报 `vimPlugins.<name> attribute not found`）。
- 包管理：所有系统包都走声明式配置（`my.packages` / `environment.systemPackages`），不推荐 `nix profile` 混用。

---

## 6. 凭据管理

本仓库不使用声明式 secrets 工具（如 vaultix / sops-nix）。用户级凭据按各应用的默认位置存放：

- **opencode**：API key 存放在 `~/.local/share/opencode/auth.json`（格式 `{"deepseek": {"api_key": "..."}}`）。用 `opencode auth login` 或手动写入该文件即可；`~/.local/share` 已由 impermanence 持久化，重启不丢。
- **其他应用**：按各自默认路径（如 `~/.ssh/`、`~/.gnupg/`），这些目录同样在持久化清单里。

> 手动写入的凭据不会被任何声明式流程覆盖；改 key 直接在对应文件里改即可。

---

## 7. 开发环境（MicroVM + Docker + 模板）

### 7.1 docker-dev 微虚拟机

`uontabc` 启用了 [microvm.nix](https://github.com/microvm-nix/microvm.nix) 框架，声明式定义了一台 **docker-dev** 微虚拟机（QEMU + KVM，2.5GB 内存 / 2 vCPU；不用整 2GB 是因为 QEMU 在恰好 2GB guest 内存时会挂起）。相比 `nixos-container`，microvm 是真正的虚拟机（独立内核、独占内存/IO），隔离更强、性能接近裸机。

配置要点（`modules/microvm.nix`）：

| 项目 | 值 | 说明 |
|------|-----|------|
| hypervisor | `qemu` | 支持 9p 共享 + SLiRP 用户网络 |
| shares | `ro-store` | 只读共享主机 `/nix/store`，guest 启动几乎不额外占磁盘 |
| shares | `dev` | `~/dev` 挂载到 guest 的 `/workspace`（可写） |
| volumes | `docker-data.img` | 8GB 数据盘（自动创建，ext4），docker 镜像重启不丢 |
| interfaces | user 网络 | SLiRP，guest 可上网，主机无需任何网卡配置 |
| forwardPorts | `2222 → 22` | SSH 进入 guest |
| docker | `virtualisation.docker.enable` | guest 内 docker daemon |
| autostart | `false` | 不随开机自启，手动启动 |

**使用：**

```bash
# 启动 / 停止 / 查看状态
systemctl start microvm@docker-dev.service
systemctl stop  microvm@docker-dev.service
systemctl status microvm@docker-dev.service

# 进入 guest：root 自动登录（串口控制台）或 SSH
ssh root@localhost -p 2222        # 密码 toor

# guest 内使用 docker（开发目录在 /workspace）
docker run --rm -it -v /workspace:/src alpine sh
```

**修改 guest 配置：** 只改 `modules/microvm.nix`，`nh os switch` 后声明式 VM 会自动重建并重启（`restartIfChanged`）。

**注意事项：**

- guest 根文件系统只读（依赖 `ro-store` 共享），在 guest 内不能 `nixos-rebuild`，安装包请直接在主机配置里加。
- VM 状态目录：`/var/lib/microvms/docker-dev/`（含 `docker-data.img`、当前 runner 等）。
- 需要 KVM：确认主机 BIOS 已开虚拟化且 `/dev/kvm` 存在（见 8.10）。

### 7.2 dev-templates（多语言开发模板）

本仓库重导出了 [the-nix-way/dev-templates](https://github.com/the-nix-way/dev-templates) 的全部模板（rust、go、python、node、zig、c-cpp、shell、nix、empty 等 40+ 个），并自带一个 `microvm-docker` 模板：

```bash
# 在已有项目目录里初始化开发环境
nix flake init -t .#rust          # 或 .#go / .#python / .#node / .#zig ...

# 或直接新建项目目录
nix flake new -t .#go ./my-project

# 进入开发环境
nix develop                       # 已装 nix-direnv 的话：direnv allow
```

查看全部可用模板：`nix flake show`（`templates.*` 部分）。

**自带模板 `microvm-docker`：** 独立的 docker 开发 MicroVM，可在任意机器上 `nix run`（无需改主机配置），适合临时开一个隔离沙箱：

```bash
nix flake init -t .#microvm-docker
nix run                          # 前台运行，SSH 端口映射 2222 → 22
```

---

## 8. 常见问题与排错

### 8.1 开机卡在滚动根目录 / 想回到"出厂状态"

`/` 每次开机都会从 `@root-blank` 回滚。若系统被改坏，无需重装——确保 `/persist` 里没有残留问题配置，重启即可"复位"。也可以手动把某个子卷快照覆盖回 root：

```bash
sudo btrfs subvolume snapshot /mnt/@root-blank /mnt/root   # 需先卸载/换挂载
```

### 8.2 `nixos-install` 报 fileSystems 相关错误

多半是 3.5 的挂载没做完整（`root`/`nix`/`persist` 三个子卷 + `/mnt/boot`），用 `findmnt` 检查 `/mnt` 下挂载点。

### 8.3 SSH 无法登录

`network.nix` 设置了 `PasswordAuthentication = false`，且用户没有密码登录通道。请确认：

- 公钥已写入 `~/.ssh/authorized_keys`（注意 impermanence：文件必须放在 `/persist/home/onyx/.ssh/` 对应位置，`~/.ssh` 软链由 `hideMounts` 处理，直接编辑 `~/.ssh/authorized_keys` 即可）
- 或临时在配置中放开密码认证后 `nh os switch` 再登录

### 8.4 NVIDIA / prime offload

`modules/hardware/nvidia.nix` 默认关闭 prime offload（`lib.mkDefault false`），如需独显渲染，把 `modules/hardware/nvidia.nix` 中的 `amdgpuBusId` / `nvidiaBusId` 注释取消并按实际 `lspci` 总线号填写，再设 `offload.enable = true`。

### 8.5 换源后 substitution 失败 / 密钥报错

镜像源使用与官方缓存相同的签名密钥，但必须显式声明。检查 `nix.settings` 中是否同时包含：

```
trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
```

### 8.6 添加/修改 host

- 新主机：在 `modules/hosts/<名字>/default.nix` 里仿照 `uontabc` 写 `hosts.<名字> = { system, stateVersion, module }`，`lib/nixos.nix` 会自动生成 `nixosConfigurations.<名字>`；同目录下的 `flake.modules.nixos.<名字>.*` 会被自动附加到该主机。
- 改用户：改 `modules/users.nix` 的 `my.name`，`impermanence.nix` 的用户目录、`nh.nix` 的 flake 路径、`wsl.nix` 的 `defaultUser` 都会跟随。

### 8.7 microvm 启动失败：找不到 /dev/kvm

`docker-dev` 是 KVM 加速虚拟机，没有 `/dev/kvm` 会启动失败。排查：

```bash
ls -l /dev/kvm            # 不存在则看下一步
grep -E "vmx|svm" /proc/cpuinfo   # CPU 是否支持虚拟化
```

- 在 BIOS/UEFI 里开启虚拟化（Intel VT-x / AMD SVM）。
- 确认宿主机的 `kvm-amd`（AMD）或 `kvm-intel`（Intel）内核模块已加载：`lsmod | grep kvm`。
- 注意：WSL2 里跑 microvm 需要 Windows 侧开启嵌套虚拟化，`uontabc`（裸机）没有这个问题。
