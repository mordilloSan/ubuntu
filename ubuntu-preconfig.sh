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
    readonly PACKAGES=("cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-common" "cockpit-file-sharing")
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
    TARGET_ARCH=""
}
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
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
        TARGET_ARCH="amd64"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: \e[33m$UNAME_M\e[0m"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : \e[33m$UNAME_M\e[0m"
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
	Show 0 "Current interpreter: \e[33m$interpreter\e[0m"
}
check_installed() {
	if dpkg-query -W -f'${db:Status-Abbrev}\n' $* 2>/dev/null \
 | grep -q '^.i $'; then
    	Show 2 "$* is Installed"
		INSTALLED=true
	else
    	Show 2 "$* is Not installed"
		INSTALLED=false
	fi
}
Check_Connection(){
    internet=$(wget -q --spider http://google.com ; echo $?)
    if [ "$internet" != 0 ]; then
		Show 1 "Can not reach the internet"
		exit 1
    fi
    Show 0 "Internet \e[33mOnline\e[0m"
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
	echo "This will update the system, remove cloud-init and snapd,
 replace systemd-networkd with network-manager, install cockpit,
 add 45Drives repository, remove cloud-init and snapd, install docker and portainer."
	echo ""
    echo "This script should *not* be run in an SSH session, as the network will be
 modified and you may be disconnected. Run this script from the console or IPMI
 remote console."
	echo ""
	Check_Arch
	Check_OS
	Check_Distribution
	Check_Permissions
    Check_Connection
    echo "" 
    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
     Show 0 "Time Zone is ${T_Z}." 
    #setting a standard working Directory
    cd /home
}
Update_System() {
	local res
	Show 2 "Updating packages"
	GreyStart
    apt-get update -q -u 
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Package update failed!"
		exit $res
	else
        Show 0 "System successfully updated"
    fi
	Show 2 "Upgrading packages"
	GreyStart
	DEBIAN_FRONTEND=noninteractive apt-get -y --autoremove dist-upgrade
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
init_network() {
	local res
	Show 2 "Installing \e[33mNetworkManager\e[0m"
	# Install packages
	GreyStart
	DEBIAN_FRONTEND=noninteractive apt-get install -y -q=2 network-manager
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Installing NetworkManager failed!"
		exit $res
	fi
	systemctl enable --now NetworkManager
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Enabling NetworkManager failed!"
		exit $res
	fi
	Show 0 "Successfully set up NetworkManager"
}
###################
# Cockpit Section #
###################
Add_45repo(){
	items=$(find /etc/apt/sources.list.d -name 45drives.sources)
	if [[ -z "$items" ]]; then
        echo -e "${aCOLOUR[2]}There were no existing 45Drives repos found. Setting up the new repo..."
	else
        count=$(echo "$items" | wc -l)
        echo -e "${aCOLOUR[2]}There were $count 45Drives repo(s) found. Archiving..."
		mkdir -p /opt/45drives/archives/repos
		mv /etc/apt/sources.list.d/45drives.sources /opt/45drives/archives/repos/45drives-$(date +%Y-%m-%d).list
		echo -e "${aCOLOUR[2]}The obsolete repos have been archived to '/opt/45drives/archives/repos'. Setting up the new repo..."
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
    apt-get update -q=2
    DEBIAN_FRONTEND=noninteractive apt-get -q=2 -y --autoremove dist-upgrade 
}
Install_Cockpit() {
	local res
    Show 2 "Installing \e[33mCockpit\e[0m"
    Show 2 "Adding the necessary repository sources"
    Add_45repo
    Show 2 "Installing cockpit modules"
    for ((i = 0; i < ${#PACKAGES[@]}; i++)); do
        packagesNeeded=${PACKAGES[i]}
        Show 2 "Prepare the necessary dependencies: \e[33m$packagesNeeded\e[0m"
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
    Show 2 "Prepare the necessary dependencies: \e[33msensors\e[0m"
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
	# Enabling Cockpit
	DEBIAN_FRONTEND=noninteractive systemctl enable --now cockpit.socket
    res=$?
    if [[ $res != 0 ]]; then
        Show 1 "Enabling cockpit.socket failed!"
        exit $res
    fi
	Show 0 "Successfully initialized Cockpit."
}
##################
# Docker Section #
##################
Check_Docker_Install() {
    Show 2 "Installing \e[33mDocker\e[0m"
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Show 2 "Docker not installed. Installing."
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCER_VERSION}.xx.xx\e[0m,\Current Docker verison is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker."
            exit 1
        else
            Show 0 "Current Docker verison is ${Docker_Version}."
        fi
    else
        Show 2 "Docker not installed. Installing."
        Install_Docker
    fi
}
Install_Docker() {
    GreyStart
        ${sudo_cmd} curl -fsSL https://get.docker.com | bash
    ColorReset
    if [[ $? -ne 0 ]]; then
        Show 1 "Installation failed, please try again."
        exit 1
    else
        Check_Docker_Install_Final
    fi
}
Check_Docker_Install_Final() {
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
    local teste
    if [ $(dpkg-query -W -f='${Status}' "snapd" 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        Show 2 "snap not installed"
    else
        #Getting List of snaps installed - Ip no snap exists??
        #stop have to stop snap.service?
        GreyStart
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
        snap remove --purge core
        snap remove --purge core20
        snap remove --purge snapd
        rm -rf /var/cache/snapd/
        DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge snapd -y
        rm -rf ~/snap
        Show 0 "snap removed"
    fi

}
Wrapup_Banner() {
    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " Cockpit ${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    systemctl status cockpit.socket
    echo -e ""
    echo -e " ${aCOLOUR[2]}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${aCOLOUR[2]}45Drives GitH   : https://github.com/45Drives"
    echo -e ""
    echo -e " ${COLOUR_RESET}${aCOLOUR[1]}Uninstall       ${COLOUR_RESET}: casaos-uninstall"
    echo -e "${COLOUR_RESET}"
}
Remove_repo_backup(){
    Show 2 "Just a test Funcion"
    return 0
}

Start
trap 'onCtrlC' INT
Welcome_Banner
Update_System
init_network
# change_renderer
Check_Docker_Install
Install_Cockpit
Remove_cloudinit
Remove_snap
Wrapup_Banner

#Ideas
#Script running in full auto or with a grafical checkbox for selection of functions
#installing everyday tools - htop (saving preferences)
#possibility of rebooting and then resuming the install
#summarize software installed
#detect ports used by services
#resolve pihole port conflict
#change defaults behaviour of "ls" to "ls -l"

exit 0