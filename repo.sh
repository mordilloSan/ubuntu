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

euid=$(id -u)

if [ $euid -ne 0 ]; then
	echo -e '\nYou must be root to run this utility.\n'
fi

distro=$(get_base_distro)
custom_distro=$(get_distro)
distro_version=$(get_version_id)

if [ "$distro" == "debian" ]; then
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

	apt-get update
	apt-get install ca-certificates -y

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

	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources

	res=$?

	if [ "$res" -ne "0" ]; then
		echo "Failed to update the new repo file. Please review the above error and try again."
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

fi
