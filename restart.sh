#!/bin/bash

NAS_IP="192.168.1.65"
LOCAL_MOUNT="/home/miguelmariz"
SERVER_PATH="/volume2/Server"

containers(){
    CONTAINERS=$(docker ps --format='{{.Names}}' --filter "status=exited")
    for container in $CONTAINERS
    do
        echo "Starting Docker Container - $container"
        docker start "$container" > /dev/null
	res=$?
	if [[ $res != 0 ]]; then
	    echo "ERROR! Docker container $container not started"
        return $res
    else
	    echo "Docker container $container successfully started!"
	fi
    done
    echo "All containers started"
    return 0
}

echo "Mounting details:
Server Address - $NAS_IP
Local Mount Point - $LOCAL_MOUNT
Path on Server - $SERVER_PATH"

if ping -c 1 "$NAS_IP" &> /dev/null; then
    echo "Setting up the NFS mount"
    mount -t nfs "$NAS_IP":"$SERVER_PATH" "$LOCAL_MOUNT"/docker
    if [[ $(findmnt -M "$LOCAL_MOUNT"/docker) ]]; then
        echo "NFS mounted. Starting docker containers"
        containers
    else
        echo "error mounting NFS"
        exit 1
    fi
else
    echo "$NAS_IP not available!"
    exit 1
fi