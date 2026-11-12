#!/bin/sh
# =============================================================================
#  tor_test_full.sh -- comprehensive test for the Tor VPN panel
#                      v69 (stage3-deltator): Auto race / Memory / Direct /
#                      Vanilla modes + Conflux, plus the whole classic panel.
#
#  What it does
#    A. Environment + tor binary capabilities (Conflux options it supports)
#    B. Installed files / UCI keys / init.d functions / LuCI view markers
#    C. OFFLINE torrc generation for every mode, each validated by the REAL
#       `tor --verify-config` (uses a scratch copy of the UCI config; the
#       live config and the running Tor are not touched)
#    D. Live service state: process, bootstrap, listeners, firewall,
#       kill switch, DNS, IPv6, ControlPort (GETCONF of the Conflux options)
#    E. Live functional checks through Tor (IsTor, exit IP, latency, speed)
#    F. LIVE MODE SWITCHING (asks first): direct, obfs4, snowflake, meek,
#       webtunnel, vanilla, memory, auto race (watches the race, RAM peak,
#       leftover processes), apply/HUP path, Conflux apply.  Tor is stopped
#       and restarted several times -> LAN traffic is interrupted.
#    G. Persistence, log scan, final restore of YOUR original settings
#
#  Usage:   sh tor_test_full.sh [options]
#     --yes          do not ask questions (runs the live mode switching)
#     --skip-live    sections A-E and G only; never restart Tor
#     --timeout N    seconds to wait for Bootstrapped 100% per mode (150)
#     --out FILE     report file (default /tmp/tor_test_report_<time>.txt)
#
#  Result: everything is also written to the report file.  Send me that file.
# =============================================================================

INIT=${INIT:-/etc/init.d/tor_ui}
TORBIN=${TORBIN:-/usr/sbin/tor}
STATE_DIR=/etc/tor/tor_ui-state
RUN_DIR=/var/run/tor_ui
NLOG=/var/log/tor/notices.log
ASSUME_YES=0; SKIP_LIVE=0; BS_TIMEOUT=150
REPORT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --yes) ASSUME_YES=1 ;;
        --skip-live) SKIP_LIVE=1 ;;
        --timeout) shift; BS_TIMEOUT="$1" ;;
        --out) shift; REPORT="$1" ;;
        -h|--help) sed -n 2,32p "$0"; exit 0 ;;
        *) echo "unknown option: $1"; exit 2 ;;
    esac
    shift
done
case "$BS_TIMEOUT" in ''|*[!0-9]*) BS_TIMEOUT=150 ;; esac
[ -n "$REPORT" ] || REPORT="/tmp/tor_test_report_$(date +%Y%m%d_%H%M%S).txt"
: > "$REPORT" || { echo "cannot write $REPORT"; exit 2; }

PASS=0; FAIL=0; WARN=0; SKIP=0; FAILED=""; WARNED=""
if [ -t 1 ]; then
    G=$(printf '\033[32m'); R=$(printf '\033[31m'); Y=$(printf '\033[33m')
    B=$(printf '\033[34m'); M=$(printf '\033[35m'); N=$(printf '\033[0m')
else G=""; R=""; Y=""; B=""; M=""; N=""; fi

emit() { # $1 colour  $2 tag  $3 text
    printf '%s\n' "$2 $3" >> "$REPORT"
    printf '%s%s%s %s\n' "$1" "$2" "$N" "$3"
}
sec()  { printf '\n' >> "$REPORT"; printf '\n' ; emit "$B" "==========" "$1 =========="; }
ok()   { PASS=$((PASS+1)); emit "$G" "[PASS]" "$1"; }
bad()  { FAIL=$((FAIL+1)); FAILED="$FAILED
  - $1"; emit "$R" "[FAIL]" "$1"; }
wrn()  { WARN=$((WARN+1)); WARNED="$WARNED
  - $1"; emit "$Y" "[WARN]" "$1"; }
skp()  { SKIP=$((SKIP+1)); emit "$M" "[SKIP]" "$1"; }
inf()  { printf '       %s\n' "$1" | tee -a "$REPORT"; }
infv() { printf '%s\n' "$1" | sed 's/^/       /' >> "$REPORT"; printf '%s\n' "$1" | sed 's/^/       /'; }
has()  { command -v "$1" >/dev/null 2>&1; }
uget() { uci -q get "tor_ui.main.$1" 2>/dev/null; }
ask()  { # $1 question -> 0 yes
    [ "$ASSUME_YES" = "1" ] && return 0
    printf '%s [y/N] ' "$1"; read -r _a
    case "$_a" in [yY]*) return 0 ;; esac
    return 1
}
now() { date +%s; }
tor_pids() {
    if has pgrep; then pgrep -x tor 2>/dev/null; else
        ps 2>/dev/null | awk '$0 ~ /[\/ ]tor( |$)/ && $0 !~ /awk/ {print $1}'
    fi
}
mem_avail_kb() {
    awk '/^MemAvailable:/{print $2; f=1} END{if(!f) exit 1}' /proc/meminfo 2>/dev/null ||
        awk '/^(MemFree|Cached):/{s+=$2} END{print s+0}' /proc/meminfo
}
rss_kb() { awk '/^VmRSS:/{print $2}' "/proc/$1/status" 2>/dev/null; }
tor_running() {
    if has ubus && has jsonfilter; then
        ubus -S call service list '{"name":"tor_ui"}' 2>/dev/null |
            jsonfilter -e '@.tor_ui.instances.tor_service.running' 2>/dev/null | grep -qx true && return 0
    fi
    _p=$(cat $RUN_DIR/tor.pid 2>/dev/null); [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null
}
last_bootstrap() { # live pct from the notices log, empty if stale/none
    [ -f "$NLOG" ] || return 0
    _bl=$(grep -na 'Bootstrapped' "$NLOG" 2>/dev/null | tail -n1)
    _bn=${_bl%%:*}; _bp=$(echo "$_bl" | grep -oE '[0-9]+%' | tail -n1)
    _sn=$(grep -na 'Catching signal\|exiting cleanly' "$NLOG" 2>/dev/null | tail -n1 | cut -d: -f1)
    [ -n "$_bp" ] || return 0
    if [ -z "$_sn" ] || [ "$_bn" -gt "$_sn" ] 2>/dev/null; then echo "${_bp%\%}"; fi
}
socks_port() { _v=$(uget socks_port); echo "${_v:-9050}"; }
curl_tor() { # curl through the local SOCKS port
    curl -sL -4 -m "${CURL_T:-25}" --socks5-hostname "127.0.0.1:$(socks_port)" "$@"
}
is_tor_check() {
    curl_tor https://check.torproject.org/api/ip 2>/dev/null | tr -d ' ' | grep -q '"IsTor":true'
}

# ---------------------------------------------------------------- snapshot of
# the user's setup, restored by the EXIT trap whatever happens
TMPD=/tmp/tor_test.$$
mkdir -p "$TMPD"
cp -f /etc/config/tor_ui "$TMPD/tor_ui.orig" 2>/dev/null
mkdir -p "$TMPD/state.orig"
cp -f $STATE_DIR/memory.conf $STATE_DIR/memory.bridges "$TMPD/state.orig/" 2>/dev/null
WAS_RUNNING=0; tor_running && WAS_RUNNING=1
LIVE_TOUCHED=0
restore_all() {
    [ "$LIVE_TOUCHED" = "1" ] || { rm -rf "$TMPD"; return 0; }
    printf '\n[restore] putting your original settings back...\n' | tee -a "$REPORT"
    /etc/init.d/tor_ui stop >/dev/null 2>&1
    cp -f "$TMPD/tor_ui.orig" /etc/config/tor_ui 2>/dev/null && uci commit tor_ui 2>/dev/null
    rm -f $STATE_DIR/memory.conf $STATE_DIR/memory.bridges
    cp -f "$TMPD"/state.orig/memory.* $STATE_DIR/ 2>/dev/null
    rm -f $RUN_DIR/race.result $RUN_DIR/race.lines $RUN_DIR/race.status
    if [ "$WAS_RUNNING" = "1" ]; then
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui start >/dev/null 2>&1
        printf '[restore] Tor was running before -> started again with your settings\n' | tee -a "$REPORT"
    else
        printf '[restore] Tor was stopped before -> left stopped\n' | tee -a "$REPORT"
    fi
    rm -rf "$TMPD"
}
trap 'restore_all' EXIT
trap 'echo; echo "interrupted"; exit 130' INT TERM

printf 'tor_test_full.sh report  %s\n' "$(date)" >> "$REPORT"
echo "Report file: $REPORT"

# =============================================================================
sec "A) Environment and tor binary capabilities"
# =============================================================================
inf "Model:    $(cat /tmp/sysinfo/model 2>/dev/null)"
inf "OpenWrt:  $(. /etc/openwrt_release 2>/dev/null; echo "$DISTRIB_DESCRIPTION")"
inf "Kernel:   $(uname -r)  arch: $(uname -m)"
inf "Memory:   total $(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo) MB, available $(( $(mem_avail_kb) / 1024 )) MB"
inf "Installer/init VERSION line: $(grep -m1 '^VERSION=' "$INIT" 2>/dev/null)"
TORV=$("$TORBIN" --version 2>/dev/null | head -n 1)
inf "Tor:      $TORV"
[ -x "$TORBIN" ] && ok "tor binary present ($TORBIN)" || bad "tor binary missing: $TORBIN"

OPTS=$("$TORBIN" --list-torrc-options 2>/dev/null | awk '{print tolower($1)}')
if [ -n "$OPTS" ]; then
    ok "tor --list-torrc-options works ($(echo "$OPTS" | wc -l) options)"
else
    wrn "tor --list-torrc-options returned nothing -- panel will treat Conflux options as unsupported"
fi
opt_has() { printf '%s\n' "$OPTS" | grep -qx "$(printf '%s' "$1" | tr 'A-Z' 'a-z')"; }
for o in ConfluxEnabled ConfluxClientUX; do
    opt_has "$o" && ok "stock Conflux option supported: $o" || wrn "stock option NOT supported by this tor: $o (needs tor >= 0.4.8)"
done
EXT=0
for o in ConfluxNumSets ConfluxNumLinkedSets ConfluxNumLegs ConfluxSetSelection ConfluxSetRttMax ConfluxSetRttPct; do
    if opt_has "$o"; then inf "DeltaTor-core option supported: $o"; EXT=$((EXT+1)); else inf "DeltaTor-core option absent:    $o"; fi
done
if [ "$EXT" -eq 6 ]; then ok "tor core = EXTENDED (all 6 DeltaTor Conflux options present)"
elif [ "$EXT" -eq 0 ]; then inf "tor core = STOCK (the 6 DeltaTor Conflux options are correctly ignored by the panel)"
else wrn "tor core has only $EXT/6 DeltaTor Conflux options -- partial custom build?"; fi

for b in lyrebird obfs4proxy snowflake-client; do
    has "$b" && inf "transport binary: $b -> $(command -v $b)" || inf "transport binary: $b -> not installed"
done
has lyrebird || has obfs4proxy && ok "at least one obfs4-capable transport installed" || wrn "no lyrebird/obfs4proxy: obfs4/webtunnel/meek modes cannot work"
for t in uci nft curl ubus jsonfilter nc timeout awk; do
    has "$t" && inf "tool: $t ok" || inf "tool: $t MISSING"
done
id tor >/dev/null 2>&1 && ok "system user 'tor' exists (needed by the race: 'User tor')" || bad "system user 'tor' missing"

# =============================================================================
sec "B) Installed files, UCI keys, init.d functions, LuCI markers"
# =============================================================================
for f in "$INIT" /etc/config/tor_ui /etc/hotplug.d/iface/95-tor_ui \
         /usr/libexec/tor_ui/status.sh /usr/libexec/tor_ui/rpc.sh \
         /usr/libexec/tor_ui/circuit-check.sh \
         /www/luci-static/resources/view/tor/settings.js \
         /usr/share/luci/menu.d/luci-app-tor.json /usr/share/rpcd/acl.d/luci-app-tor.json; do
    [ -f "$f" ] && ok "present: $f" || bad "missing: $f"
done
[ -x "$INIT" ] && ok "init script executable" || bad "init script not executable"
sh -n "$INIT" 2>/dev/null && ok "init script passes sh -n" || bad "init script has a SYNTAX ERROR"
sh -n /usr/libexec/tor_ui/status.sh 2>/dev/null && ok "status.sh passes sh -n" || bad "status.sh syntax error"
grep -q '^VERSION="69"' "$INIT" && ok "init.d VERSION=69 (stage3-deltator)" || wrn "init.d is not VERSION 69 -- wrong installer?"

for k in conn_mode race_racers race_timeout memory_enabled conflux_enabled conflux_ux \
         conflux_num_sets conflux_num_linked conflux_num_legs conflux_set_selection \
         conflux_rtt_max conflux_rtt_pct; do
    v=$(uget "$k")
    [ -n "$v" ] && ok "UCI $k = $v" || bad "UCI key missing: tor_ui.main.$k"
done
CM=$(uget conn_mode)
case "$CM" in manual|race|memory|direct|vanilla) ok "conn_mode value valid ($CM)" ;; *) bad "conn_mode invalid: '$CM'" ;; esac

for fn in resolve_conn_mode build_torrc_content conflux_torrc_lines tor_opt_supported \
          race_run race_launch race_stop race_running race_finish race_lines_for \
          memory_load memory_save memory_record_bg memory_forget proven_bridges_from \
          emit_bridge_pool plain_bridge_lines write_conn_status forget_memory config_fingerprint; do
    grep -q "^$fn()" "$INIT" && ok "init.d defines $fn()" || bad "init.d lacks $fn()"
done
grep -q 'EXTRA_COMMANDS=.*forget_memory' "$INIT" && ok "forget_memory registered as init command" || bad "forget_memory not in EXTRA_COMMANDS"
grep -q 'emit_bridge_pool "\$BUILTIN_BRIDGES_OBFS4"' "$INIT" && ok "built-in pools are emitted with the 'Bridge' keyword (pool-bug fix present)" \
    || bad "built-in pools still emitted raw -- tor will reject the torrc"
grep -q 'race_stop' "$INIT" && grep -A3 '^stop_service()' "$INIT" | grep -q race_stop && ok "stop_service stops the race" || bad "stop_service does not call race_stop"

JS=/www/luci-static/resources/view/tor/settings.js
for m in "'conn_mode'" "'race_racers'" "'race_timeout'" "'memory_enabled'" "'conflux_enabled'" "'conflux_ux'" \
         "'conflux_num_sets'" "'conflux_num_legs'" "'conflux_rtt_pct'" "renderConn" "CONNECTION"; do
    grep -q "$m" "$JS" 2>/dev/null && ok "LuCI view contains $m" || bad "LuCI view lacks $m"
done
if has node; then node --check "$JS" 2>/dev/null && ok "settings.js passes node --check" || bad "settings.js JS syntax error"; else skp "node not installed -- JS syntax not checked (check the browser console instead)"; fi
grep -q 'retain = true' "$JS" && ok "bridge fields use retain (switching mode will not wipe them)" || wrn "retain not set on bridge fields"

# =============================================================================
sec "C) OFFLINE torrc generation per mode + real 'tor --verify-config'"
# =============================================================================
# Scratch UCI copy; the init script is sourced in a subshell with uci()
# redirected to it, write_conn_status() neutered and LOG_DIR in /tmp.
TCONF="$TMPD/uci"; mkdir -p "$TCONF"
cp -f /etc/config/tor_ui "$TCONF/tor_ui" 2>/dev/null
cp -f /etc/config/network "$TCONF/network" 2>/dev/null
cp -f /etc/config/dhcp "$TCONF/dhcp" 2>/dev/null
SAMPLE_VANILLA='5.6.7.8:443 0123456789ABCDEF0123456789ABCDEF01234567
[2001:db8::1]:9001 FEDCBA9876543210FEDCBA9876543210FEDCBA98'

# gen NAME "k=v k=v ..."  -> $TMPD/NAME.torrc, $TMPD/NAME.meta (pending|err|resolved)
gen() {
    _n="$1"; _kv="$2"
    cp -f /etc/config/tor_ui "$TCONF/tor_ui"
    for _p in $_kv; do uci -c "$TCONF" set "tor_ui.main.${_p%%=*}=${_p#*=}" 2>/dev/null; done
    if [ -n "$3" ]; then uci -c "$TCONF" set "tor_ui.main.bridge_lines=$3" 2>/dev/null; fi
    uci -c "$TCONF" commit tor_ui 2>/dev/null
    (
        . "$INIT" >/dev/null 2>&1
        uci() { command uci -c "$TCONF" "$@"; }
        write_conn_status() { :; }
        LOG_DIR="$TMPD/log"; mkdir -p "$LOG_DIR"; : > "$LOG_DIR/notices.log"
        TOR_BIN="$TORBIN"; TOR_OPTS_CACHE=""
        RACE_PENDING=0; BRIDGE_TRANSPORT_ERROR=""
        build_torrc_content 1 1 > "$TMPD/$_n.torrc" 2>"$TMPD/$_n.err"
        printf '%s|%s|%s\n' "$RACE_PENDING" "$BRIDGE_TRANSPORT_ERROR" "$EFF_CONN_RESOLVED" > "$TMPD/$_n.meta"
        cp -f "$LOG_DIR/notices.log" "$TMPD/$_n.warn"
    )
}
verify() { # file -> 0 valid
    mkdir -p "$TMPD/vdata"; chmod 700 "$TMPD/vdata"
    if has timeout; then
        timeout 25 "$TORBIN" --verify-config --DataDirectory "$TMPD/vdata" -f "$1" > "$TMPD/verify.out" 2>&1
    else
        "$TORBIN" --verify-config --DataDirectory "$TMPD/vdata" -f "$1" > "$TMPD/verify.out" 2>&1
    fi
}
nbridge() { grep -c '^Bridge ' "$TMPD/$1.torrc" 2>/dev/null; }
meta_f() { cut -d'|' -f"$2" "$TMPD/$1.meta" 2>/dev/null; }
stray() { grep -cE '^(obfs4|webtunnel|snowflake|meek_lite|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:)' "$TMPD/$1.torrc"; }

check_case() { # name  expect(valid|error)   [min bridges]
    _n="$1"; _exp="$2"; _min="${3:-0}"
    if [ ! -s "$TMPD/$_n.torrc" ] && [ "$_exp" != error ]; then bad "$_n: no torrc generated"; return; fi
    _err=$(meta_f "$_n" 2); _nb=$(nbridge "$_n"); _st=$(stray "$_n")
    [ "$_st" = "0" ] && ok "$_n: no stray un-prefixed bridge lines" || bad "$_n: $_st stray lines without 'Bridge' (tor rejects these)"
    if [ "$_exp" = error ]; then
        [ -n "$_err" ] && ok "$_n: correctly refused -> $_err" || bad "$_n: expected a transport error but none was raised"
        return
    fi
    if [ -n "$_err" ]; then wrn "$_n: transport error: $_err"; return; fi
    [ "$_nb" -ge "$_min" ] && ok "$_n: $_nb Bridge line(s)" || bad "$_n: only $_nb Bridge line(s), expected >= $_min"
    if verify "$TMPD/$_n.torrc"; then ok "$_n: tor --verify-config accepts it"
    else bad "$_n: tor --verify-config REJECTED it"; sed 's/^/         /' "$TMPD/verify.out" | head -n 6 | tee -a "$REPORT"; fi
}

# classic / legacy behaviour must be unchanged
gen c_legacy_direct "conn_mode=manual use_bridge=0";                         check_case c_legacy_direct valid 0
[ "$(nbridge c_legacy_direct)" = 0 ] && ! grep -q '^UseBridges' "$TMPD/c_legacy_direct.torrc" && ok "legacy direct: no UseBridges" || bad "legacy direct emits bridges"
for m in obfs4 snowflake meek auto; do
    gen "c_legacy_$m" "conn_mode=manual use_bridge=1 bridge_mode=$m"; check_case "c_legacy_$m" valid 1
done
gen c_legacy_webtunnel "conn_mode=manual use_bridge=1 bridge_mode=webtunnel"
if has lyrebird; then check_case c_legacy_webtunnel valid 1; else check_case c_legacy_webtunnel error; fi

# new modes
gen m_direct "conn_mode=direct use_bridge=1 bridge_mode=obfs4"; check_case m_direct valid 0
[ "$(nbridge m_direct)" = 0 ] && ! grep -q '^UseBridges 1' "$TMPD/m_direct.torrc" && ok "Direct overrides use_bridge=1 (no bridges emitted)" || bad "Direct still emits bridges"

gen m_vanilla_empty "conn_mode=vanilla"
if [ -s "$STATE_DIR/bridges/vanilla.txt" ]; then check_case m_vanilla_empty valid 1; else check_case m_vanilla_empty error; fi
gen m_vanilla "conn_mode=vanilla" "obfs4 1.1.1.1:1 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA cert=x
$SAMPLE_VANILLA"
check_case m_vanilla valid 2
[ "$(nbridge m_vanilla)" = 2 ] && ok "Vanilla keeps only the 2 plain lines (obfs4 line filtered)" || bad "Vanilla filtering wrong: $(nbridge m_vanilla) lines"
grep -q '^ClientTransportPlugin' "$TMPD/m_vanilla.torrc" && bad "Vanilla registers a transport plugin" || ok "Vanilla registers NO transport plugin"

gen m_race "conn_mode=race"
check_case m_race valid 1
inf "race meta: pending=$(meta_f m_race 1) resolved=$(meta_f m_race 3)"
[ "$(meta_f m_race 1)" = 1 ] && ok "race with no stored result -> RACE_PENDING=1 (service will race first)" || inf "race result already stored this boot (pending=0)"
gen m_memory "conn_mode=memory"
check_case m_memory valid 0
inf "memory resolves to: $(meta_f m_memory 3)"
[ -s $STATE_DIR/memory.conf ] && inf "memory.conf: $(cat $STATE_DIR/memory.conf)" || inf "no memory recorded yet (memory -> race on first run, as designed)"

# Conflux
gen f_conflux_stock "conn_mode=manual use_bridge=0 conflux_enabled=1 conflux_ux=latency"
check_case f_conflux_stock valid 0
if opt_has ConfluxEnabled; then
    grep -q '^ConfluxEnabled 1' "$TMPD/f_conflux_stock.torrc" && ok "ConfluxEnabled 1 emitted" || bad "ConfluxEnabled not emitted"
    grep -q '^ConfluxClientUX latency' "$TMPD/f_conflux_stock.torrc" && ok "ConfluxClientUX latency emitted" || bad "ConfluxClientUX not emitted"
fi
gen f_conflux_all "conn_mode=manual use_bridge=0 conflux_enabled=1 conflux_ux=throughput conflux_num_sets=32 conflux_num_linked=16 conflux_num_legs=2 conflux_set_selection=1 conflux_rtt_max=400 conflux_rtt_pct=20"
check_case f_conflux_all valid 0
for pair in ConfluxNumSets:32 ConfluxNumLinkedSets:16 ConfluxNumLegs:2 ConfluxSetSelection:1 ConfluxSetRttMax:400 ConfluxSetRttPct:20; do
    o=${pair%%:*}; v=${pair#*:}
    if opt_has "$o"; then
        grep -q "^$o $v\$" "$TMPD/f_conflux_all.torrc" && ok "$o $v emitted (core supports it)" || bad "$o supported but NOT emitted"
    else
        grep -q "^$o " "$TMPD/f_conflux_all.torrc" && bad "$o emitted although this tor does not support it (would break startup)" || ok "$o correctly withheld (unsupported by this tor)"
    fi
done
[ "$EXT" -lt 6 ] && { grep -q 'does not support it' "$TMPD/f_conflux_all.warn" && ok "unsupported options leave a warning in the log" || wrn "no warning logged for unsupported Conflux options"; }
gen f_conflux_junk "conn_mode=manual use_bridge=0 conflux_num_sets=9999 conflux_num_legs=abc conflux_rtt_pct=250 conflux_enabled=junk conflux_ux=rm"
check_case f_conflux_junk valid 0
grep -qE '^ConfluxEnabled junk|^ConfluxClientUX rm|^ConfluxNumLegs abc' "$TMPD/f_conflux_junk.torrc" && bad "junk Conflux values leaked into torrc" || ok "junk Conflux values are rejected/clamped"

# fingerprint covers the new keys (changing a key must change it)
FP1=$( . "$INIT" >/dev/null 2>&1; uci() { command uci -c "$TCONF" "$@"; }; config_fingerprint )
uci -c "$TCONF" set tor_ui.main.conflux_rtt_pct=33; uci -c "$TCONF" commit tor_ui
FP2=$( . "$INIT" >/dev/null 2>&1; uci() { command uci -c "$TCONF" "$@"; }; config_fingerprint )
[ "$FP1" != "$FP2" ] && ok "config_fingerprint changes when a Conflux key changes (apply will notice)" || bad "config_fingerprint ignores Conflux keys"
uci -c "$TCONF" set tor_ui.main.conn_mode=race; uci -c "$TCONF" commit tor_ui
FP3=$( . "$INIT" >/dev/null 2>&1; uci() { command uci -c "$TCONF" "$@"; }; config_fingerprint )
[ "$FP2" != "$FP3" ] && ok "config_fingerprint changes when conn_mode changes" || bad "config_fingerprint ignores conn_mode"

# =============================================================================
sec "D) Live service state (read-only)"
# =============================================================================
if tor_running; then
    ok "tor_ui service is running"
    TPID=$(cat $RUN_DIR/tor.pid 2>/dev/null)
    inf "pid=$TPID  RSS=$(rss_kb "$TPID") kB"
    BS=$(last_bootstrap)
    [ "$BS" = 100 ] && ok "Bootstrapped 100%" || wrn "bootstrap is ${BS:-unknown}% (not complete)"
    SP=$(socks_port); TP=$(uget trans_port); DP=$(uget dns_port)
    LT=$( (netstat -ltn 2>/dev/null || ss -ltn 2>/dev/null) )
    LU=$( (netstat -lun 2>/dev/null || ss -lun 2>/dev/null) )
    echo "$LT" | grep -q ":$SP " && ok "SOCKS port $SP listening" || bad "SOCKS port $SP not listening"
    echo "$LT" | grep -q ":${TP:-9040} " && ok "TransPort ${TP:-9040} listening" || bad "TransPort not listening"
    echo "$LU" | grep -q ":${DP:-9053} " && ok "DNSPort ${DP:-9053} listening" || bad "DNSPort not listening"
    echo "$LT" | grep -q ":9051 " && ok "ControlPort 9051 listening" || wrn "ControlPort not listening"
    [ -f /etc/tor/torrc ] && inf "live torrc: $(grep -c '^Bridge ' /etc/tor/torrc) Bridge lines, UseBridges=$(grep -c '^UseBridges 1' /etc/tor/torrc), $(grep -c '^ClientTransportPlugin' /etc/tor/torrc) transport plugin line(s)"
    LIVE_RUNNING=1
else
    wrn "tor_ui service is NOT running (live checks D/E limited; section F can still start it)"
    LIVE_RUNNING=0
fi
if nft list table inet tor_ui_fw >/dev/null 2>&1; then
    ok "firewall table inet tor_ui_fw present"
    for ch in fwd_leak_guard fwd_killswitch; do
        nft list chain inet tor_ui_fw $ch >/dev/null 2>&1 && inf "chain $ch present ($(nft list chain inet tor_ui_fw $ch | grep -c drop) drop rules)" || inf "chain $ch absent"
    done
    [ "$(uget strict_killswitch)" = 1 ] && { nft list chain inet tor_ui_fw fwd_killswitch >/dev/null 2>&1 && ok "kill switch ON and chain present" || bad "kill switch ON but chain missing"; }
else
    [ "$LIVE_RUNNING" = 1 ] && bad "tor running but firewall table missing" || inf "no firewall table (service stopped / disabled)"
fi
V6=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null); inf "IPv6 forwarding=$V6 (kill switch=$(uget strict_killswitch))"
APPL=$(cat $STATE_DIR/applied.conf 2>/dev/null)
CURF=$( . "$INIT" >/dev/null 2>&1; config_fingerprint )
[ -n "$APPL" ] && { [ "$APPL" = "$CURF" ] && ok "applied.conf matches current settings" || wrn "saved settings differ from what is applied (press Save & Apply)"; }
if [ -x /usr/libexec/tor_ui/status.sh ]; then
    inf "--- status.sh ---"; SOUT=$(/usr/libexec/tor_ui/status.sh 2>/dev/null); infv "$SOUT"
    echo "$SOUT" | grep -q '^CONN_MODE_CFG=' && ok "status.sh reports CONN_MODE_CFG" || bad "status.sh lacks the v69 fields"
fi
[ -f $RUN_DIR/conn.status ] && { inf "--- conn.status ---"; infv "$(cat $RUN_DIR/conn.status)"; } || inf "no conn.status yet (written on the next start)"

# ControlPort helper (cookie auth over nc)
ctl() { # commands... -> output
    has nc || return 1
    [ -r /var/lib/tor/control_auth_cookie ] || return 1
    _ck=$(od -An -v -tx1 /var/lib/tor/control_auth_cookie 2>/dev/null | tr -d ' \n')
    { printf 'AUTHENTICATE %s\r\n' "$_ck"; for _c in "$@"; do printf '%s\r\n' "$_c"; done; printf 'QUIT\r\n'; sleep 1; } | nc -w 4 127.0.0.1 9051 2>/dev/null | tr -d '\r'
}
getconf_check() { # option expected-value-substring
    _o=$(ctl "GETCONF $1" | grep -i "^250.*$1" | head -n1)
    printf '%s' "$_o"
}
if [ "$LIVE_RUNNING" = 1 ]; then
    if has nc; then
        CT=$(ctl "GETINFO version" "GETINFO status/circuit-established" "GETINFO status/bootstrap-phase")
        if echo "$CT" | grep -q '^250'; then
            ok "ControlPort authentication works"
            infv "$(echo "$CT" | grep -E 'version=|circuit-established|bootstrap-phase' | cut -c1-110)"
            for o in ConfluxEnabled ConfluxClientUX ConfluxNumSets ConfluxNumLegs ConfluxSetRttPct ConfluxSetSelection; do
                opt_has "$o" && inf "live GETCONF: $(getconf_check $o)"
            done
            NB=$(ctl "GETINFO circuit-status" | grep -c ' BUILT ')
            inf "BUILT circuits: $NB"
            [ "$NB" -gt 0 ] && ok "tor has built circuits ($NB)" || wrn "no BUILT circuits yet"
            if [ "$EXT" -eq 6 ]; then
                CQ=$(ctl "CONFLUX QUERY" | head -n 12)
                [ -n "$CQ" ] && { inf "CONFLUX QUERY (extended core):"; infv "$CQ"; }
            fi
        else wrn "ControlPort auth failed (cookie/nc problem) -- live GETCONF checks skipped"; fi
    else skp "nc not installed -- ControlPort checks skipped"; fi
fi

# =============================================================================
sec "E) Live functional checks through Tor"
# =============================================================================
if [ "$LIVE_RUNNING" = 1 ] && [ "$(last_bootstrap)" = 100 ] && has curl; then
    CURL_T=30
    if is_tor_check; then ok "check.torproject.org says IsTor=true via SOCKS"; else bad "IsTor check FAILED via SOCKS"; fi
    EXIT_IP=$(curl_tor https://check.torproject.org/api/ip 2>/dev/null | tr -d ' ' | grep -oE '"IP":"[^"]+"' | cut -d'"' -f4)
    inf "exit IP: ${EXIT_IP:-unknown}"
    T0=$(now); curl_tor -o /dev/null https://www.gstatic.com/generate_204 -w '%{http_code}' > "$TMPD/c204" 2>/dev/null; T1=$(now)
    [ "$(cat $TMPD/c204)" = 204 ] && ok "HTTPS request through Tor ok ($((T1-T0))s)" || wrn "generate_204 via Tor returned '$(cat $TMPD/c204)'"
    SPD=$(curl_tor -o /dev/null -w '%{speed_download}' "https://speed.cloudflare.com/__down?bytes=3000000" 2>/dev/null)
    SPD_KB=$(echo "${SPD:-0}" | awk '{printf "%d", $1/1024}')
    inf "3 MB download via Tor: ${SPD_KB} KiB/s"
    [ "$SPD_KB" -gt 0 ] && ok "download works (${SPD_KB} KiB/s)" || wrn "speed test returned no data"
    P1=$( (for i in 1 2 3 4; do curl_tor -o /dev/null -w '%{speed_download}\n' "https://speed.cloudflare.com/__down?bytes=2000000" 2>/dev/null & done; wait) | awk '{s+=$1} END{printf "%d", s/1024}')
    inf "4 parallel streams: ~${P1} KiB/s total"
    if has dig; then
        DP=$(uget dns_port); dig +short +time=6 +tries=1 -p "${DP:-9053}" @127.0.0.1 check.torproject.org A 2>/dev/null | head -n1 | grep -qE '^[0-9.]+$' && ok "DNSPort resolves names through Tor" || wrn "DNSPort query returned nothing"
    else skp "dig not installed -- DNSPort query not tested"; fi
    # transparent path from the router itself only works with localhost_proxy
    if [ "$(uget localhost_proxy)" = 1 ]; then
        curl -sL -4 -m 25 https://check.torproject.org/api/ip 2>/dev/null | tr -d ' ' | grep -q '"IsTor":true' && ok "router's own traffic goes through Tor (localhost_proxy)" || bad "localhost_proxy=1 but router traffic is NOT Tor"
    fi
else
    skp "Tor not running/bootstrapped or curl missing -- functional checks skipped"
fi

# =============================================================================
sec "F) LIVE mode switching (restarts Tor several times)"
# =============================================================================
LIVE_OK=0
if [ "$SKIP_LIVE" = 1 ]; then skp "--skip-live given"
elif ! ask "This will stop/start Tor repeatedly (LAN traffic is interrupted for minutes). Your settings are restored at the end. Continue?"; then skp "live mode switching declined"
else LIVE_OK=1; fi

peak_mem_sample() { # echoes "procs:MBused" snapshot of all tor processes
    _n=0; _r=0
    for _p in $(tor_pids); do _n=$((_n+1)); _x=$(rss_kb "$_p"); _r=$((_r + ${_x:-0})); done
    echo "$_n:$((_r/1024))"
}
set_uci() { for _p in "$@"; do uci set "tor_ui.main.${_p%%=*}=${_p#*=}"; done; uci commit tor_ui; }
clean_start() { # stop + wipe transient state + start
    /etc/init.d/tor_ui stop >/dev/null 2>&1; sleep 2
    rm -f $RUN_DIR/race.result $RUN_DIR/race.lines $RUN_DIR/race.status /etc/tor/torrc
    : > "$NLOG" 2>/dev/null
    TOR_UI_MANUAL=1 /etc/init.d/tor_ui start >/dev/null 2>&1
}
wait_bootstrap() { # -> sets WB_SECS (empty on timeout)  WB_PEAK_PROCS WB_PEAK_MB WB_MINFREE
    WB_SECS=""; WB_PEAK_PROCS=0; WB_PEAK_MB=0; WB_MINFREE=$(( $(mem_avail_kb) / 1024 )); _t0=$(now); WB_RACELOG=""
    while :; do
        _el=$(( $(now) - _t0 ))
        [ "$_el" -ge "$BS_TIMEOUT" ] && return 1
        _s=$(peak_mem_sample); _pp=${_s%%:*}; _mb=${_s#*:}
        [ "$_pp" -gt "$WB_PEAK_PROCS" ] && WB_PEAK_PROCS=$_pp
        [ "$_mb" -gt "$WB_PEAK_MB" ] && WB_PEAK_MB=$_mb
        _fm=$(( $(mem_avail_kb) / 1024 )); [ "$_fm" -lt "$WB_MINFREE" ] && WB_MINFREE=$_fm
        if [ -f $RUN_DIR/race.status ]; then
            _rl=$(grep -E '^(racer\.|state=)' $RUN_DIR/race.status | tr '\n' ' ')
            [ "$_rl" != "$WB_RACELOG" ] && { WB_RACELOG="$_rl"; inf "  t=${_el}s race: $_rl"; }
        fi
        if [ "$(last_bootstrap)" = 100 ] && tor_running; then WB_SECS=$_el; return 0; fi
        sleep 3
    done
}
live_mode() { # label  expect-skip-reason(empty)  uci-args...
    _lbl="$1"; _skipwhy="$2"; shift 2
    if [ -n "$_skipwhy" ]; then skp "$_lbl: $_skipwhy"; return; fi
    inf "--- live mode: $_lbl ---"
    set_uci "$@"
    LIVE_TOUCHED=1
    clean_start
    if wait_bootstrap; then
        ok "$_lbl: Bootstrapped 100% in ${WB_SECS}s (peak ${WB_PEAK_PROCS} tor proc(s), ~${WB_PEAK_MB} MB RSS, min free ${WB_MINFREE} MB)"
        is_tor_check && ok "$_lbl: traffic exits through Tor (IsTor=true)" || bad "$_lbl: bootstrapped but IsTor check failed"
        [ -f $RUN_DIR/conn.status ] && inf "conn.status: $(tr '\n' ' ' < $RUN_DIR/conn.status)"
        LAST_OK=1
    else
        bad "$_lbl: NO 100% within ${BS_TIMEOUT}s (last: $(last_bootstrap)%)"
        grep -E 'ERROR|Unknown option|failed validation|WARNING' "$NLOG" 2>/dev/null | tail -n 4 | sed 's/^/         /' | tee -a "$REPORT"
        LAST_OK=0
    fi
}

if [ "$LIVE_OK" = 1 ]; then
    # --- baselines in classic (manual) mode --------------------------------
    live_mode "manual/direct (no bridge)" "" conn_mode=manual use_bridge=0 conflux_enabled=auto conflux_ux=default
    DIRECT_OK=$LAST_OK
    PT=0; has lyrebird || has obfs4proxy && PT=1
    live_mode "manual/obfs4 built-in pool" "$([ $PT = 1 ] || echo 'no obfs4 transport installed')" conn_mode=manual use_bridge=1 bridge_mode=obfs4
    has snowflake-client && live_mode "manual/snowflake" "" conn_mode=manual use_bridge=1 bridge_mode=snowflake || skp "manual/snowflake: snowflake-client not installed"
    has lyrebird && live_mode "manual/meek_lite" "" conn_mode=manual use_bridge=1 bridge_mode=meek || skp "manual/meek: lyrebird not installed"
    live_mode "manual/auto fallback pool" "$([ $PT = 1 ] || echo 'no transport installed')" conn_mode=manual use_bridge=1 bridge_mode=auto

    # --- DeltaTor modes -----------------------------------------------------
    live_mode "mode DIRECT" "" conn_mode=direct

    VAN_LINES=$(uget bridge_lines | tr -d '\r' | grep -E '^(Bridge )?(([0-9]{1,3}\.){3}[0-9]{1,3}|\[[0-9A-Fa-f:]+\]):[0-9]+' | head -n 1)
    [ -s $STATE_DIR/bridges/vanilla.txt ] && VAN_LINES="pool-file"
    live_mode "mode VANILLA (your plain bridge lines)" "$([ -n "$VAN_LINES" ] || echo 'no plain bridge lines in Bridge Lines or bridges/vanilla.txt -- paste some to test this mode')" conn_mode=vanilla

    # --- AUTO RACE ----------------------------------------------------------
    inf "--- AUTO RACE (default racers; watch the progress lines) ---"
    MEMBEFORE=$(( $(mem_avail_kb) / 1024 ))
    rm -f $STATE_DIR/memory.conf $STATE_DIR/memory.bridges
    set_uci conn_mode=race "race_racers=vanilla obfs4 webtunnel snowflake" race_timeout=120
    LIVE_TOUCHED=1; clean_start
    RT0=$(now)
    if wait_bootstrap; then
        WIN=$(sed -n 's/^winner=//p' $RUN_DIR/race.result 2>/dev/null | head -n1)
        ok "race: finished and service bootstrapped in ${WB_SECS}s, winner=${WIN:-?}"
        inf "race resources: peak ${WB_PEAK_PROCS} tor processes, ~${WB_PEAK_MB} MB RSS, free RAM ${MEMBEFORE} MB -> min ${WB_MINFREE} MB"
        [ -n "$WIN" ] && [ "$WIN" != none ] && ok "race produced a winner ($WIN)" || wrn "race ended with no winner (classic auto profile was used)"
        [ -f $RUN_DIR/race.result ] && ok "race.result written" || bad "race.result missing"
        sleep 3
        [ ! -d /var/run/tor_race ] && ok "race workdir /var/run/tor_race removed" || bad "race workdir left behind"
        NP=$(tor_pids | wc -l)
        [ "$NP" -le 1 ] && ok "only the winner's service tor is left running ($NP process)" || bad "$NP tor processes still running after the race (racers not cleaned up)"
        is_tor_check && ok "race: traffic exits through Tor" || bad "race: IsTor check failed"
        inf "conn.status: $(tr '\n' ' ' < $RUN_DIR/conn.status 2>/dev/null)"
        # memory recorder (background, up to a few seconds after 100%)
        W=0; while [ "$W" -lt 40 ] && [ ! -s $STATE_DIR/memory.conf ]; do sleep 2; W=$((W+2)); done
        if [ -s $STATE_DIR/memory.conf ]; then
            ok "memory recorded: $(tr '\n' ' ' < $STATE_DIR/memory.conf) ($(grep -c . $STATE_DIR/memory.bridges 2>/dev/null || echo 0) proven bridges)"
            [ "$(stat -c %a $STATE_DIR/memory.conf 2>/dev/null)" = 600 ] && ok "memory.conf perms 600" || wrn "memory.conf perms $(stat -c %a $STATE_DIR/memory.conf 2>/dev/null)"
        else wrn "memory file not written within 40s (recorder needs bridge descriptors in the log; direct wins record TYPE=direct)"; fi
        grep -E '^race:|^Auto race' "$NLOG" | head -n 8 | sed 's/^/         /' | tee -a "$REPORT"
    else
        bad "race: nothing reached 100% within ${BS_TIMEOUT}s (race.status: $(tr '\n' ' ' < $RUN_DIR/race.status 2>/dev/null))"
    fi

    # --- stop mid-race ------------------------------------------------------
    inf "--- stop during a race must clean everything up ---"
    set_uci conn_mode=race; LIVE_TOUCHED=1
    /etc/init.d/tor_ui stop >/dev/null 2>&1; sleep 2
    rm -f $RUN_DIR/race.result; : > "$NLOG"
    TOR_UI_MANUAL=1 /etc/init.d/tor_ui start >/dev/null 2>&1; sleep 6
    if [ -f $RUN_DIR/race.status ] && grep -q 'state=running' $RUN_DIR/race.status; then
        ok "race running ($(grep -c '^racer\.' $RUN_DIR/race.status) racer(s))"
        /etc/init.d/tor_ui stop >/dev/null 2>&1; sleep 4
        [ ! -d /var/run/tor_race ] && ok "stop mid-race removed the race workdir" || bad "workdir remains after stop"
        [ "$(tor_pids | wc -l)" = 0 ] && ok "stop mid-race killed every tor process" || bad "$(tor_pids | wc -l) tor process(es) survive stop"
        [ ! -f $RUN_DIR/race.result ] && ok "race.result cleared by stop" || bad "stale race.result after stop"
    else
        inf "race finished in under 6s (fast network) -- mid-race stop not exercised"
        /etc/init.d/tor_ui stop >/dev/null 2>&1
    fi

    # --- MEMORY mode (needs a record: recreate it from a quick direct/bridge connect) ---
    if [ -s $STATE_DIR/memory.conf ]; then
        live_mode "mode MEMORY (reconnect with last working setup)" "" conn_mode=memory
        inf "memory resolved: $(sed -n 's/^CONNRESOLVED=//p' $RUN_DIR/conn.status 2>/dev/null)"
        [ -n "$WB_SECS" ] && inf "memory reconnect time ${WB_SECS}s (compare with the race time above)"
    else
        skp "mode MEMORY: no memory record exists (race produced none) -- run again after a bridge/direct success"
    fi

    # --- apply / SIGHUP path -----------------------------------------------
    inf "--- apply (SIGHUP) path ---"
    set_uci conn_mode=direct; clean_start
    if wait_bootstrap; then
        P1=$(cat $RUN_DIR/tor.pid 2>/dev/null)
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui apply >/dev/null 2>&1; sleep 3
        P2=$(cat $RUN_DIR/tor.pid 2>/dev/null)
        [ "$P1" = "$P2" ] && ok "apply with unchanged settings did not restart Tor (pid $P2)" || bad "apply restarted Tor: $P1 -> $P2"
        set_uci conflux_enabled=1 conflux_ux=latency
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui apply >/dev/null 2>&1; sleep 4
        P3=$(cat $RUN_DIR/tor.pid 2>/dev/null)
        [ "$P3" = "$P1" ] && ok "Conflux change applied by SIGHUP (same pid, no restart)" || inf "Conflux change restarted Tor ($P1 -> $P3)"
        if has nc; then
            CE=$(getconf_check ConfluxClientUX); inf "live: $CE"
            echo "$CE" | grep -qi latency && ok "live tor reports ConfluxClientUX=latency after apply" || wrn "ConfluxClientUX not 'latency' in live tor after apply"
        fi
        # race via apply while running -> must restart (race needed)
        set_uci conn_mode=race
        TOR_UI_MANUAL=1 /etc/init.d/tor_ui apply >/dev/null 2>&1
        if wait_bootstrap; then
            ok "switching direct -> race via apply: race ran and Tor came back (${WB_SECS}s)"
        else bad "direct -> race via apply: Tor did not come back within ${BS_TIMEOUT}s"; fi
    else bad "apply tests: could not bring Tor up in direct mode"; fi

    # --- Conflux on a live tunnel ------------------------------------------
    inf "--- Conflux settings on a live tunnel ---"
    if [ "$EXT" -eq 6 ]; then
        live_mode "conflux EXTENDED (sets=8 legs=2 selection=1 rtt_pct=0)" "" conn_mode=direct conflux_enabled=1 conflux_ux=throughput conflux_num_sets=8 conflux_num_linked=8 conflux_num_legs=2 conflux_set_selection=1 conflux_rtt_max=0 conflux_rtt_pct=0
        if has nc; then for o in ConfluxNumSets ConfluxNumLegs ConfluxSetSelection; do inf "live: $(getconf_check $o)"; done; fi
        CURL_T=40
        PS1=$( (for i in 1 2 3 4 5 6; do curl_tor -o /dev/null -w '%{speed_download}\n' "https://speed.cloudflare.com/__down?bytes=3000000" 2>/dev/null & done; wait) | awk '{s+=$1} END{printf "%d", s/1024}')
        inf "6 parallel streams with extended Conflux: ~${PS1} KiB/s total"
    else
        live_mode "conflux STOCK (throughput)" "" conn_mode=direct conflux_enabled=1 conflux_ux=throughput
        live_mode "conflux STOCK (latency_lowmem)" "" conn_mode=direct conflux_enabled=1 conflux_ux=latency_lowmem
        live_mode "conflux STOCK + DeltaTor keys set (must be ignored, not fatal)" "" conn_mode=direct conflux_enabled=1 conflux_num_sets=32 conflux_num_legs=2 conflux_rtt_pct=20
        grep -q 'does not support it' "$NLOG" && ok "unsupported options were skipped with a warning (Tor still started)" || wrn "no 'not supported' warning in log"
    fi
fi

# =============================================================================
sec "G) Persistence, log scan, final state"
# =============================================================================
if [ -d $STATE_DIR ]; then
    PERM=$(stat -c %a $STATE_DIR 2>/dev/null); [ "$PERM" = 700 ] && ok "$STATE_DIR perms 700" || wrn "$STATE_DIR perms $PERM"
    inf "state dir: $(ls $STATE_DIR 2>/dev/null | tr '\n' ' ')"
fi
if [ -f "$NLOG" ]; then
    NE=$(grep -ciE '\[err\]|\[warn\]' "$NLOG"); inf "notices.log: $(wc -l < "$NLOG") lines, $NE warn/err"
    grep -qiE 'Unknown option|failed validation|Reading config failed' "$NLOG" && bad "config errors in notices.log" || ok "no config/validation errors in notices.log"
    inf "--- last 25 log lines ---"; infv "$(tail -n 25 "$NLOG" | cut -c1-150)"
fi
[ -s /var/log/tor/verify-config.log ] && { inf "--- verify-config.log ---"; infv "$(tail -n 8 /var/log/tor/verify-config.log)"; }
inf "--- UCI (tor_ui) at end of test, before restore ---"
infv "$(uci show tor_ui 2>/dev/null | grep -v bridge_lines | cut -c1-140)"
inf "--- firewall table summary ---"
infv "$(nft list table inet tor_ui_fw 2>/dev/null | head -n 40)"

# =============================================================================
sec "Summary"
# =============================================================================
TOTAL=$((PASS+FAIL+WARN+SKIP))
printf '  PASS: %d\n  FAIL: %d\n  WARN: %d\n  SKIP: %d\n  total checks: %d\n' "$PASS" "$FAIL" "$WARN" "$SKIP" "$TOTAL" | tee -a "$REPORT"
if [ "$FAIL" -gt 0 ]; then printf '\nFailed items:%s\n' "$FAILED" | tee -a "$REPORT"; fi
if [ "$WARN" -gt 0 ]; then printf '\nWarnings:%s\n' "$WARNED" | tee -a "$REPORT"; fi
printf '\nReport saved to: %s\n(send me this file; your original settings are restored on exit)\n' "$REPORT" | tee -a "$REPORT"
[ "$FAIL" -eq 0 ]
