#!/bin/bash

declare PCSCD_RUNNING=$(ps aux | grep [p]cscd)
if [[ -z "$PCSCD_RUNNING" ]]; then
    echo "starting pcscd"
    pcscd --debug --apdu
    pcscd --hotplug
fi

declare DBUS_DAEMON_RUNNING=$(ps aux | grep [d]bus-daemon)
if [[ -z "$DBUS_DAEMON_RUNNING" ]]; then
    echo "starting dbus-daemon"
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf
fi