#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config yubikey serial [enable|disable]
    set the visibility of the yubikey serial number over USB
arguments:
    -h,--help   show this dialog
EOF
}

OPTSLONG="help"
OPTSSHORT="h"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
while true; do
    case $1 in
        -h,--help)      usage; exit 0 ;;
        --)             shift; break ;;
    esac; shift
done

. "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")/yubikey-init.sh"
case $1 in
    enable)
        ykpersonalize -vu1y -o serial-usb-visible -o serial-api-visible ;;
    disable)
        ykpersonalize -vu1y -o -serial-usb-visible -o -serial-api-visible ;;
    *)
        echo "unknown OTP state '${1}'"; usage; exit 1 ;;
esac