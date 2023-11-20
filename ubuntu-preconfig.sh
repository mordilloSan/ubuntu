#!/usr/bin/bash

####################
# Global Variables #
####################
Start (){
    # SYSTEM INFO
    ((EUID))
    source /etc/os-release
    DIST=$(echo "${ID}")
    readonly DIST
    UNAME_M="$(uname -m)"
    readonly UNAME_M
    UNAME_U="$(uname -s)"
    readonly UNAME_U
    WORK_DIR="/home/${SUDO_USER:-$(whoami)}"
    readonly WORK_DIR
    readonly PACKAGES=("lm-sensors" "htop" "network-manager" "net-tools" "cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-common" "cockpit-file-sharing" "cockpit-pcp")
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
    readonly GREEN_BULLET="${aCOLOUR[0]}-$COLOUR_RESET"
    readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"
    #Script link
    readonly SCRIPT_LINK="https://raw.githubusercontent.com/mordilloSan/ubuntu/main/ubuntu-preconfig.sh"
}
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}
Get_IPs() {
    ALL_NIC=$(ls /sys/class/net/ | grep -v "$(ls /sys/devices/virtual/net/)")
    for NIC in ${ALL_NIC}; do
        IP=$(ifconfig "${NIC}" | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | sed -e 's/addr://g')
        if [[ -n $IP ]]; then
            ALL_IP="$ALL_IP $IP"
        fi
    done
}
##########
# Colors #
##########
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
    # PROGRESS
    elif (($1 == 4)); then
        echo -e "${aCOLOUR[2]}[$COLOUR_RESET${aCOLOUR[2]}      $COLOUR_RESET${aCOLOUR[2]}]${aCOLOUR[2]} $2"
    fi
}
GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}
ColorReset() {
    echo -e "$COLOUR_RESET\c"
}
###################
# Check Functions #
###################
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
Check_Distribution() {
    if [[ $DIST == *ubuntu* ]]; then
        Show 0 "Your Linux Distribution is : \e[33m$DIST\e[0m"
    else
        Show 1 "Aborted, installation is only supported in linux ubuntu."
        exit 1
    fi
}
Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your System is : \e[33m$UNAME_U\e[0m"
    else
        Show 1 "This script is only for Linux."
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
	euid=$(id -u)
	if [[ "$euid" != 0 ]]; then
		Show 1 "Please run as root or with sudo."
		exit 1
	fi
	Show 0 "Current interpreter : \e[33m$interpreter\e[0m"
}
Check_Connection(){
    internet=$(wget -q --spider http://google.com ; echo $?)
    if [ "$internet" != 0 ]; then
		Show 1 "Can not reach the internet"
		exit 1
    fi
    Show 0 "Internet : \e[33mOnline\e[0m"
}
Check_Reboot(){
    if [ -f /var/run/reboot-required ]; then
        Show 3 "$(cat /var/run/reboot-required* | sed -n '1p')"
        if [ "$(cat /var/run/reboot-required* | grep "linux-image" | sed -e "s/^linux-image-//")" == "" ]; then
            Show 2 "System needs to be restarted for $(cat /var/run/reboot-required.pkgs)"
        else    
            echo "Current Kernel Version - $(uname -a | awk '{print "linux-image-"$3}' | sed -e "s/^linux-image-//")"
            echo "Available Kernel Version - $(cat /var/run/reboot-required* | grep "linux-image" | sed -e "s/^linux-image-//")"
        fi
        echo "Reboot system now? [y/N]: "
        read -r response  </dev/tty # OR < /proc/$$/fd/0
        case "$response" in
            [Yy]*) 
                wget -q $SCRIPT_LINK $WORK_DIR/ubuntu-preconfig.sh
                chmod +x $WORK_DIR/ubuntu-preconfig.sh
                echo "$WORK_DIR/ubuntu-preconfig.sh" >> ~/.bashrc 
                # create a flag file to signal that we are resuming from reboot.
                touch "$WORK_DIR"/resume-after-reboot
                reboot </dev/tty
            ;;
        esac
    else
        Show 0 "No reboot required"
    fi
}
Check_Success(){
    if [[ $? != 0 ]]; then
        Show 1 "$1 failed!"
		exit $?
	else
        Show 0 "$1 sucess!"
    fi
}
###################
# Start Functions #
###################
Welcome_Banner() {
	#clear
	echo -e "\e[0m\c"
	set -e
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
	printf "\033[1mWelcome to the Ubuntu Preconfiguration Script.\033[0m\n"
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
	echo ""
	echo " This will update the system, add 45Drives repository,
 install cockpit, install docker, install general tools,
 remove cloud-init and snapd, remove backup&temp files
 switch networkd to network-manager, install portainer."
	echo ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
	Check_Arch
	Check_OS
	Check_Distribution
	Check_Permissions
    Check_Connection
    Show 2 "Current Working Directory - \e[33m$WORK_DIR\e[0m"
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo ""
}
Resume_Setup(){
    # check if the resume flag file exists. 
    # We created this file before rebooting.
    if [ ! -f "$WORK_DIR"/resume-after-reboot ]; then
        Set_Timezone
        Add_Repos
        Update_System
        Check_Reboot
    else
        Show 2 "Resuming script after reboot..."
        # Remove the line that we added in zshrc
        sed -i '/sudo bash ubuntu-preconfig.sh/d' ~/.bashrc 
        # remove the temporary file that we created to check for reboot
        rm -f "$WORK_DIR"/resume-after-reboot
        rm -f "$WORK_DIR"/ubuntu-preconfig.sh
    fi
}
Set_Timezone(){
    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
    Show 0 "Time Zone is ${T_Z}." 
}
Add_Repos(){
    Show 2 "Adding the necessary repository sources"
    items=$(find /etc/apt/sources.list.d -name 45drives.sources)
	if [[ -z "$items" ]]; then
        echo -e "${aCOLOUR[2]}There were no existing 45Drives repos found. Setting up the new repo..."
	else
        count=$(echo "$items" | wc -l)
        echo -e "${aCOLOUR[2]}There were $count 45Drives repo(s) found. Archiving..."
	    mkdir -p "$WORK_DIR"/repos     
		mv /etc/apt/sources.list.d/45drives.sources "$WORK_DIR"/repos/45drives-"$(date +%Y-%m-%d)".list
		echo -e "${aCOLOUR[2]}The obsolete repos have been archived to $WORK_DIR/repos'. Setting up the new repo..."
		if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
			rm -f /etc/apt/sources.list.d/45drives.sources
		fi
	fi
	echo -e "${aCOLOUR[2]}Updating ca-certificates to ensure certificate validity..."
	apt-get install ca-certificates -y -q=2
	wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
    Check_Success "Add the gpg key to the apt keyring"
	curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
    Check_Success "Download the new repo file"
	lsb_release_cs=$(lsb_release -cs)
	if [[ "$lsb_release_cs" == "" ]]; then
		Show 1 "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
	fi
	lsb_release_cs="focal"
	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
    Check_Success "Update the new repo file"
	echo -e "${aCOLOUR[2]}The new repo file has been downloaded."
	Show 0 "Success! 45Drives repos has been updated!"
}
Update_System() {
	Show 2 "Updating packages"
	GreyStart
    apt-get update -q
    Check_Success "Package update"
	Show 2 "Upgrading packages"
	GreyStart
	DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    Check_Success "Package upgrade"
}
#####################
# Network Functions #
#####################
change_renderer() {

    systemctl disable systemd-networkd.service
    systemctl mask systemd-networkd.service
    systemctl stop systemd-networkd.service
    local config=""
    #setting proper permissions in netplan
    chmod 777 /etc/netplan/50-cloud-init.yaml
    config=""
    sudo chmod 777 /etc/netplan/50-cloud-init.yaml

    config=$(netplan get)
    echo $config

    
	#backup current file --> what is the file name????? It changes!!!!
    #mv /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.backup
    # Changing the renderer
    config="$(netplan get)"
    if echo "$config" | grep -q "renderer: networkd"; then
        echo "$config" | sed '2a renderer: NetworkManager'

        echo "$(netplan get)" | sed '2a renderer: NetworkManager'

    else
        echo ${config/renderer: networkd/renderer: NetworkManager}
    fi
    echo $config>>test.txt
    Show 2 "$config"
    chmod 600 /etc/netplan/*.yaml 
	netplan try
    Check_Success "Netplan configuration"
    # Cleaning up
	ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
	mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf  /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup
	sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf
	systemctl restart NetworkManager
    Check_Success "NetworkManager restart"
    sleep 60
}
###################
# Package Section #
###################
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
    Show 2 "Installing Packages"
    Install_Docker
    for packagesNeeded in "${PACKAGES[@]}"; do
        Show 2 "Prepare the necessary dependencie: \e[33m$packagesNeeded\e[0m"
        lsb_release_cs=$(lsb_release -cs)
        if [ "$(dpkg-query -W -f='${Status}' "$packagesNeeded" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
            Show 2 "$packagesNeeded not installed. Installing..."
            GreyStart
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q -t "$lsb_release_cs"-backports "$packagesNeeded"
            Check_Success "$packagesNeeded installation"
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
    rm -r cockpit-sensors
    rm -f cockpit-sensors*.*
}
Initiate_Services(){
    echo ""
	DEBIAN_FRONTEND=noninteractive systemctl enable --now cockpit.socket
    Check_Success "Cockpit setup"
	DEBIAN_FRONTEND=noninteractive systemctl enable --now NetworkManager
    Check_Success "Network Manager setup"
} 
##################
# Finish Section #
##################
Remove_cloudinit(){
    Show 2 "Removing cloud-init"
    GreyStart
    if [ "$(dpkg-query -W -f='${Status}' "cloud-init" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
        Show 0 "cloud-init not installed."
    else
        DEBIAN_FRONTEND=noninteractive apt-get autoremove -q -y --purge cloud-init 
        Check_Success "Removing cloud-init"
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
            if [ "${i}" != "core" ] && [ "${i}" != "snapd" ] && [ "${i}" != "core20" ]; then
                snap remove --purge "$i"
            fi
        done
        SNAP_LIST=$(snap list | sed '1d' | grep -Eo '^[^ ]+')
        for i in $SNAP_LIST; do
                snap remove --purge "$(echo $i)"
        done
        DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge snapd -y
        rm -rf /var/cache/snapd/
        rm -rf ~/snap
        Show 0 "snap removed"
    fi

}
Remove_repo_backup(){
    Show 2 "Just a test Funcion"
    return 0
}
Wrap_up_Banner() {
    Show 0 "SETUP COMPLETE!"
    echo -e ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Cockpit ${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    COCKPIT_PORT=$(cat $"/lib/systemd/system/cockpit.socket" | grep ListenStream= | sed 's/ListenStream=//')
    for IP in ${ALL_IP}; do
        if [[ "$COCKPIT_PORT" -eq "80" ]]; then
            echo -e " ${GREEN_BULLET} http://$IP (${NIC})"
        else
            echo -e " ${GREEN_BULLET} http://$IP:$COCKPIT_PORT (${NIC})"
        fi
    done    
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${aCOLOUR[2]}45Drives GitHub : https://github.com/45Drives"
    echo -e "${COLOUR_RESET}"
}
Start
trap 'onCtrlC' INT
Welcome_Banner
Resume_Setup
Install_Packages
#change_renderer
Get_IPs
Remove_cloudinit
Remove_snap
Remove_repo_backup
Initiate_Services
Wrap_up_Banner
exit 0

#Ideas
#htop (saving preferences)
#possibility of rebooting and then resuming the install
#summarize software installed
#progress in script
#detect ports used by services
#resolve pihole port conflict