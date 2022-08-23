#!/bin/bash

usage() {
    cat <<EOF
usage: rootca crl <COMMAND> <ARGUMENT>
commands:
    new         create a new certificate revocation list
    revoke      revoke a certificate
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
USR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
case $1 in
    new)    shift; $USR/crl-new.sh "$@";;
    revoke) shift; $USR/crl-revoke.sh "$@" ;;
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
