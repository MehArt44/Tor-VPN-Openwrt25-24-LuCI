**Chinese** | [Persian](README.md) | [English](README.en.md)


# OpenWrt Tor VPN 面板（LuCI）

![License](https://img.shields.io/badge/license-MIT-blue)
![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%7C%2025.12-00B5E2)
![Package manager](https://img.shields.io/badge/packages-opkg%20%7C%20apk-lightgrey)

**版本：** `0.4.9.1-stage3c` · **支持的固件：** OpenWrt 24.10（`opkg`）以及 OpenWrt 25.12 及更高版本（`apk`）

一个适用于 OpenWrt 的 LuCI 面板，可将整个局域网（LAN）的流量通过 Tor 转发，并提供断网保护（Kill Switch）、DNS 泄漏防护、自动网桥竞速、出口国家选择、实时测试，以及面板内一键更新 / 卸载。

---

## ✨ 功能特性

- **🔒 Kill Switch（断网保护）：** 开启“自动连接”后，局域网只能通过 Tor 访问互联网；如果 Tor 断开或被停止，局域网将无法在没有 Tor 的情况下上网（直到点击 Start 或 Unblock Internet）。
- **🌉 Bridge Race（网桥竞速）：** 同时尝试直连（vanilla）、`obfs4` 和 `webtunnel`，选择第一个连接成功的方式。你也可以添加自己的网桥。
- **🚫 DNS 防泄漏：** 网络中的 DNS 请求会被重定向到 Tor 的 DNSPort（`9053`）。
- **🌍 出口国家选择：** 通过带国旗的下拉菜单选择，并可选择启用 Strict Exit（严格出口）。
- **📊 仪表盘与实时测试：** Bootstrap、SOCKS、DNS、防火墙、IPv6 泄漏、真实 IP 与 Tor IP 对比、速度以及日志。
- **🧠 Memory Mode（记忆模式）：** 记住连接成功的网桥，使下次连接更快。
- **🔄 面板内智能更新：** 更新地址固定（即本 GitHub 仓库）。面板会将已安装版本的“构建日期”与线上版本比较，仅当线上版本更新时才下载并安装（如果 GitHub 无法访问，则通过 Tor 下载）。
- **📦 双重兼容：** 同时支持 `apk`（25.12+）和 `opkg`（24.10）。如果已安装的 Tor 版本低于 `0.4.9.5`，安装程序会尝试升级。
- **🗑️ 干净卸载：** 防火墙规则、DNS 更改以及 Kill Switch 都会被清除。

---

## 🚀 安装

通过 SSH 以 root 权限在路由器上执行：

```sh
wget -O /tmp/Tor.Vpn.v0.4.9.15_install.sh https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh

```

或使用 `curl`：

```sh
curl -fsSL https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh -o /tmp/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh

```

安装完成后，按 `Ctrl+F5` 刷新 LuCI 页面，然后进入 **VPN → Tor VPN**。

**系统要求：** 安装期间路由器需要能访问互联网，并有足够的空间安装 `tor`、`tor-geoip`、`curl` 以及传输插件（`lyrebird`、`snowflake-client`、`obfs4proxy`）。安装程序会自动安装所需组件；如果软件源中没有适用于你的架构的软件包，它会发出警告，并对传输插件使用 Tor Project 提供的预编译包（经过 SHA-256 校验）。

> 如果 LuCI 没有显示菜单：按 `Ctrl+F5`，或在路由器上执行：
> `/etc/init.d/rpcd restart && /etc/init.d/uhttpd restart`

---

## 🛠️ 面板使用指南

### 1. Service Control（服务控制）
- **Start / Restart：** 启动或重新启动 Tor 隧道。
- **Stop：** 停止 Tor。如果 Kill Switch 处于启用状态，局域网将保持断网。
- **Unblock Internet：** 在 Stop 之后解除 Kill Switch，使局域网恢复普通上网（不经过 Tor）。

### 2. Auto Connect（自动连接 / Enable）
- 开启：Tor 在开机时启动，并启用 Kill Switch。
- 关闭 + Apply：停止 Tor，并移除其添加的所有规则（防火墙、Kill Switch、DNS 路由、IPv6）。

### 3. Custom Exit Node（出口国家）
启用后，在 **Target Region(s)** 中选择一个或多个国家。**Strict Exit** 会禁止从其他国家出口（Tor 会改为重试，因此连接可能更慢或不稳定）。

### 4. Bridges（网桥）
连接模式始终为 **Race**：同时尝试直连、`obfs4` 和 `webtunnel`（默认超时 120 秒）。
- **Bridge Lines：** 输入你自己的网桥（每行一个）；你输入的网桥优先于默认网桥集合。
- 格式示例：

```text
obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=<0/1/2>
webtunnel <IP>:<PORT> <FINGERPRINT> url=https://<DOMAIN>/<PATH> ver=<VERSION>
```

### 5. Router Traffic via Tor（路由器自身流量走 Tor）
让路由器自身的流量（例如 `curl` 和软件包安装）也通过 Tor。

### 6. Security Status 与 Router-Side Diagnostics（安全状态与路由器端诊断）
**Run All Tests** 按钮会检查 Tor、TransPort、Tor DNS、防火墙、DNS 泄漏防护和 IPv6 的状态。在 Bootstrap 期间测试可能较慢；请等待进度达到 100% 后再重新运行。Logs 部分显示 Tor 的实时日志。

### 7. Update / Uninstall（更新 / 卸载）
- **更新地址：** 固定，无法在面板中编辑（即本 GitHub 仓库中的 `install.sh` 文件）。`blob` 页面链接会自动转换为 raw 链接。
- **Check for updates：** 将已安装版本的“构建日期”与线上版本比较，并显示结果（更新 / 已是最新 / 更旧）。打开此部分时会自动检查一次。
- **Update now：** 下载并校验安装程序，**仅当线上构建日期更新时**才会运行；否则显示“Already up to date”，不会有任何更改。如果没有更新版本而你想重新安装当前版本，面板会在执行前要求确认。你的设置会被保留。
- **Uninstall：** 移除面板及相关规则。勾选“Also delete settings, state and Memory record”可清除所有内容。
- **Clear cache：** 仅清除 Tor 网络缓存（密钥和设置会保留）。如果 Tor 正在运行，会重启并重新下载缓存，需要几分钟。

---

## 🔄 更新

在面板中：**Update / Uninstall → Check for updates → Update now**；仅当存在更新版本（以构建日期为准）时才会安装。也可以再次运行上面的安装命令。更新后，按 `Ctrl+F5` 刷新页面。

## 🗑️ 卸载

在面板中（Uninstall），或通过 SSH：

```sh
sh /usr/libexec/tor_ui/installer.sh uninstall            # remove, keep settings
sh /usr/libexec/tor_ui/installer.sh uninstall --purge    # full removal
```

如果本地没有安装程序：

```sh
wget -O /tmp/install.sh https://raw.githubusercontent.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/main/install.sh && sh /tmp/install.sh uninstall --purge
```

---

## ⚠️ 注意事项与故障排除

- **与其他 VPN 冲突：** 如果 OpenVPN 或 WireGuard 处于启用状态并占用默认路由，Tor 默认**不会启动**（`conflict_policy=block`），原因会记录在日志中。请先关闭该 VPN。执行
  `uci set tor_ui.main.conflict_policy=downgrade && uci commit tor_ui`
  后，将不再停止 Tor，而是关闭透明路由，仅保留 SOCKS 可用。
- **Bootstrap 缓慢：** 首次运行需要几分钟；请等待至 100%。
- **错误 `wget: exited with error 4`：** 如果路由器上的 `wget` 有问题，请使用 `curl`，或执行
  `ln -sf /bin/uclient-fetch /usr/bin/wget` 后重新安装。
- **端口：** SOCKS `9050` · TransPort `9040` · DNSPort `9053`（可在 `/etc/config/tor_ui` 中修改）。
- **免责声明：** Tor 不能保证绝对匿名。请遵守你所在国家 / 地区的法律，使用责任由你自行承担。

---

## 🤝 贡献与许可

如需报告 Bug 或提出建议，请使用 **Issues**。本项目基于 **MIT** 许可证发布。

<img width="1802" height="1496" alt="image" src="https://github.com/user-attachments/assets/fb0dd2e1-791f-431e-a146-7ad69111e0c3" />


