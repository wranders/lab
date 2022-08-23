#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config yubikey init
    generate secrets and apply them
    '/media/YUBISEC' and '/media/ROOTCASEC' are required
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

if [[ ! -d /media/YUBISEC ]] || [[ ! -d /media/ROOTCASEC ]]; then
    echo "both '/media/YUBISEC' and '/media/ROOTCASEC' are required"
    echo "have you mounted the CA storage device?"
    echo "'rootca config host cadata mount <DEV>'"
    exit 1
fi
if [[ ! -w /media/YUBISEC ]] || [[ ! -w /media/ROOTCASEC ]]; then
    echo "'/media/YUBISEC' and '/media/ROOTCASEC' must be writable"
    echo "try reformatting the CA storage device and mounting it"
    echo "'rootca config host cadata format <DEV>' &&"
    echo "'rootca config host cadata mount <DEV>"
    exit 1
fi

. "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")/yubikey-init.sh"
declare DPIN=false DKEY=false

PIVINFO=$(ykman piv info)
echo $PIVINFO | grep 'default PIN' &>/dev/null
if [[ $? -eq 0 ]]; then DPIN=true; fi
echo $PIVINFO | grep 'default Management' &>/dev/null
if [[ $? -eq 0 ]]; then DKEY=true; fi

if [[ $DPIN == false ]] && [[ $DKEY == false ]]; then
    echo "yubikey is not using default credentials"
    echo "reset the device with 'rootca config yubikey reset'"
    exit 1
fi

LC_CTYPE=C
< /dev/urandom tr -cd '[:xdigit:]' | fold -w48 | head -1 > /media/YUBISEC/KEY
< /dev/urandom tr -cd '[:digit:]' | fold -w6 | head -1 > /media/YUBISEC/PIN
cp /media/YUBISEC/PIN /media/ROOTCASEC/PIN
< /dev/urandom tr -cd '[:digit:]' | fold -w8 | head -1 > /media/YUBISEC/PUK

declare KEY PIN PUK
KEY=$(cat /media/YUBISEC/KEY)
PIN=$(cat /media/YUBISEC/PIN)
PUK=$(cat /media/YUBISEC/PUK)

yubico-piv-tool -a set-mgm-key -n $KEY
yubico-piv-tool -a change-pin -P 123456 -k $KEY -N $PIN
yubico-piv-tool -a change-puk -P 12345678 -k $KEY -N $PUK
