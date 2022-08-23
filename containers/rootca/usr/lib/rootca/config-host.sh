#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host <COMMAND> <ARGUMENT>
    print scripts to run on the host. intended to be piped into bash
commands:
    selinux     SELinux policy to allow containers to mount USB devices
    udev        udev rule to create symbolic links to Yubikey devices in '/dev'
    cadata      manage CA storage devices
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
USR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
case $1 in
    selinux)    shift; $USR/config-host-selinux.sh "$@";;
    udev)       shift; $USR/config-host-udev.sh "$@" ;;
    cadata)     shift; $USR/config-host-cadata.sh "$@" ;;
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
