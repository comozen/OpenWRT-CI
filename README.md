# OpenWRT-CI（BE10000 自用分支）

[VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 的 fork，用 GitHub Actions 云编译
[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) `owrt` 分支固件。

本分支做了定向裁剪：**只编译 qualcommbe / ipq95xx 平台的小米 BE10000（IPQ9570）**，
`squashfs-factory.ubi` + `squashfs-sysupgrade.bin` 两个包。

> BE10000 与 BE10000 Pro / BE10000-es 镜像不通用，不要互刷。

## 构建触发

| 方式 | 说明 |
|---|---|
| 定时 | 每天 05:21（CST）`Auto-Clean` 清理旧产物后自动触发 `QCB-ALL` |
| 手动 | Actions → `QCB-ALL` → Run workflow，可临时填 `PACKAGE` 追加插件配置 |
| 试配置 | Actions → `WRT-TEST`，勾选 `TEST` 只出 `Config-*.txt`，不编固件（约 10 分钟） |

`OWRT-ALL` / `MTK-ALL` / `QCA-ALL` / `AIROHA-ALL` 四个平台 workflow 已禁用（只服务于本机型的构建），
`Cache-Clean`（每周清空全部 Actions 缓存）保持禁用，避免白丢 ccache 与 staging_dir。
`Cache-Clean` 与 `Auto-Clean` 的定时器需要仓库管理员在 Actions 页面手动 Enable（fork 默认禁用 schedule）。

## 目录

| 目录 | 作用 |
|---|---|
| `.github/workflows/` | `WRT-CORE.yml` 是唯一编译流程，其余为各平台入口（只传参） |
| `.github/scripts/` | Rust/Go/Python/LLVM 工具链复用、构建耗时报告收集 |
| `Config/` | 机型与插件配置，按 `平台.txt` + `GENERAL.txt` 顺序拼接进 `.config` |
| `Scripts/` | `Packages.sh` 拉第三方插件、`Settings.sh` 改默认 IP/SSID/主机名、`Handles.sh` 打主题补丁 |

## 常用改动

三个高频参数**不用改代码**，在 Actions → `QCB-ALL` → Run workflow 里直接选/填：

| 输入项 | 默认 | 说明 |
|---|---|---|
| `DEVICE` | `xiaomi_be10000` | 机型下拉框；选定后覆盖 `Config/IPQ95XX.txt` 里的设备列表 |
| `IP` | `10.0.0.99` | LAN 地址 |
| `HOSTNAME` | `OWRT` | 主机名 |
| `SSID_2G` / `SSID_5_2G` / `SSID_5_8G` | 都是 `OWRT` | 三个射频分别命名，后两个留空则沿用 2.4G |
| `WIFI_PASSWORD` | `12345678` | 三频共用，至少 8 位 |

字段留空或由 `Auto-Clean` 自动触发时，回落到表中的默认值（即 `QCB-ALL.yml` 里 `inputs.X || '默认值'` 的写法）。
机型填错不会静默成功：`WRT-CORE` 在 `make defconfig` 之后会校验设备符号，不存在就直接报错退出。

> SSID / 密码里不能出现单引号、`#`、`&`、反斜杠（会破坏 ucode 字符串或 sed 表达式），密码少于 8 位也会直接报错。
> BE10000 是 2.4G + 5.2G + 5.8G 三射频（三个 PCIe 卡，无 6GHz）。ath12k 把两张 5G 卡都上报成 `band=5g`，
> 所以 `Settings.sh` 用 `radio.freq_ranges` 的频段下界（5500000 kHz）区分 5.2G 与 5.8G。

> 想改成"改默认值也不动代码"，可以再叠一层仓库变量
> （Settings → Secrets and variables → Actions → Variables），把 `inputs.X` 换成 `inputs.X || vars.X || '默认值'` 即可。

**加减插件**：先在 `Scripts/Packages.sh` 里加 `UPDATE_PACKAGE` 把源码拉进 `package/`，再到 `.config` 里选。
配置加载顺序（后写的覆盖先写的）：

```
Config/IPQ95XX.txt → Config/GENERAL.txt → Scripts/Settings.sh
→ Config/PRIVATE.txt → Run workflow 的 PACKAGE 输入框 → make defconfig
```

想覆盖单项又不想和上游冲突，写 `Config/PRIVATE.txt`（格式约定见该文件头部注释）。
`make defconfig` 会静默丢弃源码树里不存在的包，所以新增插件必须先确认 `UPDATE_PACKAGE` 拉到了源码。

## 同步上游

```bash
git remote add upstream https://github.com/VIKINGYFY/OpenWRT-CI.git   # 只需一次
git fetch upstream main
git merge upstream/main
```

固定会冲突的文件：`Config/IPQ95XX.txt`（本分支只留 be10000）、`Scripts/Settings.sh`、`Scripts/Handles.sh`。
冲突时前两个脚本取上游版本（`git checkout --theirs`），机型配置取本地（`--ours`）。

## 上游资源

- 官方源码：<https://github.com/immortalwrt/immortalwrt>
- 自用源码：<https://github.com/VIKINGYFY/immortalwrt>
- 本地编译器：<https://github.com/VIKINGYFY/OWRT-Tools>
- 自用修改版插件：<https://github.com/VIKINGYFY/packages>
- 联发科 U-Boot：<https://github.com/VIKINGYFY/UBOOT-CI/releases>
- 高通 U-Boot（沉心）：<https://github.com/chenxin527/uboot-qsdk12.5-build>
- 高通 U-Boot（小猪）：<https://github.com/1980490718/u-boot-2016>

## 许可

MIT，见 [LICENSE](LICENSE)。上游作者 VIKINGYFY。
