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