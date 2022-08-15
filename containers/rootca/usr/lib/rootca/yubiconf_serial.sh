#!/bin/bash

usage() {
    cat <<EOF
usage: $0 yubiconf serial [enable|disable]
positional arguments:
    enable      set serial number to be visible to usb host
    disable     set serial number to not be visible to usb host
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -ne 1 ]; then usage; exit 1; fi
OPTS=$(getopt -l "help" -o "h" -a -- "$@")
eval set -- "$OPTS"
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        --)         shift; break ;;
    esac; shift
done
/usr/lib/rootca/yubikey-init.sh
case "$1" in
    enable)     ykpersonalize -vu1y -o serial-usb-visible ;;
    disable)    ykpersonalize -vu1y -o -serial-usb-visible ;;
    *)          echo "unknown OTP state '${1}'"; usage; exit 1 ;;
esac