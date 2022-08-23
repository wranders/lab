#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config yubikey otp [enable|disable]
    set the state of the OTP application
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
    enable) ykman config usb --enable OTP --force ;;
    disable) ykman config usb --disable OTP --force ;;
    *)
        echo "unknown OTP state '${1}'"
        usage
        exit 1 ;;
esac
