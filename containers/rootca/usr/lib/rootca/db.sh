#!/bin/bash

usage() {
    cat <<EOF
usage: rootca crl <COMMAND> <ARGUMENT>
commands:
    search      search the CA database
    update      set any valid certificates in the database that have expired
                as expired
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
case $1 in
    search)
        shift
        grep -iE "$@" /media/ROOTCA/db/root_ca.db | \
            cut -f 1,4,6 --output-delimiter='$' | \
            column -t -s '$' -N STATUS,SERIAL,DN -W DN
        ;;
    update)
        if [[ ! -d /media/ROOTCA ]] || [[ ! -d /media/ROOTCASEC ]]; then 
            echo "'/media/ROOTCA' and '/media/ROOTCASEC' directories are required"
            exit 1
        fi
        if [[ ! -w /media/ROOTCA ]]; then
            echo "'/media/ROOTCA' directory is not writable"
            exit 1
        fi
        if [[ ! -f /media/ROOTCASEC/PIN ]]; then
            echo "'/media/ROOTCASEC/PIN' does not exist and is required"
            exit 1
        fi
        if [[ ! -r /media/ROOTCASEC/PIN ]]; then
            echo "'/media/ROOTCASEC/PIN' is not readable"
            exit 1
        fi
        . "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")/yubikey-init.sh"
        ykman piv info 1>/dev/null
        if [[ $? -ne 0 ]]; then 
            echo "there was an error detecting a Yubikey device"
            exit 1
        fi
        ykman piv certificates export 9a - 1>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "there was an error detecting an installed certificate"
            echo "is Yubikey initialized?"
            exit 1
        fi
        pushd /media/ROOTCA >/dev/null
        openssl ca -config openssl.cnf -engine pkcs11 -keyform engine \
            -passin file:/media/ROOTCASEC/PIN -updatedb
        RC=$?
        popd >/dev/null
        exit $RC
        ;;
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
