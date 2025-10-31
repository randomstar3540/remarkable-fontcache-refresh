# remarkable-fontcache-refresh

## English
- `xochitl`, the proprietary UI process on reMarkable tablets, is launched while the root filesystem is still the only storage available.
- Many users place large font families (for example Noto Sans CJK) in `/home/root/.local/share/fonts`, but `/home` is mounted later in boot, so the fonts are missing when `xochitl` first builds its cache.
- This script installs a `systemd` unit called `fontcache-refresh.service` that waits for `/home` to mount, runs `fc-cache -fsv`, and restarts `xochitl` so custom fonts are available immediately after every reboot.
- Credits: idea adapted from [mnixry's gist](https://gist.github.com/mnixry/d0fa5de3c1b42d2efa33f13f23197c20).

### Installation Workflow
1. Copy your custom fonts to `/home/root/.local/share/fonts` (or another directory under `/home` that `fontconfig` scans).
2. From your computer, run `./fontcache-refresh.sh --host <ip> (--password | --ssh-key [path]) install`.

### Uninstall
- Run `./fontcache-refresh.sh --host <ip> (--password | --ssh-key [path]) uninstall` to disable the unit and remove the installed files.

---

## 中文
- reMarkable 平板上的 UI 进程 `xochitl` 会在启动初期就被 systemd 拉起，此时只有根文件系统可用。
- 用户常把体积较大的字体（例如 Noto Sans CJK）放在 `/home/root/.local/share/fonts`，但 `/home` 直到稍后才会挂载，导致 `xochitl` 在首次构建字体缓存时找不到这些字体。
- 本脚本会安装名为 `fontcache-refresh.service` 的 `systemd` 单元，等待 `/home` 挂载后运行 `fc-cache -fsv` 并重启 `xochitl`，让自定义字体在每次重启后都能立即生效。
- 灵感来源于 [mnixry 的 gist](https://gist.github.com/mnixry/d0fa5de3c1b42d2efa33f13f23197c20)。

### 安装流程
1. 将自定义字体复制到 `/home/root/.local/share/fonts`（或其他 `fontconfig` 会扫描的 `/home` 目录）。
2. 在电脑上执行 `./fontcache-refresh.sh --host <ip> (--password | --ssh-key [路径]) install`。

### 卸载
- 执行 `./fontcache-refresh.sh --host <ip> (--password | --ssh-key [路径]) uninstall`，即可禁用单元并删除相关文件。
