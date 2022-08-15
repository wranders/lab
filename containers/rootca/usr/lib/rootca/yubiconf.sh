#!/bin/bash

usage() {
    cat <<EOF
usage: $0 yubiconf [CMD]
commands:
    gen-secrets     create new Yubikey management key, PIV PIN, and PIV PIN
                    unlock key
    set-secrets     set Yubikey management key, PIV PIN, and PIV PIN unlock key
    otp             enable/disable OTP functionality
    serial          enabled/disable serial number USB visibility
    import-key      import private key
arguments:
    -h, --help      show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
case "$1" in
    gen-secrets)    shift; /usr/lib/rootca/yubiconf_gen-secrets.sh "$@" ;;
    set-secrets)    shift; /usr/lib/rootca/yubiconf_set-secrets.sh "$@" ;;
    otp)            shift; /usr/lib/rootca/yubiconf_otp.sh "$@" ;;
    serial)         shift; /usr/lib/rootca/yubiconf_serial.sh "$@" ;;
    import-key)     shift; /usr/lib/rootca/yubiconf_import-key.sh "$@" ;;
    *)
        OPTS=$(getopt -l "help" -o "h" -a -- "$@")
        eval set -- "$OPTS"
        while [[ -n $1 ]]; do
            case "$1" in
                -h|--help)  usage; exit 0 ;;
                --)         shift; break;
            esac; shift
        done
        echo "unknown command '${1}'"; usage; exit 1
esac