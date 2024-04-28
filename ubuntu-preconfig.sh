#!/usr/bin/bash

# Functions to handle logging
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >>"$LOG_FILE"
}
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >>"$LOG_FILE"
}
# Global Variables #
Start() {
    LOG_FILE="/var/log/ubuntu-preconfig.log"
    export DEBIAN_FRONTEND=noninteractive
    # shellcheck disable=SC1091
    source /etc/os-release || log_error "Failed to source /etc/os-release"
    DIST="$ID"
    readonly DIST
    UNAME_M="$(uname -m)"
    readonly UNAME_M
    UNAME_U="$(uname -s)"
    readonly UNAME_U
    WORK_DIR="/home/$(logname)"
    if [[ ! -d "$WORK_DIR" ]]; then
        mkdir "$WORK_DIR" || log_error "Failed to create directory $WORK_DIR"
    fi
    readonly PACKAGES=("lm-sensors" "htop" "network-manager" "cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-common" "cockpit-file-sharing" "cockpit-pcp" "wireguard-tools" "unattended-upgrades")
    readonly NETWORK_PACKAGES=("qemu-kvm" "libvirt-daemon-system" "libvirt-clients" "bridge-utils" "ovmf" "virt-manager" "cockpit-machines")
    readonly SERVICES=("cockpit.socket" "NetworkManager" "NetworkManager-wait-online.service")
    readonly NETWORK_SERVICES=("networkd-dispatcher.service" "systemd-networkd.socket" "systemd-networkd.service" "systemd-networkd-wait-online.service")
    readonly NAS_IP="192.168.1.65"
    # COLORS
    readonly COLOUR_RESET='\e[0m'
    readonly aCOLOUR=(
        '\e[38;5;154m' # green      | Lines, bullets and separators
        '\e[1m'        # Bold white | Main descriptions
        '\e[90m'       # Grey       | Credits
        '\e[91m'       # Red        | Update notifications Alert
        '\e[33m'       # Yellow     | Emphasis
    )
    readonly GREEN_LINE="${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
    #Script link
    readonly SCRIPT_LINK="https://raw.githubusercontent.com/mordilloSan/ubuntu/main/ubuntu-preconfig.sh"
    #Enable apt-get progress bar, Check if file exists or if it doesnt contain the key
    if [ ! -f /etc/apt/apt.conf.d/99fancy ] || [ "$(grep "Progress-Fancy" "/etc/apt/apt.conf.d/99fancy")" == "" ]; then
        echo 'DPkg::Progress-Fancy "1";' >>/etc/apt/apt.conf.d/99fancy || log_error "Failed to update apt configuration"
    fi
}
# shellcheck disable=SC2317
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    log_info "Script interrupted by Ctrl-C"
    exit 1
}
Get_IPs() {
    # Go through all available NICs till one IP is found
    ALL_NIC=$(ip -o link show | awk -F': ' '$2 !~ /^(lo|veth|br|docker)/ {print $2}')
    for NIC_ON in ${ALL_NIC}; do
        IP=$(ip -4 addr show "${NIC_ON}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [[ -n $IP ]]; then
            NUMBER_IP=$(wc -l <<<"$IP")
            if [[ $NUMBER_IP != 1 ]]; then
                IP=$(head -n 1 <<<"$IP")
            fi
            NIC_OFF=${ALL_NIC//$NIC_ON/}
            break
        fi
    done
    ROUTER=$(ip route | grep default | awk '{print $3}')
    COCKPIT_PORT=$(grep "ListenStream=" "/lib/systemd/system/cockpit.socket" | sed 's/ListenStream=//')
}
# Colors #
Show() {
    local log_message="[INFO] $2"
    local colour_start="${aCOLOUR[2]}"
    local colour_reset="$COLOUR_RESET"

    # OK
    if (($1 == 0)); then
        echo -e "${colour_start}[$COLOUR_RESET${aCOLOUR[0]}  OK  $colour_reset${colour_start}]$colour_reset $2"
    # FAILED
    elif (($1 == 1)); then
        echo -e "${colour_start}[$COLOUR_RESET${aCOLOUR[3]}FAILED$colour_reset${colour_start}]$colour_reset $2"
        log_message="[ERROR] $2"
    # INFO
    elif (($1 == 2)); then
        echo -e "${colour_start}[$COLOUR_RESET${aCOLOUR[0]} INFO $colour_reset${colour_start}]$colour_reset $2"
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${colour_start}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$colour_reset${colour_start}]$colour_reset $2"
    # MENTION
    elif (($1 == 4)); then
        echo -e "${colour_start}[$COLOUR_RESET${aCOLOUR[0]}      $colour_reset${colour_start}]$colour_reset $2"
    fi

    # Log the message
    echo "$(date '+%Y-%m-%d %H:%M:%S') $log_message" >>"$LOG_FILE"
}
GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}
# Check Functions #
Check_Arch() {
    case $UNAME_M in
    *64*)
        Show 0 "Your hardware architecture is : \e[33m$UNAME_M\e[0m"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: \e[33m$UNAME_M\e[0m"
        exit 1
        ;;
    esac
}
Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your OS is : \e[33m$UNAME_U\e[0m"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}
Check_Distribution() {
    if [[ $DIST == *ubuntu* ]]; then
        Show 0 "Your Linux Distribution is : \e[33m$DIST\e[0m"
    else
        Show 1 "Aborted, installation is only supported in linux ubuntu."
        exit 1
    fi
}
Check_Permissions() {
    interpreter=$(ps -p $$ | awk '$1 != "PID" {print $(NF)}' | tr -d '()')
    if [ "$interpreter" != "bash" ]; then
        Show 1 "Please run with bash. (./ubuntu-preconfig.sh or bash ubuntu-preconfig.sh)"
        Show 1 "Current interpreter: \e[33m$interpreter\e[0m"
        exit 1
    fi
    if [[ "$EUID" != 0 ]]; then
        Show 1 "Please run as root or with sudo."
        exit 1
    fi
    Show 0 "Current interpreter : \e[33m$interpreter\e[0m"
}
Check_Connection() {
    internet=$(
        wget -q --spider http://google.com
        echo $?
    )
    if [ "$internet" != 0 ]; then
        Show 1 "No internet connection"
        exit 1
    fi
    Show 0 "Internet : \e[33mOnline\e[0m"
}
Check_Success() {
    if [[ $1 != 0 ]]; then
        Show 1 "$2 failed!"
        exit "$1"
    else
        Show 0 "$2 success!"
    fi
}
# Start Functions #
Welcome_Banner() {
    clear
    echo -e "\e[0m\c"
    set -e
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    printf "\033[1mWelcome to the Ubuntu Preconfiguration Script.\033[0m\n"
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo ""
    echo " This will update the system, add 45Drives repository,
 install cockpit, install docker, install general tools,
 remove cloud-init and snapd, remove backup&temp files
 switch networkd to network-manager, install portainer"
    echo ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    Check_Arch
    Check_OS
    Check_Distribution
    Check_Permissions
    Check_Connection
    Show 2 "NFS IP - $NAS_IP"
    Show 2 "Current Working Directory - \e[33m$WORK_DIR\e[0m"
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo ""
    echo "Are you sure you want to continue? [y/N]: "
    read -r response </dev/tty # OR < /proc/$$/fd/0
    case $response in
    [yY] | [yY][eE][sS])
        echo
        ;;
    *)
        echo "Exiting..."
        exit 0
        ;;
    esac
    return 0
}
Set_Timezone() {
    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
    Show 0 "Time Zone is ${T_Z}."
}
Add_Repos() {
    Show 2 "Adding the necessary repository sources"
    GreyStart
    items=$(find /etc/apt/sources.list.d -name 45drives.sources)
    if [[ -z "$items" ]]; then
        echo -e "There were no existing 45Drives repos found. Setting up the new repo..."
        echo -e "Updating ca-certificates to ensure certificate validity..."
        apt-get install ca-certificates -y -q=2
        echo "Add the gpg key to the apt keyring"
        wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
        echo "Downloading the new repo file"
        curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
        echo "Updating the new repo file"
        sed -i "s/focal/focal/g" /etc/apt/sources.list.d/45drives.sources
        Check_Success $? "45Drives repos update"
    else
        count=$(echo "$items" | wc -l)
        echo -e "There are $count 45Drives repo(s) already."
    fi
}
Update_System() {
    echo ""
    Show 4 "Updating System"
    Add_Repos
    Show 2 "Updating packages"
    GreyStart
    apt-get -qq update
    Check_Success $? "Package update"
    Show 2 "Upgrading packages"
    GreyStart
    apt-get -qq upgrade
    Check_Success $? "System Update"
}
Reboot() {
    local kernel_update_required=0
    local general_update_required=0
    # Check for general reboot requirements
    if [ -f /var/run/reboot-required ]; then
        Show 3 "System needs to be restarted due to recent updates."
        general_update_required=1
    fi
    # Specifically check for kernel updates
    if grep -q "linux-image" /var/run/reboot-required.pkgs; then
        local current_kernel=$(uname -r)
        local new_kernel=$(grep "linux-image" /var/run/reboot-required.pkgs | sed -e "s/^linux-image-//")
        Show 3 "System needs to be restarted for new kernel update from $current_kernel to $new_kernel."
        kernel_update_required=1
    fi
    # Decide to reboot based on the update checks
    if [[ $kernel_update_required -eq 1 || $general_update_required -eq 1 ]]; then
        read -p "Reboot system now to apply critical updates? [y/N]: " response </dev/tty
        case "$response" in
        [yY] | [yY][eE][sS])
            Show 4 "Preparing to reboot..."
            touch "$HOME/resume-after-reboot" || { Show 1 "Failed to create flag file for resume after reboot."; }
            echo "curl -fsSL $SCRIPT_LINK | sudo bash" >>"$HOME/.bashrc" || { Show 1 "Failed to add script to .bashrc."; }
            Show 4 "Rebooting now..."
            reboot
            ;;
        *)
            Show 0 "Reboot postponed by user."
            ;;
        esac
    else
        Show 0 "No reboot required."
    fi
}
# Package Section #
Install_Docker() {
    Show 2 "Installing \e[33mDocker\e[0m"
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(docker version --format '{{.Server.Version}}')
        Show 0 "Docker is already installed. Current version is ${Docker_Version}."
    else
        Show 2 "Docker not installed. Installing."
        GreyStart
        curl -fsSL https://get.docker.com | bash
        Check_Docker_Install
    fi
}
Check_Docker_Install() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(docker version --format '{{.Server.Version}}')
        Show 0 "Docker installed successfully. Current version is ${Docker_Version}."
    else
        Show 1 "Docker installation failed. Please uninstall Docker."
    fi
}
Install_Packages() {
    echo ""
    Show 4 "\e[1mInstalling Packages\e[0m"
    Install_Docker
    lsb_release=$(lsb_release -cs | grep -v "LSB module" | awk '{print $NF}')
    if [[ "$lsb_release" == "" ]]; then
        Show 1 "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
    fi
    for packageNeeded in "${PACKAGES[@]}"; do
        Show 2 "Preparing the necessary dependency: \e[33m$packageNeeded\e[0m"
        if dpkg-query -W -f='${Status}' "$packageNeeded" 2>/dev/null | grep -q "ok installed"; then
            Show 0 "$packageNeeded is already installed."
        else
            Show 2 "Installing $packageNeeded..."
            GreyStart
            if apt-get install -y -qq -t "${lsb_release}-backports" "$packageNeeded"; then

                Show 0 "$packageNeeded installed successfully."
            else
                Show 1 "Failed to install $packageNeeded."
            fi
        fi
    done
    # Install sensors modules
    Show 2 "Preparing the necessary dependency: \e[33msensors\e[0m"
    GreyStart
    wget -q https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz
    res1=$?
    tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
    res2=$?
    cp -r cockpit-sensors/dist /usr/share/cockpit/sensors
    res3=$?
    if [ $res1 = 0 ] && [ $res2 = 0 ] && [ $res3 = 0 ]; then
        Show 0 "Sensors installed successfully."
    else
        Show 1 "Installation failed for sensors."
        log_error "Installation failed for sensors."
        exit 1
    fi
}
Initiate_Service() {
    echo ""
    Show 4 "\e[1mInitiating Services\e[0m"
    for SERVICE in "${SERVICES[@]}"; do
        Show 2 "Starting ${SERVICE}..."
        if systemctl enable --now "${SERVICE}"; then
            Show 0 "${SERVICE} started successfully."
        else
            Show 1 "Failed to start ${SERVICE}."
        fi
    done
}
Check_Service() {
    echo ""
    Show 4 "\e[1mChecking Services\e[0m"
    for SERVICE in "${SERVICES[@]}"; do
        Show 2 "Checking ${SERVICE}..."
        if [[ $(systemctl is-active "${SERVICE}") == "active" ]]; then
            Show 0 "${SERVICE} is running."
        else
            Show 1 "${SERVICE} is not running. Please reinstall."
        fi
    done
}
Stop_Service() {
    echo ""
    Show 4 "\e[1mRemoving Unneeded Services\e[0m"
    for NSERVICE in "${NETWORK_SERVICES[@]}"; do
        Show 2 "Stopping ${NSERVICE}..."
        GreyStart
        systemctl disable --now "${NSERVICE}" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            Show 0 "Service ${NSERVICE} stopped successfully."
        else
            Show 1 "Failed to stop service ${NSERVICE} or service does not exist."
        fi
    done
}
# Network #
Check_renderer() {
    echo ""
    Show 4 "\e[1mChanging networkd to NetworkManager\e[0m"
    # Find the Netplan configuration file
    NETPLAN_CONFIG_FILE=$(find /etc/netplan/*.yaml 2>/dev/null | head -n 1)
    if [ -z "$NETPLAN_CONFIG_FILE" ]; then
        Show 1 "Netplan configuration file not found."
        return
    fi
    Show 2 "Netplan configuration file found: $NETPLAN_CONFIG_FILE"
    # Check if NetworkManager is already set as the renderer
    if grep -q "renderer:\s*NetworkManager" "$NETPLAN_CONFIG_FILE"; then
        Show 0 "NetworkManager is already set as the renderer in $NETPLAN_CONFIG_FILE."
    else
        Change_renderer
    fi
}
Change_renderer() {
    # Backup current config
    GreyStart
    Show 2 "Backing up current config to $NETWORK_CONFIG.backup"
    mv "$NETWORK_CONFIG" "$NETWORK_CONFIG.backup"
    Check_Success $? "Backup current config"

    # Backup globally-managed-devices.conf if exists
    if [ -e /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ]; then
        Show 2 "Backing up 10-globally-managed-devices.conf"
        mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup
        Check_Success $? "Backup 10-globally-managed-devices.conf"
    fi

    # Update NetworkManager configuration
    sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf
    systemctl restart NetworkManager
    Check_Success $? "Restart NetworkManager"

    # Prepare new network configuration
    Show 2 "Preparing the new network configuration."
    echo "network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ${NIC_ON}:
      dhcp4: no
      addresses: [${IP}/24]
      routes:
      - to: default
        via: $ROUTER
      nameservers:
        addresses: [1.1.1.1]
        search: []" >>"$NETWORK_CONFIG"

    for NICS in ${NIC_OFF}; do
        echo "    ${NICS}:
      dhcp4: yes" >>"$NETWORK_CONFIG"
    done
    chmod 600 "$NETWORK_CONFIG"

    # Apply network configuration with Netplan
    netplan try
    if [ $? -eq 0 ]; then
        netplan apply
        Check_Success $? "Apply network configuration with Netplan"
    else
        Show 1 "Netplan failed!"
        return
    fi
    # Restart NetworkManager
    systemctl restart NetworkManager
    Check_Success $? "Restart NetworkManager"
}
Pihole_DNS() {
    echo ""
    Show 4 "\e[1mPreparing for Pihole\e[0m"
    Show 2 "Disabling stub resolver"
    GreyStart
    if sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf; then
        Check_Success $? "Disabling stub resolver"
    else
        Show 1 "Failed to disable stub resolver."
        return
    fi
    Show 2 "Pointing symlink to /run/systemd/resolve/resolv.conf"
    if sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'; then
        Check_Success $? "Pointing symlink"
    else
        Show 1 "Failed to point symlink."
        return
    fi
    systemctl restart systemd-resolved
    if [ $? -eq 0 ]; then
        Show 2 "systemd-resolved restarted successfully."
    else
        Show 1 "Failed to restart systemd-resolved."
        return
    fi
}
# Finish Section #
NFS_Mount() {
    echo ""
    if ping -c 1 "$NAS_IP" &>/dev/null; then
        Show 4 "\e[1mSetting up the NFS mount\e[0m"
        if [[ $(findmnt -M "$WORK_DIR"/docker) ]]; then
            Show 2 "NFS already mounted."
        else
            if [ ! -d "$WORK_DIR"/docker ]; then
                mkdir -p "$WORK_DIR"/docker
                if [ $? -eq 0 ]; then
                    Show 2 "Directory created: $WORK_DIR/docker"
                else
                    Show 1 "Failed to create directory: $WORK_DIR/docker"
                fi
            fi
            Show 2 "Mounting NFS..."
            mount -t nfs "$NAS_IP":/volume2/Server "$WORK_DIR"/docker
            if [ $? -eq 0 ]; then
                Show 2 "NFS mounted successfully."
                Show 2 "Making the mount permanent..."
                if ! grep -q "$WORK_DIR/docker" /etc/fstab; then
                    echo "$NAS_IP:/volume2/Server $WORK_DIR/docker  nfs      defaults    0       0" >>/etc/fstab
                    if [ $? -eq 0 ]; then
                        Show 3 "NFS mount added to /etc/fstab."
                    else
                        Show 1 "Failed to add NFS mount to /etc/fstab."
                    fi
                else
                    Show 0 "NFS mount already exists in /etc/fstab."
                fi
            else
                Show 1 "Failed to mount NFS."
            fi
        fi
        Containers
    else
        Show 3 "$NAS_IP not available!"
    fi
}
Containers() {
    echo ""
    Show 4 "\e[1mStarting Portainer\e[0m"
    # Check if the 'monitoring' network exists
    if ! docker network inspect monitoring &>/dev/null; then
        if docker network create monitoring &>/dev/null; then
            Show 3 "Docker network 'monitoring' created successfully."
        else
            Show 1 "Failed to create Docker network 'monitoring'."
        fi
    else
        Show 2 "Docker network 'monitoring' already exists."
    fi

    # Check if Portainer is already running
    if docker ps --format "{{.Names}}" | grep -q "portainer"; then
        Show 2 "Portainer is already running."
        # If Portainer is already running, no need to start it again
        return
    fi

    # Start Portainer
    docker_compose_file="$WORK_DIR/docker/portainer/docker-compose.yml"
    if [ -f "$docker_compose_file" ]; then
        if docker-compose --file "$docker_compose_file" up -d &>/dev/null; then
            Show 3 "Portainer started successfully."
            PORTAINER_PORT=$(docker container inspect portainer | grep HostPort --m=1 | sed 's/"//g' | sed 's/HostPort://' | sed 's/ //g')
        else
            Show 1 "Failed to start Portainer."
        fi
    else
        Show 1 "Docker Compose file for Portainer not found: $docker_compose_file"
    fi
}
Remove_cloudinit() {
    Show 2 "Removing cloud-init"
    GreyStart
    local cloudinit_installed=$(dpkg-query -W -f='${Status}' "cloud-init" 2>/dev/null | grep -c "ok installed")
    if [ "$cloudinit_installed" -eq 0 ]; then
        Show 0 "cloud-init is not installed."
        return 0
    fi

    if apt-get autoremove -q -y --purge cloud-init; then
        Check_Success $? "Removing cloud-init"
        Show 0 "cloud-init removed successfully."
    else
        Show 1 "Failed to remove cloud-init."
    fi

    if [ -d "/etc/cloud/" ]; then
        rm -rf /etc/cloud/
        Check_Success $? "Removing /etc/cloud/"
    else
        Show 0 "Directory /etc/cloud/ does not exist."
    fi

    if [ -d "/var/lib/cloud/" ]; then
        rm -rf /var/lib/cloud/
        Check_Success $? "Removing /var/lib/cloud/"
    else
        Show 0 "Directory /var/lib/cloud/ does not exist."
    fi
}
Remove_snap() {
    Show 2 "Removing snap"

    local snap_installed=$(dpkg-query -W -f='${Status}' "snapd" 2>/dev/null | grep -c "ok installed")
    if [ "$snap_installed" -eq 0 ]; then
        Show 0 "snapd is not installed."
        return 0
    fi

    GreyStart
    if systemctl stop snapd.socket && systemctl disable snapd.socket &&
        systemctl stop snapd.service && systemctl disable snapd.service; then
        Show 0 "snapd services stopped and disabled successfully."
    else
        Show 1 "Failed to stop or disable snapd services."
    fi

    if [ -d "/var/snap" ] || [ -d "/snap" ] || [ -d "$HOME/snap" ]; then
        Show 3 "Snap directories exist, indicating snaps might still be installed."
        if command -v snap &>/dev/null; then
            local snap_list=$(timeout 5 snap list --all | awk '!/disabled/{if (NR!=1) print $1}' | uniq)
            for snap in $snap_list; do
                if snap remove --purge "$snap"; then
                    Show 0 "Removed snap: $snap"
                else
                    Show 1 "Failed to remove snap: $snap"
                fi
            done
        else
            Show 1 "snap command is not functional. Manual removal may be required."
        fi
    else
        Show 0 "No snap directories found, assuming no snaps are installed."
    fi

    if apt-get autoremove --purge -y snapd; then
        Show 0 "snapd and all snaps have been removed."
    else
        Show 1 "Failed to remove snapd."
    fi

    # Cleanup snap directories
    Check_Success $? "Failed to remove /var/cache/snapd/" && rm -rf /var/cache/snapd/
    Check_Success $? "Failed to remove /var/snap" && rm -rf /var/snap
    Check_Success $? "Failed to remove /snap" && rm -rf /snap
    Check_Success $? "Failed to remove $HOME/snap" && rm -rf "$HOME/snap"
}
Clean_Up() {
    echo ""
    Show 4 "\e[1mStarting Clean Up\e[0m"
    Remove_cloudinit
    Remove_snap
    # Clean up repositories directory if it exists
    if [ -d ~/repos ]; then
        rm -rf ~/repos
        Check_Success $? "Removed ~/repos directory"
    else
        Show 0 "$HOME/repos directory does not exist."
    fi
    # Clean up cockpit-sensors files and directories
    if [ -d ~/cockpit-sensors ]; then
        rm -r ~/cockpit-sensors
        Check_Success $? "Removed ~/cockpit-sensors directory"
    fi
    # Remove any remaining cockpit-sensors files if they exist
    if compgen -G "$HOME/cockpit-sensors*.*" >/dev/null; then
        rm -f ~/cockpit-sensors*.*
        Check_Success $? "Removed cockpit-sensors files"
    else
        Show 0 "No cockpit-sensors files to remove."
    fi
    # Remove network configuration backup if it exists
    if [ -f "$NETWORK_CONFIG.backup" ]; then
        rm -f "$NETWORK_CONFIG.backup"
        Check_Success $? "Removed $NETWORK_CONFIG.backup"
    else
        Show 0 "$NETWORK_CONFIG.backup does not exist."
    fi
    Show 0 "Temp files removed"
}
Wrap_up_Banner() {
    echo -e ""
    Show 0 "\e[1mSETUP COMPLETE!\e[0m"
    echo -e ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Cockpit${COLOUR_RESET} is running at:${COLOUR_RESET}"
    echo -e "${GREEN_LINE}"
    echo -e " https://$IP:$COCKPIT_PORT (${NIC_ON})"
    echo -e ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Portainer${COLOUR_RESET} is running at:${COLOUR_RESET}"
    echo -e "${GREEN_LINE}"
    echo -e " https://$IP:$PORTAINER_PORT (${NIC_ON})"
    echo -e "${COLOUR_RESET}"
}
# Execute Everything
Setup() {
    Start
    trap 'onCtrlC' INT
    Welcome_Banner
    if [ -f /etc/myapp/resume-after-reboot ]; then
        Show 2 "Resuming script after reboot..."
        rm -f /etc/myapp/resume-after-reboot # Clean up the flag immediately after acknowledging it
    else
        Set_Timezone
        Update_System
        Reboot
    fi
    Install_Packages
    Reboot
    Initiate_Service
    Check_Service
    Stop_Service
    Get_IPs
    Check_renderer
    Pihole_DNS
    Clean_Up
    NFS_Mount
    Wrap_up_Banner
}

Setup
exit 0
