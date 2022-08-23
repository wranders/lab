#!/bin/bash

usage() {
    cat <<EOF
usage: rootca crl new <ARGUMENT>
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
        -h|--help)      usage; exit 0 ;;
        --)             shift; break ;;
    esac; shift
done

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
    -passin file:/media/ROOTCASEC/PIN -gencrl -out crl/root_ca.crl.pem
RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi

openssl crl -in crl/root_ca.crl.pem -outform der -out crl/root_ca.crl

popd >/dev/null
