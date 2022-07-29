#!/bin/bash

sudo pcscd --debug --apdu
sudo pcscd --hotplug

sudo dbus-daemon --config-file=/usr/share/dbus-1/system.conf

"$@"
