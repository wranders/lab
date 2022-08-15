#!/bin/bash

usage() {
    cat <<EOF
usage: $0 yubiconf set-secrets [ARGS]
arguments:
    -h, --help  show this dialog
    -k, --key   Yubikey Management Key (required)
    -p, --pin   Yubikey PIV PIN (required)
    -u, --puk   Yubikey PIN Unlock Key (required)
EOF
}

OPTS=$(getopt -l "help,key:,pin:,puk:" -o "hk:p:u:" -a -- "$@")
eval set -- "$OPTS"
declare KEY PIN PUK
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        -k|--key)   shift; KEY=$1 ;;
        -p|--pin)   shift; PIN=$1 ;;
        -u|--puk)   shift; PUK=$1 ;;
        --)         shift; break ;;
    esac; shift
done
if [[ -z $KEY ]] || [[ -z $PIN ]] || [[ -z $PUK ]]; then
    echo 'missing required arguments'; usage; exit 1;
fi
/usr/lib/rootca/yubikey-init.sh
ykman piv reset
yubico-piv-tool -a set-mgm-key -n $(cat ${KEY})
yubico-piv-tool -k $(cat ${KEY}) -a change-pin -P 123456 -N $(cat ${PIN})
yubico-piv-tool -k $(cat ${KEY}) -a change-puk -P 12345678 -N $(cat ${PUK})