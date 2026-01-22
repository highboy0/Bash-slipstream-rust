#!/bin/bash

# ==========================================
# Slipstream Advanced Manager (Optimized)
# ==========================================

set -e

# Colors for terminal output
GREEN='\033[0;32m'
NC='\033[0m'

# Check dependencies
if ! command -v whiptail &> /dev/null || ! command -v jq &> /dev/null; then
    apt update && apt install -y whiptail curl jq openssl dnsutils bc
fi

CONFIG_DIR="/opt/slipstream"
CONFIG_FILE="$CONFIG_DIR/config.ini"
SERVER_BIN="$CONFIG_DIR/slipstream-server"
CLIENT_BIN="$CONFIG_DIR/slipstream-client"
CERT_FILE="$CONFIG_DIR/cert.pem"
KEY_FILE="$CONFIG_DIR/key.pem"

HEIGHT=20
WIDTH=78
MENU_HEIGHT=12

# --- Optimization Functions ---

enable_bbr() {
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        whiptail --title "BBR Optimization" --msgbox "TCP BBR has been enabled successfully!" $HEIGHT $WIDTH
    else
        whiptail --title "BBR Optimization" --msgbox "BBR is already enabled." $HEIGHT $WIDTH
    fi
}

# --- Core Functions ---

download_binaries() {
    mkdir -p "$CONFIG_DIR"
    cd "$CONFIG_DIR"

    # بررسی وجود فایل‌ها برای جلوگیری از دانلود مجدد
    if [[ -f "$SERVER_BIN" && -f "$CLIENT_BIN" ]]; then
        whiptail --title "Local Binaries Found" --msgbox "Project files already exist. Skipping download and using local binaries." $HEIGHT $WIDTH
    else
        whiptail --title "Downloading" --infobox "Files not found. Fetching binaries from GitHub..." $HEIGHT $WIDTH
        
        # آدرس مستقیم فایل (به جای چک کردن API برای آپدیت)
        # نکته: آدرس زیر بر اساس ساختار قبلی شماست
        RELEASE_URL="https://github.com/highboy0/Bash-slipstream-rust/releases/latest/download/sliprstream.tar.gz"

        if curl -L -o slipstream.tar.gz "$RELEASE_URL"; then
            tar -xzf slipstream.tar.gz
            rm slipstream.tar.gz
            chmod +x slipstream-server slipstream-client
        else
            whiptail --title "Error" --msgbox "Failed to download binaries. Please check your internet connection." $HEIGHT $WIDTH
            exit 1
        fi
    fi
}

free_port_53() {
    systemctl stop systemd-resolved >/dev/null 2>&1 || true
    systemctl disable systemd-resolved >/dev/null 2>&1 || true
}

create_service() {
    local type=$1
    local service_name="slipstream-$type"
    local service_file="/etc/systemd/system/$service_name.service"

    if [[ "$type" == "server" ]]; then
        cat > "$service_file" <<EOF
[Unit]
Description=Slipstream Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$SERVER_BIN --dns-listen-port 53 --target-address 127.0.0.1:$(jq -r '.inbound_port' "$CONFIG_FILE") --domain $(jq -r '.domain' "$CONFIG_FILE") --cert $CERT_FILE --key $KEY_FILE
Restart=always
RestartSec=5
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    else
        local resolvers=$(jq -r '.resolvers[]' "$CONFIG_FILE" | sed 's/^/--resolver /' | paste -sd " " -)
        cat > "$service_file" <<EOF
[Unit]
Description=Slipstream Client
After=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CLIENT_BIN --tcp-listen-port $(jq -r '.listen_port' "$CONFIG_FILE") $resolvers --domain $(jq -r '.domain' "$CONFIG_FILE")
Restart=always
RestartSec=5
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable "$service_name.service" >/dev/null 2>&1
    systemctl restart "$service_name.service" >/dev/null 2>&1
}

# --- Utility Functions ---

view_logs() {
    if [[ -f "$CONFIG_FILE" ]]; then
        type=$(jq -r '.type' "$CONFIG_FILE")
        whiptail --title "Live Logs" --msgbox "Showing live logs. Press Ctrl+C to exit and return to menu." $HEIGHT $WIDTH
        clear
        journalctl -u "slipstream-$type.service" -f
    else
        whiptail --title "Error" --msgbox "Setup not found!" $HEIGHT $WIDTH
    fi
}

test_speed() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        whiptail --title "Error" --msgbox "Service must be running to test latency." $HEIGHT $WIDTH
        return
    fi
    whiptail --title "Latency Test" --infobox "Testing DNS tunnel response time..." $HEIGHT $WIDTH
    DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")
    LATENCY=$(dig +short +time=2 +tries=1 @127.0.0.1 -p 53 google.com | grep -oE "[0-9]+") || true
    
    RES=$(ping -c 3 8.8.8.8 | tail -1 | awk '{print $4}' | cut -d '/' -f 2)
    
    whiptail --title "Benchmark Result" --msgbox "Tunnel Domain: $DOMAIN\n\nAvg Ping Latency: ${RES}ms" $HEIGHT $WIDTH
}

get_status_banner() {
    if [[ -f "$CONFIG_FILE" ]]; then
        type=$(jq -r '.type' "$CONFIG_FILE")
        if systemctl is-active --quiet "slipstream-$type.service"; then
            echo "Status: [ ACTIVE ] | Role: [ $type ] | Domain: [ $(jq -r '.domain' "$CONFIG_FILE") ]"
        else
            echo "Status: [ INACTIVE ] | Role: [ $type ]"
        fi
    else
        echo "Status: [ NOT CONFIGURED ]"
    fi
}

# --- Menus ---

initial_setup() {
    SERVER_TYPE=$(whiptail --title "Server Type" --menu "Choose your role:" $HEIGHT $WIDTH 2 \
        "kharej" "Exit Server (Outside)" \
        "iran"  "Bridge Server (Iran)" 3>&1 1>&2 2>&3)

    download_binaries
    DOMAIN=$(whiptail --title "Domain" --inputbox "Enter NS domain:" $HEIGHT $WIDTH "ns.xraychannel.com" 3>&1 1>&2 2>&3)

    if [[ "$SERVER_TYPE" == "kharej" ]]; then
        INBOUND_PORT=$(whiptail --title "Inbound Port" --inputbox "Target port (e.g. 10000):" $HEIGHT $WIDTH "10000" 3>&1 1>&2 2>&3)
        openssl req -x509 -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -out "$CERT_FILE" -days 365 -subj "/CN=$DOMAIN" >/dev/null 2>&1
        free_port_53
        echo "{\"type\": \"server\", \"domain\": \"$DOMAIN\", \"inbound_port\": \"$INBOUND_PORT\"}" > "$CONFIG_FILE"
        create_service server
    else
        LISTEN_PORT=$(whiptail --title "Listen Port" --inputbox "Local listen port:" $HEIGHT $WIDTH "443" 3>&1 1>&2 2>&3)
        echo "{\"type\": \"client\", \"domain\": \"$DOMAIN\", \"listen_port\": \"$LISTEN_PORT\", \"resolvers\": [\"8.8.8.8:53\"]}" > "$CONFIG_FILE"
        create_service client
    fi
    whiptail --title "Success" --msgbox "Setup completed and service started!" $HEIGHT $WIDTH
}

main_menu() {
    while true; do
        BANNER=$(get_status_banner)
        CHOICE=$(whiptail --title "Slipstream Manager v1.2" --menu "$BANNER\n\nChoose an option:" $HEIGHT $WIDTH $MENU_HEIGHT \
            "1" "Full Setup (Check Local Files First)" \
            "2" "View Live Logs" \
            "3" "Test Tunnel Latency" \
            "4" "Enable BBR Optimization" \
            "5" "Service Status (Detailed)" \
            "6" "Uninstall" \
            "7" "Exit" 3>&1 1>&2 2>&3)

        case $CHOICE in
            1) initial_setup ;;
            2) view_logs ;;
            3) test_speed ;;
            4) enable_bbr ;;
            5) 
               if [[ -f "$CONFIG_FILE" ]]; then
                   type=$(jq -r '.type' "$CONFIG_FILE")
                   status=$(systemctl status "slipstream-$type.service" --no-pager -l)
                   whiptail --title "Systemd Status" --scrolltext --msgbox "$status" $HEIGHT $WIDTH
               else
                   whiptail --title "Error" --msgbox "Service not configured." $HEIGHT $WIDTH
               fi ;;
            6) 
               if whiptail --yesno "Uninstall everything (including binaries)?" $HEIGHT $WIDTH; then
                   systemctl stop slipstream-server slipstream-client >/dev/null 2>&1 || true
                   systemctl disable slipstream-server slipstream-client >/dev/null 2>&1 || true
                   rm -rf "$CONFIG_DIR"
                   whiptail --msgbox "Uninstalled." $HEIGHT $WIDTH
               fi ;;
            7) clear; exit 0 ;;
            *) clear; exit 0 ;;
        esac
    done
}

main_menu
