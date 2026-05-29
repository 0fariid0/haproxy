#!/usr/bin/env bash

# HAProxy Menu - improved local installer/menu
# Original project: github.com/Musixal/haproxy
# Updated: local shortcut installer, safer config generation, validation, backups

APP_NAME="haproxy-menu"
APP_VERSION="2.6"
INSTALL_DIR="/opt/haproxy-menu"
INSTALL_FILE="$INSTALL_DIR/haproxy.sh"
SHORTCUT_MAIN="/usr/local/bin/haproxy-menu"
SHORTCUT_SHORT="/usr/local/bin/hapmenu"
HAPROXY_CONFIG_FILE="/etc/haproxy/haproxy.cfg"
BACKUP_DIR="/etc/haproxy/backups"
LOG_FILE="/var/log/haproxy.log"
TUNNELS_FILE="/etc/haproxy/haproxy-tunnels.db"
SCRIPT_URL="https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[36m'
NC='\033[0m'

show_logo() {
    echo -e "${BLUE}"
    cat << "LOGO"
    __  _____    ____
   / / / /   |  / __ \_________  _  ____  __
  / /_/ / /| | / /_/ / ___/ __ \| |/_/ / / /
 / __  / ___ |/ ____/ /  / /_/ />  </ /_/ /
/_/ /_/_/  |_/_/   /_/   \____/_/|_|\__, /
                                   /____/
              HAProxy Menu v2.6 - grouped editable tunnels
LOGO
    echo -e "${NC}"
}

print_ok() { echo -e "${GREEN}$*${NC}"; }
print_warn() { echo -e "${YELLOW}$*${NC}"; }
print_err() { echo -e "${RED}$*${NC}"; }

pause() {
    echo
    read -r -p "Press Enter to continue..." _
}

require_root() {
    if [ "$(id -u)" != "0" ]; then
        print_err "This script must be run as root. Try: sudo hapmenu"
        exit 1
    fi
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_packages_if_missing() {
    local missing=()
    local pkg

    command_exists haproxy || missing+=("haproxy")
    command_exists curl || missing+=("curl")
    command_exists jq || missing+=("jq")

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    if ! command_exists apt-get; then
        print_err "Unsupported package manager. Please install manually: ${missing[*]}"
        pause
        exit 1
    fi

    print_warn "Installing missing packages: ${missing[*]}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    for pkg in "${missing[@]}"; do
        apt-get install -y "$pkg"
    done

    if command_exists systemctl; then
        systemctl enable haproxy >/dev/null 2>&1 || true
    fi
}

self_install() {
    local source_file="${BASH_SOURCE[0]}"
    local source_real=""
    local install_real=""
    local tmp_file
    local installed_version

    mkdir -p "$INSTALL_DIR"
    tmp_file="$INSTALL_FILE.tmp.$$"

    source_real="$(readlink -f "$source_file" 2>/dev/null || true)"
    install_real="$(readlink -f "$INSTALL_FILE" 2>/dev/null || true)"

    if [ -r "$source_file" ] && [ "$source_real" != "$install_real" ]; then
        cp "$source_file" "$tmp_file"
        mv -f "$tmp_file" "$INSTALL_FILE"
    elif [ -r "$0" ] && [ "$(readlink -f "$0" 2>/dev/null || true)" != "$install_real" ]; then
        cp "$0" "$tmp_file"
        mv -f "$tmp_file" "$INSTALL_FILE"
    elif [ -f "$INSTALL_FILE" ]; then
        # Running from the installed file. Nothing to copy; repair shortcuts only.
        :
    elif command_exists curl; then
        print_warn "Could not copy the running script. Downloading a fresh copy for local install..."
        if ! curl -4 -fsSL "$SCRIPT_URL" -o "$tmp_file"; then
            rm -f "$tmp_file"
            print_err "Could not download the script to $INSTALL_FILE"
            print_warn "Download the script once, then run: sudo bash haproxy.sh --install"
            return 1
        fi
        mv -f "$tmp_file" "$INSTALL_FILE"
    else
        rm -f "$tmp_file"
        print_err "Could not copy the running script to $INSTALL_FILE"
        print_warn "Download the script once, then run: sudo bash haproxy.sh --install"
        return 1
    fi

    chmod 755 "$INSTALL_FILE"
    ln -sf "$INSTALL_FILE" "$SHORTCUT_MAIN"
    ln -sf "$INSTALL_FILE" "$SHORTCUT_SHORT"
    hash -r 2>/dev/null || true

    installed_version="$(grep -m1 '^APP_VERSION=' "$INSTALL_FILE" 2>/dev/null | cut -d'"' -f2)"
    print_ok "Local install completed."
    print_ok "Installed version: ${installed_version:-unknown}"
    print_ok "Main command: sudo haproxy-menu"
    print_ok "Shortcut:     sudo hapmenu"
    print_ok "Installed at: $INSTALL_FILE"
}

ensure_local_shortcut() {
    local current_file
    current_file="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"

    if [ "$current_file" = "$INSTALL_FILE" ] && [ -x "$SHORTCUT_SHORT" ]; then
        return 0
    fi

    if [ ! -x "$SHORTCUT_SHORT" ] || [ ! -f "$INSTALL_FILE" ]; then
        echo
        print_warn "Creating local shortcut so you do not need to download from GitHub next time..."
        self_install || true
        echo
    fi
}

show_help() {
    cat <<HELP
$APP_NAME v$APP_VERSION

Usage:
  sudo bash haproxy.sh --install      Install locally and create shortcuts
  sudo bash haproxy.sh --only-install Install locally without opening menu
  sudo hapmenu                        Open menu after installation
  sudo haproxy-menu                   Open menu after installation
  sudo haproxy-menu --repair-shortcut Recreate shortcuts
  haproxy-menu --version              Show installed version
  haproxy-menu --doctor               Show install path and shortcut diagnostics
  sudo haproxy-menu --help            Show this help

The script is installed at: $INSTALL_FILE
Editable tunnels are stored at: $TUNNELS_FILE
Shortcuts are created at:
  $SHORTCUT_MAIN
  $SHORTCUT_SHORT
HELP
}

show_doctor() {
    echo "$APP_NAME v$APP_VERSION"
    echo
    echo "Command resolution:"
    echo "  command -v hapmenu:       $(command -v hapmenu 2>/dev/null || echo not found)"
    echo "  command -v haproxy-menu:  $(command -v haproxy-menu 2>/dev/null || echo not found)"
    echo
    echo "Symlinks:"
    echo "  $SHORTCUT_SHORT -> $(readlink -f "$SHORTCUT_SHORT" 2>/dev/null || echo missing)"
    echo "  $SHORTCUT_MAIN -> $(readlink -f "$SHORTCUT_MAIN" 2>/dev/null || echo missing)"
    echo
    echo "Installed file:"
    if [ -f "$INSTALL_FILE" ]; then
        echo "  Path: $INSTALL_FILE"
        echo "  Version line: $(grep -m1 '^APP_VERSION=' "$INSTALL_FILE" 2>/dev/null || echo missing)"
        echo "  Tunnel menu: $(grep -m1 'Manage Editable Tunnels' "$INSTALL_FILE" 2>/dev/null || echo missing)"
    else
        echo "  Missing: $INSTALL_FILE"
    fi
    echo
    echo "Running file:"
    echo "  ${BASH_SOURCE[0]}"
}


trim() {
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

normalize_port_list() {
    local value="$1"
    value="$(printf '%s' "$value" | tr -d '[:space:]')"
    value="${value#,}"
    value="${value%,}"
    printf '%s
' "$value"
}

is_valid_port_list() {
    local value="$1"
    local item

    value="$(normalize_port_list "$value")"
    [ -n "$value" ] || return 1
    [[ "$value" != *",,"* ]] || return 1

    IFS=',' read -r -a __ports_tmp <<< "$value"
    for item in "${__ports_tmp[@]}"; do
        is_valid_port "$item" || return 1
    done

    return 0
}

port_list_count() {
    local value="$1"
    value="$(normalize_port_list "$value")"
    IFS=',' read -r -a __ports_tmp <<< "$value"
    printf '%s
' "${#__ports_tmp[@]}"
}

port_list_has_duplicates() {
    local value="$1"
    local item seen

    value="$(normalize_port_list "$value")"
    seen=" "
    IFS=',' read -r -a __ports_tmp <<< "$value"
    for item in "${__ports_tmp[@]}"; do
        case "$seen" in
            *" $item "*) return 0 ;;
            *) seen="${seen}${item} " ;;
        esac
    done

    return 1
}

read_port_list() {
    local prompt="$1"
    local value
    while true; do
        read -r -p "$prompt" value
        value="$(normalize_port_list "$value")"
        if is_valid_port_list "$value"; then
            if port_list_has_duplicates "$value"; then
                print_err "Duplicate ports found in the same list. Remove repeated ports."
                continue
            fi
            printf '%s
' "$value"
            return 0
        fi
        print_err "Invalid port list. Use numbers between 1 and 65535, separated by commas. Example: 31,1030,27028"
    done
}

read_destination_port_list() {
    local prompt="$1"
    local bind_ports="$2"
    local bind_count value value_count

    bind_count="$(port_list_count "$bind_ports")"
    while true; do
        read -r -p "$prompt" value
        value="$(normalize_port_list "$value")"

        if [ -z "$value" ]; then
            printf '%s
' "$bind_ports"
            return 0
        fi

        if ! is_valid_port_list "$value"; then
            print_err "Invalid destination port list. Use a single port, a matching comma list, or leave empty."
            continue
        fi

        value_count="$(port_list_count "$value")"
        if [ "$value_count" -eq 1 ] || [ "$value_count" -eq "$bind_count" ]; then
            printf '%s
' "$value"
            return 0
        fi

        print_err "Destination ports must be empty, one port for all, or the same count as listen ports ($bind_count)."
    done
}

is_valid_host() {
    local host="$1"
    [ -n "$host" ] && [[ ! "$host" =~ [[:space:]] ]]
}

format_backend_address() {
    local host="$1"
    local port="$2"

    if [[ "$host" == \[*\] ]]; then
        echo "${host}:${port}"
    elif [[ "$host" == *:* ]]; then
        echo "[${host}]:${port}"
    else
        echo "${host}:${port}"
    fi
}

confirm_yes() {
    local prompt="$1"
    local answer
    read -r -p "$prompt (yes/no): " answer
    case "$answer" in
        yes|Yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

write_base_config() {
    local file="$1"
    cat > "$file" <<'CFG'
# HAProxy configuration generated by HAProxy Menu

global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms
CFG
    echo >> "$file"
}

backup_existing_config() {
    if [ -s "$HAPROXY_CONFIG_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$HAPROXY_CONFIG_FILE" "$BACKUP_DIR/haproxy.cfg.$(date +%Y%m%d-%H%M%S).bak"
    fi
}

validate_config() {
    local file="$1"
    haproxy -c -f "$file"
}

restart_haproxy() {
    if command_exists systemctl; then
        systemctl restart haproxy
    elif command_exists service; then
        service haproxy restart
    else
        print_err "Could not restart HAProxy automatically. Please restart it manually."
        return 1
    fi
}

stop_haproxy() {
    if command_exists systemctl; then
        systemctl stop haproxy
    elif command_exists service; then
        service haproxy stop
    else
        return 1
    fi
}

apply_config() {
    local tmp_file="$1"

    echo
    print_warn "Validating HAProxy config..."
    if ! validate_config "$tmp_file"; then
        print_err "Invalid config. Nothing was changed."
        rm -f "$tmp_file"
        pause
        return 1
    fi

    backup_existing_config
    install -m 644 "$tmp_file" "$HAPROXY_CONFIG_FILE"
    rm -f "$tmp_file"

    if restart_haproxy; then
        print_ok "Configuration applied and HAProxy restarted successfully."
    else
        print_err "Config was written, but HAProxy restart failed. Check logs."
    fi

    pause
}

read_port() {
    local prompt="$1"
    local port
    while true; do
        read -r -p "$prompt" port
        port="$(printf '%s' "$port" | trim)"
        if is_valid_port "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
        print_err "Invalid port. Enter a number between 1 and 65535."
    done
}

read_host() {
    local prompt="$1"
    local host
    while true; do
        read -r -p "$prompt" host
        host="$(printf '%s' "$host" | trim)"
        if is_valid_host "$host"; then
            printf '%s\n' "$host"
            return 0
        fi
        print_err "Invalid IP/domain. Spaces are not allowed."
    done
}

append_single_tunnel() {
    local file="$1"
    local bind_port="$2"
    local destination_host="$3"
    local destination_port="$4"
    local name_suffix="$5"
    local backend_addr

    backend_addr="$(format_backend_address "$destination_host" "$destination_port")"

    cat >> "$file" <<CFG
frontend frontend_${bind_port}_${name_suffix}
    bind *:${bind_port}
    default_backend backend_${bind_port}_${name_suffix}

backend backend_${bind_port}_${name_suffix}
    server server_${bind_port}_${name_suffix} ${backend_addr} check

CFG
}


sanitize_id() {
    local value="$1"
    value="$(printf '%s' "$value" | tr -c '[:alnum:]_' '_' | sed 's/^_*//;s/_*$//')"
    [ -n "$value" ] || value="tunnel"
    printf '%s\n' "$value"
}

normalize_enabled() {
    local value="$1"
    case "$value" in
        1|yes|YES|Yes|y|Y|true|TRUE|on|ON|enable|enabled) echo "1" ;;
        0|no|NO|No|n|N|false|FALSE|off|OFF|disable|disabled) echo "0" ;;
        *) echo "" ;;
    esac
}

ensure_tunnels_file() {
    mkdir -p "$(dirname "$TUNNELS_FILE")"
    if [ ! -f "$TUNNELS_FILE" ]; then
        cat > "$TUNNELS_FILE" <<'EOF'
# Editable HAProxy tunnels database
# Format:
# name|listen_ports|destination_host|destination_ports|enabled
#
# listen_ports and destination_ports can be comma-separated lists.
# If destination_ports has one port, all listen ports go to that one destination port.
# If destination_ports has several ports, it must have the same count as listen_ports.
#
# Example one grouped tunnel:
# 1|31,1030,27028,39464,56855|10.20.1.2|31,1030,27028,39464,56855|1
EOF
        chmod 600 "$TUNNELS_FILE"
    fi
}

valid_tunnel_name() {
    local name="$1"
    [ -n "$name" ] && [[ "$name" != *"|"* ]]
}

destination_ports_match_listen_ports() {
    local listen_ports="$1"
    local destination_ports="$2"
    local listen_count destination_count

    listen_ports="$(normalize_port_list "$listen_ports")"
    destination_ports="$(normalize_port_list "$destination_ports")"

    is_valid_port_list "$listen_ports" || return 1
    is_valid_port_list "$destination_ports" || return 1

    listen_count="$(port_list_count "$listen_ports")"
    destination_count="$(port_list_count "$destination_ports")"

    [ "$destination_count" -eq 1 ] || [ "$destination_count" -eq "$listen_count" ]
}

tunnel_bind_port_exists() {
    local wanted_port="$1"
    local exclude_index="${2:-0}"
    local line name listen_ports destination_host destination_ports enabled normalized index port

    ensure_tunnels_file
    index=0
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        [ "$index" = "$exclude_index" ] && continue
        IFS='|' read -r name listen_ports destination_host destination_ports enabled _extra <<< "$line"
        listen_ports="$(normalize_port_list "$listen_ports")"
        enabled="$(printf '%s' "$enabled" | trim)"
        normalized="$(normalize_enabled "$enabled")"
        [ "$normalized" = "1" ] || continue

        IFS=',' read -r -a __listen_array <<< "$listen_ports"
        for port in "${__listen_array[@]}"; do
            if [ "$port" = "$wanted_port" ]; then
                return 0
            fi
        done
    done < "$TUNNELS_FILE"

    return 1
}

find_conflicting_bind_port() {
    local listen_ports="$1"
    local exclude_index="${2:-0}"
    local port

    listen_ports="$(normalize_port_list "$listen_ports")"
    IFS=',' read -r -a __listen_array <<< "$listen_ports"
    for port in "${__listen_array[@]}"; do
        if tunnel_bind_port_exists "$port" "$exclude_index"; then
            printf '%s\n' "$port"
            return 0
        fi
    done

    return 1
}

check_tunnels_file() {
    local line name listen_ports destination_host destination_ports enabled extra normalized index enabled_ports duplicate_found
    local listen_count destination_count port

    ensure_tunnels_file
    index=0
    enabled_ports=" "
    duplicate_found=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        IFS='|' read -r name listen_ports destination_host destination_ports enabled extra <<< "$line"

        name="$(printf '%s' "$name" | trim)"
        listen_ports="$(normalize_port_list "$listen_ports")"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_ports="$(normalize_port_list "$destination_ports")"
        enabled="$(printf '%s' "$enabled" | trim)"
        normalized="$(normalize_enabled "$enabled")"

        if [ -n "$extra" ]; then
            print_err "Tunnel #$index is invalid: too many fields. Do not use | inside values."
            return 1
        fi
        if ! valid_tunnel_name "$name"; then
            print_err "Tunnel #$index is invalid: name is empty or contains |"
            return 1
        fi
        if ! is_valid_port_list "$listen_ports"; then
            print_err "Tunnel #$index is invalid: listen port list '$listen_ports'"
            return 1
        fi
        if port_list_has_duplicates "$listen_ports"; then
            print_err "Tunnel #$index is invalid: duplicate listen ports inside the same tunnel"
            return 1
        fi
        if ! is_valid_host "$destination_host"; then
            print_err "Tunnel #$index is invalid: destination host '$destination_host'"
            return 1
        fi
        if ! is_valid_port_list "$destination_ports"; then
            print_err "Tunnel #$index is invalid: destination port list '$destination_ports'"
            return 1
        fi
        if ! destination_ports_match_listen_ports "$listen_ports" "$destination_ports"; then
            listen_count="$(port_list_count "$listen_ports")"
            destination_count="$(port_list_count "$destination_ports")"
            print_err "Tunnel #$index is invalid: destination ports count ($destination_count) must be 1 or match listen ports count ($listen_count)"
            return 1
        fi
        if [ -z "$normalized" ]; then
            print_err "Tunnel #$index is invalid: enabled must be 1/0, yes/no, on/off"
            return 1
        fi

        if [ "$normalized" = "1" ]; then
            IFS=',' read -r -a __listen_array <<< "$listen_ports"
            for port in "${__listen_array[@]}"; do
                case "$enabled_ports" in
                    *" $port "*)
                        print_err "Duplicate enabled bind port found: $port"
                        duplicate_found=1
                        ;;
                    *) enabled_ports="${enabled_ports}${port} " ;;
                esac
            done
        fi
    done < "$TUNNELS_FILE"

    [ "$duplicate_found" = "0" ] || return 1
    return 0
}

short_value() {
    local value="$1"
    local max="${2:-34}"
    if [ "${#value}" -gt "$max" ]; then
        printf '%s...\n' "${value:0:$((max - 3))}"
    else
        printf '%s\n' "$value"
    fi
}

list_managed_tunnels() {
    local line name listen_ports destination_host destination_ports enabled normalized index any status listen_short dest_short

    ensure_tunnels_file
    index=0
    any=0

    echo
    echo -e "${BLUE}Editable tunnel groups:${NC}"
    printf '%-4s %-20s %-34s %-24s %-34s %-8s\n' "ID" "Name" "Listen ports" "Destination" "Destination ports" "Status"
    printf '%-4s %-20s %-34s %-24s %-34s %-8s\n' "----" "--------------------" "----------------------------------" "------------------------" "----------------------------------" "--------"

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        any=1
        IFS='|' read -r name listen_ports destination_host destination_ports enabled _extra <<< "$line"
        name="$(printf '%s' "$name" | trim)"
        listen_ports="$(normalize_port_list "$listen_ports")"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_ports="$(normalize_port_list "$destination_ports")"
        normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
        [ "$normalized" = "1" ] && status="enabled" || status="disabled"
        listen_short="$(short_value "$listen_ports" 34)"
        dest_short="$(short_value "$destination_ports" 34)"
        printf '%-4s %-20s %-34s %-24s %-34s %-8s\n' "$index" "$(short_value "$name" 20)" "$listen_short" "$(short_value "$destination_host" 24)" "$dest_short" "$status"
    done < "$TUNNELS_FILE"

    if [ "$any" = "0" ]; then
        print_warn "No tunnel groups saved yet. Add one from the menu."
    fi
    echo
    echo "Editable file: $TUNNELS_FILE"
}

read_tunnel_index() {
    local prompt="$1"
    local index total
    total="$(grep -vcE '^[[:space:]]*($|#)' "$TUNNELS_FILE" 2>/dev/null || true)"
    total="${total:-0}"

    if [ "$total" -eq 0 ]; then
        print_warn "No saved tunnels found."
        return 1
    fi

    while true; do
        read -r -p "$prompt" index
        index="$(printf '%s' "$index" | trim)"
        if [[ "$index" =~ ^[0-9]+$ ]] && [ "$index" -ge 1 ] && [ "$index" -le "$total" ]; then
            printf '%s\n' "$index"
            return 0
        fi
        print_err "Invalid ID. Enter a number between 1 and $total."
    done
}

replace_tunnel_line() {
    local target_index="$1"
    local new_line="$2"
    local tmp line data_index

    tmp="$(mktemp)"
    data_index=0
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*($|#) ]]; then
            echo "$line" >> "$tmp"
            continue
        fi
        data_index="$((data_index + 1))"
        if [ "$data_index" = "$target_index" ]; then
            echo "$new_line" >> "$tmp"
        else
            echo "$line" >> "$tmp"
        fi
    done < "$TUNNELS_FILE"
    install -m 600 "$tmp" "$TUNNELS_FILE"
    rm -f "$tmp"
}

delete_tunnel_line() {
    local target_index="$1"
    local tmp line data_index

    tmp="$(mktemp)"
    data_index=0
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*($|#) ]]; then
            echo "$line" >> "$tmp"
            continue
        fi
        data_index="$((data_index + 1))"
        [ "$data_index" = "$target_index" ] && continue
        echo "$line" >> "$tmp"
    done < "$TUNNELS_FILE"
    install -m 600 "$tmp" "$TUNNELS_FILE"
    rm -f "$tmp"
}

get_tunnel_line_by_index() {
    local target_index="$1"
    local line data_index

    data_index=0
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        data_index="$((data_index + 1))"
        if [ "$data_index" = "$target_index" ]; then
            printf '%s\n' "$line"
            return 0
        fi
    done < "$TUNNELS_FILE"
    return 1
}

show_tunnel_details() {
    local title="$1"
    local name="$2"
    local listen_ports="$3"
    local destination_host="$4"
    local destination_ports="$5"
    local enabled="$6"
    local status

    [ "$(normalize_enabled "$enabled")" = "1" ] && status="enabled" || status="disabled"
    echo
    echo -e "${BLUE}${title}${NC}"
    echo "Name:              $name"
    echo "Destination IP:    $destination_host"
    echo "Listen ports:      $listen_ports"
    echo "Destination ports: $destination_ports"
    echo "Status:            $status"
    echo
}

ask_apply_managed_tunnels() {
    echo
    if confirm_yes "Apply this change to $HAPROXY_CONFIG_FILE and restart HAProxy now?"; then
        apply_managed_tunnels no-confirm
    else
        print_warn "Saved in $TUNNELS_FILE only. Main HAProxy config was not changed yet."
        sleep 1
    fi
}

add_managed_tunnel() {
    local name listen_ports destination_host destination_ports enabled conflict_port

    ensure_tunnels_file
    clear
    echo -e "${BLUE}Add editable tunnel group${NC}"
    echo "This creates ONE editable tunnel with one name and a list of ports."
    echo "Example: name=1, ports=31,1030,27028,39464,56855, destination=10.20.1.2"
    echo

    while true; do
        read -r -p "Tunnel name: " name
        name="$(printf '%s' "$name" | trim)"
        if [ -n "$name" ] && valid_tunnel_name "$name"; then
            break
        fi
        print_err "Invalid name. Enter a name and do not use | in it."
    done

    listen_ports="$(read_port_list "Listen/bind port(s) on this server: ")"
    destination_host="$(read_host "Destination IP/domain: ")"
    destination_ports="$(read_destination_port_list "Destination port(s) [empty = same as listen ports, one port = all]: " "$listen_ports")"

    enabled="1"
    if conflict_port="$(find_conflicting_bind_port "$listen_ports")"; then
        print_warn "Listen port $conflict_port is already used by another enabled tunnel."
        if confirm_yes "Save this whole tunnel as disabled?"; then
            enabled="0"
        else
            print_warn "Cancelled. Nothing was saved."
            sleep 1
            return 0
        fi
    fi

    printf '%s|%s|%s|%s|%s\n' "$name" "$listen_ports" "$destination_host" "$destination_ports" "$enabled" >> "$TUNNELS_FILE"

    print_ok "Tunnel group saved."
    show_tunnel_details "Saved tunnel" "$name" "$listen_ports" "$destination_host" "$destination_ports" "$enabled"
    ask_apply_managed_tunnels
}

edit_managed_tunnel() {
    local index line name listen_ports destination_host destination_ports enabled extra normalized
    local new_name new_listen_ports new_destination_host new_destination_ports new_enabled
    local input answer conflict_port

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to edit: ")" || { pause; return 1; }
    line="$(get_tunnel_line_by_index "$index")" || { print_err "Tunnel not found."; pause; return 1; }

    IFS='|' read -r name listen_ports destination_host destination_ports enabled extra <<< "$line"
    name="$(printf '%s' "$name" | trim)"
    listen_ports="$(normalize_port_list "$listen_ports")"
    destination_host="$(printf '%s' "$destination_host" | trim)"
    destination_ports="$(normalize_port_list "$destination_ports")"
    normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
    [ "$normalized" = "1" ] || normalized="0"

    show_tunnel_details "Selected tunnel" "$name" "$listen_ports" "$destination_host" "$destination_ports" "$normalized"
    echo "Leave a field empty to keep the current value."
    echo "For destination ports, type 'same' to make them the same as listen ports."
    echo

    read -r -p "Name [$name]: " input
    new_name="$(printf '%s' "${input:-$name}" | trim)"

    read -r -p "Listen/bind port(s) [$listen_ports]: " input
    input="$(normalize_port_list "$input")"
    if [ -z "$input" ]; then
        new_listen_ports="$listen_ports"
    elif is_valid_port_list "$input" && ! port_list_has_duplicates "$input"; then
        new_listen_ports="$input"
    else
        print_err "Invalid listen port list. Nothing was changed."
        pause
        return 1
    fi

    read -r -p "Destination IP/domain [$destination_host]: " input
    input="$(printf '%s' "$input" | trim)"
    new_destination_host="${input:-$destination_host}"

    read -r -p "Destination port(s) [$destination_ports]: " input
    input="$(printf '%s' "$input" | trim)"
    if [ -z "$input" ]; then
        new_destination_ports="$destination_ports"
        if ! destination_ports_match_listen_ports "$new_listen_ports" "$new_destination_ports"; then
            new_destination_ports="$new_listen_ports"
            print_warn "Destination port list did not match the new listen-port count, so it was reset to the same ports."
        fi
    elif [ "$input" = "same" ] || [ "$input" = "SAME" ]; then
        new_destination_ports="$new_listen_ports"
    else
        input="$(normalize_port_list "$input")"
        if destination_ports_match_listen_ports "$new_listen_ports" "$input"; then
            new_destination_ports="$input"
        else
            print_err "Invalid destination ports. Use one port, a matching comma list, or type same. Nothing was changed."
            pause
            return 1
        fi
    fi

    read -r -p "Enabled? yes/no [$normalized]: " answer
    if [ -z "$answer" ]; then
        new_enabled="$normalized"
    else
        new_enabled="$(normalize_enabled "$(printf '%s' "$answer" | trim)")"
    fi

    if ! valid_tunnel_name "$new_name" || ! is_valid_host "$new_destination_host" || [ -z "$new_enabled" ]; then
        print_err "Invalid input. Nothing was changed."
        pause
        return 1
    fi

    if [ "$new_enabled" = "1" ] && conflict_port="$(find_conflicting_bind_port "$new_listen_ports" "$index")"; then
        print_err "Another enabled tunnel already uses listen port $conflict_port. Disable that one first or choose another port."
        pause
        return 1
    fi

    replace_tunnel_line "$index" "${new_name}|${new_listen_ports}|${new_destination_host}|${new_destination_ports}|${new_enabled}"
    print_ok "Tunnel group updated."
    show_tunnel_details "Updated tunnel" "$new_name" "$new_listen_ports" "$new_destination_host" "$new_destination_ports" "$new_enabled"
    ask_apply_managed_tunnels
}

toggle_managed_tunnel() {
    local index line name listen_ports destination_host destination_ports enabled normalized new_enabled conflict_port

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to enable/disable: ")" || { pause; return 1; }
    line="$(get_tunnel_line_by_index "$index")" || { print_err "Tunnel not found."; pause; return 1; }
    IFS='|' read -r name listen_ports destination_host destination_ports enabled _extra <<< "$line"

    name="$(printf '%s' "$name" | trim)"
    listen_ports="$(normalize_port_list "$listen_ports")"
    destination_host="$(printf '%s' "$destination_host" | trim)"
    destination_ports="$(normalize_port_list "$destination_ports")"
    normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"

    if [ "$normalized" = "1" ]; then
        new_enabled="0"
    else
        if conflict_port="$(find_conflicting_bind_port "$listen_ports" "$index")"; then
            print_err "Cannot enable. Another enabled tunnel already uses listen port $conflict_port."
            pause
            return 1
        fi
        new_enabled="1"
    fi

    replace_tunnel_line "$index" "${name}|${listen_ports}|${destination_host}|${destination_ports}|${new_enabled}"
    [ "$new_enabled" = "1" ] && print_ok "Tunnel group enabled." || print_warn "Tunnel group disabled."
    show_tunnel_details "Tunnel" "$name" "$listen_ports" "$destination_host" "$destination_ports" "$new_enabled"
    ask_apply_managed_tunnels
}

delete_managed_tunnel() {
    local index line name listen_ports destination_host destination_ports enabled _extra

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to delete: ")" || { pause; return 1; }
    line="$(get_tunnel_line_by_index "$index")" || { print_err "Tunnel not found."; pause; return 1; }
    IFS='|' read -r name listen_ports destination_host destination_ports enabled _extra <<< "$line"
    show_tunnel_details "Selected tunnel" "$name" "$(normalize_port_list "$listen_ports")" "$destination_host" "$(normalize_port_list "$destination_ports")" "$enabled"

    if ! confirm_yes "Delete this tunnel group from saved tunnels?"; then
        print_warn "Cancelled."
        sleep 1
        return 0
    fi

    delete_tunnel_line "$index"
    print_ok "Tunnel group deleted."
    ask_apply_managed_tunnels
}

apply_managed_tunnels() {
    local mode="${1:-confirm}"
    local tmp_file line name listen_ports destination_host destination_ports enabled normalized index enabled_count safe_name
    local listen_count destination_count i bind_port destination_port

    ensure_tunnels_file
    echo
    print_warn "Checking saved tunnel groups..."
    if ! check_tunnels_file; then
        print_err "Saved tunnels are invalid. HAProxy config was not changed."
        pause
        return 1
    fi

    tmp_file="$(mktemp)"
    write_base_config "$tmp_file"
    index=0
    enabled_count=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        IFS='|' read -r name listen_ports destination_host destination_ports enabled _extra <<< "$line"
        name="$(printf '%s' "$name" | trim)"
        listen_ports="$(normalize_port_list "$listen_ports")"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_ports="$(normalize_port_list "$destination_ports")"
        normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
        [ "$normalized" = "1" ] || continue

        IFS=',' read -r -a __listen_array <<< "$listen_ports"
        IFS=',' read -r -a __destination_array <<< "$destination_ports"
        listen_count="${#__listen_array[@]}"
        destination_count="${#__destination_array[@]}"

        for i in "${!__listen_array[@]}"; do
            bind_port="$(printf '%s' "${__listen_array[$i]}" | trim)"
            if [ "$destination_count" -eq 1 ]; then
                destination_port="$(printf '%s' "${__destination_array[0]}" | trim)"
            else
                destination_port="$(printf '%s' "${__destination_array[$i]}" | trim)"
            fi
            enabled_count="$((enabled_count + 1))"
            safe_name="$(sanitize_id "${index}_${name}_${bind_port}")"
            append_single_tunnel "$tmp_file" "$bind_port" "$destination_host" "$destination_port" "$safe_name"
        done
    done < "$TUNNELS_FILE"

    if [ "$enabled_count" -eq 0 ]; then
        print_warn "There are no enabled listen ports. This will write a base HAProxy config with no listening ports."
        if ! confirm_yes "Continue?"; then
            rm -f "$tmp_file"
            print_warn "Cancelled."
            sleep 1
            return 0
        fi
    fi

    if [ "$mode" != "no-confirm" ]; then
        print_warn "This will rebuild $HAPROXY_CONFIG_FILE from the saved tunnel groups. A backup will be created first."
        if ! confirm_yes "Continue?"; then
            rm -f "$tmp_file"
            print_warn "Cancelled."
            sleep 1
            return 0
        fi
    fi

    apply_config "$tmp_file"
}

edit_tunnels_file_manually() {
    local editor

    ensure_tunnels_file
    clear
    echo -e "${BLUE}Manual editable tunnel file${NC}"
    echo
    echo "File: $TUNNELS_FILE"
    echo "Format: name|listen_ports|destination_host|destination_ports|enabled"
    echo "Example: 1|31,1030,27028,39464,56855|10.20.1.2|31,1030,27028,39464,56855|1"
    echo

    editor="${EDITOR:-}"
    if [ -z "$editor" ]; then
        if command_exists nano; then
            editor="nano"
        elif command_exists vim; then
            editor="vim"
        elif command_exists vi; then
            editor="vi"
        fi
    fi

    if [ -z "$editor" ]; then
        print_warn "No editor found. Install nano or edit this file manually: $TUNNELS_FILE"
        pause
        return 1
    fi

    $editor "$TUNNELS_FILE"

    echo
    if check_tunnels_file; then
        print_ok "Tunnel file looks valid."
        ask_apply_managed_tunnels
    else
        print_err "Tunnel file has errors. HAProxy config was not changed."
        pause
    fi
}

tunnel_manager_menu() {
    local choice
    while true; do
        clear
        echo -e "${BLUE}Editable Tunnel Manager${NC}"
        echo "-------------------------------"
        echo "Saved tunnel file: $TUNNELS_FILE"
        echo "Each tunnel group: name | listen ports | destination IP/domain | destination ports | enabled"
        echo "-------------------------------"
        echo -e "${GREEN}1. List saved tunnel groups${NC}"
        echo -e "${GREEN}2. Add tunnel group${NC}"
        echo -e "${YELLOW}3. Edit tunnel group${NC}"
        echo -e "${YELLOW}4. Enable/disable tunnel group${NC}"
        echo -e "${RED}5. Delete tunnel group${NC}"
        echo -e "${BLUE}6. Apply/rebuild HAProxy config from saved tunnel groups${NC}"
        echo "7. Edit tunnel file manually"
        echo "8. Legacy quick tunnel config"
        echo "9. Back"
        echo "-------------------------------"
        read -r -p "Enter your choice: " choice
        case "$choice" in
            1) clear; list_managed_tunnels; pause ;;
            2) add_managed_tunnel ;;
            3) edit_managed_tunnel ;;
            4) toggle_managed_tunnel ;;
            5) delete_managed_tunnel ;;
            6) apply_managed_tunnels ;;
            7) edit_tunnels_file_manually ;;
            8) multiple_server_menu ;;
            9) return 0 ;;
            *) print_err "Invalid option!" && sleep 1 ;;
        esac
    done
}

configure_new_tunnel() {
    local haproxy_bind_ports destination_ports destination_host
    local tmp_file bind_port destination_port i
    local bind_ports_array destination_ports_array

    clear
    if ! confirm_yes "All your previous configs will be backed up and replaced. Continue?"; then
        print_err "Operation cancelled by user."
        sleep 1
        return 1
    fi

    echo
    read -r -p "1. Enter HAProxy bind ports (e.g. 443,8443,2096): " haproxy_bind_ports
    read -r -p "2. Enter Destination ports in the same order (e.g. 443,8443,2096): " destination_ports
    destination_host="$(read_host "3. Enter Destination IP/domain: ")"

    IFS=',' read -r -a bind_ports_array <<< "$haproxy_bind_ports"
    IFS=',' read -r -a destination_ports_array <<< "$destination_ports"

    if [ "${#bind_ports_array[@]}" -ne "${#destination_ports_array[@]}" ]; then
        print_err "The number of HAProxy bind ports and Destination ports must match."
        pause
        return 1
    fi

    tmp_file="$(mktemp)"
    write_base_config "$tmp_file"

    for i in "${!bind_ports_array[@]}"; do
        bind_port="$(printf '%s' "${bind_ports_array[$i]}" | trim)"
        destination_port="$(printf '%s' "${destination_ports_array[$i]}" | trim)"

        if ! is_valid_port "$bind_port" || ! is_valid_port "$destination_port"; then
            print_err "Invalid port pair: ${bind_port} -> ${destination_port}"
            rm -f "$tmp_file"
            pause
            return 1
        fi

        append_single_tunnel "$tmp_file" "$bind_port" "$destination_host" "$destination_port" "$i"
    done

    apply_config "$tmp_file"
}

add_new_server() {
    local tmp_file bind_port destination_host destination_port stamp

    if [ ! -f "$HAPROXY_CONFIG_FILE" ]; then
        echo
        print_err "There is no HAProxy config. First create a tunnel from option 1."
        pause
        return 1
    fi

    tmp_file="$(mktemp)"
    cp "$HAPROXY_CONFIG_FILE" "$tmp_file"
    stamp="$(date +%s)"

    while true; do
        clear
        bind_port="$(read_port "Enter HAProxy bind port: ")"
        destination_host="$(read_host "Enter Destination IP/domain: ")"
        destination_port="$(read_port "Enter Destination port: ")"

        append_single_tunnel "$tmp_file" "$bind_port" "$destination_host" "$destination_port" "$stamp"

        echo
        if ! confirm_yes "Do you want to add another config?"; then
            break
        fi
        stamp="$((stamp + 1))"
    done

    apply_config "$tmp_file"
}

multiple_server_menu() {
    local choice
    clear
    echo "Select an option:"
    echo
    echo -e "${GREEN}1. New Configuration${NC}"
    echo -e "${BLUE}2. Add a new config${NC}"
    echo -e "${RED}3. Back${NC}"
    echo
    read -r -p "Enter your choice: " choice
    case "$choice" in
        1) configure_new_tunnel ;;
        2) add_new_server ;;
        3) return 0 ;;
        *) print_err "Invalid option!" && sleep 1 ;;
    esac
}

load_balancing() {
    local tmp_file choice lb_algorithm bind_port destination_host destination_port server backend_addr

    clear
    if ! confirm_yes "All your previous configs will be backed up and replaced. Continue?"; then
        print_err "Operation cancelled by user."
        sleep 1
        return 1
    fi

    echo
    echo -e "${BLUE}Load balancing options:${NC}"
    echo "1. Round Robin"
    echo "2. Least Connections"
    echo "3. Source IP Hash"
    read -r -p "Select the desired load balancing algorithm: " choice

    case "$choice" in
        1) lb_algorithm="roundrobin" ;;
        2) lb_algorithm="leastconn" ;;
        3) lb_algorithm="source" ;;
        *)
            print_warn "Invalid input. Using default algorithm: roundrobin"
            lb_algorithm="roundrobin"
            ;;
    esac

    bind_port="$(read_port "Enter HAProxy bind port for load balancing: ")"

    tmp_file="$(mktemp)"
    write_base_config "$tmp_file"

    cat >> "$tmp_file" <<CFG
frontend tcp_frontend
    bind *:${bind_port}
    mode tcp
    default_backend tcp_backend

backend tcp_backend
    mode tcp
    balance ${lb_algorithm}
CFG

    server=1
    while true; do
        echo
        destination_host="$(read_host "1. Enter Destination IP/domain for load balancing: ")"
        destination_port="$(read_port "2. Enter Destination port for load balancing: ")"
        backend_addr="$(format_backend_address "$destination_host" "$destination_port")"
        echo "    server server${server} ${backend_addr} check" >> "$tmp_file"

        echo
        if ! confirm_yes "Do you want to add another server for load balancing?"; then
            break
        fi
        server="$((server + 1))"
    done

    echo >> "$tmp_file"
    apply_config "$tmp_file"
}

destroy_tunnel() {
    clear
    if ! confirm_yes "Stop HAProxy and remove $HAPROXY_CONFIG_FILE? A backup will be created first."; then
        print_warn "Cancelled."
        sleep 1
        return 0
    fi

    echo
    if stop_haproxy; then
        print_ok "HAProxy service stopped."
    else
        print_warn "Could not stop HAProxy automatically or it was not running."
    fi

    if [ -f "$HAPROXY_CONFIG_FILE" ]; then
        backup_existing_config
        rm -f "$HAPROXY_CONFIG_FILE"
        print_ok "$HAPROXY_CONFIG_FILE removed."
    else
        print_warn "$HAPROXY_CONFIG_FILE does not exist."
    fi

    pause
}

reset_service() {
    echo
    print_warn "Checking config before restart..."
    if [ -f "$HAPROXY_CONFIG_FILE" ] && ! validate_config "$HAPROXY_CONFIG_FILE"; then
        print_err "Current config is invalid. HAProxy was not restarted."
        pause
        return 1
    fi

    if restart_haproxy; then
        print_ok "HAProxy restarted successfully."
    else
        print_err "Error: Failed to restart HAProxy."
    fi
    pause
}

view_haproxy_log_realtime() {
    clear
    if [ -f "$LOG_FILE" ]; then
        echo "Displaying real-time HAProxy log ($LOG_FILE). Press Ctrl+C to exit."
        tail -f "$LOG_FILE"
    elif command_exists journalctl; then
        echo "Log file not found. Showing journalctl logs. Press Ctrl+C to exit."
        journalctl -u haproxy -f
    else
        print_err "No HAProxy log source found."
        pause
        return 1
    fi
}

view_current_config() {
    clear
    if [ -f "$HAPROXY_CONFIG_FILE" ]; then
        if command_exists less; then
            less "$HAPROXY_CONFIG_FILE"
        else
            cat "$HAPROXY_CONFIG_FILE"
            pause
        fi
    else
        print_warn "No config found at $HAPROXY_CONFIG_FILE"
        pause
    fi
}

get_public_ip() {
    curl -4 -fsS --max-time 3 https://api.ipify.org 2>/dev/null || \
    curl -4 -fsS --max-time 3 https://ifconfig.me 2>/dev/null || true
}

fetch_server_info() {
    local ip json country isp
    ip="$(get_public_ip)"

    if [ -z "$ip" ]; then
        SERVER_COUNTRY="Unknown"
        SERVER_ISP="Unknown"
        SERVER_IP="Unknown"
        return
    fi

    SERVER_IP="$ip"
    json="$(curl -fsS --max-time 4 "http://ipwhois.app/json/${ip}" 2>/dev/null || true)"
    if [ -n "$json" ] && command_exists jq; then
        country="$(printf '%s' "$json" | jq -r '.country // "Unknown"' 2>/dev/null)"
        isp="$(printf '%s' "$json" | jq -r '.isp // "Unknown"' 2>/dev/null)"
    fi

    SERVER_COUNTRY="${country:-Unknown}"
    SERVER_ISP="${isp:-Unknown}"
}

display_server_info() {
    echo -e "${GREEN}Public IP:${NC} ${SERVER_IP:-Unknown}"
    echo -e "${GREEN}Location:${NC} ${SERVER_COUNTRY:-Unknown}"
    echo -e "${GREEN}Datacenter/ISP:${NC} ${SERVER_ISP:-Unknown}"
}

show_haproxy_status() {
    if ! command_exists haproxy; then
        print_err "HAProxy is not installed."
        return
    fi

    if command_exists systemctl; then
        systemctl is-active --quiet haproxy && print_ok "HAProxy is active" || print_err "HAProxy is not active"
    elif command_exists service; then
        service haproxy status >/dev/null 2>&1 && print_ok "HAProxy is active" || print_err "HAProxy is not active"
    else
        print_warn "Cannot detect HAProxy status on this system."
    fi
}

display_menu() {
    clear
    show_logo
    display_server_info
    echo "-------------------------------"
    show_haproxy_status
    echo "-------------------------------"
    echo "Menu:"
    echo -e "${GREEN}1. Manage Editable Tunnels (IPv4/IPv6/domain)${NC}"
    echo -e "${BLUE}2. Configure Load Balancer (TCP)${NC}"
    echo -e "${RED}3. Stop HAProxy service and remove configs${NC}"
    echo -e "${YELLOW}4. Restart HAProxy Service${NC}"
    echo "5. View HAProxy real-time logs"
    echo "6. View current HAProxy config"
    echo "7. Install/repair local shortcut"
    echo "8. Exit"
    echo "-------------------------------"
    echo -e "Shortcut after install: ${GREEN}sudo hapmenu${NC}"
    echo "-------------------------------"
}

read_option() {
    local choice
    read -r -p "Enter your choice: " choice
    case "$choice" in
        1) tunnel_manager_menu ;;
        2) load_balancing ;;
        3) destroy_tunnel ;;
        4) reset_service ;;
        5) view_haproxy_log_realtime ;;
        6) view_current_config ;;
        7) self_install && pause ;;
        8) echo "Exiting..." && exit 0 ;;
        *) print_err "Invalid option!" && sleep 1 ;;
    esac
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            echo "$APP_NAME v$APP_VERSION"
            exit 0
            ;;
        --doctor|doctor)
            show_doctor
            exit 0
            ;;
        --install|install)
            require_root
            install_packages_if_missing
            self_install
            echo
            print_ok "Opening menu..."
            sleep 1
            ;;
        --only-install)
            require_root
            install_packages_if_missing
            self_install
            exit 0
            ;;
        --repair-shortcut)
            require_root
            self_install
            exit 0
            ;;
        "")
            require_root
            install_packages_if_missing
            ensure_local_shortcut
            ;;
        *)
            print_err "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac

    fetch_server_info
    while true; do
        display_menu
        read_option
    done
}

main "$@"
