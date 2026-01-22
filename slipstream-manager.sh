#!/bin/bash

# خروج در صورت بروز خطا
set -e

# بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
   echo "Error: Please run as root (sudo)."
   exit 1
fi

# نصب پیش‌نیازها
if ! command -v whiptail &> /dev/null || ! command -v jq &> /dev/null; then
    apt update && apt install -y whiptail curl jq openssl tar
fi

# تنظیمات مسیرها
SCRIPT_DIR="$(pwd)"
CONFIG_DIR="/opt/slipstream"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVER_BIN="$CONFIG_DIR/slipstream-server"
CLIENT_BIN="$CONFIG_DIR/slipstream-client"
CERT_FILE="$CONFIG_DIR/cert.pem"
KEY_FILE="$CONFIG_DIR/key.pem"
SYSCTL_CONF="/etc/sysctl.d/99-slipstream-opt.conf"

HEIGHT=20
WIDTH=78
MENU_HEIGHT=12

# ----------------------------------------------------------------
# بخش مدیریت زبان (FA/EN)
# ----------------------------------------------------------------
declare -A T

select_language() {
    LANG_CHOICE=$(whiptail --title "Language / زبان" --menu "Choose your language:" $HEIGHT $WIDTH 2 \
        "en" "English" \
        "fa" "فارسی" 3>&1 1>&2 2>&3)

    if [[ "$LANG_CHOICE" == "fa" ]]; then
        T[title]="مدیریت Slipstream"
        T[welcome]="به اسکریپت مدیریت Slipstream خوش آمدید."
        T[main_menu]="منوی اصلی - گزینه مورد نظر را انتخاب کنید:"
        T[opt1]="نصب و راه‌اندازی (Install)"
        T[opt2]="مدیریت Resolverها"
        T[opt3]="وضعیت سرویس"
        T[opt4]="مشاهده لاگ‌ها (Live)"
        T[opt5]="بهینه‌سازی سیستم (TCP/BBR)"
        T[opt6]="حذف کامل (Uninstall)"
        T[opt7]="خروج"
        T[ask_tweak]="آیا مایل هستید بهینه‌سازی‌های شبکه (TCP/BBR) برای افزایش سرعت اعمال شود؟"
        T[success]="عملیات با موفقیت انجام شد."
        T[err_no_config]="ابتدا باید نصب را انجام دهید."
        T[wait]="لطفا منتظر بمانید..."
        T[ask_domain]="دامنه NS را وارد کنید:"
        T[ask_port]="پورت را وارد کنید:"
    else
        T[title]="Slipstream Manager"
        T[welcome]="Welcome to Slipstream Management Script."
        T[main_menu]="Main Menu - Choose an option:"
        T[opt1]="Install/Setup"
        T[opt2]="Manage Resolvers"
        T[opt3]="Service Status"
        T[opt4]="View Live Logs"
        T[opt5]="System Optimization (TCP/BBR)"
        T[opt6]="Uninstall"
        T[opt7]="Exit"
        T[ask_tweak]="Do you want to apply Network Optimizations (TCP/BBR) for better speed?"
        T[success]="Operation completed successfully."
        T[err_no_config]="Please run setup first."
        T[wait]="Please wait..."
        T[ask_domain]="Enter NS Domain:"
        T[ask_port]="Enter Port:"
    fi
}

# ----------------------------------------------------------------
# بهینه‌سازی دائمی شبکه
# ----------------------------------------------------------------

apply_network_tweaks() {
    whiptail --title "${T[title]}" --infobox "${T[wait]}" $HEIGHT $WIDTH
    
    # تنظیمات برای پایداری و سرعت (دائمی)
    cat <<EOF > "$SYSCTL_CONF"
# Slipstream Network Optimizations
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_fastopen=3
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.ip_forward=1
EOF
    # اعمال تغییرات بدون نیاز به ریبوت
    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    whiptail --title "${T[title]}" --msgbox "${T[success]}" $HEIGHT $WIDTH
}

# ----------------------------------------------------------------
# مدیریت فایل‌ها و سرویس
# ----------------------------------------------------------------

extract_local_binaries() {
    mkdir -p "$CONFIG_DIR"
    LOCAL_TAR=$(find "$SCRIPT_DIR" -name "sliprstream.tar.gz" | head -n 1)

    if [[ -f "$LOCAL_TAR" ]]; then
        tar -xzf "$LOCAL_TAR" -C "$CONFIG_DIR"
        chmod +x "$SERVER_BIN" "$CLIENT_BIN" 2>/dev/null || true
    else
        whiptail --title "Error" --msgbox "File sliprstream.tar.gz not found in $SCRIPT_DIR" $HEIGHT $WIDTH
        exit 1
    fi
}

create_service() {
    local type=$1
    local silent=$2
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
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    else
        local r_cmd=""
        while read -r line; do r_cmd="$r_cmd --resolver $line"; done < <(jq -r '.resolvers[]' "$CONFIG_FILE")
        cat > "$service_file" <<EOF
[Unit]
Description=Slipstream Client
After=network.target

[Service]
Type=simple
WorkingDirectory=$CONFIG_DIR
ExecStart=$CLIENT_BIN --tcp-listen-port $(jq -r '.listen_port' "$CONFIG_FILE") $r_cmd --domain $(jq -r '.domain' "$CONFIG_FILE")
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable "$service_name" >/dev/null 2>&1
    systemctl restart "$service_name" >/dev/null 2>&1
    [[ "$silent" != "silent" ]] && whiptail --title "${T[title]}" --msgbox "${T[success]}" $HEIGHT $WIDTH
}

# ----------------------------------------------------------------
# مدیریت Resolverها
# ----------------------------------------------------------------

manage_resolvers() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        whiptail --title "${T[title]}" --msgbox "${T[err_no_config]}" $HEIGHT $WIDTH
        return
    fi

    while true; do
        CURRENT_RES=$(jq -r '.resolvers | join(", ")' "$CONFIG_FILE")
        RES_CHOICE=$(whiptail --title "${T[opt2]}" --menu "Current: [$CURRENT_RES]" $HEIGHT $WIDTH 3 \
            "1" "Add New" \
            "2" "Remove" \
            "3" "Back" 3>&1 1>&2 2>&3)

        case $RES_CHOICE in
            1)
                NEW_IP=$(whiptail --title "Add" --inputbox "IP:Port (e.g. 1.1.1.1:53):" $HEIGHT $WIDTH 3>&1 1>&2 2>&3)
                [[ -n "$NEW_IP" ]] && jq ".resolvers += [\"$NEW_IP\"]" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                ;;
            2)
                mapfile -t RES_LIST < <(jq -r '.resolvers[]' "$CONFIG_FILE")
                OPTIONS=()
                for i in "${!RES_LIST[@]}"; do OPTIONS+=("$i" "${RES_LIST[$i]}"); done
                DEL_INDEX=$(whiptail --title "Remove" --menu "Select to delete:" $HEIGHT $WIDTH $MENU_HEIGHT "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
                [[ -n "$DEL_INDEX" ]] && jq "del(.resolvers[$DEL_INDEX])" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
                ;;
            *) break ;;
        esac
        create_service client "silent"
    done
}

# ----------------------------------------------------------------
# نصب اولیه
# ----------------------------------------------------------------

initial_setup() {
    TYPE=$(whiptail --title "${T[opt1]}" --menu "${T[welcome]}" $HEIGHT $WIDTH 2 \
        "kharej" "External Server (Kharej)" \
        "iran"  "Iran Client (Iran)" 3>&1 1>&2 2>&3)

    [[ -z "$TYPE" ]] && return
    
    extract_local_binaries

    if whiptail --title "${T[title]}" --yesno "${T[ask_tweak]}" $HEIGHT $WIDTH; then
        apply_network_tweaks
    fi

    DOMAIN=$(whiptail --title "Domain" --inputbox "${T[ask_domain]}" $HEIGHT $WIDTH "ns.example.com" 3>&1 1>&2 2>&3)

    if [[ "$TYPE" == "kharej" ]]; then
        PORT=$(whiptail --title "Port" --inputbox "${T[ask_port]}" $HEIGHT $WIDTH "10000" 3>&1 1>&2 2>&3)
        # آزاد کردن پورت 53
        systemctl stop systemd-resolved || true
        systemctl disable systemd-resolved || true
        # تولید گواهی
        openssl req -x509 -newkey rsa:2048 -nodes -keyout "$KEY_FILE" -out "$CERT_FILE" -days 365 -subj "/CN=$DOMAIN" >/dev/null 2>&1
        echo "{ \"type\": \"server\", \"domain\": \"$DOMAIN\", \"inbound_port\": \"$PORT\" }" > "$CONFIG_FILE"
        create_service server
    else
        L_PORT=$(whiptail --title "Listen Port" --inputbox "${T[ask_port]}" $HEIGHT $WIDTH "443" 3>&1 1>&2 2>&3)
        echo "{ \"type\": \"client\", \"domain\": \"$DOMAIN\", \"listen_port\": \"$L_PORT\", \"resolvers\": [\"8.8.8.8:53\"] }" > "$CONFIG_FILE"
        create_service client
    fi
}

# ----------------------------------------------------------------
# شروع اصلی برنامه
# ----------------------------------------------------------------

select_language

while true; do
    CHOICE=$(whiptail --title "${T[title]}" --menu "${T[main_menu]}" $HEIGHT $WIDTH $MENU_HEIGHT \
        "1" "${T[opt1]}" \
        "2" "${T[opt2]}" \
        "3" "${T[opt3]}" \
        "4" "${T[opt4]}" \
        "5" "${T[opt5]}" \
        "6" "${T[opt6]}" \
        "7" "${T[opt7]}" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) initial_setup ;;
        2) manage_resolvers ;;
        3) 
            if [[ -f "$CONFIG_FILE" ]]; then
                type=$(jq -r '.type' "$CONFIG_FILE")
                status=$(systemctl status "slipstream-$type" --no-pager | head -n 15)
                whiptail --title "${T[opt3]}" --msgbox "$status" $HEIGHT $WIDTH
            else
                whiptail --msgbox "${T[err_no_config]}" $HEIGHT $WIDTH
            fi
            ;;
        4) 
            if [[ -f "$CONFIG_FILE" ]]; then
                type=$(jq -r '.type' "$CONFIG_FILE")
                clear
                echo "Press Ctrl+C to exit logs..."
                journalctl -u "slipstream-$type" -f -n 50
            else
                whiptail --msgbox "${T[err_no_config]}" $HEIGHT $WIDTH
            fi
            ;;
        5) apply_network_tweaks ;;
        6) 
            if whiptail --title "Uninstall" --yesno "Are you sure?" $HEIGHT $WIDTH; then
                systemctl stop slipstream-server slipstream-client 2>/dev/null || true
                systemctl disable slipstream-server slipstream-client 2>/dev/null || true
                rm -rf "$CONFIG_DIR" /etc/systemd/system/slipstream-*.service "$SYSCTL_CONF"
                systemctl daemon-reload
                whiptail --msgbox "${T[success]}" $HEIGHT $WIDTH
            fi
            ;;
        7) exit 0 ;;
        *) exit 0 ;;
    esac
done
