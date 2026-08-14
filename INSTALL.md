# NixOS Flake 安装文档

本仓库是一套基于 **Flake** 的 NixOS 配置，使用 `flake-parts` + `import-tree` 组织成模块化的目录结构，内置两个主机（host）：

| 主机名 | 用途 | 说明 |
|--------|------|------|
| `uontabc` | 裸机桌面 | AMD CPU + NVIDIA 显卡，niri Wayland 合成器，btrfs + impermanence（不可变根），GRUB 引导 |
| `wsl` | Windows WSL2 | 纯终端发行版（NixOS-WSL），无桌面，使用 Windows 宿主 GPU 驱动（WSLg） |

- nixpkgs 分支：`nixos-26.05`
- 系统 Nix：**Lix**（来自 nixpkgs）
- 包管理辅助：**nh**（`nh os switch` / `nh clean`）
- 密钥管理：**vaultix**（age 加密的声明式 secrets，见第 7 节）

---

## 1. 目录结构

```
nixos_dev/
├── flake.nix              # Flake 入口：输入源定义（nixpkgs、flake-parts、disko、impermanence、nixvim、noctalia、nixos-wsl、vaultix）
├── flake.lock             # 依赖锁定文件
├── secrets/               # vaultix 密钥仓库（见第 7 节）
│   ├── *.age              # age 加密的 secret 文件（进入 git）
│   └── cache/<host>/      # renc 生成的主机级重加密产物（进入 git）
└── modules/
    ├── base.nix           # 所有主机共用的基础模块（用户、Nix、i18n、nh、vaultix、编辑器、shell 等）
    ├── users.nix          # 用户定义（默认用户名 onyx），含 my.name / my.packages 自定义选项
    ├── nix.nix            # Lix、国内镜像源（USTC/SJTU）、Flake 实验特性
    ├── env.nix             # 全局环境变量（Wayland、XDG）
    ├── nh.nix              # nh 配置：flake 路径硬编码为 ~/nixos_dev，每周自动清理
    ├── boot.nix            # GRUB + EFI + os-prober，btrfs/ntfs 支持，/tmp 用 tmpfs
    ├── network.nix         # NetworkManager、防火墙、SSH（仅密钥登录）
    ├── impermanence.nix    # /persist 持久化目录/文件清单
    ├── disko.nix           # 引入 disko 的 NixOS 模块（分区/文件系统定义）
    ├── wsl.nix             # NixOS-WSL 模块（host: wsl 专用）
    ├── vaultix.nix         # vaultix flake 模块：identity、secrets 目录、NixOS 模块接入
    ├── flake-parts.nix     # flake-parts 接入、pkgs 构造（允许 unfree）
    ├── systems.nix         # 支持的平台（x86_64-linux）
    ├── lib/nixos.nix       # host 工厂：由 modules/hosts/* 自动生成 nixosConfigurations（含 vaultix 所需的 specialArgs.self）
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

持久化清单见 `modules/impermanence.nix`：`/var/lib/nixos`、`/var/lib/systemd`、`/var/lib/NetworkManager`、`/var/log`、`/etc/ssh/ssh_host_*_key`、`/etc/machine-id`，以及用户目录下的 `Documents`、`Downloads`、`.ssh`、`.gnupg`、`.local/share`、`Projects` 等。

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

## 6. 密钥管理（vaultix）

本仓库用 [vaultix](https://milieuim.github.io/vaultix/) 做声明式 secrets 管理（age 加密，思路类似 sops-nix / agenix-rekey）。整体依赖链：

```
你（age identity，仓库外）                ～～明文只在编辑/重加密时于本地短暂存在～～
   │ nix run .#vaultix...edit / renc
   ▼
secrets/*.age（age 加密，进 git）
   │ renc 按主机重加密
   ▼
secrets/cache/<host>/<hash>（进 git，随 flake 分发）
   │ 主机开机时由系统里的 vaultix 解密单元处理
   ▼
/run/vaultix/<name>（root 可见的明文，仅在内存/运行时盘）
```

### 6.1 目录与文件

| 路径 | 作用 | 是否进 git |
|------|------|-----------|
| `~/.config/vaultix/identity` | 主 age identity（能解密所有 secret） | 否，仓库外 |
| `secrets/*.age` | age 加密的 secret 文件 | 是 |
| `secrets/cache/<host>/` | renc 按主机重加密的产物 | 是，必须提交 |

> 主 identity 用**绝对路径字符串**写在 `modules/vaultix.nix`（`identity = "/home/onyx/.config/vaultix/identity"`），这样不会把私钥复制进 nix store。请自行备份好这个文件，丢了它所有 secret 都解不开。

### 6.2 前置条件（本仓库已全部满足）

- flake + `nix-command` 实验特性（`modules/nix.nix` 已开）
- `services.userborn.enable = true`（`modules/vaultix.nix` 中自动开启，需 NixOS 24.11+）
- `specialArgs` 传入 `self`（`modules/lib/nixos.nix` 已处理）

### 6.3 首次准备：生成 identity

若 `~/.config/vaultix/identity` 不存在：

```bash
nix run nixpkgs#age-keygen -- -o ~/.config/vaultix/identity
chmod 600 ~/.config/vaultix/identity
```

新机器部署前，先在有 identity 的机器上把 `secrets/cache/` 生成好并提交（见 6.4），否则目标机的构建会因找不到 cache 而失败。

### 6.4 日常流程

**添加/修改 secret：**

```bash
# 1. 编辑（新建或修改）age 文件；旧文件会在 $EDITOR 中展示明文
nix run .#vaultix.app.x86_64-linux.edit -- secrets/foo.age

# 2. 在目标主机的模块里声明，例如 modules/hosts/wsl/default.nix：
#      vaultix.secrets.foo = { };            # 默认对应 ./secrets/foo.age
#      或 vaultix.secrets.foo = { file = ./secrets/foo.age; owner = "user"; ... };

# 3. 提交 secret 文件，然后按主机重加密
git add secrets/foo.age
nix run .#vaultix.app.x86_64-linux.renc

# 4. 把生成的 cache 一并提交（漏了部署时会报 "secrets haven't been re-encrypted"）
git add secrets/cache
git commit
```

**在模块中使用：** 解密后的明文路径为 `/run/vaultix/<name>`，例如：

```nix
vaultix.secrets.wireguard-key = { };
# ...
networking.wireguard.interfaces.wg0.privateKeyFile = config.vaultix.secrets.wireguard-key.path;
```

**删除 secret：** 删掉模块声明 + `secrets/*.age`，跑一遍 `renc`，提交。

### 6.5 接入新主机

每个主机都要有自己的**接收公钥**（vaultix 用它重加密 secret）：

1. 在主机上确认 SSH host key 或专用 key 的公钥：
   ```bash
   cat /etc/ssh/ssh_host_ed25519_key.pub   # 主机已有 sshd 时
   ```
2. 写入该主机的 `hosts/<名字>/default.nix`：
   ```nix
   vaultix.settings.hostPubkey = "ssh-ed25519 AAAAC3...";   # 或 hostKeys 列表，见 wsl
   ```
3. 声明所需 secret，跑 `renc` 生成 `secrets/cache/<名字>/` 并提交。

> `wsl` 主机没有 sshd（不会生成 host key），所以它显式声明了 `hostKeys`（一个固定路径的 ed25519 key），需要先在 WSL 里生成一次该 key 文件；`uontabc` 的 `hostPubkey` 目前是占位符，装机后按 6.5 第 1 步替换并重跑 `renc`。

---

## 7. 常见问题与排错

### 7.1 开机卡在滚动根目录 / 想回到"出厂状态"

`/` 每次开机都会从 `@root-blank` 回滚。若系统被改坏，无需重装——确保 `/persist` 里没有残留问题配置，重启即可"复位"。也可以手动把某个子卷快照覆盖回 root：

```bash
sudo btrfs subvolume snapshot /mnt/@root-blank /mnt/root   # 需先卸载/换挂载
```

### 7.2 `nixos-install` 报 fileSystems 相关错误

多半是 3.5 的挂载没做完整（`root`/`nix`/`persist` 三个子卷 + `/mnt/boot`），用 `findmnt` 检查 `/mnt` 下挂载点。

### 7.3 SSH 无法登录

`network.nix` 设置了 `PasswordAuthentication = false`，且用户没有密码登录通道。请确认：

- 公钥已写入 `~/.ssh/authorized_keys`（注意 impermanence：文件必须放在 `/persist/home/onyx/.ssh/` 对应位置，`~/.ssh` 软链由 `hideMounts` 处理，直接编辑 `~/.ssh/authorized_keys` 即可）
- 或临时在配置中放开密码认证后 `nh os switch` 再登录

### 7.4 NVIDIA / prime offload

`modules/hardware/nvidia.nix` 默认关闭 prime offload（`lib.mkDefault false`），如需独显渲染，把 `modules/hardware/nvidia.nix` 中的 `amdgpuBusId` / `nvidiaBusId` 注释取消并按实际 `lspci` 总线号填写，再设 `offload.enable = true`。

### 7.5 换源后 substitution 失败 / 密钥报错

镜像源使用与官方缓存相同的签名密钥，但必须显式声明。检查 `nix.settings` 中是否同时包含：

```
trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
```

### 7.6 添加/修改 host

- 新主机：在 `modules/hosts/<名字>/default.nix` 里仿照 `uontabc` 写 `hosts.<名字> = { system, stateVersion, module }`，`lib/nixos.nix` 会自动生成 `nixosConfigurations.<名字>`；同目录下的 `flake.modules.nixos.<名字>.*` 会被自动附加到该主机。接入 vaultix 见 6.5。
- 改用户：改 `modules/users.nix` 的 `my.name`，`impermanence.nix` 的用户目录、`nh.nix` 的 flake 路径、`wsl.nix` 的 `defaultUser` 都会跟随。

### 7.7 构建报 "secret file path not exist" / "secrets haven't been re-encrypted"

说明 flake 源码里找不到对应的 secret 文件或 cache：

- `secret file path not exist: .../secrets/foo.age` → `secrets/foo.age` 没 `git add`（flake 只读取 git 树内的文件），或文件路径与 `vaultix.secrets.*` 声明不一致。
- `secrets haven't been re-encrypted: .../fcb146...` → `secrets/cache/<host>/` 有新增但没提交。跑一遍 `nix run .#vaultix.app.x86_64-linux.renc`，再 `git add secrets/cache`。

### 7.8 修改 secret 后其它主机没生效

`edit` 只更新 `secrets/*.age`；每台主机的明文是 renc 时按其 host key 单独重加密的，改完必须重新 `nix run .#vaultix.app.x86_64-linux.renc` 并提交 `secrets/cache/`，否则目标机拿到的还是旧值。

### 7.9 忘了 identity 的 passphrase / 换机器

- 备份：`~/.config/vaultix/identity` 是唯一能解密所有 secret 的钥匙，换机器时把它（和 `hosts/wsl` 使用的 `/etc/ssh/ssh_host_ed25519_key` 及私钥）一起迁走。
- 若 identity 丢失且没有 `extraRecipients` 备份，secret 无法恢复——只能删除 `secrets/*.age` 重新生成。
