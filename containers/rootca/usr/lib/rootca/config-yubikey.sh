#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata <COMMAND> <ARGUMENT>
commands:
    init
    otp
    reset
    serial
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
USR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
case $1 in
    init)   shift; $USR/config-yubikey-init.sh "$@";;
    otp)    shift; $USR/config-yubikey-otp.sh "$@" ;;
    reset)  shift; $USR/config-yubikey-reset.sh "$@" ;;
    serial) shift; $USR/config-yubikey-serial.sh "$@" ;;
    *)
        OPTS=$(getopt -l "help" -o "h" -a -- "$@")
        eval set -- "$OPTS"
        while true; do
            case $1 in
                -h|--help)  usage; exit 0 ;;
                --)         shift; break ;;
            esac; shift
        done
        echo "unknown command '$1'"; usage; exit 1 ;;
esac