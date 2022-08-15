#!/bin/bash

usage() {
    cat <<EOF
usage: $0 import-key [ARGS]
arguments:
    -h,--help       show this dialog
    -s,--slot       PIV slot to install key to (required)
    -k,--key        private key file (required)
    -m,--mgmt       management key file (required)
    -p,--pin        PIV PIN file (required)
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTS=$(getopt -l "help,slot:,key:,mgmt:,pin:" -o "hs:k:m:p:" -a -- "$@")
eval set -- "$OPTS"
declare SLOT KEY MGMT PIN
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        -s|--slot)  shift; SLOT=$1 ;;
        -k|--key)   shift; KEY=$1 ;;
        -m|--mgmt)  shift; MGMT=$1 ;;
        -p|--pin)   shift; PIN=$1 ;;
        --)         shift; break ;;
    esac; shift
done
# if [[ -z $SLOT ]] || [[ -z $KEY ]] || [[ -z $MGMT ]] || [[ -z $PIN ]]; then
if [[ -z $SLOT ]] || [[ -z $KEY ]] || [[ -z $MGMT ]]; then
    echo 'missing required arguments'; usage; exit 1;
fi
if [[ ! -r "$KEY" ]]; then echo "'${KEY}' does not exist"; usage; exit 1; fi
if [[ ! -r "$MGMT" ]]; then echo "'${MGMT}' does not exist"; usage; exit 1; fi
/usr/lib/rootca/yubikey-init.sh

yubico-piv-tool -a import-key -s $SLOT -k$(cat $MGMT) \
    -i <(openssl pkcs8 -topk8 -nocrypt -in $KEY)

# ykman piv keys import -m $(cat $MGMT) -P $(cat $PIN) $SLOT $KEY && \
#     echo "key import successful"