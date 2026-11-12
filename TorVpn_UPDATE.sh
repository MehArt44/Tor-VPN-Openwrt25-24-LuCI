#!/bin/sh
VERSION="0.4.9.1-stage3c-deltator-ui-ksauto"
BUILD_DATE="2026-11-12.3"
UPDATE_URL_DEFAULT="https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/blob/main/TorVpn_UPDATE.sh"
set -e
do_uninstall() {
    set +e
    echo "Uninstalling Tor VPN panel..."
    if [ -x /etc/init.d/tor_ui ]; then
        /etc/init.d/tor_ui stop >/dev/null 2>&1 || true
    fi
    rm -f /etc/rc.d/S*tor_ui /etc/rc.d/K*tor_ui 2>/dev/null || true
    rm -rf /var/run/tor_race 2>/dev/null || true
    rm -f /etc/init.d/tor_ui 2>/dev/null || true
    rm -f /etc/firewall.tor_ui /etc/firewall.tor_ui.new 2>/dev/null || true
    nft delete table inet tor_ui_fw 2>/dev/null || true
    nft delete table inet tor_dns_block 2>/dev/null || true
    uci -q delete firewall.tor_ui_include
    uci commit firewall
    /etc/init.d/firewall reload >/dev/null 2>&1 || true
    if [ -f /etc/tor/tor_ui-state/dnsmasq.backup ]; then
        uci -q delete dhcp.@dnsmasq[0].server
        while IFS='=' read -r _k _v; do
            case "$_k" in
                boguspriv)          [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].boguspriv="$_v"          || uci -q delete dhcp.@dnsmasq[0].boguspriv ;;
                rebind_protection)  [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].rebind_protection="$_v"  || uci -q delete dhcp.@dnsmasq[0].rebind_protection ;;
                noresolv)           [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].noresolv="$_v"           || uci -q delete dhcp.@dnsmasq[0].noresolv ;;
                resolvfile)         [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].resolvfile="$_v"         || uci -q delete dhcp.@dnsmasq[0].resolvfile ;;
                server)             [ -n "$_v" ] && uci add_list dhcp.@dnsmasq[0].server="$_v" ;;
            esac
        done < /etc/tor/tor_ui-state/dnsmasq.backup
        uci commit dhcp
        /etc/init.d/dnsmasq reload >/dev/null 2>&1 || /etc/init.d/dnsmasq restart >/dev/null 2>&1
    fi
    if [ -f /etc/tor/tor_ui-state/ipv6fwd.backup ]; then
        ALL= DEFAULT=; . /etc/tor/tor_ui-state/ipv6fwd.backup
        case "$ALL" in 0|1) echo "$ALL" > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true ;; esac
        case "$DEFAULT" in 0|1) echo "$DEFAULT" > /proc/sys/net/ipv6/conf/default/forwarding 2>/dev/null || true ;; esac
    fi
    rm -f /etc/sysctl.d/99-tor-ui-killswitch.conf
    rm -rf /www/luci-static/resources/view/tor 2>/dev/null || true
    rm -f /usr/share/luci/menu.d/luci-app-tor.json 2>/dev/null || true
    rm -f /usr/share/rpcd/acl.d/luci-app-tor.json 2>/dev/null || true
    rm -f /etc/hotplug.d/iface/95-tor_ui 2>/dev/null || true
    rm -rf /usr/libexec/tor_ui 2>/dev/null || true
    rm -rf /tmp/luci-* /tmp/ucache* 2>/dev/null || true
    /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    rm -rf /var/run/tor_ui /tmp/tormaint* 2>/dev/null || true
    _SU_PATHS="/etc/tor/torrc /etc/firewall.tor_ui /etc/init.d/tor_ui /etc/hotplug.d/iface/95-tor_ui /www/luci-static/resources/view/tor /usr/share/luci/menu.d/luci-app-tor.json /usr/share/rpcd/acl.d/luci-app-tor.json /usr/libexec/tor_ui"
    if [ "${TOR_UI_PURGE:-0}" = "1" ]; then
        for _f in cached-certs cached-microdesc-consensus cached-microdescs cached-descriptors state; do rm -f "/.tor/$_f" 2>/dev/null; done
        rm -rf /.tor/keys /.tor/pt_state /.tor/tor_ui-memory 2>/dev/null || true
        rm -f /etc/config/tor_ui 2>/dev/null || true
        rm -rf /etc/tor/tor_ui-state 2>/dev/null || true
        _SU_PATHS="$_SU_PATHS /etc/config/tor_ui /etc/tor/tor_ui-state"
    fi
    if [ -f /etc/sysupgrade.conf ]; then
        for _p in $_SU_PATHS; do
            grep -vxF "$_p" /etc/sysupgrade.conf > /tmp/su.tor.tmp 2>/dev/null && cat /tmp/su.tor.tmp > /etc/sysupgrade.conf
        done
        rm -f /tmp/su.tor.tmp
    fi
    echo ""
    if [ "${TOR_UI_PURGE:-0}" = "1" ]; then
        echo "Done. Full removal: settings, state and Memory record were deleted."
        echo "  /var/lib/tor/ is managed by the tor package and was left alone."
    else
        echo "Done. The following were kept on purpose:"
        echo "  /etc/config/tor_ui           (UCI settings -- delete manually if desired)"
        echo "  /etc/tor/tor_ui-state/       (Memory-mode record + optional bridges/ pool files; safe to remove)"
        echo "  /var/lib/tor/                (Tor shared data; managed by the tor package)"
        echo ""
        echo "To wipe everything too, run the uninstaller with --purge."
    fi
    set -e
}
case "${1:-}" in
    uninstall|--uninstall)
        TOR_UI_PURGE=0
        for _a in "${2:-}" "${3:-}"; do
            [ "$_a" = "--purge" ] && TOR_UI_PURGE=1
        done
        do_uninstall
        exit 0
        ;;
esac
PT="${PT:-all}"
PT_REQUIRED="${PT_REQUIRED:-all}"
pt_wanted() {
    case "$PT" in
        all|"") return 0 ;;
        *"$1"*) return 0 ;;
        *) return 1 ;;
    esac
}
pt_required() {
    case "$PT_REQUIRED" in
        all|"") return 0 ;;
        *"$1"*) return 0 ;;
        *) return 1 ;;
    esac
}
if [ -x /etc/init.d/tor_ui ] && command -v pidof >/dev/null 2>&1 && ! pidof tor >/dev/null 2>&1; then
    echo "   -> No Tor running: releasing any held Kill Switch / DNS block so downloads work..."
    if ! /etc/init.d/tor_ui unblock >/dev/null 2>&1; then
        /etc/init.d/tor_ui stop >/dev/null 2>&1 || true
        nft delete table inet tor_ui_fw 2>/dev/null || true
        nft delete table inet tor_dns_block 2>/dev/null || true
        uci -q delete firewall.tor_ui_include || true
        uci commit firewall 2>/dev/null || true
        rm -f /etc/firewall.tor_ui 2>/dev/null || true
        /etc/init.d/firewall reload >/dev/null 2>&1 || true
    fi
fi
echo "0. Ensuring all Tor, GeoIP and pluggable-transport prerequisites are installed..."
PKG_MANAGER=""
OPENWRT_RELEASE=""
if [ -r /etc/openwrt_release ]; then
    OPENWRT_RELEASE="$(. /etc/openwrt_release 2>/dev/null; printf '%s' "${DISTRIB_RELEASE:-}")"
fi
case "$OPENWRT_RELEASE" in
    25.12*|26.*|27.*|28.*|29.*)
        command -v apk >/dev/null 2>&1 && PKG_MANAGER="apk"
        ;;
    24.10*|23.*|22.*|21.*|20.*|19.*)
        command -v opkg >/dev/null 2>&1 && PKG_MANAGER="opkg"
        ;;
esac
if [ -z "$PKG_MANAGER" ]; then
    if command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"
    elif command -v opkg >/dev/null 2>&1; then
        PKG_MANAGER="opkg"
    fi
fi
case "$PKG_MANAGER" in
    apk)
        echo "   -> Package manager: apk (OpenWrt 25.12+)"
        ;;
    opkg)
        echo "   -> Package manager: opkg (OpenWrt 24.10 and older)"
        ;;
    *)
        echo "   -> ERROR: neither apk nor opkg is available on this firmware."
        echo "      Supported bases: OpenWrt 25.12+ (apk) and OpenWrt 24.10 (opkg)."
        ;;
esac
pkg_installed() {
    case "$PKG_MANAGER" in
        apk)
            apk info -e "$1" >/dev/null 2>&1
            ;;
        opkg)
            opkg list-installed 2>/dev/null | awk -v p="$1" '$1 == p {found=1} END {exit !found}'
            ;;
        *)
            return 1
            ;;
    esac
}
_pkg_update_done=0
pkg_update_once() {
    [ "$_pkg_update_done" = "1" ] && return 0
    case "$PKG_MANAGER" in
        apk)
            :
            ;;
        opkg)
            opkg update >/dev/null 2>&1 || true
            ;;
    esac
    _pkg_update_done=1
}
pkg_install_one() {
    case "$PKG_MANAGER" in
        apk)
            apk -U add "$1" >/dev/null 2>&1
            ;;
        opkg)
            opkg install "$1" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}
ensure_pkg() {
    local label name
    label="$1"; shift
    for name in "$@"; do
        if pkg_installed "$name"; then
            echo "   -> $label: '$name' already installed."
            return 0
        fi
    done
    if [ -z "$PKG_MANAGER" ]; then
        echo "   -> WARNING: no opkg/apk found on this system -- install $label manually (tried: $*)."
        return 1
    fi
    pkg_update_once
    for name in "$@"; do
        if pkg_install_one "$name"; then
            echo "   -> $label: installed '$name'."
            return 0
        fi
    done
    echo "   -> WARNING: could not install $label automatically (tried: $*)."
    echo "      It may not be prebuilt for this target/architecture; you may need to"
    echo "      cross-compile it or add a 3rd-party feed that provides it."
    return 1
}
ensure_pkg "curl"                curl                    || true
ensure_pkg "Tor daemon"          tor                     || true
ensure_pkg "Tor GeoIP/GeoIP6 databases" tor-geoip          || true

TOR_MIN_VERSION="0.4.9.5"
OWRT_ARCH=""
if [ -r /etc/openwrt_release ]; then
    OWRT_ARCH="$(. /etc/openwrt_release 2>/dev/null; printf '%s' "${DISTRIB_ARCH:-}")"
fi
TOR_UPGRADED_WHILE_RUNNING=0
ver_ge() {
    awk -v a="$1" -v b="$2" 'BEGIN{
        na=split(a,x,"."); nb=split(b,y,"."); n=(na>nb)?na:nb
        for(i=1;i<=n;i++){ p=x[i]+0; q=y[i]+0; if(p>q) exit 0; if(p<q) exit 1 }
        exit 0 }'
}
tor_installed_version() {
    command -v tor >/dev/null 2>&1 || return 1
    tor --version 2>/dev/null | sed -n '1s/^Tor version \([0-9][0-9.]*[0-9]\).*/\1/p'
}
tor_is_current() {
    local _v
    _v="$(tor_installed_version)" || true
    [ -n "$_v" ] && ver_ge "$_v" "$TOR_MIN_VERSION"
}
fetch_file() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 --max-time 240 -o "$2" "$1" 2>/dev/null && [ -s "$2" ] && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$2" "$1" 2>/dev/null && [ -s "$2" ] && return 0
    fi
    rm -f "$2" 2>/dev/null
    return 1
}
tor_feed_bases() {
    local series root p
    [ -n "$OWRT_ARCH" ] || return 0
    series="$(printf '%s' "$OPENWRT_RELEASE" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
    [ -n "$series" ] || return 0
    root="https://downloads.openwrt.org/releases"
    echo "$root/packages-$series/$OWRT_ARCH/packages"
    for p in 12 11 10 9 8 7 6 5 4 3 2 1; do
        echo "$root/$series.$p/packages/$OWRT_ARCH/packages"
    done
}
apk_pick_file() {
    local best="" bv="" cand cv
    for cand in $(apk list --allow-untrusted --repository "$1" "$2" 2>/dev/null \
            | awk -v p="$2" 'index($1,p"-")==1 { r=substr($1,length(p)+2); if (r ~ /^[0-9]/) print $1 }'); do
        cv="${cand#"$2"-}"; cv="${cv%%-r*}"
        if [ -z "$best" ] || { [ "$cv" != "$bv" ] && ver_ge "$cv" "$bv"; }; then
            best="$cand"; bv="$cv"
        fi
    done
    [ -n "$best" ] && echo "$best.apk"
    return 0
}
tor_remember_running() {
    local _p
    _p="$(cat /var/run/tor_ui/tor.pid 2>/dev/null)" || true
    if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
        TOR_UPGRADED_WHILE_RUNNING=1
    fi
}
upgrade_tor_apk() {
    local base tmpd f_tor f_geo v sim bad
    tmpd="/tmp/tor-ui-upgrade"
    for base in $(tor_feed_bases); do
        rm -rf "$tmpd"; mkdir -p "$tmpd" || return 1
        fetch_file "$base/packages.adb" "$tmpd/index.adb" || continue
        f_tor="$(apk_pick_file "$tmpd/index.adb" tor)"
        f_geo="$(apk_pick_file "$tmpd/index.adb" tor-geoip)"
        [ -n "$f_tor" ] && [ -n "$f_geo" ] || continue
        v="${f_tor#tor-}"; v="${v%.apk}"; v="${v%%-r*}"
        ver_ge "$v" "$TOR_MIN_VERSION" || continue
        echo "   -> Found Tor $v at $base"
        fetch_file "$base/$f_tor" "$tmpd/tor.apk"        || continue
        fetch_file "$base/$f_geo" "$tmpd/tor-geoip.apk"  || continue
        sim="$(apk add -s --allow-untrusted "$tmpd/tor.apk" "$tmpd/tor-geoip.apk" 2>&1)" || true
        bad="$(printf '%s\n' "$sim" \
            | awk '/^\([0-9]+\/[0-9]+\) (Installing|Upgrading|Downgrading|Replacing|Purging) /{print $3}' \
            | grep -v -x -e tor -e tor-geoip || true)"
        if [ -n "$bad" ]; then
            echo "   -> Skipping this feed: the upgrade would also change other packages: $(echo $bad)"
            continue
        fi
        tor_remember_running
        apk add --allow-untrusted "$tmpd/tor.apk" "$tmpd/tor-geoip.apk" >"$tmpd/apk.log" 2>&1 || true
        if tor_is_current; then
            rm -rf "$tmpd"
            return 0
        fi
    done
    rm -rf "$tmpd"
    return 1
}
ipk_pick() {
    awk -v p="$2" '
        /^Package: /  { pkg=$2 }
        /^Version: /  { ver=$2 }
        /^Filename: / { if (pkg==p && !done) { print ver " " $2; done=1 } }' "$1"
}
upgrade_tor_opkg() {
    local base tmpd line_t line_g v_t f_t f_g
    tmpd="/tmp/tor-ui-upgrade"
    command -v gunzip >/dev/null 2>&1 || return 1
    for base in $(tor_feed_bases); do
        rm -rf "$tmpd"; mkdir -p "$tmpd" || return 1
        fetch_file "$base/Packages.gz" "$tmpd/Packages.gz" || continue
        gunzip -c "$tmpd/Packages.gz" > "$tmpd/Packages" 2>/dev/null || continue
        line_t="$(ipk_pick "$tmpd/Packages" tor)"
        line_g="$(ipk_pick "$tmpd/Packages" tor-geoip)"
        [ -n "$line_t" ] && [ -n "$line_g" ] || continue
        v_t="${line_t%% *}"; f_t="${line_t#* }"; f_g="${line_g#* }"
        v_t="${v_t%%-*}"
        ver_ge "$v_t" "$TOR_MIN_VERSION" || continue
        echo "   -> Found Tor $v_t at $base"
        fetch_file "$base/$f_t" "$tmpd/tor.ipk"        || continue
        fetch_file "$base/$f_g" "$tmpd/tor-geoip.ipk"  || continue
        tor_remember_running
        opkg install "$tmpd/tor.ipk" "$tmpd/tor-geoip.ipk" >"$tmpd/opkg.log" 2>&1 || true
        if tor_is_current; then
            rm -rf "$tmpd"
            return 0
        fi
    done
    rm -rf "$tmpd"
    return 1
}
if ! tor_is_current; then
    _tv="$(tor_installed_version)" || true
    echo "   -> Installed Tor is ${_tv:-missing}; version >= $TOR_MIN_VERSION is required. Trying to upgrade..."
    case "$PKG_MANAGER" in
        apk)
            tor_remember_running
            apk -U add -u tor tor-geoip >/dev/null 2>&1 || true
            tor_is_current || upgrade_tor_apk || true
            ;;
        opkg)
            tor_remember_running
            opkg upgrade tor tor-geoip >/dev/null 2>&1 || true
            tor_is_current || upgrade_tor_opkg || true
            ;;
    esac
    rm -f /etc/tor/torrc.apk-new /etc/tor/torrc.opkg 2>/dev/null || true
    _tv="$(tor_installed_version)" || true
    if tor_is_current; then
        echo "   -> Tor upgraded: $_tv"
    else
        echo "   -> WARNING: Tor is ${_tv:-not installed}; no feed for this firmware provides >= $TOR_MIN_VERSION."
        echo "      The panel will still be installed, but bootstrap may fail with an old Tor."
        echo "      (Re-run this script after a firmware or feed update.)"
        TOR_UPGRADED_WHILE_RUNNING=0
    fi
else
    echo "   -> Tor $(tor_installed_version) meets the minimum ($TOR_MIN_VERSION)."
fi
if pt_wanted obfs4; then
    ensure_pkg "obfs4 transport"                       obfs4proxy obfs4 || true
fi
if pt_wanted snowflake; then
    ensure_pkg "Snowflake transport"                   snowflake-client || true
fi
if pt_wanted lyrebird; then
    ensure_pkg "lyrebird (obfs4/webtunnel/meek_lite)"  lyrebird || true
fi
TOR_PT_BUNDLE_VERSION="16.0a7"
TOR_PT_BUNDLE_BASE="https://archive.torproject.org/tor-package-archive/torbrowser/${TOR_PT_BUNDLE_VERSION}"
TOR_PT_BUNDLE_AARCH64_SHA256="1a51b37cc68f2df4d8952d3f343794f2f966c59d84fe580c56192377c00fcc1b"
TOR_PT_BUNDLE_X86_64_SHA256="280eed6c352524279d2ebc50113c4c48205a6f14b4aced9932f9568eec585396"
install_prebuilt_tor_pts() {
    local _need=0
    command -v lyrebird         >/dev/null 2>&1 || _need=1
    command -v snowflake-client >/dev/null 2>&1 || _need=1
    command -v obfs4proxy       >/dev/null 2>&1 || _need=1
    [ "$_need" = "0" ] && return 0
    local arch bundle sha tmpdir archive lyre snow obfs
    arch="$(uname -m 2>/dev/null)"
    case "$arch" in
        aarch64|arm64)
            bundle="tor-expert-bundle-linux-aarch64-${TOR_PT_BUNDLE_VERSION}.tar.gz"
            sha="$TOR_PT_BUNDLE_AARCH64_SHA256"
            ;;
        x86_64|amd64)
            bundle="tor-expert-bundle-linux-x86_64-${TOR_PT_BUNDLE_VERSION}.tar.gz"
            sha="$TOR_PT_BUNDLE_X86_64_SHA256"
            ;;
        *)
            echo "   -> WARNING: no prebuilt Tor PT bundle is configured for architecture '$arch'."
            echo "      Install lyrebird/snowflake-client/obfs4proxy from your package feed."
            return 1
            ;;
    esac
    command -v curl >/dev/null 2>&1 || return 1
    command -v sha256sum >/dev/null 2>&1 || return 1
    command -v tar >/dev/null 2>&1 || return 1
    tmpdir="/tmp/tor-ui-prebuilt-pt"
    archive="$tmpdir/$bundle"
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir" || return 1
    echo "   -> Downloading Tor Project prebuilt PT bundle ${TOR_PT_BUNDLE_VERSION} ($arch)..."
    if [ -s "/tmp/$bundle" ]; then
        echo "   -> Using local bundle /tmp/$bundle"
        cp "/tmp/$bundle" "$archive" || { rm -rf "$tmpdir"; return 1; }
    elif ! curl -fL --retry 3 --connect-timeout 15 --max-time 300 \
        "$TOR_PT_BUNDLE_BASE/$bundle" -o "$archive"; then
        _sp="$(awk '/^SocksPort[ \t]/{print $2; exit}' /etc/tor/torrc 2>/dev/null)"
        case "$_sp" in "") _sp="127.0.0.1:9050" ;; *:*) ;; *) _sp="127.0.0.1:$_sp" ;; esac
        echo "   -> Direct download failed; trying through Tor SOCKS ($_sp) if Tor is running..."
        if ! curl -fL --connect-timeout 20 --max-time 600 --socks5-hostname "$_sp" \
            "$TOR_PT_BUNDLE_BASE/$bundle" -o "$archive"; then
            echo "   -> Could not download the bundle. Either start Tor in the panel (obfs4/snowflake work"
            echo "      without it) and run this installer again, or copy"
            echo "      $bundle to /tmp/ on the router (download it on a PC) and run the installer again."
            rm -rf "$tmpdir"
            return 1
        fi
    fi
    echo "   -> Verifying Tor Project bundle SHA-256..."
    echo "$sha  $archive" | sha256sum -c - >/dev/null 2>&1 || {
        echo "   -> ERROR: Tor PT bundle checksum verification FAILED."
        rm -rf "$tmpdir"
        return 1
    }
    echo "   -> Extracting prebuilt PT binaries from the bundle..."
    mkdir -p "$tmpdir/extract" || return 1
    tar -xzf "$archive" -C "$tmpdir/extract" || {
        rm -rf "$tmpdir"
        return 1
    }
    lyre="$(find "$tmpdir/extract" -type f -name lyrebird        2>/dev/null | head -n 1)"
    snow="$(find "$tmpdir/extract" -type f -name snowflake-client 2>/dev/null | head -n 1)"
    obfs="$(find "$tmpdir/extract" -type f -name obfs4proxy       2>/dev/null | head -n 1)"
    if ! command -v lyrebird >/dev/null 2>&1 && [ -n "$lyre" ]; then
        cp "$lyre" /usr/bin/lyrebird && chmod 0755 /usr/bin/lyrebird || true
    fi
    if ! command -v snowflake-client >/dev/null 2>&1 && [ -n "$snow" ]; then
        cp "$snow" /usr/bin/snowflake-client && chmod 0755 /usr/bin/snowflake-client || true
    fi
    if ! command -v obfs4proxy >/dev/null 2>&1 && [ -n "$obfs" ]; then
        cp "$obfs" /usr/bin/obfs4proxy && chmod 0755 /usr/bin/obfs4proxy || true
    fi
    rm -rf "$tmpdir"
    command -v lyrebird >/dev/null 2>&1 || command -v snowflake-client >/dev/null 2>&1 || command -v obfs4proxy >/dev/null 2>&1
}
install_prebuilt_tor_pts || true
ensure_pkg "conntrack-tools (kill-switch conntrack flush)" conntrack-tools conntrack || true
ensure_pkg "dig (DNS test tool)" bind-dig || true
echo "   -> Verifying pluggable-transport binaries on PATH:"
pt_bin=""
for cand in lyrebird obfs4proxy; do
    command -v "$cand" >/dev/null 2>&1 && { pt_bin="$cand"; break; }
done
if [ -n "$pt_bin" ]; then
    echo "      obfs4      : OK (via $pt_bin)"
    if [ "$pt_bin" = "lyrebird" ]; then
        echo "      webtunnel  : OK (via lyrebird)"
        echo "      meek_lite  : OK (via lyrebird)"
    else
        echo "      webtunnel  : MISSING (obfs4proxy does not implement it -- need 'lyrebird')"
        echo "      meek_lite  : MISSING (obfs4proxy does not implement it -- need 'lyrebird')"
    fi
else
    echo "      obfs4      : MISSING"
    echo "      webtunnel  : MISSING"
    echo "      meek_lite  : MISSING"
fi
command -v snowflake-client >/dev/null 2>&1 && echo "      snowflake  : OK" || echo "      snowflake  : MISSING"
PT_MISSING=""
if pt_required obfs4; then
    command -v lyrebird >/dev/null 2>&1 || command -v obfs4proxy >/dev/null 2>&1 || command -v obfs4 >/dev/null 2>&1 || PT_MISSING="$PT_MISSING obfs4"
fi
if pt_required webtunnel || pt_required meek_lite || pt_required lyrebird; then
    command -v lyrebird >/dev/null 2>&1 || PT_MISSING="$PT_MISSING webtunnel+meek_lite"
fi
if pt_required snowflake; then
    command -v snowflake-client >/dev/null 2>&1 || PT_MISSING="$PT_MISSING snowflake"
fi
if [ -n "$PT_MISSING" ]; then
    echo "ERROR: Required Tor transports are still missing:$PT_MISSING"
    echo "       PT=$PT  PT_REQUIRED=$PT_REQUIRED"
    if [ "${PT_STRICT:-0}" = "1" ]; then
        echo "       PT_STRICT=1 -> aborting."
        exit 1
    fi
    echo "       WARNING: continuing anyway so the LuCI panel is installed;"
    echo "       install the missing transports later (bridges need them)."
else
    echo "      ALL REQUESTED TRANSPORTS: installed and available."
fi
if ! command -v tor >/dev/null 2>&1; then
    echo "ERROR: the 'tor' binary is not installed, so the panel would be useless."
    echo "       Fix the package feed / network, then run this installer again."
    exit 1
fi
echo "1. Creating UCI configuration defaults..."
if [ ! -f /etc/config/tor_ui ]; then
    cat << 'EOF' > /etc/config/tor_ui
config tor_ui 'main'
	option enabled '0'
	option full_tunnel '1'
	option route_dns '1'
	option custom_exit '0'
	option strict_exit '0'
	option use_bridge '0'
	option bridge_mode 'auto'
	option socks_port '9050'
	option trans_port '9040'
	option dns_port '9053'
	option localhost_proxy '0'
	option conn_mode 'race'
	option race_racers 'vanilla obfs4 webtunnel'
	option race_timeout '120'
	option memory_enabled '1'
	option persist_cache '1'
	option persist_dir '/.tor'
	option conflux_enabled 'auto'
	option conflux_ux 'default'
	option conflux_num_sets '0'
	option conflux_num_linked '0'
	option conflux_num_legs '0'
	option conflux_set_selection '0'
	option conflux_rtt_max '0'
	option conflux_rtt_pct '0'
EOF
else
    echo "   -> /etc/config/tor_ui already exists, keeping current values."
    uci -q get tor_ui.main.bridge_mode >/dev/null || uci set tor_ui.main.bridge_mode='auto'
    uci -q get tor_ui.main.socks_port >/dev/null || uci set tor_ui.main.socks_port='9050'
    uci -q get tor_ui.main.trans_port >/dev/null || uci set tor_ui.main.trans_port='9040'
    uci -q get tor_ui.main.dns_port >/dev/null || uci set tor_ui.main.dns_port='9053'
    uci -q get tor_ui.main.localhost_proxy    >/dev/null || uci set tor_ui.main.localhost_proxy='0'
    uci -q get tor_ui.main.route_dns >/dev/null || uci set tor_ui.main.route_dns='1'
    uci -q get tor_ui.main.full_tunnel >/dev/null || uci set tor_ui.main.full_tunnel='1'
    uci -q get tor_ui.main.strict_exit >/dev/null || uci set tor_ui.main.strict_exit='0'
    uci set tor_ui.main.conn_mode='race'
    uci -q get tor_ui.main.race_racers >/dev/null || uci set tor_ui.main.race_racers='vanilla obfs4 webtunnel'
    uci -q get tor_ui.main.race_timeout >/dev/null || uci set tor_ui.main.race_timeout='120'
    uci -q get tor_ui.main.memory_enabled >/dev/null || uci set tor_ui.main.memory_enabled='1'
    uci -q get tor_ui.main.persist_cache >/dev/null || uci set tor_ui.main.persist_cache='1'
    uci -q get tor_ui.main.persist_dir >/dev/null || uci set tor_ui.main.persist_dir='/.tor'
    uci set tor_ui.main.conflux_enabled='auto'
    uci set tor_ui.main.conflux_ux='default'
    uci set tor_ui.main.conflux_num_sets='0'
    uci set tor_ui.main.conflux_num_linked='0'
    uci set tor_ui.main.conflux_num_legs='0'
    uci set tor_ui.main.conflux_set_selection='0'
    uci set tor_ui.main.conflux_rtt_max='0'
    uci set tor_ui.main.conflux_rtt_pct='0'
    uci commit tor_ui
fi
# Update URL is fixed inside maint.sh now; drop the old user-editable option
uci -q delete tor_ui.main.update_url 2>/dev/null || true
uci commit tor_ui
mkdir -p /etc/tor/tor_ui-state/bridges 2>/dev/null && chmod 700 /etc/tor/tor_ui-state 2>/dev/null || true
echo "2. Creating LuCI UI view script..."
mkdir -p /www/luci-static/resources/view/tor
cat << 'EOF' > /www/luci-static/resources/view/tor/settings.js
'use strict';
'require view';
'require form';
'require fs';
'require poll';
'require ui';
return view.extend({
    render: function () {
        let m, s, o;
        function _sleepMs(ms) {
            return new Promise(function (resolve) { setTimeout(resolve, ms); });
        }
        var _jobId = '';
        function runInitDetached(action) {
            _jobId = Date.now().toString(36) + Math.floor(Math.random() * 1679616).toString(36);
            var d = '/tmp/tor_ui/jobs/' + _jobId;
            return fs.exec('/bin/sh', ['-c',
                'find /tmp/tor_ui/jobs -mindepth 1 -maxdepth 1 -type d -mmin +10 -exec rm -rf {} + 2>/dev/null; ' +
                'mkdir -p ' + d + '; ' +
                '( TOR_UI_MANUAL=1 /etc/init.d/tor_ui ' + action + ' >' + d + '/out 2>&1; ' +
                'echo $? >' + d + '/rc ) </dev/null >/dev/null 2>&1 & ' +
                'echo launched'
            ]);
        }
        function waitInitJob(maxMs) {
            var t0 = Date.now();
            var jd = '/tmp/tor_ui/jobs/' + _jobId;
            function tick() {
                return fs.exec('/bin/sh', ['-c',
                    'if [ -f ' + jd + '/rc ]; then cat ' + jd + '/rc; echo "@@OUT@@"; ' +
                    'tail -n 5 ' + jd + '/out 2>/dev/null; else echo "@@PENDING@@"; fi'
                ]).then(function (res) {
                    var out = ((res && res.stdout) || '');
                    if (out.indexOf('@@PENDING@@') === -1 && out.trim() !== '') {
                        var parts = out.split('@@OUT@@');
                        var rc = parseInt((parts[0] || '').trim(), 10);
                        return { code: isNaN(rc) ? 1 : rc, out: (parts[1] || '').trim() };
                    }
                    if (Date.now() - t0 > maxMs) return { code: null, out: '' };
                    return _sleepMs(1500).then(tick);
                }).catch(function () {
                    if (Date.now() - t0 > maxMs) return { code: null, out: '' };
                    return _sleepMs(2000).then(tick);
                });
            }
            return _sleepMs(500).then(tick);
        }
        m = new form.Map('tor_ui', '', '');
        function syncAutostart() {
            return fs.exec('/bin/sh', ['-c',
                '( if [ "$(uci -q get tor_ui.main.enabled)" = "1" ]; then ' +
                '  /etc/init.d/tor_ui enable; ' +
                'else ' +
                '  /etc/init.d/tor_ui disable; ' +
                'fi; ' +
                '/etc/init.d/tor_ui ks_sync ) </dev/null >/dev/null 2>&1 & ' +
                'echo ok'
            ]);
        }
        var _mapSave = m.save.bind(m);
        m.save = function (cb_func, silent) {
            return _mapSave(cb_func, silent).then(function (rv) {
                return syncAutostart().then(function () { return rv; });
            });
        };
        m.apply = function (cb_func) {
            return m.save(cb_func, true).then(function () {
                return runInitDetached('apply').then(function () { return waitInitJob(120000); });
            }).then(function (res) {
                if (res && typeof res.code === 'number' && res.code !== 0) {
                    throw new Error(res.out || ('exit ' + res.code));
                }
                let msg = ((res && res.out) || '').trim();
                ui.addNotification(null, E('p', (res && res.code === 0 && msg) ? msg : _('Settings saved and applied.')), 'info');
            }).catch(function (e) {
                if (/time(d)?\s*out/i.test(String(e))) {
                    ui.addNotification(null, E('p', _('Settings saved; applying to the running tunnel is still in progress.')), 'info');
                    return;
                }
                ui.addNotification(null, E('p', _('Settings saved, but applying to the running tunnel failed: ') + e), 'error');
            });
        };
        s = m.section(form.TypedSection, 'tor_ui', '');
        s.anonymous = true;
        o = s.option(form.Flag, 'enabled', _('Auto Connect (Enable)'),
            _('Start Tor on router boot. Also controls the Kill Switch: ON = LAN internet is blocked unless it goes through Tor (also while Tor is stopped, until Start or Unblock Internet). OFF + Apply = Tor is stopped and every rule it added (firewall, Kill Switch, DNS routes, IPv6) is removed.'));
        o.rmempty = false;
        o = s.option(form.Flag, 'custom_exit', _('Custom Exit Node'),
            _('Force exits from chosen countries.'));
        o.rmempty = false;
        o = s.option(form.Value, 'exit_node', _('Target Region(s)'));
        o.depends('custom_exit', '1');
        o.rmempty = true;
        o.cfgvalue = function (section_id) {
            var v = this.map.data.get(this.map.config, section_id, this.option);
            return L.toArray(v).join(' ');
        };
        o.formvalue = function (section_id) {
            var w = this.getUIElement(section_id);
            if (w && typeof w.getValue === 'function') {
                var v = w.getValue();
                if (v != null) return v;
            }
            if (_torExitNodePicker &&
                typeof _torExitNodePicker.getValue === 'function') {
                return _torExitNodePicker.getValue();
            }
            var q = document.querySelector('[data-tor-field="exit_node"]');
            if (q && typeof q.getValue === 'function') {
                return q.getValue();
            }
            var cur = this.map.data.get(this.map.config, section_id, this.option);
            return L.toArray(cur).join(' ');
        };
        o.write = function (section_id, formvalue) {
            var arr = String(formvalue == null ? '' : formvalue)
                        .split(/\s+/).filter(Boolean);
            return this.map.data.set(this.map.config, section_id, this.option, arr);
        };
        o.renderWidget = function (section_id, option_index, cfgvalue) {
            var codes = (cfgvalue == null ? '' : String(cfgvalue))
                            .split(/\s+/).filter(Boolean);
            var w = buildNordCountryPicker(codes);
            w.id = this.cbid(section_id);
            w.setAttribute('data-tor-field', 'exit_node');
            _torExitNodePicker = w;
            return w;
        };
        const countries = [
            ['AR', 'Argentina'], ['AM', 'Armenia'], ['AU', 'Australia'], ['AT', 'Austria'],
            ['BE', 'Belgium'], ['BR', 'Brazil'], ['BG', 'Bulgaria'], ['CA', 'Canada'],
            ['CL', 'Chile'], ['CO', 'Colombia'], ['CR', 'Costa Rica'], ['HR', 'Croatia'],
            ['CY', 'Cyprus'], ['CZ', 'Czech Republic'], ['DK', 'Denmark'], ['DO', 'Dominican Republic'],
            ['EC', 'Ecuador'], ['EG', 'Egypt'], ['EE', 'Estonia'], ['FI', 'Finland'],
            ['FR', 'France'], ['GE', 'Georgia'], ['DE', 'Germany'], ['GR', 'Greece'],
            ['HK', 'Hong Kong'], ['HU', 'Hungary'], ['IS', 'Iceland'], ['IN', 'India'],
            ['ID', 'Indonesia'], ['IE', 'Ireland'], ['IL', 'Israel'], ['IT', 'Italy'],
            ['JP', 'Japan'], ['KZ', 'Kazakhstan'], ['KE', 'Kenya'], ['LV', 'Latvia'],
            ['LT', 'Lithuania'], ['LU', 'Luxembourg'], ['MY', 'Malaysia'], ['MX', 'Mexico'],
            ['MD', 'Moldova'], ['NL', 'Netherlands'], ['NZ', 'New Zealand'], ['NG', 'Nigeria'],
            ['NO', 'Norway'], ['PK', 'Pakistan'], ['PA', 'Panama'], ['PE', 'Peru'],
            ['PH', 'Philippines'], ['PL', 'Poland'], ['PT', 'Portugal'], ['RO', 'Romania'],
            ['RU', 'Russia'], ['RS', 'Serbia'], ['SG', 'Singapore'], ['SK', 'Slovakia'],
            ['SI', 'Slovenia'], ['ZA', 'South Africa'], ['KR', 'South Korea'], ['ES', 'Spain'],
            ['SE', 'Sweden'], ['CH', 'Switzerland'], ['TW', 'Taiwan'], ['TH', 'Thailand'],
            ['TR', 'Turkey'], ['UA', 'Ukraine'], ['AE', 'United Arab Emirates'], ['GB', 'United Kingdom'],
            ['US', 'United States'], ['VN', 'Vietnam']
        ];
        if (!document.getElementById('noto-emoji-font')) {
            var link = document.createElement('link');
            link.id = 'noto-emoji-font';
            link.rel = 'stylesheet';
            link.href = 'https://fonts.googleapis.com/css2?family=Noto+Color+Emoji&display=swap';
            document.head.appendChild(link);
        }
        var countryNames = {};
        countries.forEach(function (c) { countryNames[c[0]] = c[1]; });
        function countryFlag(cc) {
            if (!cc || cc.length !== 2) return '';
            try {
                return String.fromCodePoint(
                    127397 + cc.toUpperCase().charCodeAt(0),
                    127397 + cc.toUpperCase().charCodeAt(1)
                ) + ' ';
            } catch (e) { return ''; }
        }
        function ccFlagImg(code) {
            code = (code || '').toUpperCase();
            var img = document.createElement('img');
            img.className = 'tor-cc-flag-img';
            img.alt = code;
            img.loading = 'lazy';
            img.src = 'https://flagcdn.com/w40/' + code.toLowerCase() + '.png';
            img.onerror = function () {
                if (!img.parentNode) return;
                var em = countryFlag(code).trim();
                if (em) {
                    var s = document.createElement('span');
                    s.textContent = em;
                    img.parentNode.replaceChild(s, img);
                } else { img.parentNode.removeChild(img); }
            };
            return img;
        }
        var _torExitNodePicker = null;
        function buildNordCountryPicker(initialCodes) {
            var selected = (initialCodes || []).filter(Boolean);
            var wrap = document.createElement('div');
            wrap.className = 'tor-cc-picker';
            wrap.value = selected.join(' ');
            var chips = document.createElement('div');
            chips.className = 'tor-cc-chips';
            chips.setAttribute('tabindex', '0');
            var arrow = document.createElement('span');
            arrow.className = 'tor-cc-arrow';
            arrow.textContent = '\u25be';
            var panel = document.createElement('div');
            panel.className = 'tor-cc-panel';
            panel.style.display = 'none';
            var search = document.createElement('input');
            search.type = 'search';
            search.className = 'tor-cc-search';
            search.placeholder = _('Search country…');
            search.autocomplete = 'off';
            var list = document.createElement('div');
            list.className = 'tor-cc-list';
            panel.appendChild(search);
            panel.appendChild(list);
            wrap.appendChild(chips);
            wrap.appendChild(arrow);
            wrap.appendChild(panel);
            function setValue() {
                wrap.value = selected.join(' ');
                wrap.dispatchEvent(new Event('change', { bubbles: true }));
            }
            function getRow(code) {
                for (var i = 0; i < countries.length; i++)
                    if (countries[i][0] === code) return countries[i];
                return null;
            }
            function renderChips() {
                while (chips.firstChild) chips.removeChild(chips.firstChild);
                if (!selected.length) {
                    var ph = document.createElement('span');
                    ph.className = 'tor-cc-placeholder';
                    ph.textContent = '\ud83c\udf10 ' + _('Automatic (recommended)');
                    chips.appendChild(ph);
                    return;
                }
                selected.forEach(function (code) {
                    var row = getRow(code);
                    var chip = document.createElement('span');
                    chip.className = 'tor-cc-chip';
                    chip.appendChild(ccFlagImg(code));
                    var cd = document.createElement('span');
                    cd.className = 'tor-cc-code';
                    cd.textContent = code;
                    chip.appendChild(cd);
                    var rm = document.createElement('button');
                    rm.type = 'button';
                    rm.className = 'tor-cc-remove';
                    rm.textContent = '\u00d7';
                    rm.title = _('Remove') + ' ' + (row ? row[1] : code);
                    rm.addEventListener('click', function (ev) {
                        ev.stopPropagation();
                        selected = selected.filter(function (x) { return x !== code; });
                        renderChips(); renderList(search.value); setValue();
                    });
                    chip.appendChild(rm);
                    chips.appendChild(chip);
                });
            }
            function renderList(filter) {
                while (list.firstChild) list.removeChild(list.firstChild);
                filter = (filter || '').toLowerCase().trim();
                var shown = countries.filter(function (c) {
                    return !filter ||
                        c[1].toLowerCase().indexOf(filter) >= 0 ||
                        c[0].toLowerCase().indexOf(filter) >= 0;
                });
                if (!shown.length) {
                    var e = document.createElement('div');
                    e.className = 'tor-cc-empty';
                    e.textContent = _('No match.');
                    list.appendChild(e);
                    return;
                }
                shown.forEach(function (c) {
                    var isSel = selected.indexOf(c[0]) >= 0;
                    var row = document.createElement('div');
                    row.className = 'tor-cc-item' + (isSel ? ' tor-cc-sel' : '');
                    row.appendChild(ccFlagImg(c[0]));
                    var nm = document.createElement('span');
                    nm.className = 'tor-cc-name';
                    nm.textContent = c[1];
                    row.appendChild(nm);
                    var rc = document.createElement('span');
                    rc.className = 'tor-cc-rowcode';
                    rc.textContent = c[0];
                    row.appendChild(rc);
                    if (isSel) {
                        var ck = document.createElement('span');
                        ck.className = 'tor-cc-check';
                        ck.textContent = '\u2713';
                        row.appendChild(ck);
                    }
                    row.addEventListener('click', function (ev) {
                        ev.stopPropagation();
                        if (isSel) selected = selected.filter(function (x) { return x !== c[0]; });
                        else selected.push(c[0]);
                        renderChips(); renderList(search.value); setValue();
                    });
                    list.appendChild(row);
                });
            }
            function openPanel() {
                panel.style.display = 'block';
                wrap.classList.add('tor-cc-open');
                search.value = '';
                renderList('');
                setTimeout(function () { search.focus(); }, 0);
            }
            function closePanel() {
                panel.style.display = 'none';
                wrap.classList.remove('tor-cc-open');
            }
            chips.addEventListener('click', function (ev) {
                ev.stopPropagation();
                if (panel.style.display === 'none') openPanel(); else closePanel();
            });
            search.addEventListener('input', function () { renderList(search.value); });
            search.addEventListener('keydown', function (ev) {
                ev.stopPropagation();
                if (ev.key === 'Escape') { ev.preventDefault(); closePanel(); chips.focus(); }
                else if (ev.key === 'Enter') {
                    ev.preventDefault();
                    var first = list.querySelector('.tor-cc-item');
                    if (first) first.click();
                }
            });
            search.addEventListener('click', function (ev) { ev.stopPropagation(); });
            document.addEventListener('click', function (ev) {
                if (!wrap.contains(ev.target)) closePanel();
            });
            renderChips();
            wrap.getValue = function () {
                return wrap.value || '';
            };
            wrap.setValue = function (v) {
                wrap.value = String(v == null ? '' : v);
                selected = wrap.value.split(/\s+/).filter(Boolean);
                renderChips();
                renderList('');
            };
            return wrap;
        }
        o = s.option(form.HiddenValue, 'conn_mode');
        o.default = 'race';
        o.rmempty = false;
        o.cfgvalue = function () { return 'race'; };
        o = s.option(form.Flag, 'use_bridge', _('Use Tor Bridges'),
            _('OFF = automatic: the panel races several bridge types and picks the fastest. ON = manual: you choose the Bridge Mode below and may paste your own bridges (empty = built-in bridges of that type).'));
        o.rmempty = false;
        o.default = '0';
        o = s.option(form.ListValue, 'bridge_mode', _('Bridge Mode'));
        o.depends('use_bridge', '1');
        o.retain = true;
        o.value('auto', _('Auto (fallback profile)'));
        o.value('obfs4', 'obfs4');
        o.value('webtunnel', 'webtunnel');
        o.value('snowflake', 'snowflake');
        o.value('meek', 'meek_lite (meek-azure)');
        o.value('vanilla', 'vanilla (plain IP:PORT bridges)');
        o.renderWidget = (function (_orig) {
            return function () {
                let node = _orig.apply(this, arguments);
                if (node) {
                    node.setAttribute('data-tor-field', 'bridge_mode');
                    const select = node.querySelector('select') || node;
                    select.addEventListener('change', function (ev) {
                        setBridgeLinesPlaceholder(ev.target.value);
                    });
                    requestAnimationFrame(function () {
                        setBridgeLinesPlaceholder(select.value);
                    });
                }
                return node;
            };
        })(o.renderWidget.bind(o));
        var PLACEHOLDERS = {
            'auto':       'obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=<0/1/2>',
            'obfs4':      'obfs4 <IP>:<PORT> <FINGERPRINT> cert=<CERT> iat-mode=<0/1/2>',
            'webtunnel':  'webtunnel <IP>:<PORT> <FINGERPRINT> url=https://<DOMAIN>/<PATH> ver=<VERSION>',
            'snowflake':  'snowflake <IP>:<PORT> <FINGERPRINT> fingerprint=<FINGERPRINT> ice=<STUN_SERVER> utls-imitate=<CLIENT_HELLO>',
            'meek':       'meek_lite <IP>:<PORT> <FINGERPRINT> url=https://<DOMAIN>/ front=<FRONT_DOMAIN>',
            'vanilla':    '<IP>:<PORT> <FINGERPRINT>',
        };
        function setBridgeLinesPlaceholder(mode) {
            const ta = document.querySelector('[data-tor-field="bridge_lines"] textarea, textarea[data-tor-field="bridge_lines"]');
            if (ta) ta.setAttribute('placeholder', PLACEHOLDERS[mode] || PLACEHOLDERS.auto);
            const hint = document.querySelector('[data-tor-field="bridge_lines"] .tor-bridge-order, .tor-bridge-order');
            if (hint) {
                if (mode === 'auto') {
                    hint.textContent = _('Fallback order: obfs4 -> snowflake -> meek_lite -> webtunnel. Tor tries each bridge in turn.');
                    hint.style.display = '';
                } else {
                    hint.textContent = '';
                    hint.style.display = 'none';
                }
            }
        }
        o = s.option(form.TextValue, 'bridge_lines', _('Bridge Lines'),
            _('One bridge per line. Empty = the built-in bridges of the selected type; pasted lines override them. (Vanilla mode has no built-in bridges: paste your own.)'));
        o.depends('use_bridge', '1');
        o.depends('conn_mode', 'vanilla');
        o.depends('conn_mode', 'race');
        o.retain = true;
        o.rows = 4;
        o.monospace = true;
        o.placeholder = PLACEHOLDERS.obfs4;
        o.renderWidget = (function (_orig) {
            return function () {
                let node = _orig.apply(this, arguments);
                if (node) {
                    node.setAttribute('data-tor-field', 'bridge_lines');
                    var hint = document.createElement('div');
                    hint.className = 'tor-bridge-order';
                    hint.style.cssText = 'margin-top:6px;font-size:11px;color:#7ee787;line-height:1.4;';
                    var wrap = node.closest ? (node.closest('.cbi-value-field') || node.parentNode) : node.parentNode;
                    if (wrap) wrap.appendChild(hint);
                    requestAnimationFrame(function () {
                        var s = document.querySelector('[data-tor-field="bridge_mode"] select, select[data-tor-field="bridge_mode"]');
                        if (s) setBridgeLinesPlaceholder(s.value);
                    });
                }
                return node;
            };
        })(o.renderWidget.bind(o));
        o = s.option(form.Flag, 'strict_exit', _('Strict Exit'),
            _('Never exit outside the chosen countries (Tor keeps retrying instead).'));
        o.depends('custom_exit', '1');
        o.rmempty = false;
        o.default = '0';
        o = s.option(form.Flag, 'localhost_proxy', _('Router Traffic via Tor'),
            _('Also route the router itself (curl, opkg) through Tor.'));
        o.rmempty = false;
        o.default = '0';
        function setCfxBadge(v) {
            var b = document.getElementById('tor-badge-cfx');
            if (!b) return;
            b.classList.remove('on', 'auto');
            if (v === '1') { b.textContent = _('ON'); b.classList.add('on'); }
            else if (v === '0') { b.textContent = _('OFF'); }
            else { b.textContent = _('AUTO'); b.classList.add('auto'); }
        }
        function accHeader(key, title, sub, subId, badgeId, badgeInit) {
            var kids = [
                E('span', { 'class': 'tor-acc-arrow' }, '\u25B6'),
                E('span', { 'class': 'tor-acc-title' }, title),
                E('span', { 'class': 'tor-acc-sub', 'id': subId }, sub)
            ];
            if (badgeId) kids.push(E('span', { 'class': 'tor-acc-badge', 'id': badgeId }, badgeInit || '\u2014'));
            return E('div', { 'class': 'tor-acc', 'data-key': key, 'data-name': 'acc_' + key }, [
                E('div', {
                    'class': 'tor-acc-hdr',
                    'click': function (ev) {
                        var dash = ev.currentTarget.closest('.tor-dash');
                        if (!dash) return;
                        var open = dash.classList.toggle('tor-' + key + '-open');
                        try { localStorage.setItem('tor-acc-' + key, open ? 'open' : 'closed'); } catch (e) {}
                        if (open && key === 'maint' && typeof maintAutoCheck === 'function') maintAutoCheck();
                    }
                }, kids)
            ]);
        }
        o = s.option(form.DummyValue, 'maint_hdr', '');
        o.rawhtml = true;
        o.render = function () {
            return accHeader('maint', _('Update / Uninstall'),
                             _('install from GitHub / remove Tor VPN'), 'tor-maint-sub', null, null);
        };
        o = s.option(form.DummyValue, 'maint_body', '');
        o.rawhtml = true;
        o.render = function () {
            return E('div', { 'class': 'tor-maint-body', 'data-name': 'maint_body' }, [
                E('div', { 'class': 'tor-maint-row' }, [
                    E('div', { 'class': 'tor-maint-info' }, [
                        E('strong', {}, _('Update')),
                        E('small', {}, _('Downloads the installer from GitHub, compares its build date with the installed one and runs it only if it is newer. Settings are kept; the panel is replaced and Tor is not restarted unless the Tor package itself was upgraded. Uses the Tor tunnel automatically if GitHub is blocked.')),
                        E('small', { 'id': 'tor-ver-info' }, ''),
                        E('small', { 'id': 'tor-ver-check' }, '')
                    ]),
                    E('button', { 'class': 'tor-btn tor-btn-refresh', 'id': 'tor-maint-check', 'type': 'button',
                        'click': function (ev) { ev.preventDefault(); maintCheck(); } }, _('Check for updates')),
                    E('button', { 'class': 'tor-btn tor-btn-check', 'id': 'tor-maint-update', 'type': 'button',
                        'click': function (ev) { ev.preventDefault(); maintConfirm('update'); } }, _('Update now'))
                ]),
                E('div', { 'class': 'tor-maint-row' }, [
                    E('div', { 'class': 'tor-maint-info' }, [
                        E('strong', {}, _('Uninstall')),
                        E('small', {}, _('Stops Tor, removes the firewall rules, kill switch and DNS changes, and deletes the panel. By default your settings and Memory record are kept.')),
                        E('label', { 'class': 'tor-maint-check' }, [
                            E('input', { 'type': 'checkbox', 'id': 'tor-maint-purge' }),
                            _('Also delete settings, state and Memory record (full removal)')
                        ])
                    ]),
                    E('button', { 'class': 'tor-btn tor-btn-stop', 'id': 'tor-maint-uninstall', 'type': 'button',
                        'click': function (ev) { ev.preventDefault(); maintConfirm('uninstall'); } }, _('Uninstall'))
                ]),
                E('div', { 'class': 'tor-maint-row' }, [
                    E('div', { 'class': 'tor-maint-info' }, [
                        E('strong', {}, _('Tor data folder (cache)')),
                        E('small', {}, _('Deletes only the downloaded network cache (consensus, descriptors, microdescriptors, certificates). Identity keys, pluggable-transport state and the Tor state file are kept. If Tor is running it restarts and re-downloads the cache (a few minutes).')),
                        E('small', { 'id': 'tor-cache-info' }, '')
                    ]),
                    E('button', { 'class': 'tor-btn tor-btn-refresh', 'id': 'tor-maint-cache', 'type': 'button',
                        'click': function (ev) { ev.preventDefault(); cacheConfirm(); } }, _('Clear cache'))
                ]),
                E('div', { 'id': 'tor-maint-status' }, ''),
                E('pre', { 'id': 'tor-maint-log' }, '')
            ]);
        };
        var RPC_SH = '/usr/libexec/tor_ui/rpc.sh';
        function cacheRefresh() {
            L.resolveDefault(fs.exec('/bin/sh', [RPC_SH, 'cache-info']), null).then(function (r) {
                var el = document.getElementById('tor-cache-info');
                if (!el) return;
                var out = (r && r.stdout) ? r.stdout.trim() : '';
                if (!out) { el.textContent = _('Cache is empty.'); return; }
                var kb = 0, dirs = [], snap = '';
                out.split('\n').forEach(function (ln) {
                    var p = ln.split(' ');
                    if (p[0] === 'saved-snapshot') { snap = p.slice(1).join(' '); return; }
                    if (p[1] === 'dir') dirs.push(p[0]);
                    else if (/^cached-/.test(p[0])) kb += parseInt(p[1], 10) || 0;
                });
                el.textContent = _('Cache size') + ': ' + (kb >= 1024 ? (kb / 1024).toFixed(1) + ' MB' : kb + ' KB') +
                    (dirs.length ? '  |  ' + dirs.join(' ') : '') +
                    (snap ? '  |  ' + _('Saved snapshot') + ': ' + snap : '  |  ' + _('No saved snapshot yet'));
            });
        }
        function cacheConfirm() {
            ui.showModal(_('Clear Tor cache'), [
                E('p', {}, _('The downloaded network cache will be deleted. Keys, pluggable-transport state and the state file are kept. If Tor is running it will restart and re-download the cache; the connection is interrupted for a few minutes.')),
                E('div', { 'class': 'right' }, [
                    E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
                    E('button', { 'class': 'cbi-button cbi-button-negative', 'click': function () { ui.hideModal(); cacheClear(); } }, _('Clear cache'))
                ])
            ]);
        }
        function cacheClear() {
            maintButtons(true);
            maintSay(_('Clearing cache\u2026'));
            L.resolveDefault(fs.exec('/bin/sh', [RPC_SH, 'clear-cache']), null).then(function (r) {
                maintButtons(false);
                var out = (r && r.stdout) ? r.stdout.trim().split('\n')[0] : '';
                maintSay(out || _('Could not clear the cache.'), out ? '#4fd88a' : '#ff8179');
                cacheRefresh();
            });
        }
        setTimeout(cacheRefresh, 600);
        var MAINT = '/usr/libexec/tor_ui/maint.sh';
        var maintTimer = null, maintFails = 0, maintAction = '';
        function maintEl(id) { return document.getElementById(id); }
        function maintSay(msg, color) {
            var el = maintEl('tor-maint-status');
            if (el) { el.textContent = msg; el.style.color = color || '#92a0b0'; }
        }
        function maintButtons(disabled) {
            ['tor-maint-update', 'tor-maint-check', 'tor-maint-uninstall', 'tor-maint-purge', 'tor-maint-cache'].forEach(function (id) {
                var b = maintEl(id); if (b) b.disabled = disabled;
            });
        }
        function maintStopPoll() { if (maintTimer) { clearInterval(maintTimer); maintTimer = null; } }
        var maintLastStatus = '', maintAutoDone = false;
        function maintAutoCheck() { if (maintAutoDone) return; maintAutoDone = true; maintCheck(); }
        function maintJson(r) {
            try { return JSON.parse(((r && r.stdout) || '').trim()); } catch (e) { return null; }
        }
        function maintVersionRefresh() {
            L.resolveDefault(fs.exec('/bin/sh', [MAINT, 'version']), null).then(function (r) {
                var v = maintJson(r), el = maintEl('tor-ver-info');
                if (!el) return;
                el.textContent = _('Installed build') + ': ' + ((v && v.date) ? v.date : _('unknown (older build)')) +
                    ((v && v.version) ? '  |  ' + v.version : '');
            });
        }
        function maintCheck() {
            var el = maintEl('tor-ver-check');
            maintButtons(true);
            maintSay(_('Checking for updates\u2026'));
            if (el) el.textContent = '';
            L.resolveDefault(fs.exec('/bin/sh', [MAINT, 'check']), null).then(function (r) {
                maintButtons(false);
                var v = maintJson(r), msg, col = '#92a0b0';
                maintLastStatus = (v && v.status) || '';
                if (!v) {
                    msg = _('Could not check (helper not available).'); col = '#e2645c';
                } else if (v.status === 'error') {
                    msg = ({
                        'no-curl': _('curl is not installed on the router.'),
                        'download-failed': _('GitHub is unreachable. Connect Tor first, then try again.')
                    })[v.error] || _('Could not check for updates.');
                    col = '#e2645c';
                } else if (v.status === 'newer') {
                    msg = _('New version available') + ': ' + v.remote + ((v.installed) ? '  (' + _('installed') + ': ' + v.installed + ')' : '') +
                        '. ' + _('Press "Update now".');
                    col = '#e0b34d';
                } else if (v.status === 'same') {
                    msg = _('You are up to date') + ' (' + v.installed + ').'; col = '#4fd88a';
                } else if (v.status === 'older') {
                    msg = _('The installed build (%s) is newer than the one online (%s).').format(v.installed, v.remote);
                } else {
                    msg = _('The online installer has no build date, so the versions cannot be compared.'); col = '#e0b34d';
                }
                maintSay('', col);
                if (el) { el.textContent = msg; el.style.color = col; }
            });
        }
        setTimeout(maintVersionRefresh, 700);
        setTimeout(function () { var d = document.querySelector('.tor-dash'); if (d && d.classList.contains('tor-maint-open')) maintAutoCheck(); }, 1500);
        function maintConfirm(action) {
            var purge = !!(maintEl('tor-maint-purge') || {}).checked;
            var title, msg, label, cls;
            if (action === 'update') {
                title = _('Update Tor VPN panel');
                msg = (maintLastStatus === 'same' || maintLastStatus === 'older')
                    ? _('No newer build was found online. Reinstall the current build anyway? The LuCI services restart, so this page may need a reload.')
                    : _('The installer is downloaded from GitHub only if its build date is newer than the installed one. The LuCI services restart, so this page may need a reload.');
                label = _('Update'); cls = 'cbi-button cbi-button-positive';
            } else {
                title = _('Uninstall Tor VPN panel');
                msg = purge
                    ? _('FULL REMOVAL: the panel, its firewall rules, settings, state and Memory record will be deleted. The LAN is released from the kill switch. This cannot be undone.')
                    : _('Tor will be stopped and the panel removed. Settings and the Memory record are kept for a later reinstall. The kill switch rules are removed too.');
                label = _('Uninstall'); cls = 'cbi-button cbi-button-negative';
            }
            ui.showModal(title, [
                E('p', {}, msg),
                E('div', { 'class': 'right' }, [
                    E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Cancel')), ' ',
                    E('button', { 'class': cls, 'click': function () { ui.hideModal(); maintStart(action, purge, (action === 'update' && (maintLastStatus === 'same' || maintLastStatus === 'older'))); } }, label)
                ])
            ]);
        }
        function maintStart(action, purge, force) {
            maintButtons(true);
            maintSay(_('Starting\u2026'));
            L.resolveDefault(fs.exec('/bin/sh', [MAINT, 'start', action, purge ? '1' : '0', force ? '1' : '0']), null).then(function (r) {
                var out = (r && r.stdout) ? r.stdout.trim() : '';
                if (out !== 'started') {
                    maintButtons(false);
                    var why = {
                        'busy': _('Another update/uninstall is already running.'),
                        'no-curl': _('curl is not installed on the router.')
                    }[out] || _('Could not start (helper not available).');
                    maintSay(why, '#e2645c');
                    return;
                }
                maintAction = action; maintFails = 0;
                var box = maintEl('tor-maint-log');
                if (box) { box.style.display = 'block'; box.textContent = ''; }
                maintSay(action === 'update' ? _('Updating\u2026 please wait (up to a few minutes).')
                                             : _('Uninstalling\u2026 this page stops working when the removal finishes.'), '#e0b34d');
                maintStopPoll();
                maintTimer = setInterval(maintPoll, 2000);
            });
        }
        function maintPoll() {
            L.resolveDefault(fs.exec('/bin/sh', [MAINT, 'status']), null).then(function (r) {
                var st = null;
                try { st = (r && r.stdout) ? JSON.parse(r.stdout.trim()) : null; } catch (e) { st = null; }
                if (!st) {
                    maintFails++;
                    if (maintFails >= 3) {
                        maintStopPoll();
                        if (maintAction === 'uninstall') {
                            maintSay(_('The helper is gone: the removal has finished. Reload the page (Ctrl+F5); the VPN menu entry disappears.'), '#4fd88a');
                        } else {
                            maintSay(_('Lost contact with the router (services are restarting). Wait a few seconds and reload the page (Ctrl+F5).'), '#e0b34d');
                            maintButtons(false);
                        }
                    }
                    return;
                }
                maintFails = 0;
                L.resolveDefault(fs.exec('/bin/sh', [MAINT, 'log']), null).then(function (l) {
                    var box = maintEl('tor-maint-log');
                    if (box && l && typeof l.stdout === 'string') { box.textContent = l.stdout; box.scrollTop = box.scrollHeight; }
                });
                if (st.state === 'uptodate') {
                    maintStopPoll();
                    maintSay(_('Already up to date - the online build is not newer. Nothing was changed.'), '#4fd88a');
                    maintButtons(false); maintVersionRefresh();
                } else if (st.state === 'done') {
                    maintStopPoll();
                    maintSay(maintAction === 'uninstall' ? _('Uninstall finished. Reload the page (Ctrl+F5).')
                                                         : _('Update finished. Reload the page (Ctrl+F5) to load the new interface.'), '#4fd88a');
                    if (maintAction !== 'uninstall') { maintButtons(false); maintVersionRefresh(); }
                } else if (st.state === 'failed') {
                    maintStopPoll();
                    maintSay(_('Failed (exit code %d). See the log below; nothing was changed if the download failed.').format(st.rc), '#e2645c');
                    maintButtons(false);
                }
            });
        }
        const TOR_LOGO_SVG = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 9.3 48 29.7" preserveAspectRatio="xMidYMid meet">
  <path fill="#68b044" d="m26.99565 11.92245 -0.749 2.996c1.0611 -2.12215 2.77755 -3.7138 4.7437 -5.11815 -1.4356 1.65405 -2.74635 3.3081 -3.52655 4.99335 1.34195 -1.90375 3.15205 -2.9336 5.18055 -3.6514 -2.7151 2.40305 -4.8685 5.02455 -6.4913 7.61485l-1.31075 -0.56175c0.21845 -2.09095 0.99865 -4.21315 2.15335 -6.2729Z" stroke-width="0.5"></path>
  <path fill="#f5f8de" d="m23.53165 17.6333 2.46545 1.0299c0 0.62415 -0.0624 2.55905 0.3433 3.1208 4.1195 5.3054 3.4329 15.97865 -0.84265 16.22835 -6.4913 0 -8.988 -4.4004 -8.988 -8.45745 0 -3.7138 4.4316 -6.14805 7.0843 -8.33265 0.7178 -0.59295 0.59295 -1.9037 -0.0624 -3.58895Z" stroke-width="0.5"></path>
  <path fill="#7e4798" d="m25.9973 18.6328 0.90505 0.46815c
    -0.0936 0.59295 0.0312 1.9037 0.62415 2.2158 2.6215 1.6228 5.05575 3.3705 6.02325 5.14935 3.4329 6.21045 -2.40305 11.984 -7.49 11.42225 2.7463 -2.02855 3.55775 -6.21045 2.52785 -10.7981 -0.4057 -1.77885 -1.0611 -3.4017 -2.2158 -5.243 -0.4993 -0.8426 -0.31205 -1.9661 -0.3745 -3.21445
    Z" stroke-width="0.5"></path>
  <path fill="#010101" d="M23.3446,17.04055l4.0883,1.68525c-.56175,1.81005,1.0611,3.0896,1.5916,3.3705c1.18595.65535,2.30945,1.34195,3.2145,2.15335c1.71645,1.5604,2.6839,3.745,2.6839,6.0232s-1.0299,4.494-2.80875,5.9608C
    30.4601,37.6068,28.1507,38.1998,25.9349,38.1998c
    -1.37315,0-2.6215-.06245-3.96345-.49935-3.08965-1.0299-5.36785-3.6514-5.5551-6.8034-.18725-2.43425.3745-4.30675,2.2782-6.2729.96745-1.02985,2.9648-2.2158,4.33795-3.15205.6866-.4369,1.4044-1.74765.03125-4.2131
    l.28085-.21845Zm.3121.65535c.15605.21845.53055,1.1547.62415,1.4356.18725.7802.09365,1.5292-.0624,1.8725-.84265,1.5604-2.34065,1.9973-3.4017,2.87115-.20945.17165-.42075.33915-.63065.507l-.1144.09165c
    -1.6557,1.3299-3.19005,2.7347-2.99995,6.45445.1248,2.09095,1.74765,4.68125,4.2131,5.86715.46945.2295.95985.4102,1.46535.55255-.6033-.26565-1.11735-.5958-1.52775-1.0518c
    0-.0312-.15605-.15605-.15605-.15605-.87385-.99865-1.96615-2.6839-2.34065-4.27555-.156-.62415-.28085-1.1235-.0936-1.77885.6532-2.3288,2.00415-3.3912,3.4179-4.3632l.0933-.06395c
    .0156-.01065.03115-.0213.04675-.0319l.14025-.09555c.0468-.0318.0936-.06365.1404-.09545.3433-.21845.78025-.43695,1.1235-.7178.5667-.3696.89995-1.3616,1.1841-2.34645l.02825-.0984c
    .06555-.22955.1288-.45755.19205-.676-.18725.96745-.4057,2.71515-1.24835,3.3705-.3433.2497-.7178.49935-1.0923.749l-.1375.0926c
    -1.48085.9967-2.9103,1.9787-3.57625,4.3702-.15605.53055-.03125,1.0923.0936,1.62285.3745,1.5292,1.4356,3.15205,2.2782,4.1195c0,.01285.02645.04155.0576.0731l.0273.0274c
    .0366.03665.07115.07205.07115.08675.60355.71325.84535.99245,2.67575,1.45235-.4484-.18275-.8779-.39985-1.17775-.60975-1.498-1.02985-2.247-2.3094-2.37185-4.2131-.0936-1.498.81145-3.0272,2.5903-3.96345c
    1.21715-.6554,1.59165-1.62285,1.96615-2.80875-.2809,1.37315-.59295,2.18455-1.8413,2.93355-1.498.84265-2.5591,2.5591-2.46545,3.7138.1248,1.4044,1.0923,3.0272,2.2158,3.99465.4531.4028,1.17025.68375,1.87285.85925-.1838-.145-.38535-.35245-.5621-.60955-.2185-.3121-.3745-.749-.53055-1.1547-.15605-.3745-.3121-.81145-.3121-1.18595
    c
    0-.90505.09365-2.02855.749-2.77755.59295-.68655.7802-.7802,1.0299-1.5916-.18725.90505-.3121.96745-.87385,1.77885-.7178.9987-.749,1.99735-.6554,2.6215.06245.40575.2185.78025.3433,1.0923.15605.4057.3433.7802.59295,1.1235.2185.2497.3433.4057.6554.56175.3433-.65535.56175-1.9661.59295-2.6839.0312-.62415.0624-1.34195-.0312-2.05975-.12485-.96745-.4057-1.9037-.4369-2.6527.156.68655.4993,1.65405.68655,2.5903.15605.749.18725,1.46675.12485,2.0285-.0624.6554-.09365,1.18595-.18725,1.7477-.0859.42935-.30305.83245-.65145,1.2575.7898-.50355,1.24755-1.3973,1.46285-2.4122.2809-1.24835.3121-2.43425.3121-3.05845
    c0-.44415-.1561-1.10295-.32945-1.7604l-.0307-.11595c
    -.03605-.1352-.0724-.26975-.108-.40185-.156-.62415-.749-1.24835-.905-1.71645-.2809-.7802-.15605-1.34195-.18725-2.43425.1248.99865.1248,1.8725.4057,2.3406.21845.40575.59295.9675.8114,1.52925.4369,1.02985.6554,2.15335.6866,2.6839.0312.90505-.09365,2.3094-.4057,3.4329-.1161.3772-.2651.7274-.43225,1.03395.3539-.54555.62435-1.18625.7443-1.75175.0203-.09515.04035-.19065.0601-.28635
    l.0294-.14365c.35985-1.77325.6096-3.59115.37865-4.68815-.06245-.28085-.15605-1.2171-.53055-2.2158-.53055-1.4668-1.31075-2.6527-1.4044-2.93355-.2979-.77455-.3683-2.6581-.4012-3.7777l-.0007-.02595c
    .00945.2757.0281.57685.0536.8839l.0083.0971c.0057.06485.01165.1299.0179.1949l.00955.0975c.00165.01625.0033.03245.00495.0487l.01015.09715c
    .09995.938.25185,1.82505.3911,2.1035.0936.2809.93625,1.62285,1.5292,3.0272.4057.90505.53055,1.7789.56175,2.02855.3121,2.6215.0624,3.7138-.62415,6.0544-.08295.28715-.1959.56125-.32715.81585.3948-.50645.6855-1.04965.79525-1.5024.6554-2.9024.90505-6.6474-.0312-9.51855-.49935-1.498-1.68525-2.80875-1.9037-3.7138-.18725-.8426-.18725-1.71645-.12485-2.83995
    l.3121.15605c-.15605.3433-.0624,2.09095.18725,2.7463.3121.87385,1.2171,1.8725,1.77885,3.2769.142.3277.284.81595.40995,1.32295l.02145.08705c.0106.0436.02115.08725.0315.13095l.02055.0873c
    .197.84315.3411,1.65985.3592,1.80465.3121,2.6215.15605,5.08695-.62415,7.17795-.3688.96805-1.14615,1.851-1.716,2.2591c1.51645-.2047,3.60645-.97965,4.868-2.00955c
    1.62285-1.34195,2.4967-3.4017,2.4967-5.49265s-.81145-4.0883-2.40305-5.49265c-.90505-.8114-2.37185-1.8101-3.3081-2.34065s-2.09095-1.9973-1.71645-3.4017L23.6567,17.6959Z" stroke-width="0.5"></path>
  <path fill="#7e4798" d="M1.685915 12.5464H18.5696c0.6242 0 1.18595 0.53055 1.18595 1.1859v4.99335c0 0.65535 -0.56175 1.1859 -1.18595 1.1859H15.1055c-0.7802 0 -1.1235 0.4369 -1.1235 0.93625v16.32195c
    0 0.56175 -0.4369 0.96745 -0.96745 0.96745H7.2722c-0.53055 0 -0.93625 -0.4057 -0.93625 -0.96745v-16.478c0 -0.4993 -0.4681 -0.8114 -0.8114 -0.8114H1.685915C1.03054 19.88035 0.5 19.3498 0.5 18.69445v
    -4.99335c0 -0.62415 0.53054 -1.1547 1.185915 -1.1547Z" stroke-width="0.5"></path>
  <path fill="#7e4798" d="M45.0032 19.1626h1.498c0.56175 0 0.9987 0.4369 0.9987 0.96745v5.33665c0 0.68655 0.0312 0.96745 -0.81145 0.96745 -1.65405 0 -2.40305 0.8738 -2.40305 1.8413v9.0192c0 0.4057 -0.4057 0.7802 -0.8738 0.7802
    H38.04375c-0.4681 0 -0.87385 -0.3433 -0.87385 -0.7802V27.0271c0 -0.18725 0 -0.4369 0.03125 -0.59295 0.28085 -3.80745 3.27685 -6.83465 7.05305 -7.24035 0.09365 0 0.53055 -0.0312 0.749 -0.0312Z" stroke-width="0.5"></path>
</svg>`;
        return m.render().then(function (mapNode) {
            if (!document.getElementById('tor-ui-style')) {
                let style = E('style', { id: 'tor-ui-style' }, `
                    .win-flag{ font-family:"Noto Color Emoji","Segoe UI Emoji",sans-serif !important; }
                    .tor-status-flag{ display:inline-block !important; font-family:"Noto Color Emoji","Segoe UI Emoji","Apple Color Emoji",sans-serif !important; font-size:1.05em !important; line-height:1 !important; vertical-align:-.08em !important; }
                    .tor-dash{ --panel:#1B2227; --panel-2:#1a1d22; --card-border:#343b46;
                        --border:rgba(255,255,255,0.08); --text:#e6e7e9; --muted:#92a0b0;
                        --green:#4fd88a; --amber:#e0b34d; --red:#e2645c; --blue:#5b9bd9;
                        width:100%; margin:0; font-family:inherit; color:var(--text); }
                    .tor-dash *{ box-sizing:border-box; }
                    .tor-dash:not(.tor-cfx-open) .tor-col-left .cbi-value[data-name^="conflux_"]{ display:none !important; }
                    .tor-dash:not(.tor-maint-open) .tor-col-left [data-name="maint_body"]{ display:none !important; }
                    .tor-dash.tor-cfx-open .tor-col-left .cbi-value[data-name^="conflux_"]{ border-left:2px solid rgba(79,216,138,.25) !important; padding-left:10px !important; }
                    .tor-acc{ width:100%; margin:3px 0; border:1px solid #2f343b; border-radius:8px; background:#1a1f25; overflow:hidden; }
                    .tor-acc-hdr{ display:flex; align-items:center; gap:10px; padding:9px 12px; cursor:pointer; user-select:none; width:100%;
                        background:linear-gradient(135deg,#1e2329,#232830); transition:background .15s ease; }
                    .tor-acc-hdr:hover{ background:linear-gradient(135deg,#232830,#2a3038); }
                    .tor-acc-arrow{ width:12px; text-align:center; color:#46505A; font-size:10px; flex-shrink:0; transition:transform .2s ease; }
                    .tor-dash.tor-cfx-open .tor-acc[data-key="cfx"] .tor-acc-arrow,
                    .tor-dash.tor-maint-open .tor-acc[data-key="maint"] .tor-acc-arrow{ transform:rotate(90deg); }
                    .tor-acc-title{ flex:1; font-weight:700; font-size:13px; color:#d5dae0; text-align:left; }
                    .tor-acc-sub{ font-size:11px; color:#46505A; font-weight:400; margin-left:6px; }
                    .tor-acc-badge{ font-size:10px; font-weight:700; padding:2px 8px; border-radius:4px; letter-spacing:.3px;
                        background:rgba(146,160,176,.15); color:#92a0b0; flex-shrink:0; }
                    .tor-acc-badge.on{ background:rgba(79,216,138,.15); color:#4fd88a; box-shadow:0 0 0 1px rgba(79,216,138,.25) inset; }
                    .tor-acc-badge.auto{ background:rgba(91,155,217,.15); color:#79c0ff; }
                    .tor-maint-body{ width:100%; padding:4px 10px 10px; border:1px solid #2b3038; border-radius:8px; background:#1a1f25; margin-bottom:3px; }
                    .tor-maint-row{ display:flex; align-items:center; gap:10px; padding:9px 4px; border-bottom:1px solid rgba(255,255,255,.04); flex-wrap:wrap; }
                    .tor-maint-info{ flex:1; min-width:200px; font-size:13px; color:#b8bfc7; }
                    .tor-maint-info small{ display:block; margin-top:2px; font-size:11px; color:#6b7683; line-height:1.3; }
                    .tor-maint-check{ display:flex; align-items:center; gap:6px; font-size:12px; color:#e0b34d; cursor:pointer; margin-top:4px; }
                    #tor-maint-status{ margin-top:8px; font-size:12px; color:#92a0b0; }
                    #tor-maint-log{ display:none; margin-top:6px; max-height:220px; overflow:auto; padding:8px; background:#12161b; border:1px solid #2b3038;
                        border-radius:6px; font-family:monospace; font-size:11px; line-height:1.45; color:#b8bfc7; white-space:pre-wrap; word-break:break-all; }
                    .tor-header{ display:flex; align-items:center; gap:12px; margin-bottom:14px; padding:2px 0; }
                    .tor-logo{ height:52px; width:auto; flex-shrink:0; display:flex; align-items:center; justify-content:center; }
                    .tor-logo svg{ height:100%; width:auto; display:block; }
                    .tor-header h2{ margin:0; font-size:20px; font-weight:700; }
                    .tor-header p{ margin:2px 0 0; font-size:11px; color:#92a0b0; }
                    .tor-topbar{ display:grid; grid-template-columns:minmax(0,1fr) auto; gap:10px 16px;
                        align-items:center; background:var(--panel); padding:10px 16px;
                        border-radius:8px; margin-bottom:0; border:1px solid #383d45;
                        box-shadow:0 4px 6px rgba(0,0,0,.3); }
                    .tor-topbar .tor-btn{ white-space:nowrap; }
                    .tor-top-row{ width:100%; margin-bottom:8px; }
                    .tor-field .v{ color:#b8bfc7; }
                    .tor-field .tor-dot{ display:none; }
                    .tor-topbar-left{ display:grid; min-width:0; align-items:stretch;
                        grid-template-columns:104px 124px minmax(110px,.9fr) minmax(170px,1.2fr) minmax(170px,1.2fr); }
                    .tor-progress-outer{ height:4px; background:#2a2f38; border-radius:2px; overflow:hidden; }
                    .tor-progress-fill{ height:100%; width:0%; border-radius:2px;
                        background:linear-gradient(90deg,
                            #22d3ee 0%,
                            #3b82f6 35%,
                            #8b5cf6 65%,
                            #e879f9 100%);
                        transition:width .5s ease; }
                    .tor-field{ display:flex; flex-direction:column; align-items:flex-start; justify-content:center; gap:3px;
                        min-width:0; padding:0 14px; border-left:1px solid #3a3f47; }
                    .tor-topbar-left > .tor-field:first-child{ border-left:0; padding-left:0; }
                    .tor-field .k{ font-size:11px; color:var(--muted); text-transform:uppercase; font-weight:700; letter-spacing:.04em; white-space:nowrap; }
                    .tor-field .v{ font-size:13px; font-weight:700; font-family:ui-monospace,Menlo,Consolas,monospace;
                        display:block; max-width:100%; min-height:18px; line-height:18px;
                        white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
                    .tor-divider{ display:none; }
                    @media (max-width:940px){
                        .tor-topbar{ grid-template-columns:minmax(0,1fr); }
                        .tor-topbar-left{ grid-template-columns:repeat(2,minmax(0,1fr)); row-gap:10px; }
                        .tor-field, .tor-topbar-left > .tor-field:first-child{ border-left:0; padding:0; }
                        .tor-topbar-left > .tor-field:nth-child(n+7){ grid-column:1 / -1; }
                    }
                    .tor-dot{ width:8px; height:8px; border-radius:50%; background:currentColor; display:inline-block; margin-inline-end:4px; }
                    .tor-btn{ border-radius:6px; padding:5px 14px; font-size:12px; font-weight:700;
                        cursor:pointer; border:1px solid transparent; }
                    .tor-btn:disabled{ opacity:.5; cursor:not-allowed; }
                    .tor-btn-stop{ background:transparent; color:var(--red); border-color:var(--red); }
                    .tor-btn-stop:hover:not(:disabled){ background:var(--red); color:#fff; }
                    .tor-btn-start{ background:transparent; color:var(--green); border-color:var(--green); }
                    .tor-btn-start:hover:not(:disabled){ background:var(--green); color:#12241b; }
                    .tor-btn-refresh{ background:transparent; color:#b8bfc7; border-color:#3a3f47; }
                    .tor-btn-check{ background:linear-gradient(135deg,#2b5876,#4e4376); color:#fff; }
                    .tor-grid{ display:flex; gap:12px; align-items:stretch; }
                    @media (max-width:940px){ .tor-grid{ flex-direction:column; } }
                    .tor-col-left{ flex:1.1; min-width:320px; display:flex; flex-direction:column;
                        background:var(--panel); padding:6px 14px; border-radius:10px;
                        border:1px solid var(--border); box-shadow:0 4px 10px rgba(0,0,0,.2); }
                    .tor-col-right{ flex:.9; min-width:320px; display:flex; flex-direction:column; gap:8px;
                        background:#1B2227; padding:10px 14px; border-radius:10px;
                        border:1px solid #383d45; box-shadow:0 4px 10px rgba(0,0,0,.3); }
                    .tor-card{ background:linear-gradient(135deg,var(--panel-2) 0%,#232830 100%);
                        border:1px solid var(--card-border); border-radius:8px; padding:10px 14px; }
                    .tor-card h3{ margin:0 0 8px; font-size:13px; font-weight:700; color:var(--muted);
                        display:flex; justify-content:space-between; align-items:center; }
                    .tor-log{ background:#181b1f; color:var(--green); padding:8px;
                        border:1px solid #2b2f35; border-radius:4px;
                        font-family:ui-monospace,Menlo,Consolas,monospace; font-size:12px;
                        height:420px; overflow-y:auto; white-space:pre-wrap; word-break:break-word; }
                    .tor-btn-ghost{ background:transparent; color:var(--red); border:1px solid var(--red);
                        padding:3px 10px; border-radius:4px; font-size:11px; cursor:pointer; }
                    .tor-stats{ display:grid; grid-template-columns:repeat(3,1fr); gap:8px; }
                    .tor-stat{ background:rgba(0,0,0,.3); border:1px solid rgba(255,255,255,.03);
                        border-radius:6px; padding:8px; text-align:center; }
                    .tor-stat .label{ font-size:10px; letter-spacing:.03em; color:var(--muted); margin-bottom:2px; }
                    .tor-stat .value{ font-size:13px; font-weight:700; color:var(--green); font-family:ui-monospace,Menlo,Consolas,monospace; }
                    .tor-leak-lines{ font-family:ui-monospace,Menlo,Consolas,monospace; font-size:12px;
                        color:var(--muted); line-height:1.7; min-height:20px; }
                    .tor-hint{ font-size:11px; color:#46505A; margin-top:8px; }
                    .tor-tests-grid{ display:grid; grid-template-columns:1fr 1fr; gap:6px 12px; }
                    .tor-test-item{ display:flex; align-items:center; justify-content:space-between;
                        background:rgba(0,0,0,.3); border:1px solid rgba(255,255,255,.03);
                        border-radius:6px; padding:7px 10px; }
                    .tor-test-label{ font-size:12px; color:#b8bfc7; display:flex; align-items:center; gap:6px; }
                    .tor-test-value{ font-size:12px; font-weight:700; font-family:ui-monospace,Menlo,Consolas,monospace; }
                    .tor-col-left > .cbi-value, .tor-col-left .cbi-value{
                        width:100% !important; padding:5px 6px !important; margin-bottom:0 !important;
                        border-bottom:1px solid rgba(255,255,255,.04) !important; display:flex !important;
                        flex-direction:row !important; align-items:center !important; min-height:34px;
                        border-radius:6px; }
                    .tor-col-left > .cbi-value:hover{ background:rgba(255,255,255,.025); }
                    .tor-col-left > .tor-service-control{
                        width:100% !important; padding:5px 6px !important; margin-bottom:0 !important;
                        border-bottom:1px solid rgba(255,255,255,.04) !important;
                        display:flex !important; flex-direction:row !important;
                        align-items:center !important; min-height:34px; border-radius:6px;
                    }
                    .tor-col-left > .tor-service-control .cbi-value-title{
                        width:38% !important; min-width:140px !important;
                        text-align:left !important; padding:0 10px 0 0 !important;
                        font-size:13px; color:#b8bfc7;
                    }
                    .tor-col-left > .tor-service-control .cbi-value-field{
                        width:62% !important; padding:0 !important; font-size:13px;
                    }
                    .tor-col-left > .tor-service-control:hover{ background:rgba(255,255,255,.025); }
                    .tor-col-left .cbi-value-title{ width:38% !important; min-width:140px !important;
                        text-align:left !important; padding:0 10px 0 0 !important; font-size:13px; color:#b8bfc7; }
                    .tor-col-left .cbi-value-field{ width:62% !important; padding:0 !important; font-size:13px; }
                    .tor-col-left .cbi-value-description{ margin-top:2px !important; font-size:11px !important;
                        color:#46505A; line-height:1.25; }
                    .tor-col-left input[type="text"], .tor-col-left select, .tor-col-left textarea{
                        padding:3px 8px !important; font-size:13px !important; background:#262b33 !important;
                        color:#c7ccd1 !important; width:100% !important; border:1px solid #383d45 !important;
                        border-radius:6px !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul{
                        flex-wrap:wrap !important; row-gap:3px !important; column-gap:0 !important;
                        min-height:32px; align-content:flex-start !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected]{
                        padding:3px 8px 3px 8px !important; font-size:13px !important;
                        margin:1px 2px 1px 0 !important; min-height:24px !important;
                        display:inline-flex !important; align-items:center !important;
                        line-height:1 !important; position:relative !important;
                        border-radius:8px !important;
                        background:rgba(45,166,178,.14) !important;
                        border:1px solid rgba(94,213,222,.55) !important;
                        flex:0 0 auto !important; width:auto !important; max-width:max-content !important; }
                    [data-tor-field="exit_node"].cbi-dropdown:not([open]) > ul > li[selected] > form{
                        display:none !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected] > label{
                        display:inline-flex !important; align-items:center !important;
                        gap:5px !important; margin:0 !important; padding:0 !important;
                        white-space:nowrap !important; width:auto !important; flex:0 0 auto !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected] .tor-country-name{
                        display:none !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected] .tor-country-flag{
                        font-family:'Noto Color Emoji','Apple Color Emoji','Segoe UI Emoji',sans-serif !important;
                        font-size:15px !important; line-height:1 !important; }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected] .tor-country-code{
                        font-size:13px !important; font-weight:700 !important;
                        letter-spacing:.4px !important; color:#7de6ee !important; }
                    [data-tor-field="exit_node"].cbi-dropdown:not([open]) .tor-country-remove{
                        appearance:none !important; -webkit-appearance:none !important;
                        border:0 !important; background:transparent !important;
                        padding:0 !important; margin:0 0 0 3px !important;
                        min-width:15px !important; width:15px !important; height:20px !important;
                        color:#9fdfe4 !important; font-size:17px !important;
                        font-weight:700 !important; line-height:1 !important;
                        cursor:pointer !important; opacity:.9 !important; }
                    [data-tor-field="exit_node"].cbi-dropdown:not([open]) .tor-country-remove:hover{
                        color:#fff !important; opacity:1 !important; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value]{
                        min-height:44px !important; padding:7px 12px !important;
                        display:flex !important; align-items:center !important;
                        line-height:1.2 !important; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] > form{
                        flex:0 0 auto !important; width:auto !important; margin:0 8px 0 0 !important; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] > label{
                        display:flex !important; flex-wrap:wrap !important;
                        align-items:baseline !important; column-gap:6px !important;
                        row-gap:2px !important; margin:0 !important; padding:0 !important;
                        white-space:normal !important; width:auto !important; flex:1 1 auto !important; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] .tor-country-flag{
                        font-family:'Noto Color Emoji','Apple Color Emoji','Segoe UI Emoji',sans-serif !important;
                        font-size:17px !important; line-height:1 !important; order:1; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] .tor-country-code{
                        font-size:15px !important; font-weight:700 !important;
                        letter-spacing:.4px !important; color:#eef2f6 !important; order:2; }
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] .tor-country-name{
                        flex-basis:100% !important; width:100% !important;
                        margin:1px 0 0 0 !important; font-size:12px !important;
                        font-weight:400 !important; color:#46505A !important; order:3; }
                    .tor-col-left input[type="checkbox"]{
                        appearance:none; -webkit-appearance:none; -moz-appearance:none;
                        width:32px; height:18px; min-width:32px;
                        border-radius:999px; background:#2a2f38; border:1px solid #3a4049;
                        position:relative; cursor:pointer; outline:none; vertical-align:middle;
                        transition:background .2s ease, border-color .2s ease; }
                    .tor-col-left input[type="checkbox"]::before{
                        content:""; position:absolute; top:2px; left:2px; width:12px; height:12px;
                        border-radius:50%; background:#9aa5b1; box-shadow:0 1px 3px rgba(0,0,0,.4);
                        transition:transform .2s ease, background .2s ease; }
                    .tor-col-left input[type="checkbox"]:checked{
                        background:linear-gradient(135deg,#4fd88a,#3cb375); border-color:#4fd88a; }
                    .tor-col-left input[type="checkbox"]:checked::before{ transform:translateX(14px); background:#fff; }
                    .tor-col-left input[type="checkbox"]:hover{ border-color:#5a6572; }
                    .tor-col-left input[type="checkbox"]:focus-visible{ box-shadow:0 0 0 3px rgba(79,216,138,.25); }
                    .tor-cc-picker{ position:relative; width:100%; }
                    .tor-cc-chips{
                        display:flex; flex-wrap:wrap; gap:5px; align-items:center;
                        min-height:30px; padding:3px 26px 3px 6px;
                        border:1px solid #414246; border-radius:8px;
                        background:#202123; cursor:pointer; transition:border-color .15s;
                    }
                    .tor-cc-chips:hover{ border-color:#5a5b60; }
                    .tor-cc-picker.tor-cc-open .tor-cc-chips{
                        border-color:#3e5fff; box-shadow:0 0 0 2px rgba(62,95,255,.18);
                    }
                    .tor-cc-arrow{
                        position:absolute; right:10px; top:50%; transform:translateY(-50%);
                        color:#8b949e; font-size:12px; pointer-events:none;
                    }
                    .tor-cc-placeholder{ color:#8b949e; font-size:13px; padding:0 4px; }
                    .tor-cc-chip{
                        display:inline-flex; align-items:center; gap:6px;
                        height:22px; padding:0 6px 0 5px; border-radius:6px;
                        background:#30343b; color:#e6e9ee; font-size:12.5px;
                        font-weight:600; flex:0 0 auto;
                    }
                    img.tor-cc-flag-img{
                        width:16px; height:12px; object-fit:cover;
                        border-radius:2px; display:inline-block;
                        vertical-align:middle;
                        box-shadow:0 0 0 1px rgba(255,255,255,.08);
                    }
                    .tor-cc-code{ font-size:11px; font-weight:800; letter-spacing:.04em; }
                    .tor-cc-remove{
                        appearance:none; -webkit-appearance:none;
                        border:0; background:transparent; color:#9aa0aa;
                        cursor:pointer; padding:0 2px; margin-left:1px;
                        font-size:15px; line-height:1; font-weight:700;
                    }
                    .tor-cc-remove:hover{ color:#ff8179; }
                    .tor-cc-panel{
                        position:absolute; left:0; right:0; top:calc(100% + 6px);
                        z-index:9999; background:#1D1E20;
                        border:1px solid #45464a; border-radius:10px;
                        box-shadow:0 14px 32px rgba(0,0,0,.55);
                        padding:5px; display:none;
                    }
                    .tor-cc-search{
                        width:100%; box-sizing:border-box;
                        min-height:28px; padding:3px 9px;
                        background:#202123; color:#f5f5f7;
                        border:1px solid #414246; border-radius:6px;
                        margin-bottom:4px; font-size:12.5px;
                    }
                    .tor-cc-search:focus{ outline:none; border-color:#3e5fff; }
                    .tor-cc-list{ max-height:210px; overflow:auto; }
                    .tor-cc-item{
                        display:flex; align-items:center; gap:8px;
                        padding:3px 8px; min-height:24px; border-radius:6px; cursor:pointer;
                        font-size:12.5px; line-height:1.2; color:#e9e9ec;
                    }
                    .tor-cc-item:hover{ background:#292a2d; }
                    .tor-cc-item.tor-cc-sel{ background:rgba(62,95,255,.14); color:#fff; }
                    .tor-cc-item .tor-cc-name{ flex:1 1 auto; overflow:hidden;
                        text-overflow:ellipsis; white-space:nowrap; }
                    .tor-cc-check{ color:#4fd88a; font-weight:800; font-size:12px; }
                    .tor-cc-rowcode{ color:#7d8590; font-size:10.5px; font-weight:700; letter-spacing:.04em; }
                    .tor-cc-empty{ color:#777d86; font-size:12px; padding:8px 10px; }
                    .tor-dash .cbi-page-actions .cbi-button-apply,
                    .tor-dash .cbi-page-actions .cbi-button-reset{
                        display:none !important;
                    }
                    .tor-dash .cbi-page-actions{
                        border-top:1px solid rgba(255,255,255,.06);
                        padding-top:8px;
                        margin-top:8px;
                    }
                    .tor-card{ overflow:hidden; box-sizing:border-box; border-radius:8px;
                        box-shadow:inset 0 1px 0 rgba(255,255,255,.05); }
                    .tor-card h3{ color:#96a5ba; }
                    .tor-col-left > .cbi-value, .tor-col-left .cbi-value{ min-height:36px; transition:background .15s ease; }
                    .tor-col-left > .tor-service-control{ min-height:36px; }
                    .tor-col-left > .cbi-value:last-child{ border-bottom:none !important; }
                    .tor-col-left input[type="text"], .tor-col-left select{
                        height:26px !important; box-sizing:border-box;
                        transition:border-color .15s ease, box-shadow .15s ease; }
                    .tor-col-left input[type="text"]:hover, .tor-col-left select:hover{ border-color:#4a5568 !important; }
                    .tor-col-left input[type="text"]:focus, .tor-col-left select:focus{
                        border-color:#4fd88a !important; box-shadow:0 0 0 3px rgba(79,216,138,.15) !important; outline:none !important; }
                    .tor-col-left .cbi-button, .tor-dash .cbi-button{
                        border-radius:6px !important;
                        transition:transform .12s ease, box-shadow .12s ease, filter .12s ease !important; }
                    .tor-col-left .cbi-button{ padding:4px 12px !important; font-size:12px !important;
                        height:auto !important; min-height:26px !important; }
                    .tor-dash .cbi-button:hover, .tor-dash button.btn:hover{ filter:brightness(1.15); transform:translateY(-1px); }
                    .tor-dash .cbi-button:active, .tor-dash button.btn:active{ transform:translateY(0); filter:brightness(.95); }
                    .psi-bar{ position:relative; height:2.5px; margin:6px 0 2px; border-radius:3px;
                        background:#3b3b43; box-shadow:inset 0 0 0 1px rgba(0,0,0,.35); }
                    .psi-bar-fill{ position:absolute; left:0; top:0; height:100%; width:0; border-radius:3px; opacity:0;
                        background-image:linear-gradient(90deg,#00e5ff,#ff00ff);
                        transition:width .9s cubic-bezier(.22,.61,.36,1), opacity .4s ease; }
                    .psi-bar-fill.up{ opacity:1; }
                    .psi-bar-fill.down{ opacity:1; background-image:linear-gradient(90deg,#ff00ff,#00e5ff);
                        transition:width 1.2s ease-in, opacity 1.2s ease-in; }
                    .psi-bar-fill::after{ content:''; position:absolute; left:0; right:0; top:100%; height:16px;
                        background:inherit; filter:blur(12px); opacity:.35;
                        -webkit-mask-image:linear-gradient(#000,transparent); mask-image:linear-gradient(#000,transparent);
                        pointer-events:none; }
                    .psi-bar-fill::before{ content:''; position:absolute; top:0; left:0; right:0; bottom:0; border-radius:inherit;
                        opacity:0; background-image:linear-gradient(90deg,transparent,rgba(255,255,255,.6),transparent);
                        background-size:40% 100%; background-repeat:no-repeat; background-position:-60% 0; }
                    .psi-bar-fill.busy::before{ opacity:1; animation:psi-shine 1.6s linear infinite; }
                    @keyframes psi-shine{ from{ background-position:-60% 0; } to{ background-position:160% 0; } }
                    @keyframes psi-glow{ 0%,100%{ filter:brightness(1); } 50%{ filter:brightness(1.3); } }
                    @media (prefers-reduced-motion: reduce){
                        .psi-bar-fill, .psi-bar-fill::before{ animation:none !important; transition:none !important; } }
                    .tor-card-log{ flex:1 1 auto; display:flex; flex-direction:column; min-height:230px;
                        background:none; border:none; padding:0; box-shadow:none; }
                    .tor-card-log .tor-log-list{ flex:1 1 0; height:auto; min-height:170px; }
                    .tor-card-log h3{ color:#92a0b0; }
                    .tor-h3-dot{ justify-content:flex-start !important; gap:6px; }
                    .tor-h3-dot::before{ content:''; width:8px; height:8px; background:#4fd88a;
                        border-radius:50%; display:inline-block; box-shadow:0 0 8px #4fd88a; }
                    .tor-stats{ display:grid; gap:8px; font-family:monospace; }
                    .tor-stats-4{ grid-template-columns:repeat(4,1fr); }
                    .tor-stats-3{ grid-template-columns:repeat(3,1fr); }
                    .tor-stats + .tor-stats{ margin-top:8px; }
                    .tor-stats .tor-stat{ background:rgba(0,0,0,.25); padding:8px; border-radius:6px; border:1px solid rgba(255,255,255,.03); text-align:center; min-width:0; }
                    .tor-stat-label{ font-size:10px; line-height:1.3; color:#92a0b0; text-transform:uppercase; letter-spacing:0; margin:0 0 2px;
                        background:none !important; border:0 !important; padding:0 !important; box-shadow:none !important; }
                    .tor-stat-value{ font-size:13px; font-weight:700; color:#fff; font-family:inherit; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
                    .tor-stat.c-green{ background:rgba(79,216,138,.05); border-color:rgba(79,216,138,.1); }
                    .tor-stat.c-green .tor-stat-label, .tor-stat.c-green .tor-stat-value{ color:#4fd88a; }
                    .tor-stat.c-blue{ background:rgba(51,153,255,.05); border-color:rgba(51,153,255,.1); }
                    .tor-stat.c-blue .tor-stat-label, .tor-stat.c-blue .tor-stat-value{ color:#5b9bd9; }
                    .tor-stat.c-amber{ background:rgba(255,204,0,.05); border-color:rgba(255,204,0,.1); }
                    .tor-stat.c-amber .tor-stat-label, .tor-stat.c-amber .tor-stat-value{ color:#e0b34d; }
                    .tor-card h3.tor-h3-dot{ margin-bottom:10px; }
                    .tor-lat-head{ display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; }
                    .tor-lat-title{ font-weight:700; color:#96a5ba; font-size:13px; }
                    .tor-lat-badge{ font-size:10px; color:#46505A; background:rgba(0,0,0,.3); padding:2px 6px; border-radius:4px; }
                    .tor-lat-grid{ display:grid; grid-template-columns:repeat(3,1fr); gap:6px; text-align:center; }
                    .tor-lat-tile{ background:rgba(0,0,0,.3); padding:8px; border-radius:6px; border:1px solid rgba(255,255,255,.03); min-width:0; }
                    .tor-lat-label{ font-size:11px; color:#92a0b0; margin:0 0 4px; font-weight:700; background:none !important; padding:0 !important; }
                    .tor-lat-value{ font-family:monospace; font-size:13px; white-space:nowrap; }
                    .tor-lat-tile.c-amber .tor-lat-value{ color:#e0b34d; }
                    .tor-lat-tile.c-green .tor-lat-value{ color:#4fd88a; }
                    .tor-lat-tile.c-blue .tor-lat-value{ color:#5b9bd9; }
                    @media (max-width:420px){ .tor-stats-4{ grid-template-columns:repeat(2,1fr); } }
                    [data-tor-field="exit_node"].cbi-dropdown > ul > li[selected] .tor-country-flag,
                    [data-tor-field="exit_node"].cbi-dropdown[open] > ul.dropdown > li[data-value] .tor-country-flag{
                        display:inline-flex; align-items:center; }
                    img.tor-cc-flag-img{
                        width:16px; height:12px; object-fit:cover;
                        border-radius:2px; display:inline-block;
                        vertical-align:-2px;
                        box-shadow:0 0 0 1px rgba(255,255,255,.08); }
                `);
                document.head.appendChild(style);
            }
            if (!document.getElementById('tor-log-style')) {
                let logStyle = E('style', { id: 'tor-log-style' }, `
                    .tor-log-head{
                        display:flex; align-items:center; gap:8px;
                        margin:0 0 8px 0;
                        min-height:26px;
                        flex-wrap:nowrap;
                    }
                    .tor-log-head h3{
                        margin:0 !important;
                        flex:0 0 auto;
                        font-size:13px;
                    }
                    .tor-log-actions{
                        display:flex; align-items:center; gap:6px;
                        margin-left:auto;
                        flex:0 0 auto;
                        max-width:100%;
                        box-sizing:border-box;
                    }
                    .tor-log-actions select,
                    .tor-log-actions input[type="search"]{
                        font-size:11px; padding:3px 8px;
                        background:#262b33; color:#c7ccd1;
                        border:1px solid #383d45; border-radius:6px;
                        min-height:26px; height:26px;
                        box-sizing:border-box;
                    }
                    .tor-log-actions input[type="search"]{
                        flex:0 1 140px; min-width:100px;
                    }
                    .tor-log-actions select{
                        flex:0 0 auto;
                    }
                    .tor-log-actions .tor-log-btn{
                        background:transparent; color:#b8bfc7;
                        border:1px solid #3a3f47; border-radius:6px;
                        padding:3px 10px; font-size:11px; cursor:pointer;
                        white-space:nowrap;
                        min-height:26px; height:26px;
                        box-sizing:border-box;
                        line-height:1;
                    }
                    .tor-log-actions .tor-log-btn:hover{
                        background:#2b3038; color:#fff;
                    }
                    .tor-log-actions .tor-log-btn-clear{
                        color:#e2645c; border-color:#e2645c;
                        border-radius:4px; font-weight:700; height:auto; min-height:0; padding:3px 10px;
                    }
                    .tor-log-actions .tor-log-btn-clear:hover{
                        background:#e2645c; color:#fff;
                    }
                        background:#e2645c; color:#fff;
                    }
                    @media (max-width:700px){
                        .tor-log-head{ flex-wrap:wrap; }
                        .tor-log-actions{ flex-wrap:wrap; }
                    }
                    .tor-log-count{
                        font-size:11px; color:#92a0b0; font-weight:400;
                    }
                    .tor-log-list{
                        background:#181b1f; border:1px solid #2b2f35;
                        border-radius:4px; padding:4px 0;
                        height:420px; overflow-y:auto;
                        font-family:ui-monospace,Menlo,Consolas,monospace;
                        font-size:12px;
                    }
                    .tor-log-row{
                        display:flex; align-items:baseline; gap:10px; min-width:0;
                        padding:2px 12px; line-height:1.45;
                        border-left:2px solid transparent;
                    }
                    .tor-log-row:hover{ background:rgba(255,255,255,.03); }
                    .tor-log-dot{ display:none; }
                    .tor-log-time{
                        color:#6d7480; font-size:11px;
                        flex:0 0 auto; min-width:56px; opacity:.6;
                    }
                    .tor-log-cat{
                        font-size:10px; font-weight:700; letter-spacing:.04em;
                        padding:0; border-radius:0;
                        flex:0 0 auto; width:66px; text-align:left;
                        background:none !important; color:#b8bfc7; opacity:.6;
                    }
                    .tor-log-msg{
                        color:#e6e7e9; flex:1 1 auto; min-width:0; opacity:.6;
                        white-space:nowrap; overflow:hidden; text-overflow:ellipsis;
                    }
                    .tor-log-row.sev-error .tor-log-msg,
                    .tor-log-row.sev-critical .tor-log-msg,
                    .tor-log-row.sev-warn .tor-log-msg{ opacity:.85; }
                    .tor-log-row.sev-critical{ border-left-color:#e2645c; background:rgba(226,100,92,.07); }
                    .tor-log-row.sev-critical .tor-log-dot{ background:#e2645c; }
                    .tor-log-row.sev-critical .tor-log-msg{ color:#ffb4ae; font-weight:600; }
                    .tor-log-row.sev-error{ border-left-color:#e2645c; }
                    .tor-log-row.sev-error .tor-log-dot{ background:#e2645c; }
                    .tor-log-row.sev-error .tor-log-msg{ color:#ffb4ae; }
                    .tor-log-row.sev-warn .tor-log-dot{ background:#e0b34d; }
                    .tor-log-row.sev-warn .tor-log-msg{ color:#e0b34d; }
                    .tor-log-row.sev-ok .tor-log-dot{ background:#4fd88a; }
                    .tor-log-row.sev-info .tor-log-dot{ background:#92a0b0; }
                    .tor-log-row.sev-debug{ opacity:.7; }
                    .tor-log-row.sev-debug .tor-log-dot{ background:#6d7480; }
                    .tor-log-cat.cat-bootstrap { background:rgba(79,216,138,.15); color:#7ee787; }
                    .tor-log-cat.cat-service   { background:rgba(91,155,217,.15); color:#79c0ff; }
                    .tor-log-cat.cat-circuit   { background:rgba(79,216,138,.15); color:#7ee787; }
                    .tor-log-cat.cat-dns       { background:rgba(91,155,217,.15); color:#79c0ff; }
                    .tor-log-cat.cat-socks     { background:rgba(91,155,217,.15); color:#79c0ff; }
                    .tor-log-cat.cat-bridge    { background:rgba(224,179,77,.15); color:#e0b34d; }
                    .tor-log-cat.cat-leak      { background:rgba(226,100,92,.20); color:#ff8179; }
                    .tor-log-cat.cat-firewall  { background:rgba(91,155,217,.15); color:#79c0ff; }
                    .tor-log-cat.cat-error     { background:rgba(226,100,92,.20); color:#ff8179; }
                    .tor-log-cat.cat-warn      { background:rgba(224,179,77,.15); color:#e0b34d; }
                    .tor-log-cat.cat-consensus { background:rgba(146,160,176,.15); color:#b8bfc7; }
                    .tor-log-cat.cat-network   { background:rgba(224,179,77,.15); color:#e0b34d; }
                    .tor-log-cat.cat-clock     { background:rgba(224,179,77,.15); color:#e0b34d; }
                    .tor-log-cat.cat-permission{ background:rgba(226,100,92,.20); color:#ff8179; }
                    .tor-log-cat.cat-info      { background:rgba(146,160,176,.12); color:#b8bfc7; }
                `);
                document.head.appendChild(logStyle);
            }
            (function () {
                var PLACEHOLDERS = {
                    'auto':       'obfs4 94.112.227.176:43595 BF61F24DD6852920E5DF3D8B03A4136CDA6E0C4B cert=TK+t/zNVAm4AXthPGlJS1pzRfkCJbaDtjjana39YMpMJnFnU7GRzZvN8mYbvL4eO8xPNeA iat-mode=0',
                    'obfs4':      'obfs4 94.112.227.176:43595 BF61F24DD6852920E5DF3D8B03A4136CDA6E0C4B cert=TK+t/zNVAm4AXthPGlJS1pzRfkCJbaDtjjana39YMpMJnFnU7GRzZvN8mYbvL4eO8xPNeA iat-mode=0',
                    'webtunnel':  'webtunnel 198.51.100.2:443 2B280B23E1107BB62ABFC40DDCC8824814F7C8AD url=https://example.com/path ver=0.0.1',
                    'snowflake':  'snowflake 192.0.2.3:1 2B280B23E1107BB62ABFC40DDCC8824814F7C8AD url=https://snowflake-broker.torproject.net/ fronts=www.google.com ice=stun:stun.l.google.com:19302 utls-imitate=hellorandomizedalpn',
                    'meek':       'meek_lite 192.0.2.4:1 97700DFE9F483596DDA6264C4D7DF7641E1E39CE url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com',
                    'vanilla':    '203.0.113.5:443 0123456789ABCDEF0123456789ABCDEF01234567',
                };
                var sel = mapNode.querySelector('[data-tor-field="bridge_mode"]');
                var ta = mapNode.querySelector('[data-tor-field="bridge_lines"]');
                if (sel && ta) {
                    var applyPlaceholder = function () {
                        var _se = sel.querySelector ? sel.querySelector('select') : null;
                        var _sv = _se ? _se.value : sel.value;
                        ta.placeholder = PLACEHOLDERS[_sv] || PLACEHOLDERS['obfs4'];
                    };
                    applyPlaceholder();
                    sel.addEventListener('change', applyPlaceholder);
                }
            })();
            (function () {
                var DEFAULT_BRIDGES = {
                    'obfs4': [
                        'obfs4 103.17.154.135:443 9B734AAA454B2F9B26342AE130AB42FC9A67E2EE cert=80jwaFv8pHr5+onzJyjVgbemIjD3GRRwEABfP+Y48G++FAsEVPUZNWWEvMWXVGJi1cwTKg iat-mode=0',
                        'obfs4 146.57.248.225:22 10A6CD36A537FCE513A322361547444B393989F0 cert=K1gDtDAIcUfeLqbstggjIw2rtgIKqdIhUlHp82XRqNSq/mtAjp1BIC9vHKJ2FAEpGssTPw iat-mode=0',
                        'obfs4 178.114.230.19:11010 7A0C1E1763208B9EDEBCD0B94814BD926032ADA9 cert=9S55BQ2wjmJP+PR5AJbw2rZM/qieoQ2AjltKNepYwiewUNvkg63Pxam0ZtxPXMJISDxdVw iat-mode=0',
                        'obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 cert=qUVQ0srL1JI/vO6V6m/24anYXiJD3QP2HgzUKQtQ7GRqqUvs7P+tG43RtAqdhLOALP7DJQ iat-mode=1',
                        'obfs4 193.11.166.194:27015 2D82C2E354D531A68469ADF7F878FA6060C6BACA cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg iat-mode=0',
                        'obfs4 193.11.166.194:27020 86AC7B8D430DAC4117E9F42C9EAED18133863AAF cert=0LDeJH4JzMDtkJJrFphJCiPqKx7loozKN7VNfuukMGfHO0Z8OGdzHVkhVAOfo1mUdv9cMg iat-mode=0',
                        'obfs4 193.11.166.194:27025 1AE2C08904527FEA90C4C4F8C1083EA59FBC6FAF cert=ItvYZw5tn6v3G4UnQa6Qz04Npro6e81AP70YujmK/KXwDFPTs3aHXcHp4n8Vt6w/bv8cA iat-mode=0',
                        'obfs4 195.52.147.5:1677 3234D58257F100D6B5D8AB6F43176E6946EFD513 cert=EGg4aZuuJO5gTc9gkRVcSYBXwDjsNdmWt/SYnqnDG7LF/WjUlEsDtUWkLMh1o9hgNIFiUQ iat-mode=0',
                        'obfs4 209.148.46.65:443 74FAD13168806246602538555B5521A0383A1875 cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw iat-mode=0',
                        'obfs4 212.172.15.201:5470 00D62BE708A0E2A00B6A2097BE0D4B45B70F5F5C cert=0VeTzN1QWoQERmTn0vTpGOiEg8XMQM9iw16GnHwDHYuBjiAsBdSBVY0QUbWj7b8+1Y8cJA iat-mode=0',
                        'obfs4 212.83.43.74:443 39562501228A4D5E27FCA4C0C81A01EE23AE3EE4 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=1',
                        'obfs4 212.83.43.95:443 BFE712113A72899AD685764B211FACD30FF52C31 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=1',
                        'obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0',
                        'obfs4 45.145.95.6:27015 C5B7CD6946FF10C5B3E89691A7D3F2C122D2117C cert=TD7PbUO0/0k6xYHMPW3vJxICfkMZNdkRrb63Zhl5j9dW3iRGiCx0A7mPhe5T2EDzQ35+Zw iat-mode=0',
                        'obfs4 51.222.13.177:80 5EDAC3B810E12B01F6FD8050D2FD3E277B289A08 cert=2uplIpLQ0q9+0qMFrK5pkaYRDOe460LL9WHBvatgkuRr/SL31wBOEupaMMJ6koRE6Ld0ew iat-mode=0',
                        'obfs4 51.38.220.224:30996 22494A012CFA8C88B1D907E2CCB8409AC35B537B cert=dOPijSCG6FD89fYv5N2F9QoeK1od3tpG6VBE/kMY0Bt1aW/7aXPIzsENDoLWZe43gI8efw iat-mode=0',
                        'obfs4 51.68.81.140:2098 F205CB5B969389061477609F8E03470B982F64C1 cert=6hFyrclX8Cg16jHGbtYqZxbGxj+p0flBn2EYZu+hvx/tGL4GROXSvBtwVQ1sRYFbi0++fQ iat-mode=0',
                        'obfs4 51.79.88.193:45529 9A7BA1AE905FBE24FCEACCA09C42ED1B59340D6C cert=5TSiurscOytr5+TpcKG9qQry0UCMkq9eIlHr1ANxFJ0SWujMjUCOpWpDx30eUUIWHC0QSg iat-mode=0',
                        'obfs4 51.89.228.250:21668 BA8BD67D8898CF378D4F73821DEB5657F4BB98DF cert=bEpLLgOwJ9fOJbeHb5r+ronUF2ck5nRd0Jl3zuy7rLoUp732QK2p/CUHjTAfBPCGfcVtSA iat-mode=0',
                        'obfs4 57.128.45.196:18384 E30D5552BEE79C5E8C61A943E9B3D2949F227C41 cert=boaTbcdp+rFHgUvweiAg60UUUpLZWecGl0uXRU358L/a7ZMrAnS/BodUKM3eyfWC+UVXTg iat-mode=0',
                        'obfs4 57.128.57.245:3099 D655AC9C21147BB62C781149150F0E723C4F8FBC cert=fnU2eGPmE6L53eXZf/29d1JloUD2XI/4KHNImTquPr/eBvkrOuuutIlpwvJsZTV1NvZ4aw iat-mode=0',
                        'obfs4 65.108.147.195:8089 DFF8DBF20F8980C4B74EDBAA9695104D613978CE cert=ICnTRGYXX2V63J9ev8XkvXsRJ+Y68XnZGOWW2LCdPIK/sOW8zcunp2gB4qSfelcUVxZDSA iat-mode=0',
                        'obfs4 70.34.221.90:9001 1970303391754B4150BF587D33FAC8074FF749E4 cert=XzoWLiOPlfyFHCUyK255KwLq5bRb8fncaMkzEgHSBZztGlUprhgzIS/P8XSXINKtug2kLw iat-mode=0',
                        'obfs4 82.65.102.109:50459 F21B650DA1B1A33C94763B3467B60D8A6D80BF91 cert=5cmbAdL18N7PXcWlph4915SC9p5DX6VtCmWsG4E4dub5rT7/bfxB3ndBn5uoRdUwGbMIQg iat-mode=0',
                        'obfs4 84.164.12.173:10740 D48C26897BDA22F58460495B9069BEC0CA6D0DA4 cert=TvoujbhzBEHi3q147Pm0efFaB13BNL+UyswKLLz3tnqdw50cFC/6tg3ULbj3uUfELQUnOw iat-mode=0',
                        'obfs4 85.31.186.26:443 91A6354697E6B02A386312F68D82CF86824D3606 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=0',
                        'obfs4 85.31.186.98:443 011F2599C0E9B27EE74B353155E244813763C3E5 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=0',
                        'obfs4 88.187.37.205:16389 28AD3F0FE38629EA49DA131BE1808EEAC0B24E28 cert=bzdHbtALuVK6Y3zQTnK2efYVrgY9DwgoXFrli+KlLr7+u2ykkt6aLmqMd2P7Ij4/nfI8CA iat-mode=0',
                        'obfs4 91.134.99.182:26566 B5D7274F4267D73372BBF8C6446C3AF2D4399A4B cert=eXB5PBSwA+Y6Selwz245/3gZWsskMoJDZcBBccAxrqTtT7OLAwSguf9z2tHU5mV3YkgjIw iat-mode=0',
                        'obfs4 94.112.227.176:43595 BF61F24DD6852920E5DF3D8B03A4136CDA6E0C4B cert=TK+t/zNVAm4AXthPGlJS1pzRfkCJbaDtjjana39YMpMJnFnU7GRzZvN8mYbvL4eO8xPNeA iat-mode=0'
                    ],
                    'snowflake': [
                        'snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://1098762253.rsc.cdn77.org/ fronts=www.cdn77.com,www.phpmyadmin.net ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478,stun:stun.bluesip.net:3478,stun:stun.dus.net:3478 utls-imitate=hellorandomizedalpn',
                        'snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://voluble-torrone-fc39bf.netlify.app/ fronts=vuejs.org ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.nextcloud.com:3478,stun:stun.bethesda.net:3478,stun:stun.nextcloud.com:443 utls-imitate=hellorandomizedalpn'
                    ],
                    'meek': [
                        'meek_lite 192.0.2.20:80 97700DFE9F483596DDA6264C4D7DF7641E1E39CE url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com utls=HelloRandomizedALPN',
                        'meek_lite 192.0.2.20:80 url=https://1603026938.rsc.cdn77.org front=www.phpmyadmin.net utls=HelloRandomizedALPN'
                    ],
                    'webtunnel': [
                        'webtunnel 192.0.2.10:443 0123456789ABCDEF0123456789ABCDEF01234567 url=https://example.invalid/webtunnel ver=0.0.1',
                        'webtunnel 192.0.2.11:443 0123456789ABCDEF0123456789ABCDEF01234567 url=https://example.org/webtunnel ver=0.0.1'
                    ]
                };
                DEFAULT_BRIDGES.auto = DEFAULT_BRIDGES.obfs4
                    .concat(DEFAULT_BRIDGES.snowflake,
                            DEFAULT_BRIDGES.meek);
                var sel = mapNode.querySelector('[data-tor-field="bridge_mode"]');
                var taWrap = mapNode.querySelector('[data-tor-field="bridge_lines"]');
                var ta = taWrap && (taWrap.matches('textarea') ? taWrap : taWrap.querySelector('textarea'));
                if (!sel || !ta) return;
                var selEl = sel.querySelector ? (sel.querySelector('select') || sel) : sel;
                var taEl = ta;
                function poolText(k) { return (DEFAULT_BRIDGES[k] || []).join('\n'); }
                function isPoolText(t) {
                    t = (t || '').replace(/\r/g, '').trim();
                    if (!t) return true;
                    return Object.keys(DEFAULT_BRIDGES).some(function (k) { return poolText(k) === t; });
                }
                function fireChange(el) {
                    ['input', 'change'].forEach(function (n) {
                        el.dispatchEvent(new Event(n, { bubbles: true }));
                    });
                }
                selEl.addEventListener('change', function () {
                    var mode = selEl.value;
                    if (!isPoolText(taEl.value)) return;
                    var txt = (mode === 'webtunnel') ? '' : poolText(mode);
                    if (taEl.value.replace(/\r/g, '').trim() === txt) return;
                    taEl.value = txt;
                    fireChange(taEl);
                });
            })();
            (function () {
                var field = mapNode.querySelector('[data-tor-field="exit_node"]');
                if (!field) return;
                function getCode(li) {
                    var code = li && li.getAttribute('data-value');
                    return code && /^[A-Za-z]{2}$/.test(code) ? code.toUpperCase() : '';
                }
                function getLabel(li) {
                    if (!li) return null;
                    for (var i = 0; i < li.children.length; i++) {
                        if (li.children[i].tagName === 'LABEL') return li.children[i];
                    }
                    return null;
                }
                function clearLabel(label) {
                    if (!label) return;
                    while (label.firstChild) label.removeChild(label.firstChild);
                }
                function makeSpan(cls, text) {
                    var el = document.createElement('span');
                    el.className = cls;
                    el.textContent = text;
                    return el;
                }
                function makeFlag(cc) {
                    cc = (cc || '').toUpperCase();
                    var wrap = document.createElement('span');
                    wrap.className = 'tor-country-flag';
                    if (!/^[A-Z]{2}$/.test(cc)) return wrap;
                    var img = document.createElement('img');
                    img.className = 'tor-cc-flag-img';
                    img.alt = cc;
                    img.loading = 'lazy';
                    img.src = 'https://flagcdn.com/w40/' + cc.toLowerCase() + '.png';
                    img.onerror = function () {
                        if (!img.parentNode) return;
                        var em = countryFlag(cc).trim();
                        if (em) {
                            var s = document.createElement('span');
                            s.textContent = em;
                            img.parentNode.replaceChild(s, img);
                        } else {
                            img.parentNode.removeChild(img);
                        }
                    };
                    wrap.appendChild(img);
                    return wrap;
                }
                function renderSelected(li) {
                    var code = getCode(li);
                    var label = getLabel(li);
                    if (!code || !label) return;
                    var name = countryNames[code] || code;
                    var flag = countryFlag(code).trim();
                    if (label.getAttribute('data-tor-country-render') === ('selected:' + code)) {
                        li.title = name;
                        return;
                    }
                    clearLabel(label);
                    label.appendChild(makeFlag(code));
                    label.appendChild(makeSpan('tor-country-code', code));
                    var removeBtn = document.createElement('button');
                    removeBtn.type = 'button';
                    removeBtn.className = 'tor-country-remove';
                    removeBtn.setAttribute('aria-label', 'Remove ' + name);
                    removeBtn.title = 'Remove ' + name;
                    removeBtn.textContent = '×';
                    removeBtn.addEventListener('click', function (ev) {
                        ev.preventDefault();
                        ev.stopPropagation();
                        removeBtn.dispatchEvent(new CustomEvent('cbi-dropdown-select', {
                            bubbles: true
                        }));
                    });
                    label.appendChild(removeBtn);
                    label.setAttribute('data-tor-country-render', 'selected:' + code);
                    li.title = name;
                }
                function renderOption(li) {
                    var code = getCode(li);
                    var label = getLabel(li);
                    if (!code || !label) return;
                    var name = countryNames[code] || code;
                    var flag = countryFlag(code).trim();
                    if (label.getAttribute('data-tor-country-render') === ('option:' + code)) {
                        li.title = name;
                        return;
                    }
                    clearLabel(label);
                    label.appendChild(makeFlag(code));
                    label.appendChild(makeSpan('tor-country-code', code));
                    label.appendChild(makeSpan('tor-country-name', name));
                    label.setAttribute('data-tor-country-render', 'option:' + code);
                    li.title = name;
                }
                function renderAll() {
                    field.querySelectorAll('li[data-value]').forEach(function (li) {
                        var ul = li.parentNode;
                        var isOpen = ul && ul.classList.contains('dropdown');
                        if (isOpen) renderOption(li);
                        else if (li.hasAttribute('selected')) renderSelected(li);
                    });
                }
                var busy = false;
                function guardedRender() {
                    if (busy) return;
                    busy = true;
                    try { renderAll(); } finally { busy = false; }
                }
                guardedRender();
                new MutationObserver(guardedRender).observe(field, {
                    subtree: true,
                    childList: true,
                    attributes: true,
                    attributeFilter: ['selected', 'class']
                });
            })();
            let stateEl, connEl, bootstrapEl, bootstrapBarEl, realIpEl, torIpEl, logBox, statCircuits = {}, statSocks = {}, statTrans = {}, statDns = {},
                fullTunnelBannerEl, stopBtn, unblockBtn, startBtn, serviceControlRow, tests = {};
            let logFilterSel = null, logAutoScroll = null;
            let logList = null;
            let _clearedAtLen = 0;
            let _lastParsedEvents = [];
            let _lastRawLog = '';
            function setButtonsBusy(busy) {
                stopBtn.disabled = busy;
                startBtn.disabled = busy;
                if (unblockBtn) unblockBtn.disabled = busy;
            }
            function flagEmoji(cc) {
                if (!cc || cc.length !== 2) return '';
                let cps = cc.toUpperCase().split('').map(function (c) { return 127397 + c.charCodeAt(0); });
                try { return String.fromCodePoint.apply(null, cps); } catch (e) { return ''; }
            }
            let realIpCache = null;
            let torIpCache = null;
            const TOR_IP_CACHE_TTL_MS = Infinity;
            // Real IP is frozen: it is captured BEFORE Tor starts (or after Tor
            // is stopped) and is never re-measured while Tor is running or on
            // "Refresh IPs".  Persisted per-browser so a page reload while Tor
            // is connected does not lose it (it cannot be measured then).
            const REAL_IP_KEY = 'tor_ui_real_ip';
            function setRealIp(g) {
                realIpCache = g;
                try { localStorage.setItem(REAL_IP_KEY, JSON.stringify(g)); } catch (e) {}
                paintRealIpFromCache();
            }
            function dropRealIp() {
                realIpCache = null;
                try { localStorage.removeItem(REAL_IP_KEY); } catch (e) {}
            }
            function loadRealIpFromStore() {
                try {
                    let g = JSON.parse(localStorage.getItem(REAL_IP_KEY) || 'null');
                    if (g && g.ip) { realIpCache = g; paintRealIpFromCache(); return true; }
                } catch (e) {}
                return false;
            }
            function clearIpCaches() {
                torIpCache = null;   // only the Tor exit IP is refreshed
            }
            function appendCountryFlag(el, cc) {
                if (!cc || cc.length !== 2) return;
                let flag = E('span', { class: 'tor-status-flag win-flag', 'aria-hidden': 'true' }, [ccFlagImg(cc)]);
                el.appendChild(flag);
                el.appendChild(document.createTextNode(' '));
            }
            function paintRealIpFromCache() {
                if (!realIpCache) return;
                realIpEl.innerHTML = '';
                let cc = realIpCache.cc;
                appendCountryFlag(realIpEl, cc);
                realIpEl.appendChild(document.createTextNode(realIpCache.ip + (cc ? ' (' + cc + ')' : '')));
                realIpEl.style.color = 'var(--green)';
            }
            function paintTorIpFromCache() {
                if (!torIpCache) return;
                torIpEl.innerHTML = '';
                let cc = torIpCache.cc;
                appendCountryFlag(torIpEl, cc);
                torIpEl.appendChild(document.createTextNode(torIpCache.ip + (cc ? ' (' + cc + ')' : '')));
                torIpEl.style.color = torIpCache.isTor ? 'var(--green)' : 'var(--red)';
            }
            function torServiceRunningOnce() {
                return fs.exec('/bin/sh', ['-c',
                    "(ubus -S call service list '{\"name\":\"tor_ui\"}' 2>/dev/null | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null | grep -qx true || { P=$(cat /var/run/tor_ui/tor.pid 2>/dev/null); [ -n \"$P\" ] && kill -0 \"$P\" 2>/dev/null; }) && echo 1 || echo 0"
                ]).then(function (res) {
                    return ((res && res.stdout) || '').trim() === '1';
                }).catch(function () { return false; });
            }
            function delay(ms) {
                return new Promise(function (resolve) { setTimeout(resolve, ms); });
            }
            function confirmTorRunning(triesLeft) {
                triesLeft = (typeof triesLeft === 'number') ? triesLeft : 3;
                return torServiceRunningOnce().then(function (running) {
                    if (running || triesLeft <= 0) return running;
                    return delay(700).then(function () { return confirmTorRunning(triesLeft - 1); });
                });
            }
            function ensureRealIp() {
                if (realIpCache) return Promise.resolve();
                let t0 = Date.now();
                function waitIdle() {
                    if (!_ipChecking || Date.now() - t0 > 15000) return Promise.resolve();
                    return delay(300).then(waitIdle);
                }
                return waitIdle().then(function () {
                    if (realIpCache) return;
                    return runCircuitCheck(true);
                }).catch(function () {});
            }
            serviceControlRow = E('div', { class: 'cbi-value tor-service-control' }, [
                E('label', { class: 'cbi-value-title' }, _('Service Control')),
                E('div', { class: 'cbi-value-field', style: 'display:flex;gap:8px;' }, [
                    startBtn = E('button', {
                        type: 'button',
                        class: 'tor-btn tor-btn-start',
                        click: ui.createHandlerFn(this, function () {
                            setButtonsBusy(true);
                            torIpCache = null;
                            // capture the real (non-Tor) IP BEFORE Tor starts
                            return ensureRealIp().then(function () { return m.save(null, false); }).then(function () {
return runInitDetached('start').catch(function () { return null; }).then(function () { return waitInitJob(120000); });
                            }).then(function (res) {
                                let code = (res && typeof res.code === 'number') ? res.code : 1;
                                if (code === 0) {
                                    ui.addNotification(null, E('p', _('Tor starting\u2026')), 'info');
                                    return;
                                }
                                return confirmTorRunning().then(function (running) {
                                    if (running) {
                                        ui.addNotification(null, E('p', _('Tor starting\u2026')), 'info');
                                    } else {
                                        ui.addNotification(null, E('p', _('Failed to start Tor (exit ') + code + ')'), 'error');
                                    }
                                });
                            }).catch(function (e) {
                                if (/time(d)?\s*out/i.test(String(e))) {
                                    return confirmTorRunning(5).then(function (running) {
                                        if (running) {
                                            ui.addNotification(null, E('p', _('Tor starting\u2026')), 'info');
                                        } else {
                                            ui.addNotification(null, E('p', _('Failed to start Tor: ') + e), 'error');
                                        }
                                    });
                                }
                                ui.addNotification(null, E('p', _('Failed to start Tor: ') + e), 'error');
                            }).finally(function () { setButtonsBusy(false); });
                        })
                    }, _('Start / Restart')),
                    stopBtn = E('button', {
                        type: 'button',
                        class: 'tor-btn tor-btn-stop',
                        click: ui.createHandlerFn(this, function () {
                            setButtonsBusy(true);
                            torIpCache = null;
                            return runInitDetached('stop').then(function () { return waitInitJob(60000); }).then(function (res) {
                                let code = (res && typeof res.code === 'number') ? res.code : 1;
                                if (code === 0) {
                                    ui.addNotification(null, E('p', _('Tor stopped.')), 'info');
                                } else {
                                    return torServiceRunningOnce().then(function (running) {
                                        if (!running) {
                                            ui.addNotification(null, E('p', _('Tor stopped.')), 'info');
                                        } else {
                                            ui.addNotification(null, E('p', _('Failed to stop Tor (exit ') + code + ')'), 'error');
                                        }
                                    });
                                }
                            }).catch(function (e) {
                                if (/time(d)?\s*out/i.test(String(e))) {
                                    return torServiceRunningOnce().then(function (running) {
                                        if (!running) {
                                            ui.addNotification(null, E('p', _('Tor stopped.')), 'info');
                                        } else {
                                            ui.addNotification(null, E('p', _('Failed to stop Tor: ') + e), 'error');
                                        }
                                    });
                                }
                                ui.addNotification(null, E('p', _('Failed to stop Tor: ') + e), 'error');
                            }).finally(function () { setButtonsBusy(false); });
                        })
                    }, _('Stop')),
                    unblockBtn = E('button', {
                        type: 'button',
                        class: 'tor-btn tor-btn-refresh',
                        title: _('Release the Kill Switch after Stop so the LAN has normal internet again (not through Tor).'),
                        click: ui.createHandlerFn(this, function () {
                            setButtonsBusy(true);
                            return fs.exec('/etc/init.d/tor_ui', ['unblock']).then(function (res) {
                                let out = ((res && res.stdout) || '').trim().split('\n')[0];
                                let ok = res && res.code === 0;
                                ui.addNotification(null, E('p', out || (ok ? _('Kill Switch released.') : _('Could not release the Kill Switch.'))), ok ? 'info' : 'warning');
                            }).catch(function (e) {
                                ui.addNotification(null, E('p', _('Unblock failed: ') + e), 'error');
                            }).finally(function () { setButtonsBusy(false); });
                        })
                    }, _('Unblock Internet'))
                ])
            ]);
            const TOR_CC_SH = "TCC=''; if [ -n \"$TORIP\" ]; then _ck=$(od -An -v -tx1 /var/lib/tor/control_auth_cookie 2>/dev/null | tr -d ' \\n'); [ -n \"$_ck\" ] && TCC=$({ printf 'AUTHENTICATE %s\\r\\nGETINFO ip-to-country/%s\\r\\nQUIT\\r\\n' \"$_ck\" \"$TORIP\"; sleep 1; } | nc -w 3 127.0.0.1 9051 2>/dev/null | tr -d '\\r' | grep -o 'ip-to-country/[^=]*=[a-z][a-z]' | head -n1 | cut -d= -f2); fi; ";
            const TOR_IP_FROM_JSON_SH = "TORIP=$(grep -o '\"IP\":\"[^\"]*\"' $TMP/tor 2>/dev/null | head -n1 | cut -d'\"' -f4); [ -z \"$TORIP\" ] && TORIP=$(grep -o '\"ip\":\"[^\"]*\"' $TMP/torgeo 2>/dev/null | head -n1 | cut -d'\"' -f4); ";
            function parseTorExit(kv) {
                let ip = '', isTor = false, cc = '', d = null, g = null;
                try { d = JSON.parse((kv.TORJSON || '').trim()); } catch (e) { d = null; }
                try { g = JSON.parse((kv.TORGEOJSON || '').trim()); } catch (e) { g = null; }
                if (d && d.IP) { ip = d.IP; isTor = !!d.IsTor; }
                else if (g && g.ip) { ip = g.ip; isTor = true; }
                let c1 = String(kv.TORCC || '').trim();
                if (/^[A-Za-z]{2}$/.test(c1)) cc = c1.toUpperCase();
                else if (g && g.country_code) cc = String(g.country_code).toUpperCase();
                return { ip: ip, isTor: isTor, cc: cc };
            }
            function realIpShell(outFile) {
                return String.raw`( dohip() { curl -s -4 -m 3 $IFACE_OPT -H "accept: application/dns-json" "https://1.1.1.1/dns-query?name=$1&type=A" 2>/dev/null | grep -o '"data":"[0-9.]*"' | head -n1 | cut -d'"' -f4; }; rget() { ip=$(dohip "$1"); if [ -n "$ip" ]; then curl -sL -4 -m 5 $IFACE_OPT --resolve "$1:$3:$ip" "$2" 2>/dev/null; else curl -sL -4 -m 5 $IFACE_OPT "$2" 2>/dev/null; fi; }; okgeo() { echo "$1" | grep -Eq '"(ip|query)"' || return 1; echo "$1" | grep -Eq '"success":false|"status":"fail"|"error"' && return 1; return 0; }; D="` + outFile + String.raw`.d"; rm -rf "$D"; mkdir -p "$D"; PL=''; for n in 1 2 3 4 5 6; do case $n in 1) h=ip-api.com; u=http://ip-api.com/json/; p=80;; 2) h=ifconfig.co; u=https://ifconfig.co/json; p=443;; 3) h=ipwho.is; u=https://ipwho.is/; p=443;; 4) h=ipapi.co; u=https://ipapi.co/json/; p=443;; 5) h=ipinfo.io; u=https://ipinfo.io/json; p=443;; 6) h=api.country.is; u=https://api.country.is/; p=443;; esac; ( R=$(rget $h $u $p); okgeo "$R" && echo "$R" > "$D/$n" ) & PL="$PL $!"; done; _t=0; while [ $_t -lt 9 ]; do for n in 1 2 3 4 5 6; do [ -s "$D/$n" ] && break 2; done; _al=0; for _q in $PL; do kill -0 $_q 2>/dev/null && _al=1; done; [ $_al = 0 ] && break; sleep 1; _t=$((_t+1)); done; : > "` + outFile + String.raw`"; for n in 1 2 3 4 5 6; do [ -s "$D/$n" ] && { cat "$D/$n" > "` + outFile + String.raw`"; break; }; done; for _q in $PL; do kill -9 $_q 2>/dev/null; done; rm -rf "$D" ) & `;
            }
            function parseRealGeo(text) {
                try {
                    let d = JSON.parse(String(text || '').trim());
                    let ip = d && (d.ip || d.query);
                    if (!ip || d.success === false || d.status === 'fail') return null;
                    let ccRaw = d.country_code || d.countryCode || d.country_iso || d.cc || (/^[A-Za-z]{2}$/.test(String(d.country || '')) ? d.country : '');
                    return { ip: ip, cc: String(ccRaw).toUpperCase() };
                } catch (e) { return null; }
            }
            let _ipChecking = false, _lastRealTry = 0, _lastTorTry = 0;
            let _prevRunning = null;
            let _prevRunning_first = true;
            function runCircuitCheck(onlyReal) {
                let needReal = !realIpCache;
                let needTor = !onlyReal && (!torIpCache ||
                              (Date.now() - (torIpCache.at || 0) > TOR_IP_CACHE_TTL_MS));
                if (needReal) { realIpEl.textContent = _('Checking\u2026'); } else { paintRealIpFromCache(); }
                if (needTor) { torIpEl.textContent = _('Checking\u2026'); } else { paintTorIpFromCache(); }
                if (!needReal && !needTor) return Promise.resolve();
                if (_ipChecking) return Promise.resolve();
                _ipChecking = true;
                if (needReal) _lastRealTry = Date.now();
                if (needTor) _lastTorTry = Date.now();
                let cmd =
                    "set +e; PORT_SOCKS=$(uci -q get tor_ui.main.socks_port); [ -z \"$PORT_SOCKS\" ] && PORT_SOCKS=9050; " +
                    "TMP=$(mktemp -d /tmp/tor_ui.XXXXXX); trap 'rm -rf $TMP' EXIT HUP INT TERM; find /tmp -maxdepth 1 -type d -name 'tor_ui.*' -mmin +5 -exec rm -rf {} + 2>/dev/null; " +
                    "WAN_IF=$(ip route show default 2>/dev/null | grep -v tun0 | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}' | head -n1); " +
                    "IFACE_OPT=''; [ -n \"$WAN_IF\" ] && IFACE_OPT=\"--interface $WAN_IF\"; ";
                cmd += "PIDS=''; ";
                if (needReal) { cmd += realIpShell('$TMP/real') + 'PIDS="$PIDS $!"; '; }
                if (needTor) {
                    cmd += "( curl -sL -4 -m 10 --socks5-hostname 127.0.0.1:$PORT_SOCKS 'https://check.torproject.org/api/ip' 2>/dev/null > $TMP/tor ) & PIDS=\"$PIDS $!\"; ";
                    cmd += "( curl -sL -4 -m 10 --socks5-hostname 127.0.0.1:$PORT_SOCKS 'https://ipwho.is/' 2>/dev/null > $TMP/torgeo ) & PIDS=\"$PIDS $!\"; ";
                }
                cmd += "_w=0; while [ $_w -lt 11 ]; do _alive=0; for _p in $PIDS; do kill -0 \"$_p\" 2>/dev/null && _alive=1; done; [ \"$_alive\" = 0 ] && break; sleep 1; _w=$((_w+1)); done; for _p in $PIDS; do kill -9 \"$_p\" 2>/dev/null; done; ";
                if (needTor) { cmd += TOR_IP_FROM_JSON_SH + TOR_CC_SH; }
                if (needReal) cmd += "printf 'REALJSON='; cat $TMP/real 2>/dev/null | tr -d '\n\r'; echo; ";
                if (needTor) {
                    cmd +=
                        "printf 'TORJSON='; cat $TMP/tor 2>/dev/null | tr -d '\n\r'; echo; " +
                        "printf 'TORGEOJSON='; cat $TMP/torgeo 2>/dev/null | tr -d '\n\r'; echo; " +
                        "printf 'TORCC=%s\\n' \"$TCC\"; ";
                }
                cmd += "rm -rf $TMP";
                return fs.exec('/bin/sh', ['-c', cmd]).then(function (res) {
                    let out = (res.stdout || '').split('\n');
                    let kv = {};
                    out.forEach(function (line) {
                        let i = line.indexOf('=');
                        if (i === -1) return;
                        kv[line.slice(0, i)] = line.slice(i + 1);
                    });
                    if (needReal) {
                        let g = parseRealGeo(kv.REALJSON);
                        if (g) { setRealIp(g); } else { realIpEl.textContent = _('Failed'); }
                    }
                    if (needTor) {
                        let ex = parseTorExit(kv);
                        if (ex.ip) {
                            torIpCache = { ip: ex.ip, cc: ex.cc, isTor: ex.isTor, at: Date.now() };
                            paintTorIpFromCache();
                        } else {
                            torIpEl.textContent = _('Unavailable');
                            torIpEl.style.color = '#e0b34d';
                        }
                    }
                }).catch(function () {
                    if (needReal) realIpEl.textContent = _('Failed');
                    if (needTor) { torIpEl.textContent = _('Unavailable'); torIpEl.style.color = '#e0b34d'; }
                }).then(function () { _ipChecking = false; });
            }
            function classifyTorLine(line) {
                var severity = 'info';
                if (/leak\s+detected|dns\s+leak|security\s+fail|panic\b/i.test(line)) {
                    severity = 'critical';
                } else if (/\[err\]/i.test(line) ||
                           /\b(error|failed|failure|refused|denied|unable|cannot)\b/i.test(line)) {
                    severity = 'error';
                } else if (/\[warn\]/i.test(line) ||
                           /\b(warn(ing)?|retry|retrying|timed?\s*out|timeout|deprecated|unsupported)\b/i.test(line)) {
                    severity = 'warn';
                } else if (/\b(connected|established|listening|active|running|success|ready|done|up\b)\b/i.test(line)) {
                    severity = 'ok';
                } else if (/\[debug\]/i.test(line)) {
                    severity = 'debug';
                }
                var category = 'info';
                if      (/bootstrapped|bootstrap\b/i.test(line))               category = 'bootstrap';
                else if (/circuit|guard|directory\s+connection/i.test(line))   category = 'circuit';
                else if (/consensus/i.test(line))                              category = 'consensus';
                else if (/\b(socks|socksport|9050)\b/i.test(line))             category = 'socks';
                else if (/\b(dns|dnsport|9053)\b/i.test(line))                 category = 'dns';
                else if (/trans\s*port|transparent/i.test(line))               category = 'firewall';
                else if (/bridge|obfs|snowflake|meek|webtunnel|pluggable/i.test(line)) category = 'bridge';
                else if (/leak/i.test(line))                                   category = 'leak';
                else if (/firewall|kill.?switch|nft|iptables/i.test(line))     category = 'firewall';
                else if (/clock|skew|system\s+time/i.test(line))               category = 'clock';
                else if (/permission\s+denied|chmod|chown|owner/i.test(line))  category = 'permission';
                else if (/network\s+unreachable|no\s+route|no\s+default/i.test(line)) category = 'network';
                else if (/opening\s+.*log|closing|starting|stopping|received\s+signal|shutdown|terminated/i.test(line)) category = 'service';
                if (category === 'info') {
                    if (severity === 'warn') category = 'warn';
                    else if (severity === 'error' || severity === 'critical') category = 'error';
                }
                var time = '';
                var tm = line.match(/(\d{2}:\d{2}:\d{2})/);
                if (tm) time = tm[1];
                var message = line
                    .replace(/^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}(\.\d+)?\s*/, '')
                    .replace(/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?\s*/, '')
                    .replace(/^\[(notice|warn|err|debug)\]\s*/i, '')
                    .trim();
                return { time: time, category: category, severity: severity,
                         message: message, raw: line };
            }
            function parseTorLog(raw) {
                if (!raw) return [];
                var lines = raw.split('\n');
                var events = [];
                var lastWasBootstrap = false;
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line.trim()) continue;
                    var ev = classifyTorLine(line);
                    if (ev.category === 'bootstrap' && lastWasBootstrap) {
                        events[events.length - 1] = ev;
                        continue;
                    }
                    lastWasBootstrap = (ev.category === 'bootstrap');
                    events.push(ev);
                }
                var byKey = {}, uniq = [];
                events.forEach(function (ev) {
                    var key = ev.category + '|' + ev.message
                        .replace(/'[^']*'/g, "'#'")
                        .replace(/\d+(\.\d+)*/g, '#');
                    var prev = byKey[key];
                    if (prev) {
                        uniq.splice(uniq.indexOf(prev), 1);
                        ev.count = (prev.count || 1) + 1;
                    }
                    byKey[key] = ev;
                    uniq.push(ev);
                });
                uniq.forEach(function (ev) {
                    if (ev.count > 1) ev.message = ev.message + ' (\u00d7' + ev.count + ')';
                });
                return uniq;
            }
            function getFilteredEvents() {
                var mode = (logFilterSel && logFilterSel.value) || 'all';
                var q = '';
                return _lastParsedEvents.filter(function (ev) {
                    if (mode === 'security' &&
                        ['leak','firewall','dns','socks','service'].indexOf(ev.category) < 0) return false;
                    if (mode === 'tor' &&
                        ['bootstrap','circuit','consensus','bridge','network','socks','dns'].indexOf(ev.category) < 0) return false;
                    if (mode === 'warn' && ev.severity !== 'warn') return false;
                    if (mode === 'err'  && ev.severity !== 'error' && ev.severity !== 'critical') return false;
                    if (q && ev.raw.toLowerCase().indexOf(q) < 0) return false;
                    return true;
                });
            }
            function buildEventRow(ev) {
                var dotCls = 'tor-log-dot sev-' + ev.severity;
                var catCls = 'tor-log-cat cat-' + ev.category;
                var row = E('div', { class: 'tor-log-row sev-' + ev.severity }, [
                    E('span', { class: dotCls }),
                    E('span', { class: 'tor-log-time' }, ev.time || '\u2014'),
                    E('span', { class: catCls }, ev.category.toUpperCase()),
                    E('span', { class: 'tor-log-msg' }, ev.message)
                ]);
                if (ev.raw && ev.raw.length > ev.message.length) row.title = ev.raw;
                return row;
            }
            function renderLogList() {
                if (!logList) return;
                var filtered = getFilteredEvents();
                var limit = 50;
                var slice = filtered.slice(-limit);
                var counts = { total: _lastParsedEvents.length, warn: 0, err: 0, crit: 0 };
                _lastParsedEvents.forEach(function (ev) {
                    if (ev.severity === 'warn') counts.warn++;
                    else if (ev.severity === 'error') counts.err++;
                    else if (ev.severity === 'critical') counts.crit++;
                });
                void counts;
                var wasAtBottom = logList.scrollTop + logList.clientHeight + 24 >= logList.scrollHeight;
                while (logList.firstChild) logList.removeChild(logList.firstChild);
                var frag = document.createDocumentFragment();
                slice.forEach(function (ev) { frag.appendChild(buildEventRow(ev)); });
                logList.appendChild(frag);
                if (wasAtBottom) {
                    logList.scrollTop = logList.scrollHeight;
                }
            }
            function copyLogToClipboard() {
                var filtered = getFilteredEvents();
                var limit = 50;
                var lines = filtered.slice(-limit).map(function (ev) {
                    var t = ev.time || '--:--:--';
                    var c = ev.category.toUpperCase();
                    while (c.length < 11) c += ' ';
                    return '[' + t + '] ' + c + ' ' + ev.message;
                });
                var text = lines.join('\n');
                if (!text) {
                    ui.addNotification(null, E('p', _('Nothing to copy.')), 'info');
                    return;
                }
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    navigator.clipboard.writeText(text).then(function () {
                        ui.addNotification(null, E('p', _('Log copied to clipboard.')), 'info');
                    }).catch(function () {
                        ui.addNotification(null, E('p', _('Clipboard write failed.')), 'error');
                    });
                }
            }
            function makeTestRow(label) {
                let valueEl = E('span', { class: 'tor-test-value' }, '\u2026');
                let row = E('div', { class: 'tor-test-item' }, [
                    E('span', { class: 'tor-test-label' }, [E('span', { class: 'tor-dot', style: 'color:var(--muted);' }), label]),
                    valueEl
                ]);
                return { row: row, valueEl: valueEl };
            }
            function setTestValue(key, ok, text, color) {
                let t = tests[key];
                if (!t) return;
                t.valueEl.textContent = text;
                t.valueEl.style.color = color || (ok === true ? 'var(--green)' : ok === false ? 'var(--red)' : 'var(--muted)');
            }
            function runAllTests() {
                _lastTorTry = Date.now();
                Object.keys(tests).forEach(function (k) { tests[k].valueEl.textContent = '\u2026'; tests[k].valueEl.style.color = ''; });
                let needReal = !realIpCache;
                let cmd =
                    "set +e; TMP=$(mktemp -d /tmp/tor_ui.XXXXXX); trap 'rm -rf $TMP' EXIT HUP INT TERM; find /tmp -maxdepth 1 -type d -name 'tor_ui.*' -mmin +5 -exec rm -rf {} + 2>/dev/null; " +
                    "PORT_SOCKS=$(uci -q get tor_ui.main.socks_port); [ -z \"$PORT_SOCKS\" ] && PORT_SOCKS=9050; " +
                    "PORT_TRANS=$(uci -q get tor_ui.main.trans_port); [ -z \"$PORT_TRANS\" ] && PORT_TRANS=9040; " +
                    "PORT_DNS=$(uci -q get tor_ui.main.dns_port);  [ -z \"$PORT_DNS\"  ] && PORT_DNS=9053; " +
                    "WAN_IF=$(ip route show default 2>/dev/null | grep -v tun0 | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}' | head -n1); " +
                    "IFACE_OPT=''; [ -n \"$WAN_IF\" ] && IFACE_OPT=\"--interface $WAN_IF\"; " +
                    "echo \"PORTS=$PORT_SOCKS,$PORT_TRANS,$PORT_DNS\"; " +
                    "(ubus -S call service list '{\"name\":\"tor_ui\"}' 2>/dev/null | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null | grep -qx true || { P=$(cat /var/run/tor_ui/tor.pid 2>/dev/null); [ -n \"$P\" ] && kill -0 \"$P\" 2>/dev/null; }) && echo SERVICE=OK || echo SERVICE=FAIL; " +
                    "LOG=/var/log/tor/notices.log; " +
                    "BS_LINE=$(grep -na 'Bootstrapped' \"$LOG\" 2>/dev/null | tail -n1); " +
                    "BS_NUM=$(echo \"$BS_LINE\" | cut -d: -f1); " +
                    "BS_PCT=$(echo \"$BS_LINE\" | grep -oE '[0-9]+%' | tail -n1); " +
                    "STOP_NUM=$(grep -na 'Catching signal\\|exiting cleanly' \"$LOG\" 2>/dev/null | tail -n1 | cut -d: -f1); " +
                    "if [ -n \"$BS_PCT\" ] && { [ -z \"$STOP_NUM\" ] || [ \"$BS_NUM\" -gt \"$STOP_NUM\" ] 2>/dev/null; }; then " +
                    "  echo \"BOOTSTRAP=$BS_PCT\"; " +
                    "else " +
                    "  echo \"BOOTSTRAP=\"; " +
                    "fi; " +
                    "if command -v netstat >/dev/null 2>&1; then " +
                    "  _ltn=\"$(netstat -ltn 2>/dev/null)\"; _lun=\"$(netstat -lun 2>/dev/null)\"; " +
                    "elif command -v ss >/dev/null 2>&1; then " +
                    "  _ltn=\"$(ss -ltn 2>/dev/null)\"; _lun=\"$(ss -lun 2>/dev/null)\"; " +
                    "else _ltn=\"\"; _lun=\"\"; fi; " +
                    "if [ -n \"$_ltn\" ]; then " +
                    "  echo \"$_ltn\" | grep -q \":$PORT_SOCKS \" && echo SOCKS_LISTEN=OK || echo SOCKS_LISTEN=FAIL; " +
                    "  echo \"$_ltn\" | grep -q \":$PORT_TRANS \" && echo TRANS_LISTEN=OK || echo TRANS_LISTEN=FAIL; " +
                    "  echo \"$_lun\" | grep -q \":$PORT_DNS \"  && echo DNS_LISTEN=OK  || echo DNS_LISTEN=FAIL; " +
                    "else echo SOCKS_LISTEN=NA; echo TRANS_LISTEN=NA; echo DNS_LISTEN=NA; fi; " +
                    "nft list table inet tor_ui_fw >/dev/null 2>&1 && echo FW_TABLE=OK || echo FW_TABLE=INACTIVE; " +
                    "echo \"TRANSPORTS=$( (command -v lyrebird >/dev/null 2>&1 && printf 'lyrebird ') ; (command -v obfs4proxy >/dev/null 2>&1 && printf 'obfs4proxy ') ; (command -v snowflake-client >/dev/null 2>&1 && printf 'snowflake-client ') )\"; " +
                    "FULL_TUNNEL=$(uci -q get tor_ui.main.full_tunnel); STRICT_KS=$(uci -q get tor_ui.main.enabled); " +
                    "if [ \"$FULL_TUNNEL\" = \"1\" ] && [ \"$STRICT_KS\" = \"1\" ]; then " +
                    "  IPV6_FWD=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null); " +
                    "  [ \"$IPV6_FWD\" = \"0\" ] && echo IPV6=BLOCKED || echo IPV6=EXPOSED; " +
                    "else echo IPV6=NA; fi; " +
                    "ROUTE_DNS=$(uci -q get tor_ui.main.route_dns); " +
                    "dns_probe_dig() { " +
                    "  dig +time=\"$3\" +tries=1 +short @\"$1\" -p \"$2\" example.com A 2>/dev/null | grep -qE '^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$' && echo OK; " +
                    "}; " +
                    "dns_probe_raw() { " +
                    "  printf '\\x12\\x34\\x01\\x00\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x07example\\x03com\\x00\\x00\\x01\\x00\\x01' | " +
                    "  timeout \"$3\" nc -u -w \"$3\" \"$1\" \"$2\" 2>/dev/null | od -An -tx1 -N4 2>/dev/null | tr -d ' \\n'; " +
                    "}; " +
                    "PIDS=''; " +
                    "if [ \"$ROUTE_DNS\" = \"1\" ]; then " +
                    "  ( if command -v dig >/dev/null 2>&1; then " +
                    "      [ -n \"$(dns_probe_dig 127.0.0.1 \"$PORT_DNS\" 4)\" ] && echo OK > $TMP/dnstor || echo FAIL > $TMP/dnstor; " +
                    "      [ -n \"$(dns_probe_dig 1.1.1.1 53 3)\" ] && echo CONFIRMED > $TMP/dnsleak || echo BLOCKED > $TMP/dnsleak; " +
                    "    else " +
                    "      DNSTOR_RESP=$(dns_probe_raw 127.0.0.1 \"$PORT_DNS\" 4); " +
                    "      case \"$DNSTOR_RESP\" in 1234*) echo OK > $TMP/dnstor ;; *) echo FAIL > $TMP/dnstor ;; esac; " +
                    "      DNSLEAK_RESP=$(dns_probe_raw 1.1.1.1 53 3); " +
                    "      case \"$DNSLEAK_RESP\" in 1234*) echo CONFIRMED > $TMP/dnsleak ;; *) echo BLOCKED > $TMP/dnsleak ;; esac; " +
                    "    fi ) & PIDS=\"$PIDS $!\"; " +
                    "fi; " +
                    "( ping -c1 -W2 1.1.1.1 2>&1 | grep -oE 'time[=<][0-9.]+' | grep -oE '[0-9.]+' | head -1 > $TMP/icmp ) & PIDS=\"$PIDS $!\"; " +
                    "( curl -sL -4 -m 10 --socks5-hostname 127.0.0.1:$PORT_SOCKS https://check.torproject.org/api/ip 2>/dev/null > $TMP/torjson ) & PIDS=\"$PIDS $!\"; " +
                    "( curl -sL -4 -m 10 --socks5-hostname 127.0.0.1:$PORT_SOCKS https://ipwho.is/ 2>/dev/null > $TMP/torgeo ) & PIDS=\"$PIDS $!\"; " +
                    "( curl -sL -4 -m 10 --socks5-hostname 127.0.0.1:$PORT_SOCKS -o /dev/null -w '%{time_appconnect}' https://check.torproject.org 2>/dev/null > $TMP/tcpms ) & PIDS=\"$PIDS $!\"; " +
                    "( curl -sL -4 -m 12 --socks5-hostname 127.0.0.1:$PORT_SOCKS -o /dev/null -w '%{time_total}' https://api.github.com/zen 2>/dev/null > $TMP/urlms ) & PIDS=\"$PIDS $!\"; " +
                    (needReal ? (realIpShell('$TMP/realjson') + 'PIDS="$PIDS $!"; ') : "") +
                    "_w=0; while [ $_w -lt 12 ]; do " +
                    "  _alive=0; for _p in $PIDS; do kill -0 \"$_p\" 2>/dev/null && _alive=1; done; " +
                    "  [ \"$_alive\" = 0 ] && break; sleep 1; _w=$((_w+1)); " +
                    "done; " +
                    "for _p in $PIDS; do kill -9 \"$_p\" 2>/dev/null; done; " +
                    "if [ \"$ROUTE_DNS\" = \"1\" ]; then " +
                    "  echo \"DNS_TOR=$(cat $TMP/dnstor 2>/dev/null || echo FAIL)\"; " +
                    "  echo \"DNS_LEAK=$(cat $TMP/dnsleak 2>/dev/null || echo CONFIRMED)\"; " +
                    "else echo DNS_TOR=NA; echo DNS_LEAK=NA; fi; " +
                    "TORJSON=$(cat $TMP/torjson 2>/dev/null | tr -d '\n\r'); " +
                    "printf 'TORJSON='; printf '%s' \"$TORJSON\"; echo; " +
                    "echo \"$TORJSON\" | grep -q 'IsTor' && echo SOCKS_CURL=OK || echo SOCKS_CURL=FAIL; " +
                    "cp $TMP/torjson $TMP/tor 2>/dev/null; " + TOR_IP_FROM_JSON_SH + TOR_CC_SH +
                    "printf 'TORGEOJSON='; cat $TMP/torgeo 2>/dev/null | tr -d '\\n\\r'; echo; " +
                    "printf 'TORCC=%s\\n' \"$TCC\"; " +
                    "echo \"TCP_MS=$(cat $TMP/tcpms 2>/dev/null)\"; " +
                    "echo \"URL_MS=$(cat $TMP/urlms 2>/dev/null)\"; " +
                    "echo \"ICMP_MS=$(cat $TMP/icmp 2>/dev/null)\"; " +
                    "printf 'REALJSON='; cat $TMP/realjson 2>/dev/null | tr -d '\n\r'; echo; " +
                    "rm -rf $TMP";
                fs.exec('/bin/sh', ['-c', cmd]).then(function (res) {
                  try {
                    let out = (res.stdout || '').split('\n');
                    let kv = {};
                    out.forEach(function (line) {
                        let i = line.indexOf('=');
                        if (i === -1) return;
                        kv[line.slice(0, i)] = line.slice(i + 1);
                    });
                    setTestValue('service', kv.SERVICE === 'OK', kv.SERVICE === 'OK' ? _('Running') : _('Stopped'));
                    if (kv.BOOTSTRAP) {
                        setTestValue('bootstrap', kv.BOOTSTRAP === '100%', kv.BOOTSTRAP);
                        setBootstrapText(kv.BOOTSTRAP);
                    } else {
                        setTestValue('bootstrap', false, '\u2013');
                        setBootstrapText(null);
                    }
                    setTestValue('socks', kv.SOCKS_LISTEN === 'OK', kv.SOCKS_LISTEN === 'NA' ? _('N/A') : kv.SOCKS_LISTEN);
                    setTestValue('trans', kv.TRANS_LISTEN === 'OK', kv.TRANS_LISTEN === 'NA' ? _('N/A') : kv.TRANS_LISTEN);
                    setTestValue('dnsport', kv.DNS_LISTEN === 'OK', kv.DNS_LISTEN === 'NA' ? _('N/A') : kv.DNS_LISTEN);
                    setTestValue('socksurl', kv.SOCKS_CURL === 'OK', kv.SOCKS_CURL);
                    setTestValue('dnstor',
                        kv.DNS_TOR === 'OK' ? true : kv.DNS_TOR === 'NA' ? null : false,
                        kv.DNS_TOR === 'OK' ? _('OK (live query)') : kv.DNS_TOR === 'NA' ? _('Disabled') : _('Not answering'),
                        kv.DNS_TOR === 'OK' ? 'var(--green)' : kv.DNS_TOR === 'NA' ? 'var(--muted)' : 'var(--red)');
                    setTestValue('dnsleak',
                        kv.DNS_LEAK === 'BLOCKED' ? true : kv.DNS_LEAK === 'NA' ? null : false,
                        kv.DNS_LEAK === 'BLOCKED' ? _('Blocked (verified)') : kv.DNS_LEAK === 'NA' ? _('Disabled') : _('LEAK CONFIRMED'),
                        kv.DNS_LEAK === 'BLOCKED' ? 'var(--green)' : kv.DNS_LEAK === 'NA' ? 'var(--muted)' : 'var(--red)');
                    setTestValue('fw', kv.FW_TABLE === 'OK', kv.FW_TABLE === 'OK' ? _('OK') : _('Not Active'));
                    setTestValue('ipv6',
                        (kv.IPV6 === 'BLOCKED' || kv.IPV6 === 'BLOCKED_KERNEL_ON') ? true
                            : kv.IPV6 === 'NA' ? null : false,
                        kv.IPV6 === 'BLOCKED' ? _('Blocked (verified)')
                            : kv.IPV6 === 'BLOCKED_KERNEL_ON' ? _('Blocked (nft rule active)')
                            : kv.IPV6 === 'NA' ? _('N/A (not armed)')
                            : _('EXPOSED'),
                        kv.IPV6 === 'BLOCKED' ? 'var(--green)'
                            : kv.IPV6 === 'BLOCKED_KERNEL_ON' ? 'var(--green)'
                            : kv.IPV6 === 'NA' ? 'var(--muted)'
                            : 'var(--red)');
                    (function () {
                        let tr = (kv.TRANSPORTS || '').trim();
                        let hasCore = /\blyrebird\b|\bobfs4proxy\b/.test(tr);
                        setTestValue('transports',
                            hasCore,
                            tr || _('none'),
                            hasCore ? 'var(--green)' : 'var(--red)');
                    })();
                    let tcpMs = Math.round(parseFloat(kv.TCP_MS || '0') * 1000);
                    setTestValue('tcplatency', tcpMs > 0, tcpMs > 0 ? tcpMs + ' ms' : _('FAIL'));
                    let urlMs = Math.round(parseFloat(kv.URL_MS || '0') * 1000);
                    setTestValue('urltest', urlMs > 0, urlMs > 0 ? _('OK') : _('FAIL'));
                    setTestValue('icmp', !!kv.ICMP_MS, kv.ICMP_MS ? Math.round(parseFloat(kv.ICMP_MS)) + ' ms' : _('FAIL'));
                    if (latIcmp) latIcmp.textContent = kv.ICMP_MS ? Math.round(parseFloat(kv.ICMP_MS)) + ' ms' : _('Error');
                    if (latTls) latTls.textContent = tcpMs > 0 ? tcpMs + ' ms' : _('Error');
                    if (latUrl) latUrl.textContent = (urlMs > 0 && urlMs < 11500) ? urlMs + ' ms' : (urlMs >= 11500 ? _('Timeout') : _('Error'));
                    saveStats(true);
                    statSocks.textContent = kv.SOCKS_LISTEN === 'OK' ? _('Listening') : _('Down');
                    statTrans.textContent = kv.TRANS_LISTEN === 'OK' ? _('Listening') : _('Down');
                    statDns.textContent = kv.DNS_LISTEN === 'OK' ? _('Listening') : _('Down');
                    let exA = parseTorExit(kv);
                    let isTor = exA.isTor, torIp = exA.ip;
                    if (needReal) {
                        let g2 = parseRealGeo(kv.REALJSON);
                        if (g2) { setRealIp(g2); } else { realIpEl.textContent = _('Failed'); }
                    }
                    if (torIp) {
                        let cc = exA.cc;
                        if (!torIpCache || (Date.now() - (torIpCache.at || 0) > TOR_IP_CACHE_TTL_MS)) {
                            torIpCache = { ip: torIp, cc: cc, isTor: isTor, at: Date.now() };
                            paintTorIpFromCache();
                        }
                        setTestValue('exitip', isTor, torIp + (cc ? ' (' + cc + ')' : ''), isTor ? 'var(--green)' : 'var(--red)');
                    } else {
                        if (!torIpCache) { torIpEl.textContent = _('Unavailable'); torIpEl.style.color = '#e0b34d'; }
                        setTestValue('exitip', false, _('N/A'));
                    }
                  } catch (e) {
                  }
                }).catch(function (e) {
                    let msg = (e && e.message) ? e.message : String(e);
                    if (/timed out/i.test(msg)) {
                        ui.addNotification(null, E('p',
                            _('Test round-trip timed out. This is normal while Tor is still bootstrapping or the circuit is slow -- wait for Bootstrap to reach 100% and press "Run All Tests" again.')), 'warning');
                    } else {
                        ui.addNotification(null, E('p', _('Test engine error: ') + msg), 'error');
                    }
                });
            }
            let statDown, statUp, statTotal, latIcmp, latTls, latUrl;
            let testCircuits = makeTestRow(_('Tor Service'));
            tests.service = testCircuits;
            let tBootstrap = makeTestRow(_('Bootstrap')); tests.bootstrap = tBootstrap;
            let tSocks = makeTestRow(_('SOCKS Port')); tests.socks = tSocks;
            let tTrans = makeTestRow(_('TransPort')); tests.trans = tTrans;
            let tDnsPort = makeTestRow(_('DNSPort')); tests.dnsport = tDnsPort;
            let tSocksUrl = makeTestRow(_('SOCKS URL (curl)')); tests.socksurl = tSocksUrl;
            let tTcpLatency = makeTestRow(_('TCP Latency (via Tor)')); tests.tcplatency = tTcpLatency;
            let tDnsTor = makeTestRow(_('DNS via Tor (live query)')); tests.dnstor = tDnsTor;
            let tDnsLeak = makeTestRow(_('DNS Leak Check (verified)')); tests.dnsleak = tDnsLeak;
            let tExitIp = makeTestRow(_('Tor Exit IP')); tests.exitip = tExitIp;
            let tUrlTest = makeTestRow(_('URL Test (via Tor)')); tests.urltest = tUrlTest;
            let tFw = makeTestRow(_('Firewall / nftables')); tests.fw = tFw;
            let tIcmp = makeTestRow(_('ICMP (WAN baseline)')); tests.icmp = tIcmp;
            let tIpv6 = makeTestRow(_('IPv6 Leak (kill-switch)')); tests.ipv6 = tIpv6;
            let tTransports = makeTestRow(_('PT Binaries')); tests.transports = tTransports;
            let wrapper = E('div', { class: 'tor-dash' }, [
                E('div', { class: 'tor-header' }, [
                    E('div', { class: 'tor-logo' }, [ (function () {
                        let d = document.createElement('div');
                        d.innerHTML = TOR_LOGO_SVG;
                        return d.firstChild;
                    })() ]),
                    E('div', {}, [
                        E('h2', {}, _('Tor Anonymous Gateway')),
                        E('p', {}, _('Leak-resistant Tor gateway for OpenWrt 24/25'))
                    ])
                ]),
                E('div', { class: 'tor-top-row' }, [
                E('div', { class: 'tor-topbar' }, [
                    E('div', { class: 'tor-topbar-left' }, [
                        E('div', { class: 'tor-field' }, [
                            E('span', { class: 'k' }, _('STATE')),
                            stateEl = E('span', { class: 'v' }, [
                                E('span', { class: 'tor-dot' }), _('Stopped')
                            ])
                        ]),
                        E('span', { class: 'tor-divider' }),
                        E('div', { class: 'tor-field' }, [
                            E('span', { class: 'k' }, _('BOOTSTRAP')),
                            bootstrapEl = E('span', { class: 'v' }, '\u2013')
                        ]),
                        E('span', { class: 'tor-divider' }),
                        E('div', { class: 'tor-field' }, [
                            E('span', { class: 'k' }, _('CONNECTION')),
                            connEl = E('span', { class: 'v' }, '\u2013')
                        ]),
                        E('span', { class: 'tor-divider' }),
                        E('div', { class: 'tor-field' }, [
                            E('span', { class: 'k' }, _('Real IP')),
                            realIpEl = E('span', { class: 'v' }, _('Checking\u2026'))
                        ]),
                        E('span', { class: 'tor-divider' }),
                        E('div', { class: 'tor-field' }, [
                            E('span', { class: 'k' }, _('TOR Float IP (EXIT)')),
                            torIpEl = E('span', { class: 'v' }, _('Disconnected'))
                        ])
                    ]),
                    E('div', { style: 'display:flex;gap:8px;' }, [
                        E('button', {
                            class: 'tor-btn tor-btn-refresh',
                            click: ui.createHandlerFn(this, function () { clearIpCaches(); runCircuitCheck(); })
                        }, _('Refresh IPs')),
                        E('button', {
                            class: 'tor-btn tor-btn-check',
                            click: ui.createHandlerFn(this, function () { runAllTests(); })
                        }, _('Run All Tests'))
                    ]),
                ]),
                E('div', { class: 'psi-bar' }, [
                    bootstrapBarEl = E('div', { class: 'psi-bar-fill' })
                ])
                ]),
                fullTunnelBannerEl = E('div', {
                    class: 'tor-fulltunnel-banner',
                    style: 'display:none;background:#5a4a1a;border:1px solid var(--amber);border-radius:6px;padding:9px 12px;margin-bottom:10px;color:#f5e0c5;font-size:12px;'
                }, [
                    E('strong', { style: 'color:var(--amber);' }, '\u26a0\ufe0f ' + _('Protection paused: ')),
                    _('Another VPN currently owns the default route. Tor will not weaken to an unprotected fallback.')
                ]),
                E('div', { class: 'tor-grid' }, [
                    E('div', { class: 'tor-col-left' }, [ mapNode ]),
                    E('div', { class: 'tor-col-right' }, [
                        E('div', { class: 'tor-card tor-card-log' }, [
                            E('div', { class: 'tor-log-head' }, [
                                E('h3', {}, _('Logs')),
                                E('div', { class: 'tor-log-actions' }, [
                                    logFilterSel = E('select', {
                                        change: function () { renderLogList(); }
                                    }, [
                                        E('option', { value: 'all' },      _('All')),
                                        E('option', { value: 'security' }, _('Security')),
                                        E('option', { value: 'tor' },      _('Tor')),
                                        E('option', { value: 'warn' },     _('Warnings')),
                                        E('option', { value: 'err' },      _('Errors'))
                                    ]),
                                    E('button', {
                                        class: 'tor-log-btn tor-log-btn-clear',
                                        type: 'button',
                                        click: ui.createHandlerFn(this, function () {
                                            _clearedAtLen = _lastRawLog.length;
                                            _lastParsedEvents = [];
                                            renderLogList();
                                        })
                                    }, _('Clear Log Screen'))
                                ])
                            ]),
                            logList = E('div', { class: 'tor-log-list', id: 'tor_live_log' })
                        ]),
                        E('div', { class: 'tor-card' }, [
                            E('h3', {}, _('Security Status')),
                            E('div', { class: 'tor-tests-grid' }, [
                                testCircuits.row, tTrans.row,
                                tDnsTor.row, tFw.row,
                                tDnsLeak.row, tIpv6.row
                            ]),
                            E('div', { class: 'tor-hint' },
                                _('Anonymity-critical checks only: Tor, TransPort, Tor DNS, firewall, DNS leak protection and IPv6.'))
                        ]),
                        E('div', { class: 'tor-card' }, [
                            E('h3', { class: 'tor-h3-dot' }, _('Tor Performance & Health Stats')),
                            E('div', { class: 'tor-stats tor-stats-4' }, [
                                E('div', { class: 'tor-stat' }, [
                                    E('div', { class: 'tor-stat-label' }, _('CIRCUITS')),
                                    statCircuits = E('div', { class: 'tor-stat-value' }, '\u2013')
                                ]),
                                E('div', { class: 'tor-stat c-green' }, [
                                    E('div', { class: 'tor-stat-label' }, _('DOWNLOAD')),
                                    statDown = E('div', { class: 'tor-stat-value' }, '0.0 KB/s')
                                ]),
                                E('div', { class: 'tor-stat c-blue' }, [
                                    E('div', { class: 'tor-stat-label' }, _('UPLOAD')),
                                    statUp = E('div', { class: 'tor-stat-value' }, '0.0 KB/s')
                                ]),
                                E('div', { class: 'tor-stat c-amber' }, [
                                    E('div', { class: 'tor-stat-label' }, _('TOTAL TRAFFIC')),
                                    statTotal = E('div', { class: 'tor-stat-value' }, '0 B')
                                ])
                            ])
                        ]),
                        E('div', { class: 'tor-card' }, [
                            E('div', { class: 'tor-lat-head' }, [
                                E('div', { class: 'tor-lat-title' }, _('Router Network Latency')),
                                E('span', { class: 'tor-lat-badge' }, _('Router-Side Diagnostics'))
                            ]),
                            E('div', { class: 'tor-lat-grid' }, [
                                E('div', { class: 'tor-lat-tile c-amber' }, [
                                    E('div', { class: 'tor-lat-label' }, _('ICMP Ping')),
                                    latIcmp = E('div', { class: 'tor-lat-value' }, '-')
                                ]),
                                E('div', { class: 'tor-lat-tile c-green' }, [
                                    E('div', { class: 'tor-lat-label' }, _('TLS Ping')),
                                    latTls = E('div', { class: 'tor-lat-value' }, '-')
                                ]),
                                E('div', { class: 'tor-lat-tile c-blue' }, [
                                    E('div', { class: 'tor-lat-label' }, _('URL Test')),
                                    latUrl = E('div', { class: 'tor-lat-value' }, '-')
                                ])
                            ])
                        ])
                    ])
                ])
            ]);
            ['cfx', 'maint'].forEach(function (k) {
                try { if (localStorage.getItem('tor-acc-' + k) === 'open') wrapper.classList.add('tor-' + k + '-open'); } catch (e) {}
            });
            mapNode.addEventListener('change', function (ev) {
                var row = ev.target && ev.target.closest ? ev.target.closest('[data-name="conflux_enabled"]') : null;
                if (row) setCfxBadge(String(ev.target.value));
            });
            let settingsCard = wrapper.querySelector('.tor-col-left');
            if (settingsCard) {
                settingsCard.insertBefore(serviceControlRow, settingsCard.firstChild);
            } else {
                wrapper.insertBefore(serviceControlRow, wrapper.firstChild);
            }
            function setState(color, text) {
                stateEl.style.color = color;
                stateEl.lastChild.textContent = text;
            }
            function setBootstrapText(pct) {
                if (!bootstrapEl) return;
                let n = parseInt(pct, 10);
                if (isNaN(n)) {
                    bootstrapEl.textContent = '\u2013';
                    bootstrapEl.style.color = '';
                    return;
                }
                n = Math.max(0, Math.min(100, n));
                bootstrapEl.textContent = n + '%' + (n === 100 ? ' (' + _('Done') + ')' : '');
                bootstrapEl.style.color = (n === 100) ? '#62D68E'
                    : 'hsl(' + Math.round(n * 1.2) + ', 72%, 60%)';
            }
            let _barKind = null;
            function barSet(kind, pct) {
                let fill = bootstrapBarEl;
                if (!fill) return;
                let prev = _barKind;
                if (kind === 'connecting') {
                    let w = Math.max(6, Math.min(100, parseInt(pct, 10) || 0));
                    fill.className = 'psi-bar-fill up busy';
                    fill.style.width = w + '%';
                } else if (kind === 'connected') {
                    fill.className = 'psi-bar-fill up done';
                    fill.style.width = '100%';
                } else {
                    fill.className = (prev === 'connected' || prev === 'connecting') ? 'psi-bar-fill down' : 'psi-bar-fill';
                    fill.style.width = '0%';
                }
                _barKind = kind;
            }
            let _lastFuncCheck = 0, _lastFuncOk = null, _funcChecking = false, _autoTestRan = false;
            function checkFunctional() {
                if (_funcChecking) return;
                _funcChecking = true;
                fs.exec('/bin/sh', ['-c',
                    "PORT_SOCKS=$(uci -q get tor_ui.main.socks_port); [ -z \"$PORT_SOCKS\" ] && PORT_SOCKS=9050; " +
                    "curl -sL -4 -m 8 --socks5-hostname 127.0.0.1:$PORT_SOCKS https://check.torproject.org/api/ip 2>/dev/null | grep -q '\"IsTor\"[[:space:]]*:[[:space:]]*true' && echo OK || echo FAIL"
                ]).then(function (res) {
                    _lastFuncOk = (res.stdout || '').trim() === 'OK';
                    _lastFuncCheck = Date.now();
                }).catch(function () {
                    _lastFuncOk = false;
                    _lastFuncCheck = Date.now();
                }).finally(function () { _funcChecking = false; });
            }
            function renderConn(ckv, running) {
                if (!connEl) return;
                let txt = ckv.CONNRESOLVED || ckv.CONNMODE || '\u2013';
                let racing = ckv.RACE_state === 'running';
                if (racing) {
                    let parts = [];
                    Object.keys(ckv).forEach(function (k) {
                        if (k.indexOf('RACE_racer.') === 0) parts.push(k.slice(11) + ' ' + ckv[k] + '%');
                    });
                    txt = _('Racing') + (parts.length ? ': ' + parts.join(' | ') : '\u2026');
                }
                if (!racing) txt = String(txt).replace(/^\s*race\s*(->|\u2192)\s*/i, '');
                connEl.title = txt;
                connEl.textContent = txt;
                connEl.style.color = racing ? '#e0b34d' : '';
            }
            poll.add(function () {
                return Promise.all([
                    fs.read_direct('/var/log/tor/notices.log', 'text').catch(function () { return ''; }),
                    fs.exec('/bin/sh', ['-c', "(ubus -S call service list '{\"name\":\"tor_ui\"}' 2>/dev/null | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null | grep -qx true || { P=\$(cat /var/run/tor_ui/tor.pid 2>/dev/null); [ -n \"\$P\" ] && kill -0 \"\$P\" 2>/dev/null; }) && echo 1 || echo 0"] ),
                    fs.exec('/bin/sh', ['-c', "cat /var/run/tor_ui/conn.status 2>/dev/null; sed 's/^/RACE_/' /var/run/tor_ui/race.status 2>/dev/null; true"]).catch(function () { return { stdout: '' }; })
                ]).then(function (res) {
                    let rawLog = (res[0] || '').trim();
                    let logText = rawLog || _('No logs available.');
                    _lastRawLog = rawLog;
                    if (_clearedAtLen > rawLog.length) _clearedAtLen = 0;
                    var viewText = _clearedAtLen > 0
                        ? rawLog.slice(_clearedAtLen).replace(/^\n+/, '')
                        : rawLog;
                    _lastParsedEvents = parseTorLog(viewText);
                    renderLogList();
                    if (fullTunnelBannerEl) {
                        fullTunnelBannerEl.style.display =
                            /transparent Tor routing disabled for this start|refusing to start Tor while another VPN owns|conflict_policy=block/.test(logText) ? '' : 'none';
                    }
                    let running = (res[1].stdout || '').trim() === '1';
                    let _justStopped = (_prevRunning === true && !running);
                    _prevRunning = running;
                    let ckv = {};
                    String((res[2] && res[2].stdout) || '').split('\n').forEach(function (l) {
                        let i = l.indexOf('=');
                        if (i > 0) ckv[l.slice(0, i)] = l.slice(i + 1);
                    });
                    renderConn(ckv, running);
                    if (_prevRunning_first) {
                        _prevRunning_first = false;
                        if (running) { if (!loadRealIpFromStore()) _lastRealTry = 0; }
                        else dropRealIp();   // stopped at page load: stored value may be stale
                    }
                    if (!realIpCache && !_ipChecking && Date.now() - _lastRealTry > 30000) runCircuitCheck(true);
                    if (!running) {
                        if (ckv.RACE_state === 'running') setState('#e0b34d', _('Racing'));
                        else setState('#92a0b0', _('Stopped'));
                        statCircuits.textContent = '\u2013';
                        setBootstrapText(null);
                        barSet('stopped');
                        resetStatsUi();
                        if (!_statsWiped) { _statsWiped = true; wipeStats(); }
                        _lastFuncOk = null; _lastFuncCheck = 0; _autoTestRan = false;
                        if (torIpCache) { torIpCache = null; torIpEl.textContent = _('Disconnected'); torIpEl.style.color = ''; }
                        if (_justStopped) { dropRealIp(); realIpEl.textContent = _('Checking\u2026'); _lastRealTry = 0; runCircuitCheck(true); }
                    } else {
                        _statsWiped = false;
                        let bsRe = /Bootstrapped (\d+)%/g, bsMatch, lastBsPct = null, lastBsIdx = -1;
                        while ((bsMatch = bsRe.exec(logText)) !== null) {
                            lastBsPct = bsMatch[1];
                            lastBsIdx = bsMatch.index;
                        }
                        let stopIdx = Math.max(logText.lastIndexOf('Catching signal'), logText.lastIndexOf('exiting cleanly'));
                        if (lastBsPct === '100' && lastBsIdx > stopIdx) {
                            setBootstrapText(100);
                            barSet('connecting', 100);
                            if (!_funcChecking && (Date.now() - _lastFuncCheck > 15000)) checkFunctional();
                            if (_lastFuncOk === true) {
                                setState('#4fd88a', _('Connected'));
                                statCircuits.textContent = _('Active');
                                barSet('connected');
                                if (!torIpCache && !_ipChecking && Date.now() - _lastTorTry > 20000) runCircuitCheck();
                                if (!_autoTestRan) { _autoTestRan = true; runAllTests(); }
                            } else if (_lastFuncOk === false) {
                                setState('var(--red)', _('Degraded') + ' (' + _('bootstrapped but circuit unusable') + ')');
                                statCircuits.textContent = _('Unusable');
                            } else {
                                setState('#e0b34d', _('Verifying\u2026'));
                                statCircuits.textContent = _('Verifying');
                            }
                        } else if (lastBsPct !== null && lastBsIdx > stopIdx) {
                            _lastFuncOk = null; _lastFuncCheck = 0; _autoTestRan = false;
                            setState('#e0b34d', _('Connecting') + ' (' + lastBsPct + '%)');
                            statCircuits.textContent = _('Building');
                            setBootstrapText(lastBsPct);
                            barSet('connecting', lastBsPct);
                        } else {
                            setState('#e0b34d', _('Connecting') + ' (0%)');
                            statCircuits.textContent = _('Building');
                            setBootstrapText(0);
                            barSet('connecting', 0);
                        }
                    }
                }).catch(function () {  });
            }, 5);
            let _trafPrev = null;
            function fmtBytes(n) {
                var u = ['B', 'KB', 'MB', 'GB', 'TB'], i = 0;
                while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
                return (i === 0 ? String(Math.round(n)) : n.toFixed(n >= 100 ? 0 : 1)) + ' ' + u[i];
            }
            function fmtRate(bps) {
                var kb = bps / 1024;
                return kb >= 1024 ? (kb / 1024).toFixed(1) + ' MB/s' : kb.toFixed(1) + ' KB/s';
            }
            function trafficReset() {
                _trafPrev = null;
                if (statDown) statDown.textContent = '0.0 KB/s';
                if (statUp) statUp.textContent = '0.0 KB/s';
                if (statTotal) statTotal.textContent = '0 B';
            }
            let _trafBase = 0;
            const STATS_FILE = '/tmp/tor_ui_stats.json';
            let _statsLive = false, _statsSavedAt = 0;
            function wipeStats() {
                fs.exec('/bin/sh', ['-c', 'rm -f ' + STATS_FILE + ' ' + STATS_FILE + '.tmp']).catch(function () {});
            }
            let _statsWiped = false;
            function resetStatsUi() {
                trafficReset(); _trafBase = 0;
                if (latIcmp) latIcmp.textContent = '-';
                if (latTls) latTls.textContent = '-';
                if (latUrl) latUrl.textContent = '-';
            }
            function saveStats(force) {
                if (_prevRunning !== true) return;
                let now = Date.now();
                if (!force && now - _statsSavedAt < 4000) return;
                _statsSavedAt = now;
                try {
                    let txt = function (el) { return el ? String(el.textContent).replace(/[^\w\s.\u2013%\/-]/g, '') : ''; };
                    let snap = {
                        v: 1, at: now,
                        circ: txt(statCircuits), down: txt(statDown), up: txt(statUp), total: txt(statTotal),
                        icmp: txt(latIcmp), tls: txt(latTls), url: txt(latUrl),
                        base: _trafBase, prev: _trafPrev
                    };
                    let json = JSON.stringify(snap).replace(/'/g, '');
                    fs.exec('/bin/sh', ['-c', "printf '%s' '" + json + "' > " + STATS_FILE + ".tmp && mv -f " + STATS_FILE + ".tmp " + STATS_FILE]).catch(function () {});
                } catch (e) {  }
            }
            function loadStats() {
                torServiceRunningOnce().then(function (isUp) {
                    if (!isUp) { wipeStats(); return null; }
                    return fs.exec('/bin/sh', ['-c', 'cat ' + STATS_FILE + ' 2>/dev/null']);
                }).then(function (res) {
                    if (!res || _statsLive || _prevRunning === false) return;
                    let d = JSON.parse(String((res && res.stdout) || '').trim());
                    if (!d || d.v !== 1) return;
                    let put = function (el, v) { if (el && v) el.textContent = v; };
                    put(statCircuits, d.circ); put(statDown, d.down); put(statUp, d.up); put(statTotal, d.total);
                    put(latIcmp, d.icmp); put(latTls, d.tls); put(latUrl, d.url);
                    if (!_trafPrev && d.prev && typeof d.prev.r === 'number') { _trafPrev = d.prev; _trafBase = d.base || 0; }
                }).catch(function () {  });
            }
            poll.add(function () {
                if (_prevRunning !== true) { resetStatsUi(); return Promise.resolve(); }
                return fs.exec('/bin/sh', ['/usr/libexec/tor_ui/rpc.sh', 'traffic']).then(function (res) {
                    if (_prevRunning !== true) { resetStatsUi(); return; }
                    _statsLive = true;
                    var out = (res && res.stdout) || '';
                    var r = /traffic\/read=(\d+)/.exec(out), w = /traffic\/written=(\d+)/.exec(out), wan = false;
                    if (!r || !w) { trafficReset(); _trafBase = 0; return; }
                    var rb = parseInt(r[1], 10), wb = parseInt(w[1], 10), now = Date.now();
                    if (wan && !_trafPrev) _trafBase = rb + wb;
                    if (_trafPrev && rb >= _trafPrev.r && wb >= _trafPrev.w && now > _trafPrev.t) {
                        var dt = (now - _trafPrev.t) / 1000;
                        statDown.textContent = fmtRate((rb - _trafPrev.r) / dt);
                        statUp.textContent = fmtRate((wb - _trafPrev.w) / dt);
                    } else {
                        statDown.textContent = '0.0 KB/s';
                        statUp.textContent = '0.0 KB/s';
                    }
                    statTotal.textContent = fmtBytes(Math.max(0, rb + wb - (wan ? _trafBase : 0)));
                    _trafPrev = { r: rb, w: wb, t: now };
                    saveStats();
                }).catch(function () {  });
            }, 5);
            loadStats();
            return wrapper;
        });
    }
});
EOF
echo "3. Registering the LuCI menu entry (VPN > Tor VPN)..."
mkdir -p /usr/share/luci/menu.d
cat << 'EOF' > /usr/share/luci/menu.d/luci-app-tor.json
{
	"admin/vpn": {
		"title": "VPN",
		"order": 60,
		"action": {
			"type": "alias",
			"path": "admin/vpn/tor"
		}
	},
	"admin/vpn/tor": {
		"title": "Tor VPN",
		"order": 65,
		"action": {
			"type": "view",
			"path": "tor/settings"
		},
		"depends": {
			"uci": {
				"tor_ui": true
			}
		}
	}
}
EOF
echo "4. Creating hardened init.d script for procd..."
cat << 'EOF' > /etc/init.d/tor_ui
#!/bin/sh /etc/rc.common
VERSION="83"
START=99
STOP=10
USE_PROCD=1
EXTRA_COMMANDS="apply purge refresh_fw forget_memory clear_cache unblock ks_sync"
EXTRA_HELP="	apply		Apply saved settings to a running Tor tunnel
	purge		Stop Tor and wipe all cached state (consensus, keys, logs)
	forget_memory	Forget the Memory mode record (last mode + proven bridges)
	unblock		Release the Kill Switch after Stop (only when Tor is not running)
	ks_sync		Auto Connect OFF + Tor stopped: release any held block now
	clear_cache	Delete only the downloaded network cache (cached-*); keeps
			state, keys/ and pt_state/, then restarts Tor if it was running
	refresh_fw	Re-render the firewall include (used by WAN hotplug
			so the localhost_proxy source-IP exclusion tracks the
			current WAN address without restarting Tor)"
FW_TABLE="tor_ui_fw"
LOG_DIR="/var/log/tor"
TOR_BIN="/usr/sbin/tor"
FW_INCLUDE="/etc/firewall.tor_ui"
LOCK_PATH="/var/run/tor_ui.lock"
acquire_lock() {
	mkdir -p /var/run 2>/dev/null || return 1
	if command -v flock >/dev/null 2>&1; then
		exec 9>"$LOCK_PATH"
		flock -n 9
		return $?
	fi
	local lockdir="${LOCK_PATH}.d" oldpid
	if mkdir "$lockdir" 2>/dev/null; then
		echo "$$" > "$lockdir/pid"
		trap 'rm -rf "$lockdir"' EXIT
		return 0
	fi
	oldpid=$(cat "$lockdir/pid" 2>/dev/null)
	case "$oldpid" in ''|*[!0-9]*) return 1 ;; esac
	kill -0 "$oldpid" 2>/dev/null && return 1
	rm -rf "$lockdir" 2>/dev/null || return 1
	mkdir "$lockdir" 2>/dev/null || return 1
	echo "$$" > "$lockdir/pid"
	trap 'rm -rf "$lockdir"' EXIT
	return 0
}
flush_conntrack() {
	command -v conntrack >/dev/null 2>&1 || return 0
	local lan_dev lan_subnet
	lan_dev=$(uci -q get network.lan.device)
	[ -n "$lan_dev" ] || lan_dev="br-lan"
	lan_subnet=$(ip -o -4 addr show "$lan_dev" 2>/dev/null | awk '{print $4}' | head -n1)
	if [ -n "$lan_subnet" ]; then
		conntrack -D -s "$lan_subnet" >/dev/null 2>&1 || true
	else
		logger -t tor_ui "flush_conntrack: LAN subnet unknown, skipped (no global flush)"
	fi
	return 0
}
wan_is_up() {
	local iface any_iface route
	if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
		for iface in $(ubus -S list network.interface 2>/dev/null | sed 's/^network.interface.//'); do
			route=$(ubus -S call "network.interface.$iface" status 2>/dev/null)
			[ -n "$route" ] || continue
			if [ -n "$(printf '%s' "$route" | jsonfilter -e '@.route[@.target="0.0.0.0"].nexthop' 2>/dev/null)" ]; then
				return 0
			fi
			if [ -n "$(printf '%s' "$route" | jsonfilter -e '@.route[@.target="0.0.0.0/0"].nexthop' 2>/dev/null)" ]; then
				return 0
			fi
			if [ -n "$(printf '%s' "$route" | jsonfilter -e '@.route[*].gateway' 2>/dev/null | grep -v '^$' | head -n1)" ]; then
				return 0
			fi
		done
	fi
	if ip route show default 2>/dev/null | grep -q '^default'; then
		return 0
	fi
	return 1
}
detect_wan_dev() {
	local dev
	if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
		dev=$(ubus -S call network.interface.wan status 2>/dev/null | jsonfilter -e '@.l3_device' 2>/dev/null)
	fi
	[ -n "$dev" ] || dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev") print $(i+1)}' | grep -Ev '^(tun|tap|wg|tailscale|zt|ipsec|utun)' | head -n1)
	[ -n "$dev" ] || dev=$(uci -q get network.wan.device)
	[ -n "$dev" ] || dev=$(uci -q get network.wan.ifname)
	echo "$dev"
}
tor_is_running() {
	if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
		local running
		running=$(ubus -S call service list '{"name":"tor_ui"}' 2>/dev/null | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null)
		[ -n "$running" ] && { [ "$running" = "true" ] && return 0 || return 1; }
	fi
	local pid
	pid=$(cat /var/run/tor_ui/tor.pid 2>/dev/null)
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}
config_fingerprint() {
	printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
		"$(uci -q get tor_ui.main.full_tunnel)" \
		"$(uci -q get tor_ui.main.route_dns)" \
		"$(uci -q get tor_ui.main.custom_exit)" \
		"$(uci -q get tor_ui.main.exit_node)" \
		"$(uci -q get tor_ui.main.strict_exit)" \
		"$(uci -q get tor_ui.main.use_bridge)" \
		"$(uci -q get tor_ui.main.bridge_mode)" \
		"$(uci -q get tor_ui.main.bridge_lines)" \
		"1" \
		"$(uci -q get tor_ui.main.socks_port)" \
		"$(uci -q get tor_ui.main.trans_port)" \
		"$(uci -q get tor_ui.main.dns_port)" \
		"$(uci -q get tor_ui.main.localhost_proxy)" \
		"race" \
		"$RACE_RACERS" \
		"-" \
		"-" \
		"-" \
		"-" \
		"-" \
		"-" \
		"-" \
		"-" \
		"$RACE_TIMEOUT"
}
vpn_conflict_reason() {
	local sec proto enabled redirect_gw
	for sec in $(uci show openvpn 2>/dev/null | grep "=openvpn$" | cut -d. -f2 | cut -d= -f1); do
		enabled=$(uci -q get openvpn.$sec.enabled)
		[ "$enabled" = "1" ] || continue
		redirect_gw=$(uci -q get openvpn.$sec.redirect_gateway)
		if [ -n "$redirect_gw" ] || uci -q get openvpn.$sec.client >/dev/null; then
			pgrep -f "openvpn.*$sec" >/dev/null 2>&1 && {
				echo "OpenVPN client '$sec' is already routing LAN traffic (redirect-gateway)"
				return 0
			}
		fi
	done
	for sec in $(uci show network 2>/dev/null | grep "\.allowed_ips=" | grep "0\.0\.0\.0/0" | cut -d. -f2); do
		local iface
		iface=$(uci -q get network.$sec.interface 2>/dev/null)
		[ -z "$iface" ] && iface=$(echo "$sec" | sed -n "s/^\(wg_[^_]*\).*/\1/p")
		if ip route show default dev "$iface" 2>/dev/null | grep -q "^default"; then
			echo "WireGuard peer on '$iface' already carries a default route (0.0.0.0/0)"
			return 0
		fi
	done
	local wan_dev_check
	wan_dev_check=$(detect_wan_dev)
	for tun_iface in $(ip route show default 2>/dev/null | awk '{print $5}' | sort -u); do
		[ -z "$tun_iface" ] && continue
		[ "$tun_iface" = "$wan_dev_check" ] && continue
		case "$tun_iface" in eth*|br-*) continue ;; esac
		echo "Tunnel interface '$tun_iface' is carrying the default route -- may conflict with Full Tunnel"
		return 0
	done
	echo ""
	return 1
}
FW_CHANGED=0
write_fw_include() {
	local full_tunnel="$1" route_dns="$2" trans_port="$3" strict_ks="$4"
	local localhost_proxy="${5:-0}"
	local tor_uid="${6:-0}"
	local lan_dev wan_dev lan_subnet wan_ip
	lan_dev=$(uci -q get network.lan.device)
	[ -n "$lan_dev" ] || lan_dev="br-lan"
	wan_dev=$(detect_wan_dev)
	wan_ip=""
	[ -n "$wan_dev" ] && wan_ip=$(ip -o -4 addr show dev "$wan_dev" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
	lan_subnet=""
	[ -n "$lan_dev" ] && lan_subnet=$(ip -o -4 addr show "$lan_dev" 2>/dev/null | awk '{print $4}' | head -n1)
	FW_CHANGED=0
	local new_content="${FW_INCLUDE}.new"
	rm -f "$new_content"
	cat > "$new_content" <<NFT
table inet $FW_TABLE
delete table inet $FW_TABLE
table inet $FW_TABLE {
	chain dstnat {
		type nat hook prerouting priority -99;
		policy accept;
$(if [ "$full_tunnel" = "1" ]; then
	printf '\t\tiifname "%s" ip daddr 10.192.0.0/10 meta l4proto tcp counter redirect to :%s\n' "$lan_dev" "$trans_port"
fi)
		ip daddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 127.0.0.0/8 } counter return;
$(if [ "$route_dns" = "1" ]; then
	printf '\t\tiifname "%s" udp dport 53 counter redirect to :53\n' "$lan_dev"
	printf '\t\tiifname "%s" tcp dport 53 counter redirect to :53\n' "$lan_dev"
fi)
$(if [ "$full_tunnel" = "1" ]; then
	printf '\t\tiifname "%s" meta l4proto tcp counter redirect to :%s\n' "$lan_dev" "$trans_port"
fi)
	}

$(if [ "$route_dns" = "1" ]; then
	cat <<'DNSCHAIN'
	chain out_dns_block {
		type filter hook output priority 0;
		policy accept;
		oifname != "lo" udp dport 53 counter drop;
		oifname != "lo" tcp dport 53 counter drop;
	}
DNSCHAIN
fi)
$(if [ "$route_dns" = "1" ] && [ -n "$wan_dev" ]; then
	cat <<'FWDCHAIN'
	chain fwd_dns_block {
		type filter hook forward priority 0;
		policy accept;
FWDCHAIN
	printf '\t\toifname "%s" udp dport 53 counter drop;\n' "$wan_dev"
	printf '\t\toifname "%s" tcp dport 53 counter drop;\n' "$wan_dev"
	printf '\t}\n'
fi)
$(if [ "$route_dns" = "1" ]; then
	cat <<'DOHDOTCHAIN'
	chain fwd_doh_dot_block {
		type filter hook forward priority 0;
		policy accept;
		ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9, 149.112.112.112, 208.67.222.222, 208.67.220.220, 94.140.14.14, 94.140.15.15, 76.76.2.0, 76.76.10.0, 45.90.28.0, 45.90.30.0 } tcp dport { 443, 853 } counter drop;
		ip daddr { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9, 149.112.112.112, 208.67.222.222, 208.67.220.220, 94.140.14.14, 94.140.15.15 } udp dport 443 counter drop;
	}
DOHDOTCHAIN
fi)
$(if [ "$full_tunnel" = "1" ]; then
	cat <<'LEAKCHAIN'
	chain fwd_leak_guard {
		type filter hook forward priority 1; policy accept;
LEAKCHAIN
	if [ -n "$lan_dev" ]; then
		printf '\t\tiifname "%s" meta nfproto ipv6 counter drop;\n' "$lan_dev"
		printf '\t\tiifname "%s" oifname != "%s" meta l4proto != tcp counter drop;\n' "$lan_dev" "$lan_dev"
	fi
	printf '\t}\n'
fi)
$(if [ "$strict_ks" = "1" ]; then
	cat <<'KSCHAIN'
	chain fwd_killswitch {
		type filter hook forward priority 1;
		policy accept;
KSCHAIN
	if [ -n "$lan_dev" ]; then
		printf '\t\tiifname "%s" meta nfproto ipv6 counter drop;\n' "$lan_dev"
		printf '\t\tiifname "%s" oifname != "%s" meta nfproto ipv4 counter drop;\n' "$lan_dev" "$lan_dev"
	else
		printf '\t\tcounter drop;\n'
	fi
	printf '\t}\n'
fi)
$(if [ "$localhost_proxy" = "1" ] && [ "$full_tunnel" = "1" ]; then
	cat <<'OUTCHAIN'
	chain output_proxy {
		type nat hook output priority -100; policy accept;
OUTCHAIN
	printf '\t\tip daddr 127.0.0.0/8 counter return;\n'
	printf '\t\tip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 } counter return;\n'
	[ -n "$lan_subnet" ] && printf '\t\tip daddr %s counter return;\n' "$lan_subnet"
	printf '\t\tmeta skuid %s counter return;\n' "$tor_uid"
	[ -n "$wan_ip" ] && printf '\t\tip saddr %s counter return;\n' "$wan_ip"
	printf '\t\tmeta l4proto tcp counter redirect to :%s;\n' "$trans_port"
	printf '\t}\n'
fi)
}
NFT
	if command -v nft >/dev/null 2>&1; then
		if ! nft -c -f "$new_content" >/dev/null 2>"$LOG_DIR/firewall-verify.log"; then
			echo "ERROR: generated nftables rules failed validation; keeping previous ruleset." >> "$LOG_DIR/notices.log"
			cat "$LOG_DIR/firewall-verify.log" >> "$LOG_DIR/notices.log"
			rm -f "$new_content"
			return 1
		fi
	fi
	if [ -f "$FW_INCLUDE" ] && cmp -s "$new_content" "$FW_INCLUDE"; then
		rm -f "$new_content"
	else
		mv "$new_content" "$FW_INCLUDE"
		chmod 600 "$FW_INCLUDE"
		FW_CHANGED=1
	fi
	if [ "$(uci -q get firewall.tor_ui_include.enabled)"  != "1" ] ||
	   [ "$(uci -q get firewall.tor_ui_include.type)"     != "nftables" ] ||
	   [ "$(uci -q get firewall.tor_ui_include.path)"     != "$FW_INCLUDE" ] ||
	   [ "$(uci -q get firewall.tor_ui_include.position)" != "ruleset-post" ]; then
		uci -q batch <<-UCI
			delete firewall.tor_ui_include
			set firewall.tor_ui_include=include
			set firewall.tor_ui_include.enabled='1'
			set firewall.tor_ui_include.type='nftables'
			set firewall.tor_ui_include.path='$FW_INCLUDE'
			set firewall.tor_ui_include.position='ruleset-post'
		UCI
		uci commit firewall
		FW_CHANGED=1
	fi
	return 0
}
remove_fw_include() {
	FW_CHANGED=0
	if [ -n "$(uci -q get firewall.tor_ui_include)" ]; then
		uci -q delete firewall.tor_ui_include
		uci commit firewall
		FW_CHANGED=1
	fi
	if nft delete table inet "$FW_TABLE" 2>/dev/null; then
		FW_CHANGED=1
	fi
	if [ -f "$FW_INCLUDE" ]; then
		rm -f "$FW_INCLUDE"
		FW_CHANGED=1
	fi
	return 0
}
set_killswitch() {
	local enable="$1" state_dir="/etc/tor/tor_ui-state"
	local state_file="/etc/tor/tor_ui-state/ipv6fwd.backup"
	local sysctl_file="/etc/sysctl.d/99-tor-ui-killswitch.conf" all_value default_value
	mkdir -p "$state_dir" || return 1
	chmod 700 "$state_dir" 2>/dev/null || true
	if [ "$enable" = "1" ]; then
		if [ ! -f "$state_file" ]; then
			all_value=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null); [ -n "$all_value" ] || all_value=0
			default_value=$(cat /proc/sys/net/ipv6/conf/default/forwarding 2>/dev/null); [ -n "$default_value" ] || default_value=0
			{ echo "ALL=$all_value"; echo "DEFAULT=$default_value"; } > "$state_file" || return 1
			chmod 600 "$state_file" 2>/dev/null || true
		fi
		echo 0 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || return 1
		echo 0 > /proc/sys/net/ipv6/conf/default/forwarding 2>/dev/null || return 1
		mkdir -p /etc/sysctl.d
		cat > "$sysctl_file" <<'SYSCTL'
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.default.forwarding=0
SYSCTL
	else
		if [ -f "$state_file" ]; then
			ALL= DEFAULT=; . "$state_file"
			case "$ALL" in 0|1) ;; *) ALL=0 ;; esac
			case "$DEFAULT" in 0|1) ;; *) DEFAULT=0 ;; esac
			echo "$ALL" > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true
			echo "$DEFAULT" > /proc/sys/net/ipv6/conf/default/forwarding 2>/dev/null || true
			rm -f "$state_file"
		fi
		rm -f "$sysctl_file"
	fi
	return 0
}
configure_dns_over_tor() {
	local enable="$1" dns_port="$2"
	local backup_file="/etc/tor/tor_ui-state/dnsmasq.backup"
	local before after
	before=$(uci export dhcp 2>/dev/null)
	if [ "$enable" = "1" ]; then
		mkdir -p "$(dirname "$backup_file")"
		chmod 700 "$(dirname "$backup_file")" 2>/dev/null || true
		if [ ! -f "$backup_file" ]; then
			{
				echo "boguspriv=$(uci -q get dhcp.@dnsmasq[0].boguspriv)"
				echo "rebind_protection=$(uci -q get dhcp.@dnsmasq[0].rebind_protection)"
				echo "noresolv=$(uci -q get dhcp.@dnsmasq[0].noresolv)"
				echo "resolvfile=$(uci -q get dhcp.@dnsmasq[0].resolvfile)"
				uci -q get dhcp.@dnsmasq[0].server | tr ' ' '\n' | sed 's/^/server=/'
			} > "$backup_file"
			chmod 600 "$backup_file" 2>/dev/null || true
		fi
		uci set dhcp.@dnsmasq[0].boguspriv='0'
		uci set dhcp.@dnsmasq[0].rebind_protection='0'
		uci set dhcp.@dnsmasq[0].noresolv='1'
		uci -q set dhcp.@dnsmasq[0].resolvfile=''
		uci -q delete dhcp.@dnsmasq[0].server
		uci add_list dhcp.@dnsmasq[0].server="127.0.0.1#$dns_port"
		nft delete table inet tor_dns_block 2>/dev/null || true
	else
		if [ -f "$backup_file" ]; then
			uci -q delete dhcp.@dnsmasq[0].server
			while IFS='=' read -r _k _v; do
				case "$_k" in
					boguspriv) [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].boguspriv="$_v" || uci -q delete dhcp.@dnsmasq[0].boguspriv ;;
					rebind_protection) [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].rebind_protection="$_v" || uci -q delete dhcp.@dnsmasq[0].rebind_protection ;;
					noresolv) [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].noresolv="$_v" || uci -q delete dhcp.@dnsmasq[0].noresolv ;;
					resolvfile) [ -n "$_v" ] && uci set dhcp.@dnsmasq[0].resolvfile="$_v" || uci -q delete dhcp.@dnsmasq[0].resolvfile ;;
					server) [ -n "$_v" ] && uci add_list dhcp.@dnsmasq[0].server="$_v" ;;
				esac
			done < "$backup_file"
			rm -f "$backup_file"
		else
			uci set dhcp.@dnsmasq[0].boguspriv='1'
			uci set dhcp.@dnsmasq[0].rebind_protection='1'
			uci set dhcp.@dnsmasq[0].noresolv='0'
			uci -q delete dhcp.@dnsmasq[0].resolvfile
			uci -q delete dhcp.@dnsmasq[0].server
			for _rf in /tmp/resolv.conf.d/resolv.conf.auto /tmp/resolv.conf /etc/resolv.conf; do
				[ -s "$_rf" ] && { uci set dhcp.@dnsmasq[0].resolvfile="$_rf"; break; }
			done
		fi
	fi
	after=$(uci export dhcp 2>/dev/null)
	if [ "$before" = "$after" ]; then
		return 0
	fi
	uci commit dhcp
	/etc/init.d/dnsmasq reload >/dev/null 2>&1 || /etc/init.d/dnsmasq restart >/dev/null 2>&1
}
compute_effective_protections() {
	EFF_FULL_TUNNEL=1
	EFF_ROUTE_DNS=1
	EFF_CONFLICT_BLOCK=0
	EFF_CONFLICT_REASON=""
	local policy reason
	policy=$(uci -q get tor_ui.main.conflict_policy 2>/dev/null)
	[ -n "$policy" ] || policy="block"
	reason=$(vpn_conflict_reason)
	if [ -n "$reason" ]; then
		EFF_CONFLICT_REASON="$reason"
		if [ "$policy" = "downgrade" ]; then
			EFF_FULL_TUNNEL=0
			EFF_ROUTE_DNS=0
			echo "WARNING: transparent Tor routing disabled for this start (conflict_policy=downgrade) -- $reason" >> "$LOG_DIR/notices.log"
		else
			EFF_CONFLICT_BLOCK=1
			echo "ERROR: refusing to start Tor while another VPN owns the default route (conflict_policy=block) -- $reason" >> "$LOG_DIR/notices.log"
		fi
	fi
}
BUILTIN_BRIDGES_OBFS4='obfs4 103.17.154.135:443 9B734AAA454B2F9B26342AE130AB42FC9A67E2EE cert=80jwaFv8pHr5+onzJyjVgbemIjD3GRRwEABfP+Y48G++FAsEVPUZNWWEvMWXVGJi1cwTKg iat-mode=0
obfs4 146.57.248.225:22 10A6CD36A537FCE513A322361547444B393989F0 cert=K1gDtDAIcUfeLqbstggjIw2rtgIKqdIhUlHp82XRqNSq/mtAjp1BIC9vHKJ2FAEpGssTPw iat-mode=0
obfs4 178.114.230.19:11010 7A0C1E1763208B9EDEBCD0B94814BD926032ADA9 cert=9S55BQ2wjmJP+PR5AJbw2rZM/qieoQ2AjltKNepYwiewUNvkg63Pxam0ZtxPXMJISDxdVw iat-mode=0
obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 cert=qUVQ0srL1JI/vO6V6m/24anYXiJD3QP2HgzUKQtQ7GRqqUvs7P+tG43RtAqdhLOALP7DJQ iat-mode=1
obfs4 193.11.166.194:27015 2D82C2E354D531A68469ADF7F878FA6060C6BACA cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg iat-mode=0
obfs4 193.11.166.194:27020 86AC7B8D430DAC4117E9F42C9EAED18133863AAF cert=0LDeJH4JzMDtkJJrFphJCiPqKx7loozKN7VNfuukMGfHO0Z8OGdzHVkhVAOfo1mUdv9cMg iat-mode=0
obfs4 193.11.166.194:27025 1AE2C08904527FEA90C4C4F8C1083EA59FBC6FAF cert=ItvYZw5tn6v3G4UnQa6Qz04Npro6e81AP70YujmK/KXwDFPTs3aHXcHp4n8Vt6w/bv8cA iat-mode=0
obfs4 195.52.147.5:1677 3234D58257F100D6B5D8AB6F43176E6946EFD513 cert=EGg4aZuuJO5gTc9gkRVcSYBXwDjsNdmWt/SYnqnDG7LF/WjUlEsDtUWkLMh1o9hgNIFiUQ iat-mode=0
obfs4 209.148.46.65:443 74FAD13168806246602538555B5521A0383A1875 cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw iat-mode=0
obfs4 212.172.15.201:5470 00D62BE708A0E2A00B6A2097BE0D4B45B70F5F5C cert=0VeTzN1QWoQERmTn0vTpGOiEg8XMQM9iw16GnHwDHYuBjiAsBdSBVY0QUbWj7b8+1Y8cJA iat-mode=0
obfs4 212.83.43.74:443 39562501228A4D5E27FCA4C0C81A01EE23AE3EE4 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=1
obfs4 212.83.43.95:443 BFE712113A72899AD685764B211FACD30FF52C31 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=1
obfs4 37.218.245.14:38224 D9A82D2F9C2F65A18407B1D2B764F130847F8B5D cert=bjRaMrr1BRiAW8IE9U5z27fQaYgOhX1UCmOpg2pFpoMvo6ZgQMzLsaTzzQNTlm7hNcb+Sg iat-mode=0
obfs4 45.145.95.6:27015 C5B7CD6946FF10C5B3E89691A7D3F2C122D2117C cert=TD7PbUO0/0k6xYHMPW3vJxICfkMZNdkRrb63Zhl5j9dW3iRGiCx0A7mPhe5T2EDzQ35+Zw iat-mode=0
obfs4 51.222.13.177:80 5EDAC3B810E12B01F6FD8050D2FD3E277B289A08 cert=2uplIpLQ0q9+0qMFrK5pkaYRDOe460LL9WHBvatgkuRr/SL31wBOEupaMMJ6koRE6Ld0ew iat-mode=0
obfs4 51.38.220.224:30996 22494A012CFA8C88B1D907E2CCB8409AC35B537B cert=dOPijSCG6FD89fYv5N2F9QoeK1od3tpG6VBE/kMY0Bt1aW/7aXPIzsENDoLWZe43gI8efw iat-mode=0
obfs4 51.68.81.140:2098 F205CB5B969389061477609F8E03470B982F64C1 cert=6hFyrclX8Cg16jHGbtYqZxbGxj+p0flBn2EYZu+hvx/tGL4GROXSvBtwVQ1sRYFbi0++fQ iat-mode=0
obfs4 51.79.88.193:45529 9A7BA1AE905FBE24FCEACCA09C42ED1B59340D6C cert=5TSiurscOytr5+TpcKG9qQry0UCMkq9eIlHr1ANxFJ0SWujMjUCOpWpDx30eUUIWHC0QSg iat-mode=0
obfs4 51.89.228.250:21668 BA8BD67D8898CF378D4F73821DEB5657F4BB98DF cert=bEpLLgOwJ9fOJbeHb5r+ronUF2ck5nRd0Jl3zuy7rLoUp732QK2p/CUHjTAfBPCGfcVtSA iat-mode=0
obfs4 57.128.45.196:18384 E30D5552BEE79C5E8C61A943E9B3D2949F227C41 cert=boaTbcdp+rFHgUvweiAg60UUUpLZWecGl0uXRU358L/a7ZMrAnS/BodUKM3eyfWC+UVXTg iat-mode=0
obfs4 57.128.57.245:3099 D655AC9C21147BB62C781149150F0E723C4F8FBC cert=fnU2eGPmE6L53eXZf/29d1JloUD2XI/4KHNImTquPr/eBvkrOuuutIlpwvJsZTV1NvZ4aw iat-mode=0
obfs4 65.108.147.195:8089 DFF8DBF20F8980C4B74EDBAA9695104D613978CE cert=ICnTRGYXX2V63J9ev8XkvXsRJ+Y68XnZGOWW2LCdPIK/sOW8zcunp2gB4qSfelcUVxZDSA iat-mode=0
obfs4 70.34.221.90:9001 1970303391754B4150BF587D33FAC8074FF749E4 cert=XzoWLiOPlfyFHCUyK255KwLq5bRb8fncaMkzEgHSBZztGlUprhgzIS/P8XSXINKtug2kLw iat-mode=0
obfs4 82.65.102.109:50459 F21B650DA1B1A33C94763B3467B60D8A6D80BF91 cert=5cmbAdL18N7PXcWlph4915SC9p5DX6VtCmWsG4E4dub5rT7/bfxB3ndBn5uoRdUwGbMIQg iat-mode=0
obfs4 84.164.12.173:10740 D48C26897BDA22F58460495B9069BEC0CA6D0DA4 cert=TvoujbhzBEHi3q147Pm0efFaB13BNL+UyswKLLz3tnqdw50cFC/6tg3ULbj3uUfELQUnOw iat-mode=0
obfs4 85.31.186.26:443 91A6354697E6B02A386312F68D82CF86824D3606 cert=PBwr+S8JTVZo6MPdHnkTwXJPILWADLqfMGoVvhZClMq/Urndyd42BwX9YFJHZnBB3H0XCw iat-mode=0
obfs4 85.31.186.98:443 011F2599C0E9B27EE74B353155E244813763C3E5 cert=ayq0XzCwhpdysn5o0EyDUbmSOx3X/oTEbzDMvczHOdBJKlvIdHHLJGkZARtT4dcBFArPPg iat-mode=0
obfs4 88.187.37.205:16389 28AD3F0FE38629EA49DA131BE1808EEAC0B24E28 cert=bzdHbtALuVK6Y3zQTnK2efYVrgY9DwgoXFrli+KlLr7+u2ykkt6aLmqMd2P7Ij4/nfI8CA iat-mode=0
obfs4 91.134.99.182:26566 B5D7274F4267D73372BBF8C6446C3AF2D4399A4B cert=eXB5PBSwA+Y6Selwz245/3gZWsskMoJDZcBBccAxrqTtT7OLAwSguf9z2tHU5mV3YkgjIw iat-mode=0
obfs4 94.112.227.176:43595 BF61F24DD6852920E5DF3D8B03A4136CDA6E0C4B cert=TK+t/zNVAm4AXthPGlJS1pzRfkCJbaDtjjana39YMpMJnFnU7GRzZvN8mYbvL4eO8xPNeA iat-mode=0
obfs4 152.53.83.232:1992 49A53936AF2895A1612603AAA3C1CF8A01830157 cert=uVXUO414i8rmHt58SMvdiR0KDxVX7NLmQqLEnINtZxc3g/2B6X+VLLfLZl2m+Mvk6McMHQ iat-mode=0
obfs4 37.228.129.84:8443 6CE81F88D8C686EDB7A6CEBBF6FA257D4D4C0AF9 cert=2TzCqNYkQPFedZNEinALcWWz4aLdwgZbEwKze73fb7TdbGMQYecC1qHeTYMWuwsLl3XRAA iat-mode=0
obfs4 [2a01:4f9:c010:c2c9::1]:9003 E39E2A16023AC199A1927B0F86008FBE51C02058 cert=ILRHQaiIIX4AfvyAT631YBUcqxKFUBJ0cgnZZL4UAFlH8E2lLAhp2GGqcn70qZIxq64FYA iat-mode=0
obfs4 [2a03:4000:27:71::13]:45741 5E4F1FC1B90BACEC3A9B83D55E71134636C89484 cert=RGQ7dcx7NKBdpRx71hGa4pxhrqBluaVqUDwERGXfEjQ3/Uiw7+q9K5gnUTZDaO6PsaSGYw iat-mode=0'

BUILTIN_BRIDGES_SNOWFLAKE='snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://1098762253.rsc.cdn77.org/ fronts=www.cdn77.com,www.phpmyadmin.net ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478 utls-imitate=hellorandomizedalpn
snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://voluble-torrone-fc39bf.netlify.app/ fronts=vuejs.org ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478 utls-imitate=hellorandomizedalpn'

BUILTIN_BRIDGES_MEEK='meek_lite 192.0.2.20:80 97700DFE9F483596DDA6264C4D7DF7641E1E39CE url=https://meek.azureedge.net/ front=ajax.aspnetcdn.com utls=HelloRandomizedALPN
meek_lite 192.0.2.20:80 url=https://1603026938.rsc.cdn77.org front=www.phpmyadmin.net utls=HelloRandomizedALPN'

BUILTIN_BRIDGES_WEBTUNNEL='webtunnel 192.0.2.10:443 0123456789ABCDEF0123456789ABCDEF01234567 url=https://example.invalid/webtunnel ver=0.0.1
webtunnel 192.0.2.11:443 0123456789ABCDEF0123456789ABCDEF01234567 url=https://example.org/webtunnel ver=0.0.1
webtunnel [2001:db8:747d:f959:7714:e5ea:b6d8:66e7]:443 CF1827C41B504EB3CCF3D4EDE7D8D88761F2039E url=https://sp-sk.bitcdn.ovh/standbakhdown ver=0.0.4
webtunnel [2001:db8:aa16:aa07:b3:b4f0:a667:3f08]:443 775A648318DA1E1240EF0DEC038154B60696DE5B url=https://pod01.oneclickhost.eu/jLoIafiPpOBkJRJBN5mm6GPe ver=0.0.7
webtunnel [2001:db8:1b1d:debc:1c57:32bf:5baf:5948]:443 62B3904A4F84BF916310286FFEFE4CB4D24BFAFE url=https://dashboard-132.3b.lol/5d6e7f8g9h0i1j2k3l4m5n6o ver=0.0.2
webtunnel [2001:db8:1da7:e44a:892b:6ada:b3e2:4160]:443 ACBB486B9D60979A05E623D11CC8181A16A81E51 url=https://usa.bulger.au/7gBqm1jbTOpU0jLV91IZHN0f ver=0.0.1
webtunnel [2001:db8:2091:9afb:4e45:7aab:e2d0:a8c7]:443 3683B1036F18DF4B560865C17AF85C373232A8D5 url=https://o.ofdma.de/pg9PbqaxSvIbjtbVZMt9H7xF ver=0.0.5
webtunnel [2001:db8:bb9d:97fd:ed39:10a0:2f60:73b3]:443 3068C8728C4FCBFD3AD9E0AE1CBBF69F7DEBE7E6 url=https://drive.gehenna.cz/9F2A77B13C ver=0.0.7'

TOR_STATE_DIR="/etc/tor/tor_ui-state"
TOR_RUN_DIR="/var/run/tor_ui"
RACE_DIR="/var/run/tor_race"
MEM_CONF="$TOR_STATE_DIR/memory.conf"
MEM_BRIDGES="$TOR_STATE_DIR/memory.bridges"
POOL_DIR="$TOR_STATE_DIR/bridges"

emit_bridge_pool() {
	printf '%s\n' "$1" | while IFS= read -r _p; do
		[ -n "$_p" ] && echo "Bridge $_p"
	done
}
norm_bridge_lines() {
	tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
		-e 's/^[Bb]ridge[[:space:]]\{1,\}//' -e 's/^meek[[:space:]]/meek_lite /' | grep -v '^$'
}
plain_bridge_lines() {
	norm_bridge_lines | grep -E '^(([0-9]{1,3}\.){3}[0-9]{1,3}|\[[0-9A-Fa-f:]+\]):[0-9]+([[:space:]]|$)'
}
transport_bridge_lines() {
	norm_bridge_lines | grep -E "^$1[[:space:]]"
}
lines_need_pt() {
	printf '%s\n' "$1" | grep -qE '^(obfs4|webtunnel|snowflake|meek_lite)[[:space:]]'
}
hash_str() {
	if command -v md5sum >/dev/null 2>&1; then
		printf '%s' "$1" | md5sum | cut -d' ' -f1
	else
		printf '%s' "$1" | cksum | cut -d' ' -f1
	fi
}
race_sig() {
	hash_str "race|$RACE_RACERS|$(uci -q get tor_ui.main.bridge_lines)"
}
pt_binary() {
	local b
	for b in lyrebird obfs4proxy; do
		command -v "$b" >/dev/null 2>&1 && { command -v "$b"; return 0; }
	done
	return 1
}

memory_load() {
	MEM_TYPE=""; MEM_LINES=""
	[ -f "$MEM_CONF" ] || return 1
	MEM_TYPE=$(sed -n 's/^TYPE=\([a-z]*\)$/\1/p' "$MEM_CONF" | head -n 1)
	case "$MEM_TYPE" in
		direct) return 0 ;;
		bridges)
			MEM_LINES=$(cat "$MEM_BRIDGES" 2>/dev/null | norm_bridge_lines)
			[ -n "$MEM_LINES" ] && return 0
			MEM_TYPE=""; return 1 ;;
	esac
	MEM_TYPE=""; return 1
}
memory_forget() {
	rm -f "$MEM_CONF" "$MEM_BRIDGES" 2>/dev/null
}
memory_save() {
	local type="$1" lines="$2" merged old
	mkdir -p "$TOR_STATE_DIR" 2>/dev/null; chmod 700 "$TOR_STATE_DIR" 2>/dev/null
	if [ "$type" = "bridges" ] && [ -n "$lines" ]; then
		old=$(cat "$MEM_BRIDGES" 2>/dev/null)
		merged=$(printf '%s\n%s\n' "$lines" "$old" | norm_bridge_lines | awk '!seen[$0]++' | head -n 60)
		if [ "$merged" != "$old" ]; then
			printf '%s\n' "$merged" > "$MEM_BRIDGES.new" && mv "$MEM_BRIDGES.new" "$MEM_BRIDGES"
			chmod 600 "$MEM_BRIDGES" 2>/dev/null
		fi
	fi
	[ "$type" = "bridges" ] && [ ! -s "$MEM_BRIDGES" ] && return 0
	if [ "$(sed -n 's/^TYPE=//p' "$MEM_CONF" 2>/dev/null | head -n 1)" != "$type" ]; then
		printf 'TYPE=%s\n' "$type" > "$MEM_CONF.new" && mv "$MEM_CONF.new" "$MEM_CONF"
		chmod 600 "$MEM_CONF" 2>/dev/null
	fi
}
proven_bridges_from() {
	local torrc="$1" log="$2" fps
	fps=$(grep -E "new bridge descriptor|Learned fingerprint" "$log" 2>/dev/null \
		| grep -oE '[0-9A-Fa-f]{40}' | tr 'a-f' 'A-F' | sort -u)
	[ -n "$fps" ] || return 0
	grep -E '^Bridge[[:space:]]' "$torrc" 2>/dev/null | sed 's/^Bridge[[:space:]]*//' | while IFS= read -r _l; do
		_fp=$(printf '%s' "$_l" | grep -oE '[0-9A-Fa-f]{40}' | head -n 1 | tr 'a-f' 'A-F')
		[ -n "$_fp" ] || continue
		printf '%s\n' "$fps" | grep -qx "$_fp" && printf '%s\n' "$_l"
	done
}
memory_record_bg() {
	[ "1" = "0" ] && return 0
	(
		w=0
		while [ "$w" -lt 180 ]; do
			sleep 5; w=$((w + 1))
			grep -q 'Bootstrapped 100%' "$LOG_DIR/notices.log" 2>/dev/null && break
		done
		grep -q 'Bootstrapped 100%' "$LOG_DIR/notices.log" 2>/dev/null || exit 0
		if grep -q '^UseBridges 1' /etc/tor/torrc 2>/dev/null; then
			proven=$(proven_bridges_from /etc/tor/torrc "$LOG_DIR/notices.log")
			[ -n "$proven" ] && memory_save bridges "$proven"
		else
			memory_save direct ""
		fi
	) >/dev/null 2>&1 </dev/null 9>&- &
}

resolve_conn_mode() {
	local cm ub bm bl w sig rl
	cm=race
	ub=$(uci -q get tor_ui.main.use_bridge || echo 0)
	bm=$(uci -q get tor_ui.main.bridge_mode || echo auto)
	bl=$(uci -q get tor_ui.main.bridge_lines || echo "")
	[ "$ub" = "1" ] && cm=manual
	EFF_CONN_MODE="$cm"; EFF_CONN_RESOLVED="$cm"; RACE_PENDING=0
	[ "$cm" = "manual" ] && EFF_CONN_RESOLVED="manual -> $bm"
	EFF_USE_BRIDGE="$ub"; EFF_BRIDGE_MODE="$bm"; EFF_BRIDGE_LINES="$bl"
	if [ "$cm" = "memory" ]; then
		if memory_load; then
			if [ "$MEM_TYPE" = "direct" ]; then
				EFF_USE_BRIDGE=0; EFF_CONN_RESOLVED="memory -> direct"
			else
				EFF_USE_BRIDGE=1; EFF_BRIDGE_LINES="$MEM_LINES"
				if lines_need_pt "$MEM_LINES"; then EFF_BRIDGE_MODE=auto; else EFF_BRIDGE_MODE=vanilla; fi
				EFF_CONN_RESOLVED="memory -> $(printf '%s\n' "$MEM_LINES" | grep -c .) proven bridge(s)"
			fi
			return 0
		fi
		cm="race"; EFF_CONN_RESOLVED="memory (empty) -> race"
	fi
	case "$cm" in
	direct)
		EFF_USE_BRIDGE=0 ;;
	vanilla)
		EFF_USE_BRIDGE=1; EFF_BRIDGE_MODE=vanilla
		EFF_BRIDGE_LINES=$(printf '%s\n' "$bl" | plain_bridge_lines)
		[ -n "$EFF_BRIDGE_LINES" ] || EFF_BRIDGE_LINES=$(cat "$POOL_DIR/vanilla.txt" 2>/dev/null | plain_bridge_lines | head -n 30)
		;;
	race)
		sig=$(race_sig)
		if [ -f "$TOR_RUN_DIR/race.result" ] && [ "$(sed -n 's/^sig=//p' "$TOR_RUN_DIR/race.result")" = "$sig" ]; then
			w=$(sed -n 's/^winner=//p' "$TOR_RUN_DIR/race.result" | head -n 1)
			case "$w" in
			direct)
				EFF_USE_BRIDGE=0; EFF_CONN_RESOLVED="race -> direct" ;;
			none|"")
				EFF_USE_BRIDGE=1; EFF_BRIDGE_MODE=auto; EFF_BRIDGE_LINES="$bl"
				EFF_CONN_RESOLVED="race -> no winner, classic auto profile" ;;
			*)
				rl=$(cat "$TOR_RUN_DIR/race.lines" 2>/dev/null)
				EFF_USE_BRIDGE=1; EFF_BRIDGE_LINES="$rl"
				if lines_need_pt "$rl"; then EFF_BRIDGE_MODE=auto; else EFF_BRIDGE_MODE=vanilla; fi
				EFF_CONN_RESOLVED="race -> $w" ;;
			esac
		else
			RACE_PENDING=1
			EFF_USE_BRIDGE=1; EFF_BRIDGE_MODE=auto; EFF_BRIDGE_LINES="$bl"
			EFF_CONN_RESOLVED="race (pending)"
		fi ;;
	esac
	return 0
}

TOR_OPTS_CACHE=""
tor_opt_supported() {
	[ -x "$TOR_BIN" ] || return 1
	[ -n "$TOR_OPTS_CACHE" ] || TOR_OPTS_CACHE=$("$TOR_BIN" --list-torrc-options 2>/dev/null | awk '{print tolower($1)}')
	[ -n "$TOR_OPTS_CACHE" ] || return 1
	printf '%s\n' "$TOR_OPTS_CACHE" | grep -qx "$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
}
conflux_core_kind() {
	if tor_opt_supported ConfluxNumSets && tor_opt_supported ConfluxNumLegs; then
		echo extended
	elif tor_opt_supported ConfluxEnabled; then
		echo stock
	else
		echo unknown
	fi
}
conflux_num_opt() {
	local name="$1" val="$2" max="$3"
	case "$val" in ''|*[!0-9]*) return 0 ;; esac
	[ "$val" -gt 0 ] 2>/dev/null || return 0
	[ "$val" -le "$max" ] 2>/dev/null || val="$max"
	if tor_opt_supported "$name"; then
		echo "$name $val"
	else
		echo "WARNING: $name is set but this Tor binary does not support it (needs the Delta-Kronecker/tor Conflux core) -- ignored." >> "$LOG_DIR/notices.log"
	fi
}
conflux_torrc_lines() {
	tor_opt_supported ConfluxEnabled && echo "ConfluxEnabled auto"
	return 0
}

race_port() {
	case "$1" in
		vanilla) echo 9150 ;; obfs4) echo 9250 ;; webtunnel) echo 9350 ;;
		snowflake) echo 9450 ;; meek) echo 9550 ;; direct) echo 9650 ;;
		memory) echo 9750 ;; *) echo 0 ;;
	esac
}
race_lines_for() {
	local r="$1" ub out tp
	ub=$(uci -q get tor_ui.main.bridge_lines || echo "")
	case "$r" in
	vanilla)
		out=$(printf '%s\n' "$ub" | plain_bridge_lines)
		[ -n "$out" ] || out=$(cat "$POOL_DIR/vanilla.txt" 2>/dev/null | plain_bridge_lines) ;;
	obfs4|webtunnel|snowflake)
		out=$(printf '%s\n' "$ub" | transport_bridge_lines "$r")
		[ -n "$out" ] || out=$(cat "$POOL_DIR/$r.txt" 2>/dev/null | transport_bridge_lines "$r")
		if [ -z "$out" ]; then
			case "$r" in
				obfs4)     out="$BUILTIN_BRIDGES_OBFS4" ;;
				snowflake) out="$BUILTIN_BRIDGES_SNOWFLAKE" ;;
			esac
		fi ;;
	meek)
		out=$(printf '%s\n' "$ub" | transport_bridge_lines meek_lite)
		[ -n "$out" ] || out="$BUILTIN_BRIDGES_MEEK" ;;
	memory)
		memory_load && out="$MEM_LINES" ;;
	esac
	printf '%s\n' "$out" | norm_bridge_lines | head -n 30
}
race_stop() {
	local p r
	p=$(cat "$TOR_RUN_DIR/race.pid" 2>/dev/null)
	case "$p" in ''|*[!0-9]*) ;; *) kill "$p" 2>/dev/null ;; esac
	rm -f "$TOR_RUN_DIR/race.pid"
	if [ -d "$RACE_DIR" ]; then
		for r in "$RACE_DIR"/*; do
			[ -f "$r/tor.pid" ] || continue
			p=$(cat "$r/tor.pid" 2>/dev/null)
			case "$p" in ''|*[!0-9]*) continue ;; esac
			kill "$p" 2>/dev/null
		done
		sleep 1
		for r in "$RACE_DIR"/*; do
			[ -f "$r/tor.pid" ] || continue
			p=$(cat "$r/tor.pid" 2>/dev/null)
			case "$p" in ''|*[!0-9]*) continue ;; esac
			[ -d "/proc/$p" ] && kill -9 "$p" 2>/dev/null
		done
		rm -rf "$RACE_DIR"
	fi
	rm -f "$TOR_RUN_DIR/race.status"
}
race_running() {
	local p
	p=$(cat "$TOR_RUN_DIR/race.pid" 2>/dev/null)
	case "$p" in ''|*[!0-9]*) return 1 ;; esac
	kill -0 "$p" 2>/dev/null
}
race_run() {
	local want racers="" r i n lines pt port dir avail maxn timeout t pct winner alive
	local sig tor_user
	sig=$(race_sig)
	want="$RACE_RACERS"
	timeout="$RACE_TIMEOUT"
	case "$timeout" in ''|*[!0-9]*) timeout=120 ;; esac
	[ "$timeout" -ge 20 ] || timeout=20
	[ "$timeout" -le 600 ] || timeout=600
	pt=$(pt_binary)
	id tor >/dev/null 2>&1 || { echo "ERROR: race needs the 'tor' system user." >> "$LOG_DIR/notices.log"; want=""; }
	rm -rf "$RACE_DIR"; mkdir -p "$RACE_DIR"; chmod 755 "$RACE_DIR"
	for r in memory obfs4 vanilla webtunnel snowflake meek direct; do
		case " $want " in
			*" $r "*) ;;
			*) [ "$r" = "memory" ] || continue ;;
		esac
		if [ "$r" = "memory" ]; then
			[ "1" = "0" ] && continue
			memory_load || continue
			[ "$MEM_TYPE" = "bridges" ] || continue
		fi
		if [ "$r" != "direct" ]; then
			lines=$(race_lines_for "$r")
			if [ -z "$lines" ]; then
				echo "race: skipping $r (no bridge lines available)" >> "$LOG_DIR/notices.log"; continue
			fi
			case "$r" in
				obfs4) [ -n "$pt" ] || { echo "race: skipping obfs4 (no lyrebird/obfs4proxy)" >> "$LOG_DIR/notices.log"; continue; } ;;
				webtunnel|meek) command -v lyrebird >/dev/null 2>&1 || { echo "race: skipping $r (needs lyrebird)" >> "$LOG_DIR/notices.log"; continue; } ;;
				snowflake) command -v snowflake-client >/dev/null 2>&1 || { echo "race: skipping snowflake (no snowflake-client)" >> "$LOG_DIR/notices.log"; continue; } ;;
				memory) [ -n "$pt" ] || { lines=$(printf '%s\n' "$lines" | plain_bridge_lines); [ -n "$lines" ] || continue; } ;;
			esac
		fi
		racers="$racers $r"
	done
	avail=$(awk '/^MemAvailable:/{print $2; f=1} END{}' /proc/meminfo 2>/dev/null | head -n 1)
	[ -n "$avail" ] || avail=$(awk '/^(MemFree|Cached):/{s+=$2} END{print s+0}' /proc/meminfo 2>/dev/null)
	case "$avail" in ''|*[!0-9]*) avail=0 ;; esac
	maxn=$(( (avail - 40000) / 45000 )); [ "$maxn" -ge 1 ] || maxn=1
	n=0; alive=""
	for r in $racers; do
		n=$((n + 1))
		if [ "$n" -gt "$maxn" ]; then
			echo "race: dropping $r (only ~$((avail / 1024)) MB free, $maxn racer(s) fit)" >> "$LOG_DIR/notices.log"
			continue
		fi
		alive="$alive $r"
	done
	racers="$alive"; alive=""
	if [ -z "$racers" ]; then
		echo "race: no usable racer; falling back to the classic auto profile." >> "$LOG_DIR/notices.log"
		race_finish none "" "$sig"; return 0
	fi
	for r in $racers; do
		port=$(race_port "$r"); dir="$RACE_DIR/$r"
		mkdir -p "$dir/data"; chown -R tor:tor "$dir" 2>/dev/null; chmod 700 "$dir/data"
		{
			echo "DataDirectory $dir/data"
			echo "Log notice file $dir/notices.log"
			echo "SocksPort 127.0.0.1:$port"
			echo "User tor"
			echo "AvoidDiskWrites 1"
			echo "ClientOnly 1"
			if [ "$r" != "direct" ]; then
				lines=$(race_lines_for "$r")
				echo "UseBridges 1"
				case "$r" in
					obfs4)     echo "ClientTransportPlugin obfs4 exec $pt" ;;
					webtunnel) echo "ClientTransportPlugin webtunnel exec $(command -v lyrebird)" ;;
					meek)      echo "ClientTransportPlugin meek_lite exec $(command -v lyrebird)" ;;
					snowflake) echo "ClientTransportPlugin snowflake exec $(command -v snowflake-client)" ;;
					memory)
						if command -v lyrebird >/dev/null 2>&1; then
							echo "ClientTransportPlugin obfs4,webtunnel,meek_lite exec $(command -v lyrebird)"
						elif command -v obfs4proxy >/dev/null 2>&1; then
							echo "ClientTransportPlugin obfs4 exec $(command -v obfs4proxy)"
						fi
						command -v snowflake-client >/dev/null 2>&1 && echo "ClientTransportPlugin snowflake exec $(command -v snowflake-client)" ;;
				esac
				printf '%s\n' "$lines" > "$dir/lines"
				printf '%s\n' "$lines" | while IFS= read -r _l; do echo "Bridge $_l"; done
			fi
		} > "$dir/torrc"
		: > "$dir/notices.log"; chown tor:tor "$dir/notices.log" 2>/dev/null
		"$TOR_BIN" -f "$dir/torrc" >"$dir/stdout" 2>&1 </dev/null 9>&- &
		echo "$!" > "$dir/tor.pid"
		alive="$alive $r"
	done
	racers="$alive"
	winner=""; t=0
	while [ "$t" -lt "$timeout" ] && [ -z "$winner" ]; do
		sleep 2; t=$((t + 2))
		{
			echo "state=running"; echo "elapsed=$t"; echo "timeout=$timeout"
			alive=""
			for r in $racers; do
				pct=$(grep -o 'Bootstrapped [0-9]*%' "$RACE_DIR/$r/notices.log" 2>/dev/null | tail -n 1 | grep -o '[0-9]*')
				[ -n "$pct" ] || pct=0
				echo "racer.$r=$pct"
				[ "$pct" = "100" ] && [ -z "$winner" ] && winner="$r"
				p=$(cat "$RACE_DIR/$r/tor.pid" 2>/dev/null)
				[ -n "$p" ] && kill -0 "$p" 2>/dev/null && alive="$alive $r"
			done
		} > "$TOR_RUN_DIR/race.status.new" 2>/dev/null && mv "$TOR_RUN_DIR/race.status.new" "$TOR_RUN_DIR/race.status"
		[ -n "$winner" ] && break
		[ -n "$alive" ] || break
	done
	if [ -n "$winner" ]; then
		echo "race: $winner reached 100% after ${t}s" >> "$LOG_DIR/notices.log"
		lines=""
		if [ "$winner" != "direct" ]; then
			lines=$(proven_bridges_from "$RACE_DIR/$winner/torrc" "$RACE_DIR/$winner/notices.log")
			[ -n "$lines" ] || lines=$(cat "$RACE_DIR/$winner/lines" 2>/dev/null)
		fi
		for f in cached-certs cached-microdesc-consensus cached-microdescs cached-microdescs.new; do
			[ -f "$RACE_DIR/$winner/data/$f" ] && cp -f "$RACE_DIR/$winner/data/$f" "/var/lib/tor/$f" 2>/dev/null && chown tor:tor "/var/lib/tor/$f" 2>/dev/null
		done
		if [ "$winner" = "direct" ]; then
			[ "1" = "0" ] || memory_save direct ""
		else
			[ "1" = "0" ] || memory_save bridges "$lines"
		fi
		race_finish "$winner" "$lines" "$sig"
	else
		echo "race: no racer reached 100% within ${timeout}s" >> "$LOG_DIR/notices.log"
		race_finish none "" "$sig"
	fi
}
race_finish() {
	local i
	local keep_pid="$TOR_RUN_DIR/race.pid"
	printf '%s\n' "$2" > "$TOR_RUN_DIR/race.lines"
	printf 'winner=%s\nsig=%s\n' "$1" "$3" > "$TOR_RUN_DIR/race.result"
	{ echo "state=done"; echo "winner=$1"; } > "$TOR_RUN_DIR/race.status"
	rm -f "$keep_pid"
	race_stop
	{ echo "state=done"; echo "winner=$1"; } > "$TOR_RUN_DIR/race.status"
	for i in 1 2 3 4 5 6; do
		/etc/init.d/tor_ui start >/dev/null 2>&1
		sleep 3
		tor_is_running && break
		[ -f "$TOR_RUN_DIR/race.result" ] || break
	done
}
race_launch() {
	race_running && return 0
	mkdir -p "$TOR_RUN_DIR" 2>/dev/null
	rm -f "$TOR_RUN_DIR/race.result" "$TOR_RUN_DIR/race.lines"
	echo "Auto race: starting parallel transport race (timeout ${RACE_TIMEOUT}s)." >> "$LOG_DIR/notices.log"
	{ echo "state=running"; echo "elapsed=0"; } > "$TOR_RUN_DIR/race.status"
	( race_run ) >/dev/null 2>&1 </dev/null 9>&- &
	echo "$!" > "$TOR_RUN_DIR/race.pid"
}
write_conn_status() {
	mkdir -p "$TOR_RUN_DIR" 2>/dev/null
	{
		echo "CONNMODE=$EFF_CONN_MODE"
		echo "CONNRESOLVED=$EFF_CONN_RESOLVED"
		echo "CONFLUX_CORE=$(conflux_core_kind)"
	} > "$TOR_RUN_DIR/conn.status" 2>/dev/null
}

build_torrc_content() {
	local full_tunnel="$1" route_dns="$2"
	local custom_exit exit_nodes strict_exit use_bridge bridge_mode
	local bridge_lines socks_port trans_port dns_port lan_ip pt_bin
	custom_exit=$(uci -q get tor_ui.main.custom_exit || echo 0)
	strict_exit=$(uci -q get tor_ui.main.strict_exit || echo 0)
	[ "$strict_exit" = "1" ] || strict_exit=0
	exit_nodes=$(uci -q get tor_ui.main.exit_node || echo "")
	resolve_conn_mode
	use_bridge="$EFF_USE_BRIDGE"
	bridge_mode="$EFF_BRIDGE_MODE"
	bridge_lines="$EFF_BRIDGE_LINES"
	socks_port=$(uci -q get tor_ui.main.socks_port || echo 9050)
	trans_port=$(uci -q get tor_ui.main.trans_port || echo 9040)
	dns_port=$(uci -q get tor_ui.main.dns_port || echo 9053)
	[ -n "$socks_port" ] || socks_port=9050
	[ -n "$trans_port" ] || trans_port=9040
	[ -n "$dns_port" ] || dns_port=9053
	lan_ip=$(uci -q get network.lan.ipaddr)
	if [ -z "$lan_ip" ]; then
		lan_ip="127.0.0.1"
		echo "WARNING: LAN IP could not be resolved; binding SOCKS/TransPort to loopback only. Check network.lan.ipaddr." >> "$LOG_DIR/notices.log"
	fi
	write_conn_status
	echo "DataDirectory /var/lib/tor"
	echo "PidFile /var/run/tor_ui/tor.pid"
	if [ -f /usr/share/tor/geoip ]; then
		echo "GeoIPFile /usr/share/tor/geoip"
	elif [ -f /rom/usr/share/tor/geoip ]; then
		echo "GeoIPFile /rom/usr/share/tor/geoip"
	fi
	if [ -f /usr/share/tor/geoip6 ]; then
		echo "GeoIPv6File /usr/share/tor/geoip6"
	elif [ -f /rom/usr/share/tor/geoip6 ]; then
		echo "GeoIPv6File /rom/usr/share/tor/geoip6"
	fi
	echo "Log notice file $LOG_DIR/notices.log"
	echo "SocksPort 127.0.0.1:$socks_port"
	echo "SocksPort $lan_ip:$socks_port"
	if [ "$full_tunnel" = "1" ]; then
		echo "TransPort 127.0.0.1:$trans_port"
		echo "TransPort $lan_ip:$trans_port"
		echo "VirtualAddrNetworkIPv4 10.192.0.0/10"
		echo "AutomapHostsOnResolve 1"
		echo "AutomapHostsSuffixes ."
	fi
	if [ "$route_dns" = "1" ]; then
		echo "DNSPort 127.0.0.1:$dns_port"
	fi
	echo "ControlPort 127.0.0.1:9051"
	echo "CookieAuthentication 1"
	conflux_torrc_lines
	if [ "$custom_exit" = "1" ] && [ -n "$exit_nodes" ]; then
		local nodes="" n
		for n in $exit_nodes; do
			case "$n" in
				[A-Za-z][A-Za-z]) nodes="${nodes:+$nodes,}{$n}" ;;
				*) echo "WARNING: ignoring invalid exit node code '$n' (must be 2-letter ISO-3166 alpha-2)" >> "$LOG_DIR/notices.log" ;;
			esac
		done
		if [ -n "$nodes" ]; then
			echo "ExitNodes $nodes"
			echo "StrictNodes $([ "$strict_exit" = "1" ] && echo 1 || echo 0)"
		fi
	fi
	BRIDGE_TRANSPORT_ERROR=""
	if [ "$use_bridge" = "1" ]; then
		echo "UseBridges 1"
		pt_bin=""
		if command -v lyrebird >/dev/null 2>&1; then
			pt_bin="$(command -v lyrebird)"
		elif command -v obfs4proxy >/dev/null 2>&1; then
			pt_bin="$(command -v obfs4proxy)"
		fi
		case "$bridge_mode" in
			webtunnel)
				if [ -n "$pt_bin" ]; then
					echo "ClientTransportPlugin webtunnel exec $pt_bin"
				else
					echo "WARNING: Bridge Mode '$bridge_mode' selected but lyrebird is not installed -- bridges will not connect." >> "$LOG_DIR/notices.log"
					BRIDGE_TRANSPORT_ERROR="Bridge Mode '$bridge_mode' requires the 'lyrebird' transport binary, but it is not installed."
				fi ;;
			meek)
				if [ -n "$pt_bin" ]; then
					echo "ClientTransportPlugin meek_lite exec $pt_bin"
				else
					echo "WARNING: Bridge Mode '$bridge_mode' selected but lyrebird is not installed -- bridges will not connect." >> "$LOG_DIR/notices.log"
					BRIDGE_TRANSPORT_ERROR="Bridge Mode '$bridge_mode' requires the 'lyrebird' transport binary, but it is not installed."
				fi ;;
			obfs4)
				if [ -n "$pt_bin" ]; then
					echo "ClientTransportPlugin obfs4 exec $pt_bin"
				elif ! command -v obfs4proxy >/dev/null 2>&1; then
					BRIDGE_TRANSPORT_ERROR="Bridge Mode 'obfs4' requires 'lyrebird' or 'obfs4proxy', but neither is installed."
				fi ;;
			snowflake)
				if command -v snowflake-client >/dev/null 2>&1; then
					echo "ClientTransportPlugin snowflake exec $(command -v snowflake-client)"
				else
					echo "WARNING: Bridge Mode 'snowflake' selected but no snowflake-client binary is installed -- bridges will not connect." >> "$LOG_DIR/notices.log"
					BRIDGE_TRANSPORT_ERROR="Bridge Mode 'snowflake' requires 'snowflake-client', but it is not installed."
				fi ;;
			vanilla)
				if [ -z "$bridge_lines" ]; then
					BRIDGE_TRANSPORT_ERROR="Vanilla mode needs plain bridge lines (IP:PORT FINGERPRINT). Paste them into Bridge Lines or put them in $POOL_DIR/vanilla.txt."
				fi ;;
			auto)
				if command -v lyrebird >/dev/null 2>&1; then
					echo "ClientTransportPlugin obfs4,webtunnel,meek_lite exec $(command -v lyrebird)"
				elif command -v obfs4proxy >/dev/null 2>&1; then
					echo "ClientTransportPlugin obfs4 exec $(command -v obfs4proxy)"
				fi
				command -v snowflake-client >/dev/null 2>&1 && \
					echo "ClientTransportPlugin snowflake exec $(command -v snowflake-client)"
				;;
		esac
		if [ -n "$bridge_lines" ]; then
			local _bridge_n=0
			printf '%s\n' "$bridge_lines" | while IFS= read -r _bl; do
				_bridge_n=$((_bridge_n + 1))
				_bl=$(printf '%s' "$_bl" | tr -d '\r' \
					| sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
						      -e 's/^[Bb]ridge[[:space:]]\{1,\}//')
				[ -n "$_bl" ] || continue
				case "$_bl" in
					obfs4\ *|webtunnel\ *|snowflake\ *|meek_lite\ *)
						echo "Bridge $_bl" ;;
					meek\ *)
						echo "Bridge meek_lite${_bl#meek}" ;;
					[0-9]*.[0-9]*.[0-9]*.[0-9]*:[0-9]*\ *)
						echo "Bridge $_bl" ;;
					\[*\]:[0-9]*\ *)
						echo "Bridge $_bl" ;;
					*)
						echo "WARNING: skipping bridge line #$_bridge_n (unrecognized prefix '${_bl%% *}')" >> "$LOG_DIR/notices.log" ;;
				esac
			done
		elif [ "$bridge_mode" = "auto" ]; then
			emit_bridge_pool "$BUILTIN_BRIDGES_OBFS4"
			emit_bridge_pool "$BUILTIN_BRIDGES_SNOWFLAKE"
			emit_bridge_pool "$BUILTIN_BRIDGES_MEEK"
		elif [ "$bridge_mode" = "obfs4" ]; then
			emit_bridge_pool "$BUILTIN_BRIDGES_OBFS4"
		elif [ "$bridge_mode" = "snowflake" ]; then
			emit_bridge_pool "$BUILTIN_BRIDGES_SNOWFLAKE"
		elif [ "$bridge_mode" = "meek" ]; then
			emit_bridge_pool "$BUILTIN_BRIDGES_MEEK"
		elif [ "$bridge_mode" = "webtunnel" ]; then
			emit_bridge_pool "$BUILTIN_BRIDGES_WEBTUNNEL"
		fi

	fi
}
validate_tor_ports() {
	local socks_port="$1" trans_port="$2" dns_port="$3" p name
	for name in socks_port trans_port dns_port; do
		case "$name" in socks_port) p=$socks_port ;; trans_port) p=$trans_port ;; dns_port) p=$dns_port ;; esac
		case "$p" in ''|*[!0-9]*) echo "ERROR: invalid $name: $p" >> "$LOG_DIR/notices.log"; return 1 ;; esac
		[ "$p" -ge 1 ] 2>/dev/null && [ "$p" -le 65535 ] 2>/dev/null || { echo "ERROR: $name must be 1..65535" >> "$LOG_DIR/notices.log"; return 1; }
	done
	[ "$socks_port" != "$trans_port" ] && [ "$socks_port" != "$dns_port" ] && [ "$trans_port" != "$dns_port" ] || { echo "ERROR: Tor ports must be distinct" >> "$LOG_DIR/notices.log"; return 1; }
}
sweep_tmp() {
	local d f ok
	find /tmp -maxdepth 1 -type d -name 'tor_ui.*' -mmin +5 -exec rm -rf {} + 2>/dev/null
	for d in /tmp/tmp.??????; do
		[ -d "$d" ] || continue
		[ -n "$(find "$d" -maxdepth 0 -mmin +5 2>/dev/null)" ] || continue
		ok=1
		for f in $(ls -A "$d" 2>/dev/null); do
			case "$f" in
				real|tor|torgeo|torjson|realjson|dnstor|dnsleak|tcpms|urlms|icmp|real.done|tor.done) ;;
				*) ok=0; break ;;
			esac
		done
		[ "$ok" = "1" ] && rm -rf "$d" 2>/dev/null
	done
	return 0
}
PERSIST_FILES="cached-certs cached-microdesc-consensus cached-microdescs cached-descriptors state"
persist_dir() {
	local d
	d=$(uci -q get tor_ui.main.persist_dir 2>/dev/null)
	case "$d" in /*) ;; *) d="/.tor" ;; esac
	[ "$d" = "/" ] && d="/.tor"
	[ "$d" = "/var/lib/tor" ] && d="/.tor"
	printf '%s' "$d"
}
persist_enabled() {
	[ "$(uci -q get tor_ui.main.persist_cache 2>/dev/null)" != "0" ]
}
persist_restore() {
	local P f d n=0
	persist_enabled || return 0
	P=$(persist_dir)
	[ -d "$P" ] || return 0
	for f in $PERSIST_FILES; do
		[ -s "$P/$f" ] && [ ! -s "/var/lib/tor/$f" ] && cp -f "$P/$f" "/var/lib/tor/$f" 2>/dev/null && n=$((n + 1))
	done
	for d in keys pt_state; do
		if [ -d "$P/$d" ] && [ -n "$(ls -A "$P/$d" 2>/dev/null)" ] && [ -z "$(ls -A "/var/lib/tor/$d" 2>/dev/null)" ]; then
			cp -R "$P/$d/." "/var/lib/tor/$d/" 2>/dev/null && n=$((n + 1))
		fi
	done
	mkdir -p "$TOR_STATE_DIR" 2>/dev/null; chmod 700 "$TOR_STATE_DIR" 2>/dev/null
	for f in memory.conf memory.bridges; do
		if [ -s "$P/tor_ui-memory/$f" ] && [ ! -s "$TOR_STATE_DIR/$f" ]; then
			cp -f "$P/tor_ui-memory/$f" "$TOR_STATE_DIR/$f" 2>/dev/null && chmod 600 "$TOR_STATE_DIR/$f" 2>/dev/null && n=$((n + 1))
		fi
	done
	[ "$n" -gt 0 ] && echo "Restored $n saved item(s) from $P (previous successful connection)." >> "$LOG_DIR/notices.log"
	return 0
}
persist_save() {
	local P f d n=0
	persist_enabled || return 0
	P=$(persist_dir)
	[ -s /var/lib/tor/cached-microdesc-consensus ] || return 0
	mkdir -p "$P" 2>/dev/null || return 0
	chmod 700 "$P" 2>/dev/null || true
	for f in $PERSIST_FILES; do
		[ -s "/var/lib/tor/$f" ] || continue
		cmp -s "/var/lib/tor/$f" "$P/$f" 2>/dev/null && continue
		if cp -f "/var/lib/tor/$f" "$P/$f.tmp" 2>/dev/null && mv -f "$P/$f.tmp" "$P/$f" 2>/dev/null; then
			n=$((n + 1))
		else
			rm -f "$P/$f.tmp" 2>/dev/null
		fi
	done
	for d in keys pt_state; do
		mkdir -p "$P/$d" 2>/dev/null
		if [ -n "$(ls -A "/var/lib/tor/$d" 2>/dev/null)" ]; then
			cp -R "/var/lib/tor/$d/." "$P/$d/" 2>/dev/null
		fi
	done
	chmod 700 "$P/keys" "$P/pt_state" 2>/dev/null || true
	mkdir -p "$P/tor_ui-memory" 2>/dev/null && chmod 700 "$P/tor_ui-memory" 2>/dev/null
	for f in memory.conf memory.bridges; do
		[ -s "$TOR_STATE_DIR/$f" ] || continue
		cmp -s "$TOR_STATE_DIR/$f" "$P/tor_ui-memory/$f" 2>/dev/null && continue
		cp -f "$TOR_STATE_DIR/$f" "$P/tor_ui-memory/$f" 2>/dev/null && chmod 600 "$P/tor_ui-memory/$f" 2>/dev/null && n=$((n + 1))
	done
	sync
	echo "Saved successful-connection snapshot to $P ($n file(s) changed)." >> "$LOG_DIR/notices.log"
	return 0
}
persist_wipe() {
	local P f
	P=$(persist_dir)
	[ -d "$P" ] || return 0
	rm -f "$P"/cached-* 2>/dev/null
	[ "$1" = "all" ] && rm -rf "$P/state" "$P/keys" "$P/pt_state" "$P/tor_ui-memory" 2>/dev/null
	return 0
}
persist_save_bg() {
	persist_enabled || return 0
	(
		w=0
		while [ "$w" -lt 180 ]; do
			sleep 5; w=$((w + 1))
			grep -q 'Bootstrapped 100%' "$LOG_DIR/notices.log" 2>/dev/null && break
		done
		grep -q 'Bootstrapped 100%' "$LOG_DIR/notices.log" 2>/dev/null || exit 0
		sleep 90
		tor_is_running || exit 0
		persist_save
	) >/dev/null 2>&1 </dev/null 9>&- &
}
ensure_data_dir() {
	local d="/var/lib/tor"
	mkdir -p "$d" "$d/keys" "$d/pt_state" 2>/dev/null || true
	if [ -f "$d/lock" ] && command -v pidof >/dev/null 2>&1 && ! pidof tor >/dev/null 2>&1; then
		rm -f "$d/lock" 2>/dev/null || true
	fi
	if id tor >/dev/null 2>&1; then
		chown tor:tor "$d" "$d/keys" "$d/pt_state" 2>/dev/null || true
	fi
	chmod 700 "$d" "$d/keys" "$d/pt_state" 2>/dev/null || true
	return 0
}
RACE_RACERS="vanilla obfs4 webtunnel snowflake meek"
RACE_TIMEOUT=120
ks_on() {
	if [ "$(uci -q get tor_ui.main.enabled 2>/dev/null)" = "1" ]; then echo 1; else echo 0; fi
}
ks_sync() {
	if [ "$(ks_on)" = "0" ] && ! tor_is_running && ! race_running; then
		unblock >/dev/null 2>&1
	fi
	return 0
}
teardown_all() {
	if tor_is_running || race_running; then stop; fi
	unblock >/dev/null 2>&1
	TOR_UI_RELEASED=1
	return 0
}
unblock() {
	if tor_is_running || race_running; then
		echo "Tor is running - the Kill Switch is part of the tunnel. Stop Tor first."
		return 1
	fi
	FW_CHANGED=0
	remove_fw_include
	[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
	set_killswitch 0
	configure_dns_over_tor 0
	flush_conntrack
	echo "Kill Switch released: LAN internet is open again (not through Tor)."
	return 0
}
clear_cache() {
	local was_running=0 f n=0
	if tor_is_running || race_running; then was_running=1; fi
	[ "$was_running" = "1" ] && stop
	for f in /var/lib/tor/cached-*; do
		[ -e "$f" ] || continue
		rm -f "$f" 2>/dev/null && n=$((n + 1))
	done
	persist_wipe
	ensure_data_dir
	echo "Cleared $n cache file(s) (RAM + saved copy). state, keys/ and pt_state/ were kept."
	if [ "$was_running" = "1" ]; then
		echo "Restarting Tor (it will re-download the network cache)..."
		TOR_UI_MANUAL=1 start
	fi
	return 0
}
start_service() {
	local full_tunnel route_dns custom_exit exit_nodes strict_exit use_bridge bridge_lines
	local bridge_mode strict_ks socks_port trans_port dns_port
	local lan_ip conflict_reason pt_bin cand nodes n torrc_valid
	if ! acquire_lock; then
		mkdir -p "$LOG_DIR" 2>/dev/null || true
		echo "Another tor_ui operation is already in progress; refusing to start." >> "$LOG_DIR/notices.log"
		return 1
	fi
	mkdir -p "$LOG_DIR" /var/lib/tor /etc/tor /var/run/tor_ui
	if ! id tor >/dev/null 2>&1; then
		echo "ERROR: system user 'tor' is missing; refusing to run Tor as root." >> "$LOG_DIR/notices.log"
		local _rootks _roottp
		_rootks=$(ks_on)
		_roottp=$(uci -q get tor_ui.main.trans_port 2>/dev/null); [ -n "$_roottp" ] || _roottp=9040
		if [ "$_rootks" != "0" ]; then
			if ! write_fw_include 0 0 "$_roottp" 1 0 0; then
				set_killswitch 1
				return 1
			fi
			if [ "$FW_CHANGED" = "1" ] && ! /etc/init.d/firewall reload >/dev/null 2>&1; then
				echo "ERROR: firewall reload failed while refusing root execution." >> "$LOG_DIR/notices.log"
				set_killswitch 1
				return 1
			fi
			set_killswitch 1
		fi
		return 1
	fi
	sweep_tmp
	ensure_data_dir
	persist_restore
	chown -R tor:tor /var/lib/tor /var/run/tor_ui "$LOG_DIR" 2>/dev/null || true
	chmod 700 /var/lib/tor /var/run/tor_ui
	if [ -f "$LOG_DIR/notices.log" ] && [ -s "$LOG_DIR/notices.log" ]; then
		tail -n 500 "$LOG_DIR/notices.log" > "$LOG_DIR/notices.log.1" 2>/dev/null || true
	fi
	: > "$LOG_DIR/notices.log"
	chown tor:tor "$LOG_DIR/notices.log" 2>/dev/null || true
	chmod 600 "$LOG_DIR/notices.log"
	if [ -f /etc/tor/tor_ui-state/tor-state ]; then
		mkdir -p /var/lib/tor 2>/dev/null || true
		cp -f /etc/tor/tor_ui-state/tor-state /var/lib/tor/state 2>/dev/null || true
		if id tor >/dev/null 2>&1; then
			chown tor:tor /var/lib/tor/state 2>/dev/null || true
		fi
		chmod 600 /var/lib/tor/state 2>/dev/null || true
	fi
	if [ "${TOR_UI_MANUAL:-0}" != "1" ] && [ "$(uci -q get tor_ui.main.enabled)" != "1" ]; then
		echo "Auto Connect disabled; refusing automatic Tor start." >> "$LOG_DIR/notices.log"
		local _ks2 _tp2
		_ks2=0
		_tp2=$(uci -q get tor_ui.main.trans_port || echo 9040)
		[ -n "$_tp2" ] || _tp2=9040
		if [ "$_ks2" = "1" ]; then
			FW_CHANGED=0
			write_fw_include 0 0 "$_tp2" 1 0 0
			[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
			set_killswitch 1
		else
			remove_fw_include
			[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
			set_killswitch 0
		fi
		configure_dns_over_tor 0
		flush_conntrack
		return 0
	fi
	full_tunnel=1
	route_dns=1
	strict_ks=$(ks_on)
	[ "$strict_ks" = "0" ] || strict_ks=1
	localhost_proxy=$(uci -q get tor_ui.main.localhost_proxy 2>/dev/null)
	[ "$localhost_proxy" = "1" ] || localhost_proxy=0
	custom_exit=$(uci -q get tor_ui.main.custom_exit || echo 0)
	strict_exit=$(uci -q get tor_ui.main.strict_exit || echo 0)
	[ "$strict_exit" = "1" ] || strict_exit=0
	exit_nodes=$(uci -q get tor_ui.main.exit_node || echo "")
	use_bridge=$(uci -q get tor_ui.main.use_bridge || echo 0)
	bridge_mode=$(uci -q get tor_ui.main.bridge_mode || echo "auto")
	bridge_lines=$(uci -q get tor_ui.main.bridge_lines || echo "")
	socks_port=$(uci -q get tor_ui.main.socks_port || echo 9050)
	trans_port=$(uci -q get tor_ui.main.trans_port || echo 9040)
	dns_port=$(uci -q get tor_ui.main.dns_port || echo 9053)
	[ -n "$socks_port" ] || socks_port=9050
	[ -n "$trans_port" ] || trans_port=9040
	[ -n "$dns_port" ] || dns_port=9053
	validate_tor_ports "$socks_port" "$trans_port" "$dns_port" || return 1
	lan_ip=$(uci -q get network.lan.ipaddr)
	if [ -z "$lan_ip" ]; then
		lan_ip="127.0.0.1"
		echo "WARNING: LAN IP could not be resolved; binding SOCKS/TransPort to loopback only. Check network.lan.ipaddr." >> "$LOG_DIR/notices.log"
	fi
	if [ ! -x "$TOR_BIN" ]; then
		echo "ERROR: $TOR_BIN not found. Install the 'tor' package." > "$LOG_DIR/notices.log"
		return 1
	fi
	compute_effective_protections
	full_tunnel=$EFF_FULL_TUNNEL
	route_dns=$EFF_ROUTE_DNS
	build_torrc_content "$full_tunnel" "$route_dns" > /etc/tor/torrc
	bridge_transport_error="$BRIDGE_TRANSPORT_ERROR"
	if [ -n "$bridge_transport_error" ]; then
		echo "ERROR: $bridge_transport_error" >> "$LOG_DIR/notices.log"
		echo "Tor NOT started. Install the required transport or choose a bridge mode supported by an installed transport." >> "$LOG_DIR/notices.log"
		if [ "$strict_ks" = "1" ]; then
			if ! write_fw_include 0 0 "$trans_port" 1 0 0; then
				echo "ERROR: failed to write kill-only firewall include." >> "$LOG_DIR/notices.log"
				set_killswitch 1
				return 1
			fi
			if [ "$FW_CHANGED" = "1" ] && ! /etc/init.d/firewall reload >/dev/null 2>&1; then
				echo "ERROR: firewall reload failed while preserving strict kill switch." >> "$LOG_DIR/notices.log"
				set_killswitch 1
				return 1
			fi
			set_killswitch 1
		else
			remove_fw_include
			[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
			set_killswitch 0
		fi
		configure_dns_over_tor 0
		flush_conntrack
		return 1
	fi
	torrc_valid=1
	: > "$LOG_DIR/verify-config.log"
	mkdir -p /tmp/tor-verify-data
	chmod 700 /tmp/tor-verify-data
	if ! timeout 15 "$TOR_BIN" --DataDirectory /tmp/tor-verify-data --verify-config -f /etc/tor/torrc > "$LOG_DIR/verify-config.log" 2>&1; then
		torrc_valid=0
		{
			echo "ERROR: torrc failed validation (tor --verify-config) -- Tor NOT started."
			echo "-- verify-config output --"
			cat "$LOG_DIR/verify-config.log"
		} >> "$LOG_DIR/notices.log"
	fi
	rm -rf /tmp/tor-verify-data
	local tor_uid
	tor_uid=$(id -u tor 2>/dev/null || echo 0)
	FW_CHANGED=0
	if ! write_fw_include "$full_tunnel" "$route_dns" "$trans_port" "$strict_ks" "$localhost_proxy" "$tor_uid"; then
		echo "ERROR: firewall include write failed during start_service." >> "$LOG_DIR/notices.log"
		[ "$strict_ks" = "1" ] && set_killswitch 1
		return 1
	fi
	if [ "$strict_ks" != "1" ]; then
		nft delete chain inet "$FW_TABLE" fwd_killswitch 2>/dev/null || true
	fi
	if [ "$FW_CHANGED" = "1" ] && ! /etc/init.d/firewall reload >/dev/null 2>&1; then
		echo "ERROR: firewall reload failed; refusing to continue startup." >> "$LOG_DIR/notices.log"
		[ "$strict_ks" = "1" ] && set_killswitch 1
		return 1
	fi
	set_killswitch "$([ "$full_tunnel" = "1" ] && [ "$strict_ks" = "1" ] && echo 1 || echo 0)"
	configure_dns_over_tor "$route_dns" "$dns_port"
	flush_conntrack
	if [ "$EFF_CONFLICT_BLOCK" = "1" ]; then
		echo "conflict_policy=block: refusing to start Tor while another VPN owns the default route." >> "$LOG_DIR/notices.log"
		echo "LAN stays fail-closed via the kill-switch rules already applied." >> "$LOG_DIR/notices.log"
		return 1
	fi
	if ! wan_is_up; then
		echo "Waiting for WAN connectivity before starting Tor..." >> "$LOG_DIR/notices.log"
		return 0
	fi
	if [ "$torrc_valid" != "1" ]; then
		return 1
	fi
	if [ "$RACE_PENDING" = "1" ]; then
		config_fingerprint > /etc/tor/tor_ui-state/applied.conf 2>/dev/null
		cp -f /etc/tor/tor_ui-state/applied.conf /var/run/tor_ui/applied.conf 2>/dev/null || true
		race_launch
		return 0
	fi
	(
		w=0
		while [ "$w" -lt 18 ]; do
			sleep 5
			w=$((w + 1))
			last=$(grep -oE 'Bootstrapped [0-9]+%' "$LOG_DIR/notices.log" 2>/dev/null | tail -1)
			case "$last" in *100%*) exit 0 ;; esac
		done
		{
			echo "HINT: Tor has not reached Bootstrapped 100% after 90 seconds."
			echo "HINT: You likely need a FRESH bridge for this network."
			echo "HINT: Get one at https://bridges.torproject.org/bridges?transport=obfs4"
			echo "HINT: then paste it into VPN -> Tor VPN -> Bridge Lines."
		} >> "$LOG_DIR/notices.log"
	) >/dev/null 2>&1 </dev/null &

	procd_open_instance "tor_service"
	procd_set_param command "$TOR_BIN" -f /etc/tor/torrc
	if id tor >/dev/null 2>&1; then
		procd_set_param user tor
	fi
	procd_set_param stdout 1
	procd_set_param stderr 1
	procd_set_param respawn 3600 3 5
	procd_set_param limits nofile="8192 8192"
	procd_close_instance
	mkdir -p /etc/tor/tor_ui-state /var/run/tor_ui
	chmod 700 /etc/tor/tor_ui-state 2>/dev/null || true
	config_fingerprint > /etc/tor/tor_ui-state/applied.conf
	cp -f /etc/tor/tor_ui-state/applied.conf /var/run/tor_ui/applied.conf 2>/dev/null || true
	memory_record_bg
	persist_save_bg
}
kill_process_tree() {
	local root="$1" sig="$2" child children
	[ -n "$root" ] || return 0
	case "$root" in *[!0-9]*|'') return 0 ;; esac
	[ "$root" -gt 1 ] 2>/dev/null || return 0
	[ -d "/proc/$root" ] || return 0
	children=$(cat "/proc/$root/task/$root/children" 2>/dev/null || true)
	for child in $children; do kill_process_tree "$child" "$sig"; done
	kill -"$sig" "$root" 2>/dev/null || true
}
stop_service() {
	local tor_pid i
	race_stop
	rm -f /var/run/tor_ui/race.result /var/run/tor_ui/race.lines /var/run/tor_ui/race.status
	tor_pid=$(cat /var/run/tor_ui/tor.pid 2>/dev/null || true)
	if [ -n "$tor_pid" ]; then
		kill_process_tree "$tor_pid" TERM
		for i in 1 2 3 4 5; do
			[ ! -d "/proc/$tor_pid" ] && break
			sleep 1
		done
		[ -d "/proc/$tor_pid" ] && kill_process_tree "$tor_pid" KILL
	fi
	rm -f /var/run/tor_ui/tor.pid
	local _ks _tp
	_ks=$(ks_on)
	[ "$_ks" = "0" ] || _ks=1
	_tp=$(uci -q get tor_ui.main.trans_port || echo 9040)
	[ -n "$_tp" ] || _tp=9040
	if [ "$_ks" = "1" ]; then
		FW_CHANGED=0
		write_fw_include 0 0 "$_tp" 1 0 0
		[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
		set_killswitch 1
	else
		remove_fw_include
		[ "$FW_CHANGED" = "1" ] && /etc/init.d/firewall reload >/dev/null 2>&1
		set_killswitch 0
	fi
	configure_dns_over_tor 0
	flush_conntrack
	if [ -f /var/lib/tor/state ]; then
		mkdir -p /etc/tor/tor_ui-state 2>/dev/null
		chmod 700 /etc/tor/tor_ui-state 2>/dev/null || true
		cp -f /var/lib/tor/state /etc/tor/tor_ui-state/tor-state 2>/dev/null || true
		chmod 600 /etc/tor/tor_ui-state/tor-state 2>/dev/null || true
	fi
	return 0
}
service_stopped() {
	return 0
}
purge() {
	stop
	rm -rf /var/lib/tor/* "$LOG_DIR"/*.log /etc/tor/torrc 2>/dev/null
	persist_wipe all
	memory_forget
	return 0
}
forget_memory() {
	memory_forget
	echo "Memory mode record cleared."
	return 0
}
refresh_fw() {
	local full_tunnel route_dns trans_port strict_ks localhost_proxy
	full_tunnel=1
	route_dns=1
	strict_ks=$(ks_on)
	[ "$strict_ks" = "0" ] || strict_ks=1
	localhost_proxy=$(uci -q get tor_ui.main.localhost_proxy 2>/dev/null)
	[ "$localhost_proxy" = "1" ] || localhost_proxy=0
	trans_port=$(uci -q get tor_ui.main.trans_port || echo 9040)
	[ -n "$trans_port" ] || trans_port=9040
	FW_CHANGED=0
	if ! write_fw_include "$full_tunnel" "$route_dns" "$trans_port" "$strict_ks" "$localhost_proxy"; then
		echo "ERROR: failed to write firewall include during WAN refresh." >> "$LOG_DIR/notices.log"
		[ "$strict_ks" = "1" ] && set_killswitch 1
		return 1
	fi
	if [ "$strict_ks" != "1" ]; then
		nft delete chain inet "$FW_TABLE" fwd_killswitch 2>/dev/null || true
	fi
	if [ "$FW_CHANGED" = "1" ] && ! /etc/init.d/firewall reload >/dev/null 2>&1; then
		echo "ERROR: firewall reload failed during WAN hotplug refresh." >> "$LOG_DIR/notices.log"
		[ "$strict_ks" = "1" ] && set_killswitch 1
		return 1
	fi
	return 0
}
reload_tor() {
	if ! acquire_lock; then
		echo "Another tor_ui operation is in progress; refusing to reload." >> "$LOG_DIR/notices.log"
		return 1
	fi
	local current previous
	current=$(config_fingerprint)
	previous=$(cat /etc/tor/tor_ui-state/applied.conf 2>/dev/null || echo "")
	if [ "$current" = "$previous" ]; then
		echo "Configuration unchanged; Tor left running as-is." >> "$LOG_DIR/notices.log"
		return 0
	fi
	if command -v build_torrc_content >/dev/null 2>&1 || type build_torrc_content >/dev/null 2>&1; then
		compute_effective_protections 2>/dev/null || { EFF_FULL_TUNNEL=1; EFF_ROUTE_DNS=1; EFF_CONFLICT_BLOCK=0; }
		if [ "$EFF_CONFLICT_BLOCK" = "1" ]; then
			echo "conflict_policy=block: refusing to reload while another VPN owns the default route." >> "$LOG_DIR/notices.log"
			return 1
		fi
		build_torrc_content "$EFF_FULL_TUNNEL" "$EFF_ROUTE_DNS" > /tmp/torrc.new 2>/dev/null
		if [ "$RACE_PENDING" = "1" ]; then
			rm -f /tmp/torrc.new
			stop
			TOR_UI_MANUAL=1 start
			return $?
		fi
		if [ -n "$BRIDGE_TRANSPORT_ERROR" ]; then
			echo "ERROR: $BRIDGE_TRANSPORT_ERROR" >> "$LOG_DIR/notices.log"
			echo "Reload aborted; previous Tor configuration left running." >> "$LOG_DIR/notices.log"
			rm -f /tmp/torrc.new
			return 1
		fi
		: > "$LOG_DIR/verify-config.log"
		mkdir -p /tmp/tor-verify-data
		chmod 700 /tmp/tor-verify-data
		if ! timeout 15 "$TOR_BIN" --DataDirectory /tmp/tor-verify-data --verify-config -f /tmp/torrc.new > "$LOG_DIR/verify-config.log" 2>&1; then
			{
				echo "ERROR: new torrc failed validation (tor --verify-config) -- reload aborted."
				echo "-- verify-config output --"
				cat "$LOG_DIR/verify-config.log"
			} >> "$LOG_DIR/notices.log"
			rm -f /tmp/torrc.new
			return 1
		fi
		rm -rf /tmp/tor-verify-data
		mv /tmp/torrc.new /etc/tor/torrc
		local tor_uid trans_port dns_port strict_ks localhost_proxy
		tor_uid=$(id -u tor 2>/dev/null || echo 0)
		trans_port=$(uci -q get tor_ui.main.trans_port || echo 9040)
		[ -n "$trans_port" ] || trans_port=9040
		dns_port=$(uci -q get tor_ui.main.dns_port || echo 9053)
		[ -n "$dns_port" ] || dns_port=9053
		strict_ks=$(ks_on)
		[ "$strict_ks" = "0" ] || strict_ks=1
		localhost_proxy=$(uci -q get tor_ui.main.localhost_proxy 2>/dev/null)
		[ "$localhost_proxy" = "1" ] || localhost_proxy=0
		FW_CHANGED=0
		if ! write_fw_include "$EFF_FULL_TUNNEL" "$EFF_ROUTE_DNS" "$trans_port" "$strict_ks" "$localhost_proxy" "$tor_uid"; then
			echo "ERROR: firewall include write failed during reload_tor; aborting reload." >> "$LOG_DIR/notices.log"
			[ "$strict_ks" = "1" ] && set_killswitch 1
			return 1
		fi
		if [ "$strict_ks" != "1" ]; then
			nft delete chain inet "$FW_TABLE" fwd_killswitch 2>/dev/null || true
		fi
		if [ "$FW_CHANGED" = "1" ] && ! /etc/init.d/firewall reload >/dev/null 2>&1; then
			echo "ERROR: firewall reload failed during reload_tor; aborting reload." >> "$LOG_DIR/notices.log"
			[ "$strict_ks" = "1" ] && set_killswitch 1
			return 1
		fi
		set_killswitch "$([ "$EFF_FULL_TUNNEL" = "1" ] && [ "$strict_ks" = "1" ] && echo 1 || echo 0)"
		configure_dns_over_tor "$EFF_ROUTE_DNS" "$dns_port"
		flush_conntrack
		local tor_pid
		tor_pid=$(cat /var/run/tor_ui/tor.pid 2>/dev/null)
		if [ -n "$tor_pid" ] && [ -d "/proc/$tor_pid" ]; then
			kill -HUP "$tor_pid" 2>/dev/null || true
		fi
		config_fingerprint > /etc/tor/tor_ui-state/applied.conf
		cp -f /etc/tor/tor_ui-state/applied.conf /var/run/tor_ui/applied.conf 2>/dev/null || true
		return 0
	fi
	stop
	TOR_UI_MANUAL=1 start
	return $?
}
apply() {
	local _cur _prev
	if ! acquire_lock; then
		echo "Another tor_ui operation is in progress; refusing to apply."
		return 1
	fi
	_cur=$(ks_on)
	_prev=$(cat "$TOR_STATE_DIR/autoconnect.applied" 2>/dev/null)
	if [ "$_prev" != "$_cur" ]; then
		mkdir -p "$TOR_STATE_DIR" 2>/dev/null
		printf '%s\n' "$_cur" > "$TOR_STATE_DIR/autoconnect.applied" 2>/dev/null || true
	fi
	if [ "$_cur" = "0" ] && [ "$_prev" != "0" ]; then
		teardown_all
		echo "Auto Connect is OFF: Tor stopped; firewall, DNS and Kill Switch rules removed."
		return 0
	fi
	if tor_is_running; then
		reload_tor
		return $?
	fi
	if race_running; then
		stop
		TOR_UI_MANUAL=1 start
		return $?
	fi
	echo "Tor is not running; settings remain saved but unapplied to a stopped tunnel."
	return 0
}
EOF
chmod +x /etc/init.d/tor_ui
mkdir -p /usr/share/rpcd/acl.d
cat << 'ACLEOF' > /usr/share/rpcd/acl.d/luci-app-tor.json
{
    "luci-app-tor": {
        "description": "Tor VPN control panel permissions",
        "read": {
            "file": {
                "/var/log/tor/notices.log": [ "read" ],
                "/var/log/tor/notices.log.1": [ "read" ],
                "/etc/tor/torrc": [ "read" ],
                "/etc/tor/tor_ui-state/*": [ "read" ]
            }
        },
        "write": {
            "file": {
                "/bin/sh": [ "exec" ],
                "/etc/init.d/tor_ui": [ "exec" ]
            },
            "uci": {
                "tor_ui": [ "read", "write", "order" ]
            }
        }
    }
}
ACLEOF
echo "5. Adding WAN-online hotplug hook (auto-retry once internet is back)..."
mkdir -p /etc/hotplug.d/iface
cat << 'EOF' > /etc/hotplug.d/iface/95-tor_ui
#!/bin/sh
[ "$ACTION" = "ifup" ] || exit 0
if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
	_nexthop=$(ubus -S call network.interface.$INTERFACE status 2>/dev/null \
		| jsonfilter -e '@.route[@.target="0.0.0.0"].nexthop' 2>/dev/null)
	[ -n "$_nexthop" ] || exit 0
else
	case "$INTERFACE" in
		wan|wan6) ;;
		*) exit 0 ;;
	esac
fi
[ "$(uci -q get tor_ui.main.enabled)" = "1" ] || exit 0
_tor_running=0
if command -v ubus >/dev/null 2>&1 && command -v jsonfilter >/dev/null 2>&1; then
	_running=$(ubus -S call service list '{"name":"tor_ui"}' 2>/dev/null \
		| jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null)
	[ "$_running" = "true" ] && _tor_running=1
else
	_p=$(cat /var/run/tor_ui/tor.pid 2>/dev/null)
	[ -n "$_p" ] && kill -0 "$_p" 2>/dev/null && _tor_running=1
fi
if [ "$_tor_running" = "1" ]; then
	if ! /etc/init.d/tor_ui refresh_fw >/dev/null 2>&1; then
		logger -t tor_ui "refresh_fw failed after WAN ifup on interface '$INTERFACE'"
	fi
else
	if ! /etc/init.d/tor_ui start >/dev/null 2>&1; then
		logger -t tor_ui "start failed after WAN ifup on interface '$INTERFACE'"
	fi
fi
EOF
chmod +x /etc/hotplug.d/iface/95-tor_ui
if [ "$(uci -q get tor_ui.main.enabled)" = "1" ]; then
    /etc/init.d/tor_ui enable
else
    /etc/init.d/tor_ui disable
    /etc/init.d/tor_ui stop >/dev/null 2>&1 || true
fi
echo "6. Marking persistent paths for sysupgrade..."
SUCONF="/etc/sysupgrade.conf"
touch "$SUCONF"
for _p in \
    /etc/config/tor_ui \
    /etc/tor/torrc \
    /etc/tor/tor_ui-state \
    /etc/firewall.tor_ui \
    /etc/init.d/tor_ui \
    /etc/hotplug.d/iface/95-tor_ui \
    /www/luci-static/resources/view/tor \
    /usr/share/luci/menu.d/luci-app-tor.json \
    /usr/share/rpcd/acl.d/luci-app-tor.json \
    /usr/libexec/tor_ui
do
    grep -qxF "$_p" "$SUCONF" 2>/dev/null || echo "$_p" >> "$SUCONF"
done
echo "7. Installing /usr/libexec/tor_ui/status.sh..."
mkdir -p /usr/libexec/tor_ui
cat > /usr/libexec/tor_ui/status.sh <<'STATUSEOF'
#!/bin/sh

LOG=/var/log/tor/notices.log
if [ ! -s "$LOG" ] && [ -s "$LOG.1" ]; then
    LOG="$LOG.1"
fi
PIDFILE=/var/run/tor_ui/tor.pid

RUNNING=0
if ubus -S call service list '{"name":"tor_ui"}' 2>/dev/null \
   | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null \
   | grep -qx true; then
    RUNNING=1
else
    P=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$P" ] && kill -0 "$P" 2>/dev/null && RUNNING=1
fi
echo "RUNNING=$RUNNING"

SOCKS=$(uci -q get tor_ui.main.socks_port); [ -z "$SOCKS" ] && SOCKS=9050
TRANS=$(uci -q get tor_ui.main.trans_port); [ -z "$TRANS" ] && TRANS=9040
DNS=$(uci -q get tor_ui.main.dns_port);    [ -z "$DNS" ]   && DNS=9053
echo "SOCKS_PORT=$SOCKS"
echo "TRANS_PORT=$TRANS"
echo "DNS_PORT=$DNS"

BS=""
if [ -f "$LOG" ]; then
    BS=$(grep -o 'Bootstrapped [0-9]*%' "$LOG" 2>/dev/null | tail -1 | grep -o '[0-9]*%')
    STOP_NUM=$(grep -na 'Catching signal\|exiting cleanly' "$LOG" 2>/dev/null | tail -1 | cut -d: -f1)
    BS_NUM=$(grep -na 'Bootstrapped' "$LOG" 2>/dev/null | tail -1 | cut -d: -f1)
    if [ -n "$STOP_NUM" ] && [ -n "$BS_NUM" ] && [ "$BS_NUM" -lt "$STOP_NUM" ]; then
        BS=""
    fi
fi
echo "BOOTSTRAP=${BS}"

_ltn=""
if command -v netstat >/dev/null 2>&1; then
    _ltn=$(netstat -ltn 2>/dev/null)
elif command -v ss >/dev/null 2>&1; then
    _ltn=$(ss -ltn 2>/dev/null)
fi
case "$_ltn" in
    *":$SOCKS "*) echo "SOCKS_LISTEN=1" ;;
    *) echo "SOCKS_LISTEN=0" ;;
esac
case "$_ltn" in
    *":$TRANS "*) echo "TRANS_LISTEN=1" ;;
    *) echo "TRANS_LISTEN=0" ;;
esac

if nft list table inet tor_ui_fw >/dev/null 2>&1; then
    echo "FW_TABLE=1"
else
    echo "FW_TABLE=0"
fi
if nft list chain inet tor_ui_fw fwd_leak_guard >/dev/null 2>&1; then
    echo "FW_LEAKGUARD=1"
else
    echo "FW_LEAKGUARD=0"
fi
if nft list chain inet tor_ui_fw fwd_killswitch >/dev/null 2>&1; then
    echo "FW_KILLSWITCH=1"
else
    echo "FW_KILLSWITCH=0"
fi

TR=""; for b in lyrebird obfs4proxy snowflake-client; do
    command -v "$b" >/dev/null 2>&1 && TR="$TR $b"
done
echo "TRANSPORTS=$TR"

echo "CONN_MODE_CFG=race"
[ -r /var/run/tor_ui/conn.status ] && cat /var/run/tor_ui/conn.status
if [ -r /var/run/tor_ui/race.status ]; then sed 's/^/RACE_/' /var/run/tor_ui/race.status; fi
if [ -r /etc/tor/tor_ui-state/memory.conf ]; then
    echo "MEMORY_TYPE=$(sed -n 's/^TYPE=//p' /etc/tor/tor_ui-state/memory.conf | head -n 1)"
    echo "MEMORY_BRIDGES=$(grep -c . /etc/tor/tor_ui-state/memory.bridges 2>/dev/null || echo 0)"
fi

FT=$(uci -q get tor_ui.main.full_tunnel)
KS=$(uci -q get tor_ui.main.enabled)
if [ "$FT" = "1" ] || [ "$KS" = "1" ]; then
    _v6_rule=0
    if nft list chain inet tor_ui_fw fwd_leak_guard 2>/dev/null | grep -q "meta nfproto ipv6"; then
        _v6_rule=1
    elif nft list chain inet tor_ui_fw fwd_killswitch 2>/dev/null | grep -q "meta nfproto ipv6"; then
        _v6_rule=1
    fi
    IPV6=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null)
    if [ "$_v6_rule" = "1" ]; then
        if [ "$IPV6" = "0" ]; then
            echo "IPV6=BLOCKED"
        else
            echo "IPV6=BLOCKED_KERNEL_ON"
        fi
    else
        echo "IPV6=EXPOSED"
    fi
else
    echo "IPV6=NA"
fi

if [ "${1:-}" = "test-functional" ] && [ "$RUNNING" = "1" ]; then
    if curl -sL -4 -m 8 --socks5-hostname 127.0.0.1:"$SOCKS" \
       https://check.torproject.org/api/ip 2>/dev/null \
       | grep -q '"IsTor"[[:space:]]*:[[:space:]]*true'; then
        echo "FUNCTIONAL=1"
    else
        echo "FUNCTIONAL=0"
    fi
fi
STATUSEOF
chmod 0755 /usr/libexec/tor_ui/status.sh
echo "   -> /usr/libexec/tor_ui/status.sh installed"
echo "7a. Installing fixed RPC dispatcher (not yet wired into LuCI)..."
cat > /usr/libexec/tor_ui/rpc.sh <<'RPC_EOF'
#!/bin/sh
set -e

[ "$#" -eq 1 ] || { echo "rpc.sh: exactly one subcommand is required" >&2; exit 2; }

case "$1" in
    sync-autostart)
        if [ "$(uci -q get tor_ui.main.enabled 2>/dev/null || true)" = "1" ]; then
            /etc/init.d/tor_ui enable
        else
            /etc/init.d/tor_ui disable
        fi
        ;;
    apply)
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui apply
        ;;
    start)
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui start
        ;;
    stop)
        /etc/init.d/tor_ui stop
        ;;
    status)
        exec /usr/libexec/tor_ui/status.sh
        ;;
    test-functional)
        exec /usr/libexec/tor_ui/status.sh test-functional
        ;;
    check-running)
        if ubus -S call service list '{"name":"tor_ui"}' 2>/dev/null \
           | jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null \
           | grep -qx true; then
            echo 1
            exit 0
        fi
        _pid=$(cat /var/run/tor_ui/tor.pid 2>/dev/null || true)
        case "$_pid" in
            ''|*[!0-9]*) echo 0 ;;
            *) if kill -0 "$_pid" 2>/dev/null; then echo 1; else echo 0; fi ;;
        esac
        ;;
    cache-info)
        for _f in /var/lib/tor/cached-* /var/lib/tor/state /var/lib/tor/lock; do
            [ -e "$_f" ] || continue
            printf '%s %s\n' "$(basename "$_f")" "$(( $(wc -c < "$_f") / 1024 ))"
        done
        for _d in keys pt_state; do
            if [ -d "/var/lib/tor/$_d" ]; then echo "$_d/ dir"; fi
        done
        _P=$(uci -q get tor_ui.main.persist_dir 2>/dev/null || true); [ -n "$_P" ] || _P=/.tor
        if [ -s "$_P/cached-microdesc-consensus" ]; then echo "saved-snapshot $(date -r "$_P/cached-microdesc-consensus" '+%Y-%m-%d %H:%M')"; fi
        ;;
    clear-cache)
        /etc/init.d/tor_ui clear_cache
        ;;
    traffic)
        _out=""
        _cf=/var/lib/tor/control_auth_cookie
        _ck=$(od -An -v -tx1 "$_cf" 2>/dev/null | tr -d ' \n' || true)
        [ -n "$_ck" ] || _ck=$(hexdump -ve '1/1 "%.2x"' "$_cf" 2>/dev/null || true)
        _cmds=$(printf 'AUTHENTICATE %s\r\nGETINFO traffic/read\r\nGETINFO traffic/written\r\nQUIT\r\n' "$_ck")
        if [ -n "$_ck" ]; then
            _out=$({ printf '%s\r\n' "$_cmds"; sleep 1; } | nc -w 3 127.0.0.1 9051 2>/dev/null | tr -d '\r' || true)
            case "$_out" in *traffic/read=*) ;; *)
                _out=$({ printf '%s\r\n' "$_cmds"; sleep 1; } | curl -s -m 4 telnet://127.0.0.1:9051 -T - 2>/dev/null | tr -d '\r' || true) ;;
            esac
        fi
        case "$_out" in
            *traffic/read=*) printf '%s\n' "$_out"; exit 0 ;;
        esac
        # ControlPort unusable: count only while tor runs; baseline = first sample of this tor pid
        _tp=$(cat /var/run/tor_ui/tor.pid 2>/dev/null || true)
        case "$_tp" in ''|*[!0-9]*) exit 0 ;; esac
        kill -0 "$_tp" 2>/dev/null || exit 0
        _src=io; _r=""; _w=""
        if [ -r "/proc/$_tp/io" ]; then
            _r=$(sed -n 's/^rchar: //p' "/proc/$_tp/io" 2>/dev/null || true)
            _w=$(sed -n 's/^wchar: //p' "/proc/$_tp/io" 2>/dev/null || true)
        fi
        case "$_r$_w" in
            ''|*[!0-9]*)
                _src=wan
                _dev=$(ubus -S call network.interface.wan status 2>/dev/null | jsonfilter -e '@.l3_device' 2>/dev/null || true)
                [ -n "$_dev" ] || _dev=$(uci -q get network.wan.device || true)
                [ -n "$_dev" ] || _dev=$(ip route show default 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')
                _r=""; _w=""
                if [ -n "$_dev" ] && [ -r "/sys/class/net/$_dev/statistics/rx_bytes" ]; then
                    _r=$(cat "/sys/class/net/$_dev/statistics/rx_bytes")
                    _w=$(cat "/sys/class/net/$_dev/statistics/tx_bytes")
                fi
                ;;
        esac
        case "$_r$_w" in ''|*[!0-9]*) exit 0 ;; esac
        _bf=/var/run/tor_ui/traf.base; _bs=""; _bp=""; _br=0; _bw=0
        if [ -r "$_bf" ]; then read -r _bs _bp _br _bw < "$_bf" || true; fi
        if [ "$_bs" != "$_src" ] || [ "$_bp" != "$_tp" ] || [ "$_r" -lt "$_br" ] || [ "$_w" -lt "$_bw" ]; then
            _br=$_r; _bw=$_w
            echo "$_src $_tp $_r $_w" > "$_bf" 2>/dev/null || true
        fi
        echo "traffic/read=$((_r - _br))"
        echo "traffic/written=$((_w - _bw))"
        ;;
    traffic-debug)
        echo "tools: od=$(command -v od || echo MISSING) hexdump=$(command -v hexdump || echo MISSING) nc=$(command -v nc || echo MISSING) curl=$(command -v curl || echo MISSING)"
        _tp=$(cat /var/run/tor_ui/tor.pid 2>/dev/null || true); echo "tor pid: $_tp"
        echo "proc io: $([ -r "/proc/$_tp/io" ] && echo present || echo MISSING)"
        _ck=$(od -An -v -tx1 /var/lib/tor/control_auth_cookie 2>/dev/null | tr -d ' \n' || true)
        echo "cookie hex length: ${#_ck}"
        echo "--- control port reply ---"
        { printf 'AUTHENTICATE %s\r\nGETINFO traffic/read\r\nQUIT\r\n' "$_ck"; sleep 1; } | nc -w 3 127.0.0.1 9051 2>&1 | tr -d '\r' || true
        ;;
    read-log)
        if [ -r /var/log/tor/notices.log ]; then
            tail -n 500 /var/log/tor/notices.log
        fi
        ;;
    *)
        echo "rpc.sh: unknown subcommand" >&2
        exit 2
        ;;
esac
RPC_EOF
chmod 0755 /usr/libexec/tor_ui/rpc.sh
echo "   -> /usr/libexec/tor_ui/rpc.sh installed (UI migration is a later step)"
echo "7b. Installing fixed circuit-check helper (not yet wired into LuCI)..."
cat > /usr/libexec/tor_ui/circuit-check.sh <<'CIRCUIT_EOF'
#!/bin/sh
set +e

[ "$#" -eq 0 ] || { echo "circuit-check.sh: no arguments are accepted" >&2; exit 2; }

PORT_SOCKS=$(uci -q get tor_ui.main.socks_port 2>/dev/null)
case "$PORT_SOCKS" in ''|*[!0-9]*) PORT_SOCKS=9050 ;; esac

TMP=$(mktemp -d /tmp/tor_ui.XXXXXX 2>/dev/null) || TMP=''
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "ERROR: mktemp failed" >&2; exit 1; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
: > "$TMP/real"
: > "$TMP/tor"
: > "$TMP/torgeo"

WAN_IF=$(ip route show default 2>/dev/null | awk '$0 !~ /(^|[[:space:]])dev[[:space:]]+tun0([[:space:]]|$)/ { for (i=1;i<=NF;i++) if ($i=="dev" && (i+1)<=NF) { print $(i+1); exit } }')

(
    if [ -n "$WAN_IF" ]; then
        RIP=$(curl -s -4 -m 2 --interface "$WAN_IF" -H 'accept: application/dns-json' \
            'https://1.1.1.1/dns-query?name=ipwho.is&type=A' 2>/dev/null |
            sed -n 's/.*"data":"\([0-9.]*\)".*/\1/p' | head -n1)
    else
        RIP=$(curl -s -4 -m 2 -H 'accept: application/dns-json' \
            'https://1.1.1.1/dns-query?name=ipwho.is&type=A' 2>/dev/null |
            sed -n 's/.*"data":"\([0-9.]*\)".*/\1/p' | head -n1)
    fi
    R=''
    if [ -n "$RIP" ]; then
        if [ -n "$WAN_IF" ]; then
            R=$(curl -sL -4 -m 3 --interface "$WAN_IF" --resolve "ipwho.is:443:$RIP" 'https://ipwho.is/' 2>/dev/null)
        else
            R=$(curl -sL -4 -m 3 --resolve "ipwho.is:443:$RIP" 'https://ipwho.is/' 2>/dev/null)
        fi
    fi
    if [ -z "$R" ]; then
        if [ -n "$WAN_IF" ]; then
            R=$(curl -sL -4 -m 3 --interface "$WAN_IF" 'https://ipwho.is/' 2>/dev/null)
        else
            R=$(curl -sL -4 -m 3 'https://ipwho.is/' 2>/dev/null)
        fi
    fi
    printf '%s' "$R" | grep -q '"ip"' || R=''
    printf '%s' "$R" | grep -q '"success":false' && R=''
    if [ -z "$R" ]; then
        if [ -n "$WAN_IF" ]; then
            R=$(curl -sL -4 -m 3 --interface "$WAN_IF" 'https://ipapi.co/json/' 2>/dev/null)
        else
            R=$(curl -sL -4 -m 3 'https://ipapi.co/json/' 2>/dev/null)
        fi
    fi
    printf '%s' "$R" | grep -q '"error"' && R=''
    printf '%s' "$R" > "$TMP/real"
    : > "$TMP/real.done"
) &
REAL_PID=$!

(
    curl -sL -4 -m 7 --socks5-hostname "127.0.0.1:$PORT_SOCKS" \
        'https://check.torproject.org/api/ip' 2>/dev/null > "$TMP/tor"
    TORIP=$(grep -o '"IP":"[^"]*"' "$TMP/tor" 2>/dev/null | head -n1 | cut -d'"' -f4)
    if [ -n "$TORIP" ]; then
        curl -sL -4 -m 4 "https://ipwho.is/$TORIP" 2>/dev/null > "$TMP/torgeo"
    fi
    : > "$TMP/tor.done"
) &
TOR_PID=$!

_elapsed=0
while [ "$_elapsed" -lt 12 ]; do
    [ -f "$TMP/real.done" ] && [ -f "$TMP/tor.done" ] && break
    sleep 1
    _elapsed=$((_elapsed + 1))
done
[ -f "$TMP/real.done" ] || kill "$REAL_PID" 2>/dev/null
[ -f "$TMP/tor.done" ] || kill "$TOR_PID" 2>/dev/null
wait "$REAL_PID" 2>/dev/null
wait "$TOR_PID" 2>/dev/null


printf 'REALJSON='; tr -d '\n\r' < "$TMP/real" 2>/dev/null; echo
printf 'TORJSON='; tr -d '\n\r' < "$TMP/tor" 2>/dev/null; echo
printf 'TORGEOJSON='; tr -d '\n\r' < "$TMP/torgeo" 2>/dev/null; echo
CIRCUIT_EOF
chmod 0755 /usr/libexec/tor_ui/circuit-check.sh
echo "   -> /usr/libexec/tor_ui/circuit-check.sh installed (UI migration is a later step)"
echo "7c. Installing update/uninstall helper..."
cat > /usr/libexec/tor_ui/maint.sh <<'MAINT_EOF'
#!/bin/sh
MAINT_LOG=/tmp/tormaint.log
MAINT_ST=/tmp/tormaint.state
MAINT_RUN=/tmp/tormaint-run.sh
LOCAL_INSTALLER=/usr/libexec/tor_ui/installer.sh
MAINT_SELF=/usr/libexec/tor_ui/maint.sh
# Fixed update source (not user-editable). A github.com/.../blob/... page link is
# converted to its raw.githubusercontent.com form before downloading.
UPDATE_URL="https://github.com/MehArt44/Tor-VPN-Openwrt25-24-LuCI/blob/main/TorVpn_UPDATE.sh"
raw_url() { printf '%s' "$1" | sed 's#^https://github\.com/\([^/]*\)/\([^/]*\)/blob/#https://raw.githubusercontent.com/\1/\2/#'; }
RAW_URL=$(raw_url "$UPDATE_URL")
inst_build() { sed -n 's/^BUILD_DATE=//p' /usr/libexec/tor_ui/version 2>/dev/null | head -n1 | tr -cd '0-9.-'; }
file_build() { head -n 25 "$1" 2>/dev/null | sed -n 's/^BUILD_DATE="\([0-9.-]*\)".*/\1/p' | head -n1; }
# cmp_build REMOTE INSTALLED -> unknown | newer | same | older
cmp_build() {
	rd="$1"; id="$2"
	printf '%s' "$rd" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}(\.[0-9]+)?$' || { echo unknown; return 0; }
	[ -n "$id" ] || { echo newer; return 0; }
	rdd=$(printf '%s' "${rd%%.*}" | tr -d '-'); rrv=0; case "$rd" in *.*) rrv="${rd#*.}" ;; esac
	idd=$(printf '%s' "${id%%.*}" | tr -d '-'); irv=0; case "$id" in *.*) irv="${id#*.}" ;; esac
	case "$irv" in ''|*[!0-9]*) irv=0 ;; esac
	if [ "$rdd" -gt "$idd" ] 2>/dev/null; then echo newer
	elif [ "$rdd" -lt "$idd" ] 2>/dev/null; then echo older
	elif [ "$rrv" -gt "$irv" ] 2>/dev/null; then echo newer
	elif [ "$rrv" -lt "$irv" ] 2>/dev/null; then echo older
	else echo same; fi
}

url_ok() { printf '%s' "$1" | grep -qE '^https://[A-Za-z0-9._~:/?#@!+,=%&-]+$'; }

cmd_start() {
	act="$1"; purge="$2"; force="$3"; url="$RAW_URL"; port=""
	case "$act" in update|uninstall) ;; *) echo "bad-action"; return 1 ;; esac
	[ "$purge" = "1" ] || purge=0
	[ "$force" = "1" ] || force=0
	url_ok "$url" || { echo "bad-url"; return 1; }
	need_dl=1
	[ "$act" = "uninstall" ] && [ -s "$LOCAL_INSTALLER" ] && need_dl=0
	if [ "$need_dl" = "1" ]; then
		command -v curl >/dev/null 2>&1 || { echo "no-curl"; return 1; }
	fi
	if [ -f "$MAINT_ST" ] && grep -q '^running' "$MAINT_ST" 2>/dev/null; then
		pid=$(awk '{print $3}' "$MAINT_ST" 2>/dev/null)
		case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
		[ "$pid" -gt 1 ] && kill -0 "$pid" 2>/dev/null && { echo "busy"; return 1; }
	fi
	tp=$(cat /var/run/tor_ui/tor.pid 2>/dev/null)
	if [ -n "$tp" ] && kill -0 "$tp" 2>/dev/null; then
		port=$(uci -q get tor_ui.main.socks_port 2>/dev/null); [ -n "$port" ] || port=9050
	fi
	cat > "$MAINT_RUN" <<'__TOR_RUN__'
#!/bin/sh
trap '' HUP
ACTION="$1"
ST=/tmp/tormaint.state
F=/tmp/tormaint-installer.sh
fin() { echo "$1 $ACTION $$ $2" > "$ST"; }
rm -f "$F"
if [ "$ACTION" = "uninstall" ] && [ -s "$TOR_LOCAL" ]; then
	echo "[1/3] Using the local installer copy"
	cp "$TOR_LOCAL" "$F" || { echo "ERROR: cannot copy the local installer."; fin failed 3; exit 3; }
else
	echo "[1/3] Downloading $TOR_URL"
	if curl -fsSL -m 60 -H "Cache-Control: no-cache" --url "$TOR_URL" -o "$F" 2>/dev/null; then
		echo "      direct download OK"
	elif [ -n "$TOR_SOCKS" ] && curl -fsSL -m 90 -H "Cache-Control: no-cache" --socks5-hostname "127.0.0.1:$TOR_SOCKS" --url "$TOR_URL" -o "$F" 2>/dev/null; then
		echo "      downloaded through the Tor tunnel"
	else
		echo "ERROR: download failed (GitHub is unreachable). Connect Tor first, then try again."
		rm -f "$F"; fin failed 3; exit 3
	fi
fi
echo "[2/3] Checking the script"
SZ=$(wc -c < "$F" 2>/dev/null); SZ=${SZ:-0}
if [ "$SZ" -lt 3000 ] || ! head -n1 "$F" | grep -q '^#!/bin/sh' || ! grep -q 'tor_ui' "$F" || ! sh -n "$F" 2>/dev/null; then
	echo "ERROR: not a valid installer script (size $SZ) - nothing was changed."
	rm -f "$F"; fin failed 4; exit 4
fi
echo "      OK ($SZ bytes)"
if [ "$ACTION" = "update" ]; then
	set -- $(sh "$TOR_MAINT" cmpfile "$F" 2>/dev/null)
	CMP="$1"; RB="$2"; IB="$3"
	echo "      installed build: ${IB:-unknown} | online build: ${RB:-unknown} ($CMP)"
	if [ "$TOR_FORCE" != "1" ] && { [ "$CMP" = "same" ] || [ "$CMP" = "older" ]; }; then
		echo "Already up to date - the online build is not newer. Nothing was changed."
		rm -f "$F"; fin uptodate 0; exit 0
	fi
fi
echo "[3/3] Running it"
case "$ACTION" in
	update)    sh "$F" ;;
	uninstall) if [ "$TOR_PURGE" = "1" ]; then sh "$F" uninstall --purge; else sh "$F" uninstall; fi ;;
esac
rc=$?
rm -f "$F"
if [ "$rc" = 0 ]; then echo "FINISHED OK"; fin done 0; else echo "FINISHED WITH ERRORS (exit $rc)"; fin failed "$rc"; fi
exit "$rc"
__TOR_RUN__
	chmod 700 "$MAINT_RUN"
	: > "$MAINT_LOG"
	if command -v setsid >/dev/null 2>&1; then
		TOR_SOCKS="$port" TOR_PURGE="$purge" TOR_FORCE="$force" TOR_MAINT="$MAINT_SELF" TOR_URL="$url" TOR_LOCAL="$LOCAL_INSTALLER" setsid sh "$MAINT_RUN" "$act" >"$MAINT_LOG" 2>&1 </dev/null &
	else
		TOR_SOCKS="$port" TOR_PURGE="$purge" TOR_FORCE="$force" TOR_MAINT="$MAINT_SELF" TOR_URL="$url" TOR_LOCAL="$LOCAL_INSTALLER" nohup sh "$MAINT_RUN" "$act" >"$MAINT_LOG" 2>&1 </dev/null &
	fi
	echo "running $act $!" > "$MAINT_ST"
	echo started
}

cmd_status() {
	[ -f "$MAINT_ST" ] || { echo '{"state":"idle","action":"","rc":0}'; return 0; }
	read -r st act pid rc < "$MAINT_ST"
	case "$act" in update|uninstall) ;; *) act="" ;; esac
	case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
	case "$rc" in ''|*[!0-9]*) rc=0 ;; esac
	if [ "$st" = running ] && { [ "$pid" -le 1 ] || ! kill -0 "$pid" 2>/dev/null; }; then st=failed; rc=1; fi
	case "$st" in running|done|failed|uptodate) ;; *) st=idle ;; esac
	printf '{"state":"%s","action":"%s","rc":%s}\n' "$st" "$act" "$rc"
}

cmd_version() {
	vf=/usr/libexec/tor_ui/version; iv=""; ib=""
	if [ -r "$vf" ]; then
		iv=$(sed -n 's/^BUILD_DATE=//p' "$vf" | head -n1 | tr -cd 'A-Za-z0-9._-')
		ib=$(sed -n 's/^VERSION=//p' "$vf" | head -n1 | tr -cd 'A-Za-z0-9._-')
	fi
	printf '{"version":"%s","date":"%s"}\n' "$ib" "$iv"
}

cmd_check() {
	url="$RAW_URL"; port=""; via=direct
	url_ok "$url" || { echo '{"status":"error","error":"bad-url"}'; return 1; }
	command -v curl >/dev/null 2>&1 || { echo '{"status":"error","error":"no-curl"}'; return 1; }
	f=/tmp/tormaint-check.head; rm -f "$f"
	if ! { curl -fsSL -m 7 -r 0-4095 -H "Cache-Control: no-cache" --url "$url" -o "$f" 2>/dev/null && [ -s "$f" ]; }; then
		rm -f "$f"; ok=0
		tp=$(cat /var/run/tor_ui/tor.pid 2>/dev/null)
		if [ -n "$tp" ] && kill -0 "$tp" 2>/dev/null; then
			port=$(uci -q get tor_ui.main.socks_port 2>/dev/null); [ -n "$port" ] || port=9050
			if curl -fsSL -m 10 -r 0-4095 -H "Cache-Control: no-cache" --socks5-hostname "127.0.0.1:$port" --url "$url" -o "$f" 2>/dev/null && [ -s "$f" ]; then ok=1; via=tor; fi
		fi
		[ "$ok" = 1 ] || { echo '{"status":"error","error":"download-failed"}'; return 1; }
	fi
	rd=$(file_build "$f"); rm -f "$f"
	id=$(inst_build)
	st=$(cmp_build "$rd" "$id")
	[ "$st" = unknown ] && rd=""
	printf '{"status":"%s","installed":"%s","remote":"%s","via":"%s"}\n' "$st" "$id" "$rd" "$via"
}

cmd_cmpfile() {
	rd=$(file_build "$1"); id=$(inst_build)
	printf '%s %s %s\n' "$(cmp_build "$rd" "$id")" "$rd" "$id"
}

case "$1" in
	start)  cmd_start "$2" "$3" "$4" ;;
	cmpfile) cmd_cmpfile "$2" ;;
	status) cmd_status ;;
	version) cmd_version ;;
	check)  cmd_check "$2" ;;
	log)    tail -n 150 "$MAINT_LOG" 2>/dev/null ;;
	*)      echo "maint.sh: unknown subcommand" >&2; exit 2 ;;
esac
MAINT_EOF
chmod 0755 /usr/libexec/tor_ui/maint.sh
printf 'VERSION=%s\nBUILD_DATE=%s\n' "$VERSION" "$BUILD_DATE" > /usr/libexec/tor_ui/version
chmod 0644 /usr/libexec/tor_ui/version
echo "   -> installed build: $BUILD_DATE ($VERSION)"
if [ -r "$0" ] && head -n1 "$0" 2>/dev/null | grep -q '^#!/bin/sh' && grep -q 'luci-app-tor.json' "$0" 2>/dev/null; then
    cp -f "$0" /usr/libexec/tor_ui/installer.sh 2>/dev/null && chmod 0700 /usr/libexec/tor_ui/installer.sh && echo "   -> local installer copy saved (offline uninstall)"
fi
echo "   -> /usr/libexec/tor_ui/maint.sh installed"
echo "8. Clearing LuCI cache and restarting services..."
rm -rf /tmp/luci-* /tmp/ucache* 2>/dev/null || true
/etc/init.d/rpcd restart
sleep 1
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart 2>/dev/null || true
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
if [ "$TOR_UPGRADED_WHILE_RUNNING" = "1" ]; then
    echo "   -> Restarting Tor to load the upgraded binary..."
    ( TOR_UI_MANUAL=1 /etc/init.d/tor_ui start >/dev/null 2>&1 </dev/null & )
fi
echo "Done. Reload the LuCI page and open VPN -> Tor to use the new panel."
echo "Use the Stop / Start-Restart buttons in the panel to control the live tunnel."
