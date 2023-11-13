#!/usr/bin/env bash

####################
# Global Variables #
####################
start (){
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

    INSTALLED=true

    readonly COCKPIT_PACKAGES=("cockpit" "cockpit-navigator" "realmd" "tuned" "udisks2-lvm2" "samba" "winbind" "nfs-kernel-server" "nfs-client" "nfs-common" "cockpit-file-sharing")

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

    trap 'onCtrlC' INT

}
start
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
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
#########################
# Start Check Functions #
#########################
Check_Arch() {
    case $UNAME_M in
    *64*)
        TARGET_ARCH="amd64"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"
}
Check_Distribution() {
    sType=0
    notice=""
    case $DIST in
    *ubuntu*) ;;

    *)
        Show 1 "Aborted, installation is only supported in linux ubuntu."
        exit 1
        ;;
    esac
    Show ${sType} "Your Linux Distribution is : ${DIST} ${notice}"
}
Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}
Check_Permissions() {
	interpreter=$(ps -p $$ | awk '$1 != "PID" {print $(NF)}' | tr -d '()')

	if [ "$interpreter" != "bash" ]; then
		Show 1 "Please run with bash. (\`./ubuntu-preconfig.sh\` or \`bash ubuntu-preconfig.sh\`)"
		Show 1 "Current interpreter: $interpreter"
		exit 1
	fi

	euid=$(id -u)

	if [[ "$euid" != 0 ]]; then
		Show 1 "Please run as root or with sudo."
		exit 1
	fi
	Show 0 "Current interpreter: $interpreter"
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
###################
# Script Functions #
###################
welcome() {

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
    echo "" 

    Show 2 "Setting Time Zone"
    timedatectl set-timezone Europe/Lisbon
    T_Z=$(timedatectl show --va -p Timezone)
    echo ""
    Show 0 "Time Zone is ${T_Z}." 
}
update_system() {
	local res
	echo ""
	Show 2 "Updating packages"
	echo ""
	GreyStart
    apt-get update -q -u 
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Package update failed!"
		exit $res
	else
        echo ""
        Show 0 "System successfully updated"
    fi
    echo ""
	Show 2 "Upgrading packages"
    echo ""
	GreyStart
	DEBIAN_FRONTEND=noninteractive apt-get -y --autoremove dist-upgrade
    res=$?
    if [[ $res != 0 ]]; then
		echo ""
        Show 1 "Package upgrade failed!"
		exit $res
	else
        echo ""
        Show 0 "System successfully upgraded"
    fi
}
init_network() {
	local res
	Show 2 "INSTALLING NETWORK MANAGER"
	echo ""
	# Install packages
	GreyStart
	apt-get install -y network-manager
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Installing network manager failed!"
		exit $res
	fi
	systemctl enable --now NetworkManager
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Enabling network manager failed!"
		exit $res
	fi
	echo ""
	Show 0 "Successfully set up network manager"
	echo ""
}
remove_garbage() {
	local res
    Show 2 "REMOVING CLOUD-INIT AND SNAPD"
	# Remove cloud-init
	check_installed "cloud-init"
    GreyStart
	if [ "$INSTALLED"  = true ]; then
    	apt-get autoremove --purge cloud-init -y
    	rm -rf /etc/cloud/
    	rm -rf /var/lib/cloud/

    	res=$?
	   	if [[ $res != 0 ]]; then
			Show 1 "Removing cloud-init failed!"
			exit $res
		fi
	fi
    ColorReset
	# Remove snapd
	check_installed "snapd"
    GreyStart
	if [ "$INSTALLED"=true ]; then
		snap remove--purge lxd
    	snap remove--purge core20
    	snap remove--purge snapd
    	apt-get autoremove --purge snapd -y
    	rm -rf /var/cache/snapd/
    	rm -rf ~/snap

    	res=$?
	    if [[ $res != 0 ]]; then
			Show 1 "Removing snapd failed!"
			exit $res
		fi
	fi
    ColorReset
	Show 0 "Successfully removed cloud-init and snapd."
}
change_renderer() {
	local res
	Show 2 "ENABLING NETWORK MANAGER"
    GreyStart
    yourfilename=`ls /etc/netplan/*.yaml`
    #If there is no config file create one. If there is more than one file it can break
    if [[ -z ${yourfilename} ]]; then
		Show 1 "There isn't a network config file. Creating.."
    cat > /etc/netplan/00-networkmanager.yaml <<EOF
network:
    version: 2
    renderer: NetworkManager
EOF
    else
        rendline=`grep -c -i renderer: networkd`
    	if [[ $rendline = 0 ]]; then
        #if networkd string exist in config file, replace it
            sed -i 's@networkd@NetworkManager@g' /etc/netplan/$yourfilename.yaml
	    else
        #if networkd string doesnt exist in config file, add it
            sed -i '2i   renderer: NetworkManager' /etc/netplan/$yourfilename.yaml
	    fi
    fi
	res=$?
	if [[ $res != 0 ]]; then
		echo ""
        Show 1 "Changing renderer failed."
		exit $res
	else
        Show 0 "Changing renderer sucessful."        
    fi
    #change permissions of file 
    chmod 600 /etc/netplan/*.yaml
    #Test config
	netplan try
	res=$?
	if [[ $res != 0 ]]; then
		Show 1 "netplan try failed."
		exit $res
	fi
    netplan apply

	ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
	mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf  /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup
	sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf
	systemctl restart network-manager
	res=$?
	if [[ $res != 0 ]]; then
		Show 1 "Reloading network-manager failed."
		exit $res
	fi
	Show 2 "Successfully enabled network manager."
	return 0
}
###################
# Cockpit Section #
###################
add_45repo(){
	items=$(find /etc/apt/sources.list.d -name 45drives.list)
	if [[ -z "$items" ]]; then
		Show 2 "There were no existing 45Drives repos found. Setting up the new repo..."
	else
		count=$(echo "$items" | wc -l)
		Show 2 "There were $count 45Drives repo(s) found. Archiving..."
		mkdir -p /opt/45drives/archives/repos
		mv /etc/apt/sources.list.d/45drives.list /opt/45drives/archives/repos/45drives-$(date +%Y-%m-%d).list
		Show 2 "The obsolete repos have been archived to '/opt/45drives/archives/repos'. Setting up the new repo..."
	fi
	if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
		rm -f /etc/apt/sources.list.d/45drives.sources
	fi
    echo ""
	Show 2 "Updating ca-certificates to ensure certificate validity..."
    echo ""    
    GreyStart
	apt-get update -q
	apt-get install ca-certificates -y
	wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to add the gpg key to the apt keyring. Please review the above error and try again."
		exit 1
	else
        Show 0 "gpg key added"
    fi
    curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to download the new repo file. Please review the above error and try again."
		exit 1
	else
        Show 0 "repo file downloaded"
	fi
	lsb_release_cs=$(lsb_release -cs)
	if [[ "$lsb_release_cs" == "" ]]; then
		Show 1 "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
		exit 1
	else
        Show 0 "distribution codename fetched"
	fi
	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to update the new repo file. Please review the above error and try again."
		exit 1
	else
        Show 0 "repo file updated fetched"
	fi
	echo ""
    Show 0 "Success! Your repo has been updated to our new server!"
}
install_cockpit() {
	local res
	echo ""
    Show 2 "INSTALLING COCKPIT"
    echo ""
    Show 2 "Adding the necessary repository sources"
    echo ""   
    add_45repo
    Show 2 "Installing cockpit modules"
    echo ""   
    for ((i = 0; i < ${#COCKPIT_PACKAGES[@]}; i++)); do
        packagesNeeded=${COCKPIT_PACKAGES[i]}
        echo ""
        Show 2 "Install the necessary dependencies: \e[33m$packagesNeeded \e[0m"
        echo ""
        GreyStart
        PKG_OK=$(dpkg-query -W --showformat='${Status}\n'$packagesNeeded|grep "install ok installed")
        if [ "" = "$PKG_OK" ]; then
            Show 2 "No $packagesNeeded. Setting up $packagesNeeded."
            #DEBIAN_FRONTEND=noninteractive apt-get -y -q install "$packagesNeeded" --no-upgrade --show-progress
            DEBIAN_FRONTEND=noninteractive apt-get -y install "$packagesNeeded" --no-upgrade --show-progress
            res=$?
            if [[ $res != 0 ]]; then
                echo ""
                Show 1 "Instalation  failed!"
                exit $res
            else
                echo ""
                Show 0 "\e[33m$packagesNeeded\e[0m installed"               
            fi
        else
            Show 0 "\e[33m$packagesNeeded\e[0m already installed"
        fi
    done

    #install sensors modules
    echo ""
    Show 2 "Install the necessary dependencies: \e[33mSensors \e[0m"
    echo ""
    GreyStart
    wget -q https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz --show-progress
    tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
    cp -r cockpit-sensors/dist /usr/share/cockpit/sensors
    rm -r cockpit-sensors
    rm cockpit-sensors.tar.xz
    ColorReset

	# Enabling Cockpit
	DEBIAN_FRONTEND=noninteractive systemctl enable --now cockpit.socket
    res=$?
    if [[ $res != 0 ]]; then
        Show 1 "Enabling cockpit.socket failed!"
        exit $res
    fi
    echo ""
	Show 0 "Successfully initialized Cockpit."

}
##################
# Docker Section #
##################
Check_Docker_Install() {
    echo ""
    Show 2 "INSTALLING DOCKER"
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            echo ""
            Show 2 "Docker not installed. Installing."
            Install_Docker
        elif [[ ${Docker_Version:0:2} -lt "${MINIMUM_DOCER_VERSION}" ]]; then
            echo ""
            Show 1 "Recommended minimum Docker version is \e[33m${MINIMUM_DOCER_VERSION}.xx.xx\e[0m,\Current Docker verison is \e[33m${Docker_Version}\e[0m,\nPlease uninstall current Docker."
            exit 1
        else
            echo ""
            Show 0 "Current Docker verison is ${Docker_Version}."
        fi
    else
        echo ""
        Show 2 "Docker not installed. Installing."
        echo ""
        Install_Docker
    fi
}
Install_Docker() {
    GreyStart
        ${sudo_cmd} curl -fsSL https://get.docker.com | bash
    ColorReset
    if [[ $? -ne 0 ]]; then
        echo ""
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

Welcome_Banner() {
    CASA_TAG=$(casaos -v)

    echo -e "${GREEN_LINE}${aCOLOUR[1]}"
    echo -e " CasaOS ${CASA_TAG}${COLOUR_RESET} is running at${COLOUR_RESET}${GREEN_SEPARATOR}"
    echo -e "${GREEN_LINE}"
    Get_IPs
    echo -e " Open your browser and visit the above address."
    echo -e "${GREEN_LINE}"
    echo -e ""
    echo -e " ${aCOLOUR[2]}CasaOS Project  : https://github.com/IceWhaleTech/CasaOS"
    echo -e " ${aCOLOUR[2]}CasaOS Team     : https://github.com/IceWhaleTech/CasaOS#maintainers"
    echo -e " ${aCOLOUR[2]}CasaOS Discord  : https://discord.gg/knqAbbBbeX"
    echo -e " ${aCOLOUR[2]}Website         : https://www.casaos.io"
    echo -e " ${aCOLOUR[2]}Online Demo     : http://demo.casaos.io"
    echo -e ""
    echo -e " ${COLOUR_RESET}${aCOLOUR[1]}Uninstall       ${COLOUR_RESET}: casaos-uninstall"
    echo -e "${COLOUR_RESET}"
}

welcome
update_system
Check_Docker_Install
install_cockpit
#change_renderer
# init_network
# remove_garbage

exit 0