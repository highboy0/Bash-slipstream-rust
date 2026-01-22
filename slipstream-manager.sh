#!/bin/bash

set -e

# Install prerequisites
if ! command -v whiptail &> /dev/null || ! command -v jq &> /dev/null; then
    apt update && apt install -y whiptail curl jq openssl
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

# Download Binaries Function
download_binaries() {
    mkdir -p "$CONFIG_DIR"
    cd "$CONFIG_DIR"

    if whiptail --title "Download Binary" --yesno "Download latest Slipstream version?" $HEIGHT $WIDTH; then
        whiptail --title "Downloading" --infobox "Fetching release info..." $HEIGHT $WIDTH
        
        RELEASE_DATA=$(curl -s https://api.github.com/repos/highboy0/Bash-slipstream-rust/releases/latest)
        ASSET_URL=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name == "sliprstream.tar.gz") | .browser_download_url')

        if [[ -z "$ASSET_URL" || "$ASSET_URL" == "null" ]]; then
            whiptail --title "Error" --msgbox "File sliprstream.tar.gz not found in releases." $HEIGHT $WIDTH
            exit 1
        fi

        curl -L -o slipstream.tar.gz "$ASSET_URL"
        tar -xzf slipstream.tar.gz
        rm slipstream.tar.gz
        
        if [[ -f "slipstream-server" ]]; then
            chmod +x slipstream-server slipstream-client
            whiptail --title "Success" --msgbox "Download and extraction completed." $HEIGHT $WIDTH
        else
            whiptail --title "Error" --msgbox "Binaries not found in the archive." $HEIGHT $WIDTH
            exit 1
        fi
    fi
}

# Generate Certificate
generate_cert() {
    local domain=$1
    whiptail --title "SSL Certificate" --infobox "Generating self-signed cert for $domain..." $HEIGHT $WIDTH
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$KEY_FILE" -out "$CERT_FILE" -days 365 \
        -subj "/CN=$domain" >/dev/null 2>&1
}

# Free Port 53
free_port_53() {
    systemctl stop systemd-resolved >/dev/null 2>&1 || true
    systemctl disable systemd-resolved >/dev/null 2>&1 || true
}

# Create Systemd Service
create_service() {
    local type=$1
    local service_name="slipstream-$type"
    local service_file="/etc/systemd/system/$service_name.service"

    if [[ "$type" == "server" ]]; then
        cat > "$service_file" <<EOF
[Unit]
Description=Slipstream Server (DNS Tunnel)
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
Description=Slipstream Client (Fragment)
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
    whiptail --title "Success" --msgbox "Service $service_name updated and restarted." $HEIGHT $WIDTH
}

# Status Info
show_status() {
    if [[ -f "$CONFIG_FILE" ]]; then
        type=$(jq -r '.type' "$CONFIG_FILE")
        status=$(systemctl status "slipstream-$type.service" --no-pager -l || echo "Service not running")
        whiptail --title "Service Status" --scrolltext --msgbox "$status" $HEIGHT $WIDTH
    else
        whiptail --title "Error" --msgbox "Setup not found!" $HEIGHT $WIDTH
    fi
}

# Initial Setup
initial_setup() {
    if [[ -f "$CONFIG_FILE" ]]; then
        if ! whiptail --title "Warning" --yesno "Setup already exists. Overwrite?" $HEIGHT $WIDTH; then
            return
        fi
    fi

    SERVER_TYPE=$(whiptail --title "Server Type" --menu "Choose your role:" $HEIGHT $WIDTH 2 \
        "kharej" "Exit Server (Outside)" \
        "iran"  "Bridge Server (Iran)" 3>&1 1>&2 2>&3)

    download_binaries

    DOMAIN=$(whiptail --title "Domain" --inputbox "Enter NS domain (e.g., ns.example.com):" $HEIGHT $WIDTH "ns.xraychannel.com" 3>&1 1>&2 2>&3)

    if [[ "$SERVER_TYPE" == "kharej" ]]; then
        INBOUND_PORT=$(whiptail --title "Inbound Port" --inputbox "Marzban/Xray inbound port (localhost):" $HEIGHT $WIDTH "10000" 3>&1 1>&2 2>&3)
        generate_cert "$DOMAIN"
        free_port_53

        echo "{\"type\": \"server\", \"domain\": \"$DOMAIN\", \"inbound_port\": \"$INBOUND_PORT\"}" > "$CONFIG_FILE"
        create_service server
    else
        LISTEN_PORT=$(whiptail --title "Listen Port" $HEIGHT $WIDTH "443" 3>&1 1>&2 2>&3)

        RESOLVERS_STR=""
        while true; do
            RES=$(whiptail --title "Resolvers" --inputbox "Add Resolver (e.g. 8.8.8.8:53). Leave empty to finish:" $HEIGHT $WIDTH 3>&1 1>&2 2>&3) || break
            [[ -z "$RES" ]] && break
            if [[ -z "$RESOLVERS_STR" ]]; then RESOLVERS_STR="\"$RES\""; else RESOLVERS_STR="$RESOLVERS_STR, \"$RES\""; fi
        done

        if [[ -z "$RESOLVERS_STR" ]]; then
            whiptail --title "Error" --msgbox "At least one resolver is required!" $HEIGHT $WIDTH
            return
        fi

        echo "{\"type\": \"client\", \"domain\": \"$DOMAIN\", \"listen_port\": \"$LISTEN_PORT\", \"resolvers\": [$RESOLVERS_STR]}" > "$CONFIG_FILE"
        create_service client
    fi
}

# Main Menu
main_menu() {
    while true; do
        CHOICE=$(whiptail --title "Slipstream Manager" --menu "Choose an option:" $HEIGHT $WIDTH $MENU_HEIGHT \
            "1" "Initial Setup" \
            "2" "Show Service Status" \
            "3" "Uninstall" \
            "4" "Exit" 3>&1 1>&2 2>&3)

        case $CHOICE in
            1) initial_setup ;;
            2) show_status ;;
            3) uninstall ;;
            4) exit 0 ;;
            *) exit 0 ;;
        esac
    done
}

# Uninstall
uninstall() {
    if whiptail --title "Confirm" --yesno "Are you sure you want to uninstall?" $HEIGHT $WIDTH; then
        if [[ -f "$CONFIG_FILE" ]]; then
            type=$(jq -r '.type' "$CONFIG_FILE")
            systemctl stop "slipstream-$type.service" >/dev/null 2>&1 || true
            systemctl disable "slipstream-$type.service" >/dev/null 2>&1 || true
            rm -f "/etc/systemd/system/slipstream-$type.service"
        fi
        rm -rf "$CONFIG_DIR"
        systemctl daemon-reload
        whiptail --title "Success" --msgbox "Slipstream has been uninstalled." $HEIGHT $WIDTH
    fi
}

# Start Script
whiptail --title "Welcome" --msgbox "Slipstream Management Script\nInteractive GUI for DNS Tunneling." $HEIGHT $WIDTH
main_menu
