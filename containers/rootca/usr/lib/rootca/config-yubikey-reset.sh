#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config yubikey reset
    reset the PIV application on a Yubikey
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
ykman piv reset
