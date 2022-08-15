#!/bin/bash

usage() {
    cat <<EOF
usage: $0 yubiconf otp [enable|disable]
positional arguments:
    enable      enable one-time password touch action
    disable     disable one-time password touch action
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -ne 1 ]; then _yubiconf_otp_usage; exit 1; fi
OPTS=$(getopt -l "help" -o "h" -a -- "$@")
eval set -- "$OPTS"
while true; do
    case $1 in
        -h|--help)  _yubiconf_otp_usage; exit 0 ;;
        --)         shift; break ;;
    esac; shift
done
/usr/lib/rootca/yubikey-init.sh
case "$1" in
    enable) ykman config usb --enable OTP --force ;;
    disable) ykman config usb --disable OTP --force ;;
    *)
        echo "unknown OTP state '${1}'"
        _yubiconf_otp_usage
        exit 1 ;;
esac