#!/usr/bin/env bash

# HAProxy Menu - improved local installer/menu
# Original project: github.com/Musixal/haproxy
# Updated: local shortcut installer, safer config generation, validation, backups

APP_NAME="haproxy-menu"
APP_VERSION="2.3"
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
              HAProxy Menu v2.3 - editable tunnels
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
# name|bind_port|destination_host|destination_port|enabled
# Example:
# iran-443|443|1.2.3.4|443|1
EOF
        chmod 600 "$TUNNELS_FILE"
    fi
}

valid_tunnel_name() {
    local name="$1"
    [ -n "$name" ] && [[ "$name" != *"|"* ]]
}

tunnel_bind_port_exists() {
    local wanted_port="$1"
    local exclude_index="${2:-0}"
    local line name bind_port destination_host destination_port enabled normalized index

    ensure_tunnels_file
    index=0
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        [ "$index" = "$exclude_index" ] && continue
        IFS='|' read -r name bind_port destination_host destination_port enabled _extra <<< "$line"
        bind_port="$(printf '%s' "$bind_port" | trim)"
        enabled="$(printf '%s' "$enabled" | trim)"
        normalized="$(normalize_enabled "$enabled")"
        if [ "$normalized" = "1" ] && [ "$bind_port" = "$wanted_port" ]; then
            return 0
        fi
    done < "$TUNNELS_FILE"

    return 1
}

check_tunnels_file() {
    local line name bind_port destination_host destination_port enabled extra normalized index enabled_ports duplicate_found

    ensure_tunnels_file
    index=0
    enabled_ports=" "
    duplicate_found=0

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        IFS='|' read -r name bind_port destination_host destination_port enabled extra <<< "$line"

        name="$(printf '%s' "$name" | trim)"
        bind_port="$(printf '%s' "$bind_port" | trim)"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_port="$(printf '%s' "$destination_port" | trim)"
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
        if ! is_valid_port "$bind_port"; then
            print_err "Tunnel #$index is invalid: bind port '$bind_port'"
            return 1
        fi
        if ! is_valid_host "$destination_host"; then
            print_err "Tunnel #$index is invalid: destination host '$destination_host'"
            return 1
        fi
        if ! is_valid_port "$destination_port"; then
            print_err "Tunnel #$index is invalid: destination port '$destination_port'"
            return 1
        fi
        if [ -z "$normalized" ]; then
            print_err "Tunnel #$index is invalid: enabled must be 1/0, yes/no, on/off"
            return 1
        fi

        if [ "$normalized" = "1" ]; then
            case "$enabled_ports" in
                *" $bind_port "*)
                    print_err "Duplicate enabled bind port found: $bind_port"
                    duplicate_found=1
                    ;;
                *) enabled_ports="${enabled_ports}${bind_port} " ;;
            esac
        fi
    done < "$TUNNELS_FILE"

    [ "$duplicate_found" = "0" ] || return 1
    return 0
}

list_managed_tunnels() {
    local line name bind_port destination_host destination_port enabled normalized index any status

    ensure_tunnels_file
    index=0
    any=0

    echo
    echo -e "${BLUE}Editable tunnels:${NC}"
    printf '%-4s %-22s %-10s %-30s %-10s %-8s\n' "ID" "Name" "Listen" "Destination" "D.Port" "Status"
    printf '%-4s %-22s %-10s %-30s %-10s %-8s\n' "----" "----------------------" "----------" "------------------------------" "----------" "--------"

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^[[:space:]]*($|#) ]] && continue
        index="$((index + 1))"
        any=1
        IFS='|' read -r name bind_port destination_host destination_port enabled _extra <<< "$line"
        name="$(printf '%s' "$name" | trim)"
        bind_port="$(printf '%s' "$bind_port" | trim)"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_port="$(printf '%s' "$destination_port" | trim)"
        normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
        [ "$normalized" = "1" ] && status="enabled" || status="disabled"
        printf '%-4s %-22s %-10s %-30s %-10s %-8s\n' "$index" "${name:0:22}" "$bind_port" "${destination_host:0:30}" "$destination_port" "$status"
    done < "$TUNNELS_FILE"

    if [ "$any" = "0" ]; then
        print_warn "No tunnels saved yet. Add one from the menu."
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

ask_apply_managed_tunnels() {
    echo
    if confirm_yes "Apply/rebuild HAProxy config from saved tunnels now?"; then
        apply_managed_tunnels
    fi
}

add_managed_tunnel() {
    local name bind_port destination_host destination_port enabled

    ensure_tunnels_file
    clear
    echo -e "${BLUE}Add editable tunnel${NC}"
    echo

    bind_port="$(read_port "Listen/bind port on this server: ")"
    destination_host="$(read_host "Destination IP/domain: ")"
    destination_port="$(read_port "Destination port: ")"
    read -r -p "Tunnel name (optional): " name
    name="$(printf '%s' "$name" | trim)"
    [ -n "$name" ] || name="tunnel-${bind_port}-to-${destination_port}"

    if ! valid_tunnel_name "$name"; then
        print_err "Invalid name. Do not use | in tunnel names."
        pause
        return 1
    fi

    if tunnel_bind_port_exists "$bind_port"; then
        print_warn "Another enabled tunnel already listens on port $bind_port."
        if ! confirm_yes "Save it anyway as disabled?"; then
            print_warn "Cancelled."
            sleep 1
            return 0
        fi
        enabled="0"
    else
        enabled="1"
    fi

    printf '%s|%s|%s|%s|%s\n' "$name" "$bind_port" "$destination_host" "$destination_port" "$enabled" >> "$TUNNELS_FILE"
    print_ok "Tunnel saved."
    ask_apply_managed_tunnels
}

edit_managed_tunnel() {
    local index line name bind_port destination_host destination_port enabled extra normalized
    local new_name new_bind_port new_destination_host new_destination_port new_enabled answer

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to edit: ")" || { pause; return 1; }
    line="$(get_tunnel_line_by_index "$index")" || { print_err "Tunnel not found."; pause; return 1; }

    IFS='|' read -r name bind_port destination_host destination_port enabled extra <<< "$line"
    name="$(printf '%s' "$name" | trim)"
    bind_port="$(printf '%s' "$bind_port" | trim)"
    destination_host="$(printf '%s' "$destination_host" | trim)"
    destination_port="$(printf '%s' "$destination_port" | trim)"
    normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
    [ "$normalized" = "1" ] || normalized="0"

    echo
    echo "Leave a field empty to keep the current value."
    read -r -p "Name [$name]: " new_name
    read -r -p "Listen/bind port [$bind_port]: " new_bind_port
    read -r -p "Destination IP/domain [$destination_host]: " new_destination_host
    read -r -p "Destination port [$destination_port]: " new_destination_port
    read -r -p "Enabled? yes/no [$normalized]: " answer

    new_name="$(printf '%s' "${new_name:-$name}" | trim)"
    new_bind_port="$(printf '%s' "${new_bind_port:-$bind_port}" | trim)"
    new_destination_host="$(printf '%s' "${new_destination_host:-$destination_host}" | trim)"
    new_destination_port="$(printf '%s' "${new_destination_port:-$destination_port}" | trim)"

    if [ -z "$answer" ]; then
        new_enabled="$normalized"
    else
        new_enabled="$(normalize_enabled "$(printf '%s' "$answer" | trim)")"
    fi

    if ! valid_tunnel_name "$new_name" || ! is_valid_port "$new_bind_port" || ! is_valid_host "$new_destination_host" || ! is_valid_port "$new_destination_port" || [ -z "$new_enabled" ]; then
        print_err "Invalid input. Nothing was changed."
        pause
        return 1
    fi

    if [ "$new_enabled" = "1" ] && tunnel_bind_port_exists "$new_bind_port" "$index"; then
        print_err "Another enabled tunnel already uses bind port $new_bind_port. Disable that one first or choose another port."
        pause
        return 1
    fi

    replace_tunnel_line "$index" "${new_name}|${new_bind_port}|${new_destination_host}|${new_destination_port}|${new_enabled}"
    print_ok "Tunnel updated."
    ask_apply_managed_tunnels
}

toggle_managed_tunnel() {
    local index line name bind_port destination_host destination_port enabled normalized new_enabled

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to enable/disable: ")" || { pause; return 1; }
    line="$(get_tunnel_line_by_index "$index")" || { print_err "Tunnel not found."; pause; return 1; }
    IFS='|' read -r name bind_port destination_host destination_port enabled _extra <<< "$line"

    name="$(printf '%s' "$name" | trim)"
    bind_port="$(printf '%s' "$bind_port" | trim)"
    destination_host="$(printf '%s' "$destination_host" | trim)"
    destination_port="$(printf '%s' "$destination_port" | trim)"
    normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"

    if [ "$normalized" = "1" ]; then
        new_enabled="0"
    else
        if tunnel_bind_port_exists "$bind_port" "$index"; then
            print_err "Cannot enable. Another enabled tunnel already uses bind port $bind_port."
            pause
            return 1
        fi
        new_enabled="1"
    fi

    replace_tunnel_line "$index" "${name}|${bind_port}|${destination_host}|${destination_port}|${new_enabled}"
    [ "$new_enabled" = "1" ] && print_ok "Tunnel enabled." || print_warn "Tunnel disabled."
    ask_apply_managed_tunnels
}

delete_managed_tunnel() {
    local index

    ensure_tunnels_file
    clear
    list_managed_tunnels
    index="$(read_tunnel_index "Enter tunnel ID to delete: ")" || { pause; return 1; }

    if ! confirm_yes "Delete tunnel #$index from saved tunnels?"; then
        print_warn "Cancelled."
        sleep 1
        return 0
    fi

    delete_tunnel_line "$index"
    print_ok "Tunnel deleted."
    ask_apply_managed_tunnels
}

apply_managed_tunnels() {
    local tmp_file line name bind_port destination_host destination_port enabled normalized index enabled_count safe_name

    ensure_tunnels_file
    echo
    print_warn "Checking saved tunnels..."
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
        IFS='|' read -r name bind_port destination_host destination_port enabled _extra <<< "$line"
        name="$(printf '%s' "$name" | trim)"
        bind_port="$(printf '%s' "$bind_port" | trim)"
        destination_host="$(printf '%s' "$destination_host" | trim)"
        destination_port="$(printf '%s' "$destination_port" | trim)"
        normalized="$(normalize_enabled "$(printf '%s' "$enabled" | trim)")"
        [ "$normalized" = "1" ] || continue
        enabled_count="$((enabled_count + 1))"
        safe_name="$(sanitize_id "${index}_${name}")"
        append_single_tunnel "$tmp_file" "$bind_port" "$destination_host" "$destination_port" "$safe_name"
    done < "$TUNNELS_FILE"

    if [ "$enabled_count" -eq 0 ]; then
        print_warn "There are no enabled tunnels. This will write a base HAProxy config with no listening ports."
        if ! confirm_yes "Continue?"; then
            rm -f "$tmp_file"
            print_warn "Cancelled."
            sleep 1
            return 0
        fi
    fi

    print_warn "This will rebuild $HAPROXY_CONFIG_FILE from the saved tunnel list. A backup will be created first."
    if ! confirm_yes "Continue?"; then
        rm -f "$tmp_file"
        print_warn "Cancelled."
        sleep 1
        return 0
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
    echo "Format: name|bind_port|destination_host|destination_port|enabled"
    echo "Example: iran-443|443|1.2.3.4|443|1"
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
        echo "Each tunnel: name | listen port | destination IP/domain | destination port | enabled"
        echo "-------------------------------"
        echo -e "${GREEN}1. List saved tunnels${NC}"
        echo -e "${GREEN}2. Add tunnel${NC}"
        echo -e "${YELLOW}3. Edit tunnel${NC}"
        echo -e "${YELLOW}4. Enable/disable tunnel${NC}"
        echo -e "${RED}5. Delete tunnel${NC}"
        echo -e "${BLUE}6. Apply/rebuild HAProxy config from saved tunnels${NC}"
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
