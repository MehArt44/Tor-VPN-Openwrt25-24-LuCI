**English** | [Persian](README.md) | [Chinese](README.zh.md)


# Tor VPN Panel for OpenWrt (LuCI)

![License](https://img.shields.io/badge/license-MIT-blue)
![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%7C%2025.12-00B5E2)
![Package manager](https://img.shields.io/badge/packages-opkg%20%7C%20apk-lightgrey)

**Version:** `0.4.9.1-stage3c` · **Supported firmware:** OpenWrt 24.10 (`opkg`) and OpenWrt 25.12 or newer (`apk`)

A LuCI panel for OpenWrt that routes your entire LAN through Tor, with a kill switch, DNS leak protection, automatic bridge racing, exit-country selection, live tests, and update / uninstall from inside the panel.

---

## ✨ Features

- **🔒 Kill Switch:** While Auto Connect is on, LAN internet access goes only through Tor. If Tor drops or is stopped, the LAN cannot reach the internet without Tor (until you press Start or Unblock Internet).
- **🌉 Bridge Race:** Direct connection (vanilla), `obfs4`, and `webtunnel` are tried simultaneously, and the first successful connection wins. You can also add your own custom bridges.
- **🚫 DNS Leak Protection:** Network DNS requests are redirected to Tor's DNSPort (`9053`).
- **🌍 Exit Country Selection:** Pick from a dropdown with flags, with an optional Strict Exit mode.
- **📊 Dashboard and Live Tests:** Bootstrap, SOCKS, DNS, firewall, IPv6 leak, real IP vs. Tor IP, speed, and logs.
- **🧠 Memory Mode:** Successful bridges are remembered so the next connection is faster.
- **🔄 Smart In-Panel Update:** The update URL is fixed (this GitHub repository). The panel compares the installed "Build date" with the online one, and only downloads and installs if the online version is newer (if GitHub is blocked, it downloads through Tor).
- **📦 Dual Compatibility:** Works with `apk` (25.12+) and `opkg` (24.10). If the installed Tor is older than `0.4.9.5`, the installer tries to upgrade it.
- **🗑️ Clean Uninstall:** Firewall rules, DNS changes, and the kill switch are all removed.

---

## 🚀 Installation

Run on the router over SSH with root access:

```sh
wget -O /tmp/Tor.Vpn.v0.4.9.15_install.sh https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh

```

Or with `curl`:

```sh
curl -fsSL https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh -o /tmp/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh

```

When the installation finishes, refresh the LuCI page with `Ctrl+F5` and go to **VPN → Tor VPN**.

**Requirements:** Internet access on the router during installation, and enough free space for the `tor`, `tor-geoip`, `curl` packages and the transports (`lyrebird`, `snowflake-client`, `obfs4proxy`). The installer installs whatever is needed; if a package is not available in the feed for your architecture, it warns you and uses a prebuilt Tor Project package for the transports (verified with SHA-256).

> If LuCI doesn't show the menu: press `Ctrl+F5`, or run this on the router:
> `/etc/init.d/rpcd restart && /etc/init.d/uhttpd restart`

---

## 🛠️ Panel Guide

### 1. Service Control
- **Start / Restart:** Starts or restarts the Tor tunnel.
- **Stop:** Stops Tor. If the kill switch is active, LAN internet stays blocked.
- **Unblock Internet:** After Stop, releases the kill switch so the LAN gets normal internet (without Tor).

### 2. Auto Connect (Enable)
- On: Tor starts at boot and the kill switch is active.
- Off + Apply: Tor is stopped and every rule it added (firewall, kill switch, DNS routing, IPv6) is removed.

### 3. Custom Exit Node (Exit Country)
Enable it, then choose one or more countries under **Target Region(s)**. **Strict Exit** prevents exiting from any other country (Tor will retry instead, so the connection may be slower or less stable).

### 4. Bridges
The connection mode is always **Race**: direct connection, `obfs4`, and `webtunnel` are tried at the same time (default timeout: 120 seconds).
- **Bridge Lines:** Enter your own bridges (one per line); bridges you enter take priority over the default set.
- Example formats:

```text
obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=<0/1/2>
webtunnel <IP>:<PORT> <FINGERPRINT> url=https://<DOMAIN>/<PATH> ver=<VERSION>
```

### 5. Router Traffic via Tor
Also routes the router's own traffic (such as `curl` and package installation) through Tor.

### 6. Security Status and Router-Side Diagnostics
The **Run All Tests** button checks the status of Tor, TransPort, Tor DNS, the firewall, the DNS leak guard, and IPv6. During bootstrap, tests may take a while; wait until it reaches 100% and run them again. The Logs section shows the live Tor log.

### 7. Update / Uninstall
- **Update URL:** Fixed and not editable in the panel (the `install.sh` file in this GitHub repository). `blob` page links are automatically converted to raw links.
- **Check for updates:** Compares the installed "Build date" with the online one and shows the result (newer / up to date / older). Opening this section triggers one automatic check.
- **Update now:** Downloads and validates the installer, and runs it **only if the online Build date is newer**; otherwise it shows "Already up to date" and nothing changes. If there is no newer version and you want to reinstall the current one, the panel asks for confirmation first. Your settings are preserved.
- **Uninstall:** Removes the panel and its rules. Check "Also delete settings, state and Memory record" to wipe everything.
- **Clear cache:** Clears only Tor's network cache (keys and settings are kept). If Tor is running, it restarts and re-downloads the cache, which takes a few minutes.

---

## 🔄 Update

From the panel: **Update / Uninstall → Check for updates → Update now**. Installation happens only if a newer version exists (based on Build date). Alternatively, run the installation command above again. After updating, refresh the page with `Ctrl+F5`.

## 🗑️ Uninstall

From the panel (Uninstall), or over SSH:

```sh
sh /usr/libexec/tor_ui/installer.sh uninstall            # remove, keep settings
sh /usr/libexec/tor_ui/installer.sh uninstall --purge    # full removal
```

If the local copy of the installer is missing:

```sh
wget -O /tmp/install.sh https://raw.githubusercontent.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/main/install.sh && sh /tmp/install.sh uninstall --purge
```

---

## ⚠️ Notes and Troubleshooting

- **Conflict with other VPNs:** If OpenVPN or WireGuard is active and owns the default route, Tor **will not start** by default (`conflict_policy=block`), and the reason is written to the log. Turn that VPN off first. With
  `uci set tor_ui.main.conflict_policy=downgrade && uci commit tor_ui`
  transparent routing is turned off instead of stopping Tor, leaving only SOCKS available.
- **Slow bootstrap:** The first run takes a few minutes; wait until it reaches 100%.
- **Error `wget: exited with error 4`:** If the router's `wget` has problems, use `curl`, or run
  `ln -sf /bin/uclient-fetch /usr/bin/wget` and repeat the installation.
- **Ports:** SOCKS `9050` · TransPort `9040` · DNSPort `9053` (configurable in `/etc/config/tor_ui`).
- **Disclaimer:** Tor does not guarantee absolute anonymity. Follow the laws of your country; use is at your own responsibility.

---

## 🤝 Contributing and License

Use **Issues** to report bugs or make suggestions. This project is released under the **MIT** license.

<img width="1802" height="1496" alt="image" src="https://github.com/user-attachments/assets/fb0dd2e1-791f-431e-a146-7ad69111e0c3" />
