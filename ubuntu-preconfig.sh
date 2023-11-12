#!/usr/bin/env bash

###############################################################################
# GLOBAL VARIABLES                                                            #
###############################################################################

((EUID)) && sudo_cmd="sudo"

# shellcheck source=/dev/null
source /etc/os-release

# SYSTEM INFO
LSB_DIST=$([ -n "${ID}" ] && echo "${ID}")
readonly LSB_DIST

DIST=$(echo "${ID}")
readonly DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

INSTALLED=true

readonly COCKPIT_PACKAGES=('cockpit' 'cockpit-navigator' 'cockpit-file-sharing' 'realmd' 'tuned' 'udisks2-lvm2' 'samba' 'winbind' 'nfs-kernel-server' 'nfs-client' 'nfs-common')

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

###################
# Check Functions #
###################

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

prepare() {
	local response
	echo ""
	read -p "Are you sure you want to $*? [y/N]: " response

	case $response in
		[yY]|[yY][eE][sS])
			"$*"
			;;
		*)
			echo "Skipping..."
			;;
	esac

}

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

}

update_system() {
	local res
	Show 2 "UPDATING SYSTEM"
	## Update system
	Show 2 "Updating packages"
	echo ""
	OUTPUT=`apt-get update 2>&1`
	if [[ $? != 0 ]]; then
  		echo "$OUTPUT"
	fi
		GreyStart
    if [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get update
    fi
    ColorReset
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Package update failed!"
		exit $res
	fi
	## Upgrade system
	echo ""
	Show 2 "Upgrading packages"
	echo ""
	GreyStart
	apt-get upgrade -y
    ColorReset
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Package upgrade failed!"
		exit $res
	fi
	echo ""
	Show 0 "Successfully updated system!"
	echo ""
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
    ColorReset
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
	# Use Network Manager instead of systemd-networkd
    GreyStart

    sed '2   renderer: NetworkManager' /etc/netplan/00-networkmanager.yaml

	netplan try
    ColorReset
	res=$?

	if [[ $res != 0 ]]; then
		Show 1 "netplan try failed."
		exit $res
	fi
	GreyStart
	ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

	mv /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf  /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf.backup

	sed -i '/^managed/s/false/true/' /etc/NetworkManager/NetworkManager.conf

	systemctl restart network-manager
    ColorReset
	res=$?

	if [[ $res != 0 ]]; then
		Show 1 "Reloading network-manager failed."
		exit $res
	fi

	Show 2 "Successfully enabled network manager."

	return 0
}

install_cockpit() {

    # Install cockpit and cockpit related things
	local res

    Show 2 "INITIALIZING COCKPIT"

    GreyStart
    # Add the 45 drives repo
    add_45repo
    #curl -sSL https://repo.45drives.com/setup | sudo bash

    for i in "${COCKPIT_PACKAGES[@]}"
    do
    cmd=${COCKPIT_PACKAGES[i]}
        if [[ ! -x $(${sudo_cmd} which "$cmd") ]]; then
            packagesNeeded=${COCKPIT_PACKAGES[i]}
            Show 2 "Install the necessary dependencies: \e[33m$packagesNeeded \e[0m"

            if [ -x "$(command -v apt-get)" ]; then
                ${sudo_cmd} apt-get -y -q install "$packagesNeeded" --no-upgrade
                res=$?
                if [[ $res != 0 ]]; then
		        Show 1 "Instalation  failed!"
		        exit $res
	            fi
            else
                Show 1 "Package manager not found. You must manually install: \e[33m$packagesNeeded \e[0m"
            fi
        fi
    done

    #install sensors modules
    Show 2 "Install the necessary dependencies: \e[33mSensors \e[0m"
    GreyStart
    wget https://github.com/ocristopfer/cockpit-sensors/releases/latest/download/cockpit-sensors.tar.xz
    tar -xf cockpit-sensors.tar.xz cockpit-sensors/dist
    mv cockpit-sensors/dist /usr/share/cockpit/sensors
    rm -r cockpit-sensors
    rm cockpit-sensors.tar.xz
    ColorReset

	# Enabling Cockpit

	systemctl enable --now cockpit.socket

	  res=$?

	  if [[ $res != 0 ]]; then
		  Show 1 "Enabling cockpit.socket failed!"
		  exit $res
  fi

	Show 2 "Successfully initialized Cockpit."

}

#Repo Aux Functions
function get_base_distro() {
        local distro=$(cat /etc/os-release | grep '^ID_LIKE=' | head -1 | sed 's/ID_LIKE=//' | sed 's/"//g' | awk '{print $1}')

        if [ -z "$distro" ]; then
                distro=$(cat /etc/os-release | grep '^ID=' | head -1 | sed 's/ID=//' | sed 's/"//g' | awk '{print $1}')
        fi

        echo $distro
}
function get_distro() {
        local distro=$(cat /etc/os-release | grep '^ID=' | head -1 | sed 's/ID=//' | sed 's/"//g' | awk '{print $1}')

        echo $distro
}
function get_version_id() {
        local version_id=$(cat /etc/os-release | grep '^VERSION_ID=' | head -1 | sed 's/VERSION_ID=//' | sed 's/"//g' | awk '{print $1}' | awk 'BEGIN {FS="."} {print $1}')

        echo $version_id
}



add_45repo(){

euid=$(id -u)

if [ $euid -ne 0 ]; then
        echo -e '\nYou must be root to run this utility.\n'
fi

distro=$(get_base_distro)
custom_distro=$(get_distro)
distro_version=$(get_version_id)


        echo "Detected Debian-based distribution. Continuing..."

        items=$(find /etc/apt/sources.list.d -name 45drives.list)

        if [[ -z "$items" ]]; then
                echo "There were no existing 45Drives repos found. Setting up the new repo..."
        else
                count=$(echo "$items" | wc -l)
                echo "There were $count 45Drives repo(s) found. Archiving..."

                mkdir -p /opt/45drives/archives/repos

                mv /etc/apt/sources.list.d/45drives.list /opt/45drives/archives/repos/45drives-$(date +%Y-%m-%d).list

                echo "The obsolete repos have been archived to '/opt/45drives/archives/repos'. Setting up the new repo..."
        fi

        if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
                rm -f /etc/apt/sources.list.d/45drives.sources
        fi

        echo "Updating ca-certificates to ensure certificate validity..."

        apt update
        apt install ca-certificates -y

        wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg

        res=$?

        if [ "$res" -ne "0" ]; then
                echo "Failed to add the gpg key to the apt keyring. Please review the above error and try again."
                exit 1
        fi

        curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources

        res=$?

        if [ "$res" -ne "0" ]; then
                echo "Failed to download the new repo file. Please review the above error and try again."
                exit 1
        fi

        lsb_release_cs=$(lsb_release -cs)

        if [[ "$lsb_release_cs" == "" ]]; then
                echo "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
                exit 1
        fi

        if [[ "$lsb_release_cs" != "focal" ]] && [[ "$lsb_release_cs" != "bionic" ]]; then
        read -p "You are on an unsupported version of Debian. Would you like to use 'focal' packages? [y/N] " response

                case $response in
                        [yY]|[yY][eE][sS])
                                echo
                                ;;
                        *)
                                echo "Exiting..."
                                exit 1
                                ;;
                esac

                lsb_release_cs="focal"
        fi

        sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources

        res=$?

        if [ "$res" -ne "0" ]; then
                echo "Failed to update the new repo file. Please review the above error and try again."
                exit 1
        fi

        echo "The new repo file has been downloaded. Updating your package lists..."

        pm_bin=apt

        $pm_bin update -y

        res=$?

        if [ "$res" -ne "0" ]; then
                echo "Failed to run '$pm_bin update -y'. Please review the above error and try again."
                exit 1
        fi

        echo "Success! Your repo has been updated to our new server!"

}
##################
# Docker Section #
##################
Install_Docker() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Prepare_Docker
        else
            Show 0 "Current Docker verison is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'curl -fsSL https://get.docker.com | bash' and rerun the CasaOS installation script."
        exit 1
    fi
}
Prepare_Docker() {
    Show 2 "Install the necessary dependencies: \e[33mDocker \e[0m"
    if [[ ! -d "${PREFIX}/etc/apt/sources.list.d" ]]; then
        ${sudo_cmd} mkdir -p "${PREFIX}/etc/apt/sources.list.d"
    fi
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
Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if [[ ! $(${sudo_cmd} systemctl is-active docker) == "active" ]]; then
            Show 1 "Docker is not running, try to start"
            ${sudo_cmd} systemctl start docker
        else
            break
        fi
    done
}
Check_Docker_Install_Final() {
    if [[ -x "$(command -v docker)" ]]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}')
        if [[ $? -ne 0 ]]; then
            Install_Docker
        else
            Show 0 "Current Docker verison is ${Docker_Version}."
            Check_Docker_Running
        fi
    else
        Show 1 "Installation failed, please run 'curl -fsSL https://get.docker.com | bash' and rerun the CasaOS installation script."
        exit 1
    fi
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

prepare update_system

install_cockpit

prepare Install_Docker

#prepare init_network

#prepare change_renderer

#prepare remove_garbage

exit 0
