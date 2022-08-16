#!/bin/bash

usage() {
    cat <<EOF
usage: $0 yubiconf gen-secrets [DIR] [ARGS]
positional arguments:
    DIR             directory to store management key, PIV PIN, and PIV PIN 
                    unlock key
arguments:
    -h, --help      show this dialog
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
if [ ! -d "${1}" ]; then
    read -p 'directory does not exist. create [y/N]:' yn
    if [[ "$yn" == [Yy]* ]]; then
        mkdir -p $1
    else
        echo "exiting..."
        exit 1
    fi
fi

LC_CTYPE=C < /dev/urandom tr -cd '[:xdigit:]' | head -c48 > "${1}/KEY"
LC_CTYPE=C < /dev/urandom tr -cd '[:digit:]' | head -c6 > "${1}/PIN"
LC_CTYPE=C < /dev/urandom tr -cd '[:digit:]' | head -c8 > "${1}/PUK"
