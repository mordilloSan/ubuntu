#!/bin/bash

	items=$(find /etc/apt/sources.list.d -name 45drives.sources)
	if [[ -z "$items" ]]; then
		echo "There were no existing 45Drives repos found. Setting up the new repo..."
	else
		count=$(echo "$items" | wc -l)
		echo "There were $count 45Drives repo(s) found. Archiving..."
		mkdir -p /opt/45drives/archives/repos
		mv /etc/apt/sources.list.d/45drives.sources /opt/45drives/archives/repos/45drives-$(date +%Y-%m-%d).list
		echo "The obsolete repos have been archived to '/opt/45drives/archives/repos'. Setting up the new repo..."
		if [[ -f "/etc/apt/sources.list.d/45drives.sources" ]]; then
			rm -f /etc/apt/sources.list.d/45drives.sources
		fi
	fi
	echo "Updating ca-certificates to ensure certificate validity..."
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
	if [[ "$lsb_release_cs" == "" ]]; then
		echo "Failed to fetch the distribution codename. This is likely because the command, 'lsb_release' is not available. Please install the proper package and try again. (apt install -y lsb-core)"
		exit 1
	fi
#	if [[ "$lsb_release_cs" != "focal" ]] && [[ "$lsb_release_cs" != "bionic" ]]; then
#	read -p "You are on an unsupported version of Debian. Would you like to use 'focal' packages? [y/N] " response
#
#		case $response in
#			[yY]|[yY][eE][sS])
#				echo
#				;;
#			*)
#				echo "Exiting..."
#				exit 1
#				;;
#		esac
#
#		lsb_release_cs="focal"
#	fi
	sed -i "s/focal/$lsb_release_cs/g" /etc/apt/sources.list.d/45drives.sources
	res=$?
	if [ "$res" -ne "0" ]; then
		echo "Failed to update the new repo file. Please review the above error and try again."
		exit 1
	fi
	echo "The new repo file has been downloaded."
	echo "Success! Your repo has been updated to our new server!"