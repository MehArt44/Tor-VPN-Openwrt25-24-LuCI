# Tor VPN Panel for OpenWrt (LuCI)

![License](https://img.shields.io/badge/license-MIT-blue)
![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%7C%2025.12-00B5E2)
![Package manager](https://img.shields.io/badge/packages-opkg%20%7C%20apk-lightgrey)

**Version:** `0.4.9.1-stage3c` · **Supported firmware:** OpenWrt 24.10 (`opkg`) and OpenWrt 25.12+ (`apk`)

A LuCI panel that routes your whole LAN through Tor on OpenWrt, with a kill switch, DNS leak protection, automatic bridge racing, exit-country selection, live tests and one-click update / uninstall.

یک پنل LuCI برای OpenWrt که کل شبکهٔ LAN را از Tor عبور می‌دهد؛ همراه با کیل‌سوئیچ، جلوگیری از نشت DNS، انتخاب خودکار پل (Bridge)، انتخاب کشور خروجی، تست زنده و آپدیت/حذف از داخل پنل.

---

## ✨ ویژگی‌ها (Features)

- **🔒 Kill Switch:** وقتی Auto Connect روشن است، اینترنت LAN فقط از مسیر Tor عبور می‌کند؛ اگر Tor قطع یا متوقف شود، LAN بدون Tor به اینترنت نمی‌رسد (تا Start یا Unblock Internet).
- **🌉 Bridge Race (مسابقهٔ خودکار پل‌ها):** اتصال مستقیم (vanilla)، `obfs4` و `webtunnel` هم‌زمان امتحان می‌شوند و اولین اتصال موفق انتخاب می‌شود. پل شخصی هم می‌توانید اضافه کنید.
- **🚫 ضد نشت DNS:** درخواست‌های DNS شبکه به DNSPort تور (`9053`) هدایت می‌شوند.
- **🌍 انتخاب کشور خروجی:** با منوی کشویی و پرچم؛ همراه با گزینهٔ Strict Exit.
- **📊 داشبورد و تست زنده:** Bootstrap، SOCKS، DNS، فایروال، نشت IPv6، IP واقعی در برابر IP تور، سرعت و لاگ.
- **🧠 Memory Mode:** پل‌های موفق ذخیره می‌شوند تا اتصال بعدی سریع‌تر باشد.
- **🔄 آپدیت از داخل پنل:** نمایش تاریخ نسخهٔ نصب‌شده، بررسی نسخهٔ جدید در گیت‌هاب و آپدیت با یک کلیک (اگر گیت‌هاب بسته باشد از مسیر Tor دانلود می‌کند).
- **📦 سازگاری دوگانه:** `apk` (25.12+) و `opkg` (24.10). اگر Tor نصب‌شده قدیمی‌تر از `0.4.9.5` باشد، نصاب تلاش می‌کند آن را ارتقا دهد.
- **🗑️ حذف تمیز:** قوانین فایروال، تغییرات DNS و کیل‌سوئیچ پاک می‌شوند.

---

## 🚀 نصب (Installation)

روی روتر با SSH و دسترسی root اجرا کنید:

```sh
wget -O /tmp/Tor.Vpn.v0.4.9.15_install.sh https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh
```

یا با `curl`:

```sh
curl -fsSL https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/releases/download/0.4.9.15/Tor.Vpn.v0.4.9.15_install.sh -o /tmp/Tor.Vpn.v0.4.9.15_install.sh && sh /tmp/Tor.Vpn.v0.4.9.15_install.sh
```

پس از پایان نصب، صفحهٔ LuCI را با `Ctrl+F5` تازه کنید و به **VPN → Tor VPN** بروید.

**نیازمندی‌ها:** اینترنت روی روتر هنگام نصب، فضای کافی برای بسته‌های `tor`، `tor-geoip`، `curl` و ترنسپورت‌ها (`lyrebird`، `snowflake-client`، `obfs4proxy`). نصاب هر چه لازم باشد خودش نصب می‌کند؛ اگر بسته‌ای برای معماری شما در فید موجود نباشد، هشدار می‌دهد و برای ترنسپورت‌ها از بستهٔ آمادهٔ Tor Project (با بررسی SHA-256) استفاده می‌کند.

> اگر LuCI منو را نشان نداد: `Ctrl+F5` بزنید یا روی روتر
> `/etc/init.d/rpcd restart && /etc/init.d/uhttpd restart` را اجرا کنید.

---

## 🛠️ راهنمای پنل (Panel Guide)

### ۱. Service Control (کنترل سرویس)
- **Start / Restart:** تونل Tor را روشن یا دوباره راه‌اندازی می‌کند.
- **Stop:** Tor را خاموش می‌کند. اگر کیل‌سوئیچ فعال باشد، اینترنت LAN قطع می‌ماند.
- **Unblock Internet:** پس از Stop، کیل‌سوئیچ را آزاد می‌کند تا LAN اینترنت عادی (بدون Tor) داشته باشد.

### ۲. Auto Connect (Enable)
- روشن: Tor هنگام بوت اجرا می‌شود و کیل‌سوئیچ فعال است.
- خاموش + Apply: Tor متوقف می‌شود و همهٔ قوانینی که اضافه کرده (فایروال، کیل‌سوئیچ، مسیر DNS، IPv6) برداشته می‌شود.

### ۳. Custom Exit Node (کشور خروجی)
با روشن کردن آن، از **Target Region(s)** یک یا چند کشور انتخاب کنید. گزینهٔ **Strict Exit** مانع خروج از کشورهای دیگر می‌شود (Tor به‌جای آن دوباره تلاش می‌کند، پس ممکن است اتصال کندتر یا ناپایدار شود).

### ۴. Bridges (پل‌ها)
حالت اتصال همیشه **Race** است: اتصال مستقیم، `obfs4` و `webtunnel` هم‌زمان امتحان می‌شوند (مهلت پیش‌فرض ۱۲۰ ثانیه).
- **Bridge Lines:** پل شخصی خود را (هر پل در یک خط) وارد کنید؛ پل‌های واردشده بر مجموعهٔ پیش‌فرض اولویت دارند.
- نمونه قالب‌ها:
  - `obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=<0/1/2>`
  - `webtunnel <IP>:<PORT> <FINGERPRINT> url=https://<DOMAIN>/<PATH> ver=<VERSION>`

### ۵. Router Traffic via Tor
ترافیک خود روتر (مثل `curl` و نصب بسته) را هم از Tor عبور می‌دهد.

### ۶. Security Status و Router-Side Diagnostics
دکمهٔ **Run All Tests** وضعیت Tor، TransPort، DNS تور، فایروال، محافظ نشت DNS و IPv6 را بررسی می‌کند. در زمان Bootstrap ممکن است تست‌ها زمان‌بر باشند؛ تا رسیدن به ۱۰۰٪ صبر کنید و دوباره اجرا کنید. بخش Logs لاگ زندهٔ Tor را نشان می‌دهد.

### ۷. Update / Uninstall
- **Update URL:** آدرس raw فایل `install.sh` (به‌صورت پیش‌فرض همین مخزن).
- **Check for updates:** تاریخ نسخهٔ نصب‌شده را با نسخهٔ گیت‌هاب مقایسه می‌کند.
- **Update now:** نصاب را دانلود و اجرا می‌کند. تنظیمات حفظ می‌شود.
- **Uninstall:** پنل و قوانین را حذف می‌کند. با تیک «Also delete settings, state and Memory record» همه‌چیز پاک می‌شود.
- **Clear cache:** فقط کش شبکهٔ Tor را پاک می‌کند (کلیدها و تنظیمات می‌مانند). اگر Tor روشن باشد، چند دقیقه ری‌استارت و دانلود دوباره انجام می‌شود.

---

## 🔄 آپدیت

از داخل پنل: **Update / Uninstall → Check for updates → Update now**، یا با اجرای دوبارهٔ دستور نصب. پس از آپدیت صفحه را با `Ctrl+F5` تازه کنید.

## 🗑️ حذف

از پنل (Uninstall)، یا از SSH:

```sh
sh /usr/libexec/tor_ui/installer.sh uninstall            # حذف، با حفظ تنظیمات
sh /usr/libexec/tor_ui/installer.sh uninstall --purge    # حذف کامل
```

اگر نسخهٔ محلی نصاب موجود نیست:

```sh
wget -O /tmp/install.sh https://raw.githubusercontent.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/main/install.sh && sh /tmp/install.sh uninstall --purge
```

---

## ⚠️ نکات مهم و عیب‌یابی

- **تداخل با VPNهای دیگر:** اگر OpenVPN یا WireGuard فعال باشد و مسیر پیش‌فرض (default route) را در اختیار داشته باشد، Tor به‌صورت پیش‌فرض **شروع نمی‌شود** (`conflict_policy=block`) و علت در لاگ ثبت می‌شود. ابتدا آن VPN را خاموش کنید. با
  `uci set tor_ui.main.conflict_policy=downgrade && uci commit tor_ui`
  به‌جای توقف، مسیریابی شفاف خاموش می‌شود و فقط SOCKS در دسترس می‌ماند.
- **Bootstrap کند:** بار اول چند دقیقه طول می‌کشد؛ تا ۱۰۰٪ صبر کنید.
- **خطای `wget: exited with error 4`:** اگر `wget` روتر مشکل داشت، از `curl` استفاده کنید یا
  `ln -sf /bin/uclient-fetch /usr/bin/wget` را اجرا کنید و نصب را تکرار کنید.
- **پورت‌ها:** SOCKS `9050` · TransPort `9040` · DNSPort `9053` (در `/etc/config/tor_ui` قابل تغییر).
- **سلب مسئولیت:** Tor ناشناسی مطلق تضمین نمی‌کند. قوانین کشور خود را رعایت کنید و مسئولیت استفاده با خودتان است.

---

## 🤝 مشارکت و لایسنس

برای گزارش باگ یا پیشنهاد از **Issues** استفاده کنید. این پروژه تحت لایسنس **MIT** منتشر شده است.

<img width="1802" height="1496" alt="image" src="https://github.com/user-attachments/assets/fb0dd2e1-791f-431e-a146-7ad69111e0c3" />
