#!/usr/bin/bash
# Global Variables #
Start (){
    # SYSTEM INFO
    export DEBIAN_FRONTEND=noninteractive
    # shellcheck disable=SC1091
    source /etc/os-release
    DIST="$ID"
    readonly DIST
    UNAME_M="$(uname -m)"
    readonly UNAME_M
    UNAME_U="$(uname -s)"
    readonly UNAME_U
    WORK_DIR="/home/$(logname)"
    if [[ ! -d "$WORK_DIR" ]]; then
        mkdir "$WORK_DIR"
    fi
    readonly PACKAGES=("lm-sensors" "htop" "network-manager" "net-tools" "cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-common" "cockpit-file-sharing" "cockpit-pcp" "wireguard-tools" "unattended-upgrades")
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
        echo 'DPkg::Progress-Fancy "1";' >> /etc/apt/apt.conf.d/99fancy
    fi    
}
# shellcheck disable=SC2317
onCtrlC() { 
    echo -e "${COLOUR_RESET}"
    exit 1
}
Get_IPs() {
    # go trough all available NIC's till one IP is found
    ALL_NIC=$(ip -o link show | awk -F': ' '$2 !~ /^(lo|veth|br|docker)/ {print $2}')
    for NIC_ON in ${ALL_NIC}; do
        IP=$(ifconfig "${NIC_ON}" | grep inet | grep -v 127.0.0.1 | grep -v 172.17.0.1 | grep -v inet6 | awk '{print $2}' | sed -e 's/addr://g')
        if [[ -n $IP ]]; then
            #IF MORE THAN ONE IP EXISTS IN THAT NIC (ex. cloud VM's)
            NUMBER_IP=$(wc -l <<< "$IP")
            if [[ $NUMBER_IP != 1 ]]; then
                #removes all but first line
                IP=$(sed '2,$d' <<< "$IP")
            fi
            #remove current nic from the list
            NIC_OFF=${ALL_NIC//$NIC_ON/}
            break
        fi
    done
    # gets router IP
    ROUTER=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
    #gets cockpit port
    COCKPIT_PORT=$(grep "ListenStream=" "/lib/systemd/system/cockpit.socket" | sed 's/ListenStream=//')
}
# Colors #
Show() {
    # OK
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}  OK  $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # FAILED
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[3]}FAILED$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
        exit 1
    # INFO
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]} INFO $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # NOTICE
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[4]}NOTICE$COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    # MENTION
    elif (($1 == 4)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[0]}      $COLOUR_RESET${aCOLOUR[2]}]$COLOUR_RESET $2"
    fi
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
Check_Connection(){
    internet=$(wget -q --spider http://google.com ; echo $?)
    if [ "$internet" != 0 ]; then
		Show 1 "No internet connection"
		exit 1
    fi
    Show 0 "Internet : \e[33mOnline\e[0m"
}
Check_Success(){
    if [[ $1 != 0 ]]; then
        Show 1 "$2 failed!"
		exit "$1"
	else
        Show 0 "$2 sucess!"
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
 switch networkd to network-manager, install portainer, and start all stacks"
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
    read -r response  </dev/tty # OR < /proc/$$/fd/0
	case $response in
		[yY]|[yY][eE][sS])
			echo
			;;
		*)
			echo "Exiting..."
			exit 0
			;;
	esac
	return 0
}
Set_Timezone(){
    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
    Show 0 "Time Zone is ${T_Z}." 
}
Add_Repos(){
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
        lsb_release_cs=$(lsb_release -cs)
        if [[ "$lsb_release_cs" == "" ]]; then
            Show 1 "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
        fi
        lsb_release_cs="focal"
        echo "Updating the new repo file"
        sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
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
Reboot(){
    if [ -f /var/run/reboot-required ] || [ -f /var/run/reboot-required.pkgs ]; then
        if [ "$(cat /var/run/reboot-required* | grep "linux-image" | sed -e "s/^linux-image-//")" == "" ]; then
            Show 3 "System needs to be restarted for $(cat /var/run/reboot-required.pkgs)"
        else
            Show 3 "System needs to be restarted for new Kernel"    
            echo "Current Kernel Version - $(uname -a | awk '{print "linux-image-"$3}' | sed -e "s/^linux-image-//")"
            echo "Available Kernel Version - $(cat /var/run/reboot-required* | grep "linux-image" | sed -e "s/^linux-image-//")"
        fi
        echo "Reboot system now? [y/N]: "
        read -r response  </dev/tty # OR < /proc/$$/fd/0
        case $response in
            [yY]|[yY][eE][sS])
                Show 4 "Preparing to reboot..."
                # create a flag file to signal that we are resuming from reboot.
                if ! [ -f ~/resume-after-reboot ]; then
                    touch ~/resume-after-reboot
                    Check_Success $? "Flag file to resume after reboot"
                fi                
                # add the link to bashrc to start the script on login
                echo "curl -fsSL $SCRIPT_LINK | sudo bash" >> ~/.bashrc
                Check_Success $? "Setting up run script on boot"
                reboot </dev/tty
                ;;
        esac
    else
        Show 0 "No reboot required"
    fi
}
# Package Section #
Install_Docker() {
    Show 2 "Installing \e[33mDocker\e[0m"
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(docker version --format '{{.Server.Version}}')
        Show 0 "Current Docker verison is ${Docker_Version}."
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
        Show 0 "Current Docker verison is ${Docker_Version}."
    else
        Show 1 "Installation failed, please uninstall docker"
    fi
}
Install_Packages() {
    echo ""
    Show 4 "\e[1mInstalling Packages\e[0m"
    Install_Docker
    for packagesNeeded in "${PACKAGES[@]}"; do
        Show 2 "Prepare the necessary dependencie: \e[33m$packagesNeeded\e[0m"
        lsb_release_cs=$(lsb_release -cs)
        if [ "$(dpkg-query -W -f='${Status}' "$packagesNeeded" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
            Show 2 "$packagesNeeded not installed. Installing..."
            GreyStart
            apt-get install -y -qq -t "$lsb_release_cs"-backports "$packagesNeeded"
            Check_Success $? "$packagesNeeded installation"
        else
            Show 0 "$packagesNeeded already installed"
        fi
    done
    #install sensors modules
    Show 2 "Prepare the necessary dependencie: \e[33msensors\e[0m"
    GreyStart 
    wget -q https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz
    res1=$?
    tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
    res2=$?
    cp -r cockpit-sensors/dist /usr/share/cockpit/sensors
    res3=$?
    if [ $res1 = 0 ] && [ $res2 = 0 ] && [ $res3 = 0 ]; then
        Show 0 "sensors installed"
    else
        Show 1 "Instalation  failed!"
        return 1
    fi
}
Initiate_Service(){
    echo ""
    Show 4 "\e[1mInitiating Services\e[0m"
    for SERVICE in "${SERVICES[@]}"; do
        Show 2 "Starting ${SERVICE}..."
        systemctl enable --now "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
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
            Show 1 "${SERVICE} is not running, Please reinstall."
            exit 1
        fi
    done
}
Stop_Service(){
    echo ""
    Show 4 "\e[1mRemoving Unneeded Services\e[0m"
    for NSERVICE in "${NETWORK_SERVICES[@]}"; do
        Show 2 "Stoping ${NSERVICE}..."
        GreyStart
        systemctl disable --now "${NSERVICE}" || Show 2 "Service ${NSERVICE} does not exist."
        Check_Success $? "Disabling ${NSERVICE}"
    done
}
# Network #
Check_renderer(){
    echo ""
    Show 4 "\e[1mChanging networkd to NetworkManager\e[0m"
    #crude renderer checkfind
    NETWORK_CONFIG=$(find /etc/netplan/* | sed -n '1p')
    Show 2 "Config File exists - $NETWORK_CONFIG"
    if grep -Fq "renderer: Network" "$NETWORK_CONFIG"; then
        Show 0 "Network Manager OK"
    else
        Change_renderer
    fi
}
Change_renderer() {
    # backing up current config
    GreyStart
    Show 2 "Backing up current config to $NETWORK_CONFIG.backup"
    mv "$NETWORK_CONFIG" "$NETWORK_CONFIG.backup"
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    if [ -e /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf ]; then
        Show 2 "Backing up 10-globally-managed-devices.conf"
        mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf  /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup
    fi
    sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf
    systemctl restart NetworkManager
    Check_Success $? "NetworkManager"
    systemctl enable NetworkManager-wait-online.service
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
        search: []" >> "$NETWORK_CONFIG"
    for NICS in ${NIC_OFF}; do
        echo "    ${NICS}:
      dhcp4: yes" >> "$NETWORK_CONFIG"
    done
    chmod 600 "$NETWORK_CONFIG"
    netplan try
    aux=$?  
    if [[ $aux = 0 ]]; then
        netplan apply
        Check_Success $? "Your current IP is $IP. Netplan"
	else
        Show 1 " Netplan failed!"
    fi
    systemctl restart NetworkManager
    Check_Success $? "NetworkManager"
}
Pihole_DNS(){
    echo ""
    Show 4 "\e[1mPreparing for Pihole\e[0m"
    Show 2 "Disabling stub resolver"
    GreyStart
    sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
    Check_Success $? "Disabling stub resolver"
    Show 2 "Pointing symlink to /run/systemd/resolve/resolv.conf"
    sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'
    Check_Success $? "Pointing symlink"
    systemctl restart systemd-resolved
    Check_Success $? "Restarting systemd-resolved"
}
# Finish Section #
NFS_Mount(){
    #mounting the NAS
    echo ""
    if ping -c 1 "$NAS_IP" &> /dev/null; then
        Show 4 "\e[1mSetting up the NFS mount\e[0m"
        if [[ $(findmnt -M "$WORK_DIR"/docker) ]]; then
            Show 2 "NFS already mounted"
        else
            if [ ! -d  "$WORK_DIR"/docker ]; then
                Show 2 "Creating Directory"
                mkdir "$WORK_DIR"/docker
            fi
            Show 2 "NFS Mounting in progress"
            mount -t nfs "$NAS_IP":/volume2/Server "$WORK_DIR"/docker
            Check_Success $? "NAS NFS mount"
            Show 2 "Making the mount permanent"
            if ! grep ~/docker /etc/fstab; then
                echo "$NAS_IP:/volume2/Server $WORK_DIR/docker  nfs      defaults    0       0" >> /etc/fstab
                Check_Success $? "NFS mount on boot"
            else
                Show 0 "NFS Mount on boot"
            fi
        fi
        Containers
    else
        Show 3 "$NAS_IP not available!"
    fi
}
Containers(){
    echo ""
    Show 4 "\e[1mStarting Portainer\e[0m"
    if [ "$(docker network ls | grep -c "monitoring")" -eq 0 ]; then
        docker network create monitoring
        Check_Success $? "Creation of Docker network -monitoring-"
    else
        Show 2 "Docker network already exists"
    fi
    # Start Portainer
    docker compose --project-directory "$WORK_DIR"/docker/portainer/ up -d
    PORTAINER_PORT=$(docker container inspect portainer | grep HostPort --m=1 | sed 's/"HostPort": "//' | sed 's/"//')
}
Remove_cloudinit(){
    Show 2 "Removing cloud-init"
    GreyStart
    if [ "$(dpkg-query -W -f='${Status}' "cloud-init" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
        Show 0 "cloud-init not installed."
    else
        apt-get autoremove -q -y --purge cloud-init 
        Check_Success $? "Removing cloud-init"
        rm -rf /etc/cloud/
        rm -rf /var/lib/cloud/
    fi
}
Remove_snap(){
    Show 2 "Removing snap"
    local SNAP_LIST
    if [ "$(dpkg-query -W -f='${Status}' "snapd" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
        Show 0 "snap not installed"
    else
        GreyStart
        systemctl disable snapd.socket
        systemctl disable snapd.service
        #Getting List of snaps installed - If no snap exists??
        
        SNAP_LIST=$(snap list | sed '1d' | grep -Eo '^[^ ]+')
        for i in $SNAP_LIST; do
            if [ "${i}" != "core" ] && [ "${i}" != "snapd" ] && [ "${i}" != "core22" ]; then
                snap remove --purge "$i"
            fi
        done
        SNAP_LIST=$(snap list | sed '1d' | grep -Eo '^[^ ]+')
        for i in $SNAP_LIST; do
                snap remove --purge "$i"
        done
        apt-get autoremove --purge snapd -y
        rm -rf /var/cache/snapd/
        rm -rf ~/snap
        Show 0 "snap removed"
    fi
}
Clean_Up(){
    echo ""
    Show 4 "\e[1mStarting Clean Up\e[0m"
    Remove_cloudinit
    Remove_snap
    # Remove the line that we added in bashrc
    sed -i "/curl -fsSL/d" ~/.bashrc
    Check_Success $? "Start script at boot disabled"
    # remove the temporary file that we created to check for reboot
    rm -f ~/resume-after-reboot
    # if all packages are installed ok we can remove the repo backup
    rm -rf ~/repos
    #leftovers of package install
    rm -r cockpit-sensors
    rm -f cockpit-sensors*.*
    #backup of the original network config
    rm -f "$NETWORK_CONFIG.backup"
    Show 0 "Temp files Removed"
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
Setup(){
    Start
    trap 'onCtrlC' INT
    Welcome_Banner
    # check if the resume flag file exists. 
    if ! [ -f ~/resume-after-reboot ]; then
        Set_Timezone
        Update_System
        Reboot
    else
        Show 2 "Resuming script after reboot..."
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