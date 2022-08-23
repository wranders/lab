#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config <COMMAND> <ARGUMENT>
commands:
    deploy      configure Root CA deployment
    init        initialize a new Root CA
    host        return host configuration scripts
    yubikey     configure Yubikey device
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
USR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
case $1 in
    deploy)     shift; $USR/config-deploy.sh "$@" ;;
    init)       shift; $USR/config-init.sh "$@" ;;
    host)       shift; $USR/config-host.sh "$@" ;;
    yubikey)    shift; $USR/config-yubikey.sh "$@" ;;
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