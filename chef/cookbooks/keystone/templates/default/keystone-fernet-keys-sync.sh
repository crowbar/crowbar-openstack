#!/bin/sh
if [ -z "$CRM_alert_version" ]; then
    echo "$0 must be run by Pacemaker version 1.1.15 or later"
    exit 0
fi

# skip if alert is not triggered by node joining event
[ "$CRM_alert_kind" = "node" -a "$CRM_alert_desc" = "member" ] || exit 0

myname=$(uname -n)

# skip if triggered on the re-joining node itself
[ "$CRM_alert_node" = "$myname" ] && exit 0

# sleep some random time (0-10s) to avoid all nodes hitting the new one at the same time
sleep $(( $RANDOM % 11 ))

# push keys to the joining node
sudo /usr/bin/keystone-fernet-keys-push.sh $CRM_alert_node --ignore-existing
