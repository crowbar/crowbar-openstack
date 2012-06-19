#!/bin/sh

BASE_DIR=$(dirname $(readlink -f $0))


SSH="$(which ssh) -S $(mktemp -u)"
SSH_CREDS=${SSH_CREDS:-$1}

if [ -z "$SSH_CREDS" ]; then
	echo "Missing parameter: admin node SSH credentials"
	exit 1
fi

echo "Connecting to the admin node"
$SSH -M $SSH_CREDS -Nf

echo "Uploading source files"

rsync -e "$SSH ." -rv $BASE_DIR/crowbar_framework/ :/opt/dell/crowbar_framework

echo "Restarting RoR application"

#$SSH . sudo bluepill crowbar-webserver restart

echo "Cleaning up"

$SSH -O exit .
