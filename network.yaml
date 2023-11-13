	#Setting the repo
    items=$(find /etc/apt/sources.list.d -name 45drives.list)
	if [[ -z "$items" ]]; then
		echo "There were no existing 45Drives repos found. Setting up the new repo..."
	else
		count=$(echo "$items" | wc -l)
		echo "There were $count 45Drives repo(s) found. Archiving..."
		mkdir -p /opt/45drives/archives/repos
		mv /etc/apt/sources.list.d/45drives.list /opt/45drives/archives/repos/45drives-$(date +%Y-%m-%d).list
		Show 3 "The obsolete repos have been archived to '/opt/45drives/archives/repos'. Setting up the new repo..."
	fi
	if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
		rm -f /etc/apt/sources.list.d/45drives.sources
	fi
	#Setting the certificates
	echo "Updating ca-certificates to ensure certificate validity..."
	apt-get install ca-certificates -y
	wget -qO - https://repo.45drives.com/key/gpg.asc | gpg --pinentry-mode loopback --batch --yes --dearmor -o /usr/share/keyrings/45drives-archive-keyring.gpg
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to add the gpg key to the apt keyring. Please review the above error and try again."
		exit 1
	fi
	#Downloading the repo
	curl -sSL https://repo.45drives.com/lists/45drives.sources -o /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to download the new repo file. Please review the above error and try again."
		exit 1
	fi
	#Updating the repo
	lsb_release_cs=$(lsb_release -cs)
	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		Show 1 "Failed to update the new repo file. Please review the above error and try again."
		exit 1
	fi
	#Updating system
	echo "The new repo file has been downloaded. Updating your package lists..."
    apt-get update -q -u 
    res=$?
    if [[ $res != 0 ]]; then
		Show 1 "Package update failed!"
		exit $res
    fi
	Show 0 "Success! Your repo has been updated to our new server!"

