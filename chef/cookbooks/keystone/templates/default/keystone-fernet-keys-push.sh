#!/bin/sh
TARGETNODE=$1
shift
RSYNC_ARGS=$@
test -z "$TARGETNODE" && { echo "usage: $0 <node-address> [extra rsync args]"; exit 1; }
rsync -a --timeout=300 --delete-after $RSYNC_ARGS /etc/keystone/fernet-keys $TARGETNODE:/etc/keystone/
