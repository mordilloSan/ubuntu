#!/usr/bin/env bash

####################
# Global Variables #
####################
Start (){
    # SYSTEM INFO
    ((EUID)) && sudo_cmd="sudo"
    source /etc/os-release
    LSB_DIST=$([ -n "${ID}" ] && echo "${ID}")
    readonly LSB_DIST
    DIST=$(echo "${ID}")
    readonly DIST
    UNAME_M="$(uname -m)"
    readonly UNAME_M
    UNAME_U="$(uname -s)"
    readonly UNAME_U
    readonly PACKAGES=("lm-sensors" "htop" "network-manager" "net-tools" "cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-common" "cockpit-file-sharing")
    # COLORS
    readonly COLOUR_RESET='\e[0m'
    readonly aCOLOUR=(
        '\e[38;5;154m' # green      | Lines, bullets and separators
        '\e[1m'        # Bold white | Main descriptions
        '\e[90m'       # Grey       | Credits
        '\e[91m'       # Red        | Update notifications Alert
        '\e[33m'       # Yellow     | Emphasis
    )
    readonly GREEN_LINE=" ${aCOLOUR[0]}─────────────────────────────────────────────────────$COLOUR_RESET"
    readonly GREEN_BULLET=" ${aCOLOUR[0]}-$COLOUR_RESET"
    readonly GREEN_SEPARATOR="${aCOLOUR[0]}:$COLOUR_RESET"
    #Working Directory in user home folder
    WORK_DIR="/home/$(echo "$USER")"
    cd $WORK_DIR
    #Script link
    SCRIPT_LINK="https://raw.githubusercontent.com/mordilloSan/ubuntu/main/ubuntu-preconfig.sh"
}
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}
Get_IPs() {
    PORT=$(${sudo_cmd} cat $"/lib/systemd/system/cockpit.socket" | grep ListenStream= | sed 's/ListenStream=//')
    ALL_NIC=$($sudo_cmd ls /sys/class/net/ | grep -v "$(ls /sys/devices/virtual/net/)")
    for NIC in ${ALL_NIC}; do
        IP=$($sudo_cmd ifconfig "${NIC}" | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | sed -e 's/addr://g')
        if [[ -n $IP ]]; then
            if [[ "$PORT" -eq "80" ]]; then
                echo -e "${GREEN_BULLET} http://$IP (${NIC})"
            else
                echo -e "${GREEN_BULLET} http://$IP:$PORT (${NIC})"
            fi
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
Warn() {
    echo -e "${aCOLOUR[3]}$1$COLOUR_RESET"
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
		Show 1 "Please run with bash. (\`./ubuntu-preconfig.sh\` or \`bash ubuntu-preconfig.sh\`)"
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
Check_Resume(){
    # check if the resume flag file exists. 
    # We created this file before rebooting.
    if [ ! -f resume-after-reboot ]; then
        echo "running script for the first time.."
        # add this script to bashrc so it gets triggered immediately after reboot
        wget $SCRIPT_LINK
        echo "bash ubuntu-preconfig.sh" >> ~/.bashrc 
        # create a flag file to check if we are resuming from reboot.
        touch resume-after-reboot
    else
        echo "resuming script after reboot.."
        # Remove the line that we added in zshrc
        sed -i '/bash ubuntu-preconfig.sh/d' ~/.bashrc 
        # remove the temporary file that we created to check for reboot
        rm -f /var/run/resume-after-reboot
    fi
}
Check_Service_status() {
    for SERVICE in "${CASA_SERVICES[@]}"; do
        Show 2 "Checking ${SERVICE}..."
        if [[ $(${sudo_cmd} systemctl is-active "${SERVICE}") == "active" ]]; then
            Show 0 "${SERVICE} is running."
        else
            Show 1 "${SERVICE} is not running, Please reinstall."
            exit 1
        fi
    done
}
Check_Reboot(){
    if [ -f /var/run/reboot-required ]; then
        #TESTE=$(cat /var/run/reboot-required* | sed  "/libc6/d" | sed  "/linux-base/d" ; uname -a | awk '{print "linux-image-"$3}')
        Show 3 "$(cat /var/run/reboot-required* | sed -n '1p')"
        Show 4 "Current Kernel Version - $(uname -a | awk '{print "linux-image-"$3}')"
        Show 4 "Available Kernel Version - $(cat /var/run/reboot-required* | grep "linux-image")"
    	echo "Reboot system now? [y/N]: " | read response
        read -p "Are you sure? " -n 1 -r
        if [[ $response =~ ^[Yy]$ ]]; then
            reboot
        fi
    fi
}
Check_Success(){
    if [[ $? != 0 ]]; then
        Show 1 "$1 failed!"
		exit $res
	else
        Show 0 "$1 sucess!"
    fi
}
###################
# Start Functions #
###################
Welcome_Banner() {
	clear
	echo -e "\e[0m\c"
	set -e
	printf "\033[1mWelcome to the Ubuntu Preconfiguration Script.\033[0m\n"
	echo ""
	echo " This will update the system, remove cloud-init and snapd,
 replace systemd-networkd with network-manager, install cockpit,
 add 45Drives repository, remove cloud-init and snapd, install docker and portainer."
	echo ""
    echo " This script should *not* be run in an SSH session, as the network will be
 modified and you may be disconnected. Run this script from the console or IPMI
 remote console."
	echo ""
	Check_Arch
	Check_OS
	Check_Distribution
	Check_Permissions
    Check_Connection
    W_D=$( pwd )
    Show 0 "Current Working Directory - \e[33m$W_D\e[0m"
    echo "" 
    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
    Show 0 "Time Zone is ${T_Z}." 
}
Add_repos(){
    Show 2 "Adding the necessary repository sources"
    items=$(find /etc/apt/sources.list.d -name 45drives.sources)
	if [[ -z "$items" ]]; then
        echo -e "${aCOLOUR[2]}There were no existing 45Drives repos found. Setting up the new repo..."
	else
        count=$(echo "$items" | wc -l)
        echo -e "${aCOLOUR[2]}There were $count 45Drives repo(s) found. Archiving..."
	    mkdir -p ~/repos     
		mv /etc/apt/sources.list.d/45drives.sources ~/repos/45drives-$(date +%Y-%m-%d).list
		echo -e "${aCOLOUR[2]}The obsolete repos have been archived to '$(echo ~)/repos'. Setting up the new repo..."
		if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
			rm -f /etc/apt/sources.list.d/45drives.sources
		fi
	fi
	echo -e "${aCOLOUR[2]}Updating ca-certificates to ensure certificate validity..."
	apt-get install ca-certificates -y -q=2
	wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to add the gpg key to the apt keyring. Please review the above error and try again."
		exit $res
	fi
	curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to download the new repo file. Please review the above error and try again."
		exit $res
	fi
	lsb_release_cs=$(lsb_release -cs)
	if [[ "$lsb_release_cs" == "" ]]; then
		Show 1 "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
		exit $res
	fi
	lsb_release_cs="focal"
	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to update the new repo file. Please review the above error and try again."
		exit $res
	fi
	echo -e "${aCOLOUR[2]}The new repo file has been downloaded."
	Show 0 "Success! Your repo has been updated to our new server!"
}
Update_System() {
	local res
	Show 2 "Updating packages"
	GreyStart
    apt-get update -q -u 
    res=$?
    Check_Success "Package update"
    if [[ $res != 0 ]]; then
		Show 1 "Package update failed!"
		exit $res
	else
        Show 0 "System successfully updated"
    fi
	Show 2 "Upgrading packages"
	GreyStart
	DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y --autoremove 
    res=$?
    if [[ $res != 0 ]]; then
        Show 1 "Package upgrade failed!"
		exit $res
	else
        Show 0 "System successfully upgraded"
    fi
}
#####################
# Network Functions #
#####################
change_renderer() {

    systemctl disable systemd-networkd.service
    systemctl mask systemd-networkd.service
    systemctl stop systemd-networkd.service

	local res
    local config=""
    #setting proper permissions in netplan
    chmod 777 /etc/netplan/50-cloud-init.yaml
    config=""
    sudo chmod 777 /etc/netplan/50-cloud-init.yaml

    config=$(netplan get)
    echo $config
    printf "$config" > file.log
    
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
	res=$?
	if [[ $res != 0 ]]; then
		echo "netplan try failed."
        #we should restore the old file then and retry netplan!!!!
		exit $res
	fi
    # Cleaning up
	ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
	mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf  /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup
	sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf
	systemctl restart NetworkManager
	res=$?
	if [[ $res != 0 ]]; then
		echo "Reloading network-manager failed."
		exit $res
	fi
	echo "Successfully enabled network manager."
    sleep 60
}
###################
# Package Section #
###################
Install_Packages() {
	local res
    Show 2 "Installing Packages"
    for packagesNeeded in "${PACKAGES[@]}"; do
        Show 2 "Prepare the necessary dependencie: \e[33m$packagesNeeded\e[0m"
        lsb_release_cs=$(lsb_release -cs)
        if [ $(dpkg-query -W -f='${Status}' "$packagesNeeded" 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
            Show 2 "$packagesNeeded not installed. Installing..."
            GreyStart
            DEBIAN_FRONTEND=noninteractive apt-get install -y -q -t "$lsb_release_cs"-backports "$packagesNeeded"
            res=$?
            if [[ $res != 0 ]]; then
                Show 1 "Instalation  failed!"
                exit $res
            else
                Show 0 "$packagesNeeded installed" 
            fi
        else
            Show 0 "$packagesNeeded already installed"
        fi
    done
    #install sensors modules
    Show 2 "Prepare the necessary dependencie: \e[33msensors\e[0m"
    GreyStart 
    wget -q https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz #--show-progress
    res1=$?
    tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
    res2=$?
    cp -r cockpit-sensors/dist /usr/share/cockpit/sensors
    res3=$?
    if [ $res1 = 0 ] && [ $res2 = 0 ] && [ $res3 = 0 ]; then
        Show 0 "sensors installed"
    else
        Show 1 "Instalation  failed!"
        exit $res
    fi
    rm -r cockpit-sensors
    rm cockpit-sensors*.*
}
Initiate_Services(){
    local res
    echo ""
	# Enabling Cockpit
	DEBIAN_FRONTEND=noninteractive systemctl enable --now cockpit.socket
    res=$?
    if [[ $res != 0 ]]; then
        Show 1 "Enabling cockpit.socket failed!"
        exit $res
    fi
	Show 0 "Successfully initialized Cockpit."

	DEBIAN_FRONTEND=noninteractive systemctl enable --now NetworkManager
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Enabling NetworkManager failed!"
		exit $res
	fi
	Show 0 "Successfully set up NetworkManager"
} 
##################
# Docker Section #
##################
Install_Docker() {
    Show 2 "Installing \e[33mDocker\e[0m"
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        Show 0 "Current Docker verison is ${Docker_Version}."
    else
        Show 2 "Docker not installed. Installing."
        GreyStart
        ${sudo_cmd} curl -fsSL https://get.docker.com | bash
        if [[ $? -ne 0 ]]; then
            Show 1 "Installation failed, please try again."
            exit 1
        else
            Check_Docker_Install
        fi
    fi
}
Check_Docker_Install() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        Show 0 "Current Docker verison is ${Docker_Version}."
    else
        Show 1 "Installation failed, please uninstall docker"
    fi
}
Uninstall_Docker(){
    sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras -y
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
}
##################
# Finish Section #
##################
Remove_cloudinit(){
    Show 2 "Removing cloud-init"
    GreyStart
    local res
    if [ $(dpkg-query -W -f='${Status}' "cloud-init" 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        Show 0 "cloud-init not installed."
    else
        DEBIAN_FRONTEND=noninteractive apt-get autoremove -q -y --purge cloud-init 
    	res=$?
	    if [[ $res != 0 ]]; then
            Show 1 "Removing cloud-init failed!"
            exit $res
        fi
        Show 0 "cloud-init removed"
        rm -rf /etc/cloud/
        rm -rf /var/lib/cloud/
    fi
}
Remove_snap(){
    Show 2 "Removing snap"
    local res
    local SNAP_LIST
    if [ $(dpkg-query -W -f='${Status}' "snapd" 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        Show 0 "snap not installed"
    else
        GreyStart
        systemctl disable snapd.socket
        systemctl disable snapd.service
        #Getting List of snaps installed - If no snap exists??
        SNAP_LIST=$(snap list | sed '1d' | grep -Eo '^[^ ]+')
        for i in $SNAP_LIST; do
            if [ "${i}" != "core" ] && [ "${i}" != "snapd" ] && [ "${i}" != "core20" ]; then
                snap remove --purge $(echo $i)
            fi
        done
        SNAP_LIST=$(snap list | sed '1d' | grep -Eo '^[^ ]+')
        for i in $SNAP_LIST; do
                snap remove --purge $(echo $i)
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
    echo -e ""
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Cockpit ${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${aCOLOUR[2]}45Drives GitHub : https://github.com/45Drives"
    echo -e ""
    echo -e " ${COLOUR_RESET}${aCOLOUR[1]}Uninstall       ${COLOUR_RESET}: uninstall"
    echo -e "${COLOUR_RESET}"
}

Start
trap 'onCtrlC' INT
Welcome_Banner
Add_repos
Update_System
Check_Reboot
Install_Docker
Install_Packages
#change_renderer 
Remove_cloudinit
Remove_snap
Remove_repo_backup
Initiate_Services
Wrap_up_Banner
Check_Reboot
Show 0 "SETUP COMPLETE"
exit 0

#Ideas
#Script running in full auto or with a grafical checkbox for selection of functions
#htop (saving preferences)
#possibility of rebooting and then resuming the install
#summarize software installed
#progress in script
#detect ports used by services
#resolve pihole port conflict
