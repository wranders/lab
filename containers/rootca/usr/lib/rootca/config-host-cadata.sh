#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata <COMMAND> <ARGUMENT>
commands:
    format      format a block device for use as Root CA data and secret storage
    mount       mount Root CA data device
    unmount     unmount Root CA data device
    sync        syncronize two Root CA block devices
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
USR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
case $1 in
    format)     shift; $USR/config-host-cadata-format.sh "$@" ;;
    mount)      shift; $USR/config-host-cadata-mount.sh "$@" ;;
    unmount)    shift; $USR/config-host-cadata-unmount.sh "$@" ;;
    sync)       shift; $USR/config-host-cadata-sync.sh "$@" ;;
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