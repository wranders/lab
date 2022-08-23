#!/bin/bash

usage() {
    cat <<EOF
usage: rootca sign <ARGUMENTS>
arguments:
    -h,--help
    -i,--in
    -o,--out
EOF
}

if [ $# -eq 0 ]; then usage; exit 0; fi
OPTSLONG="help,in:,out:"
OPTSSHORT="hi:o:"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare CSRIN CRTOUT
while true; do
    case $1 in
        -i|--in)        shift; CSRIN=$(realpath $1) ;;
        -o|--out)       shift; CRTOUT=$(realpath $1) ;;
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

eval "openssl ca -config openssl.cnf -engine pkcs11 -keyform engine \
        -passin file:/media/ROOTCASEC/PIN -extensions issuing_ca_ext \
        -in ${CSRIN} -out ${CRTOUT}"
RC=$?
popd >/dev/null
exit $RC
