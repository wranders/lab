#!/bin/bash

usage() {
    cat <<EOF
usage: $0 genpkey [ARGS]
    $0 genpkey -a ec -l 384 -out ./ca.key
    $0 genpkey -a rsa -l 3072
    $0 genpkey -a ec -l 384 --yubikey -s 9a -m 01..23 -p 123456
arguments:
    -h,--help       show this dialog
    -a, --algo      private key algorithm (ec, rsa) (required)
    -l, --length    length of the key in bits (required)
                    Yubikey sizes are restricted to:
                    RSA - 1024,2048
                    EC  - 256,384 (NIST P-Curves)
    --nocrypt       do not password protect private key (default: false)
    --pkcs8         output encrypted key in PKCS#8 format instead of PKCS#1
    -o, --out       output file location
    --yubikey       generate private key on Yubikey device
    -s, --slot      Yubikey slot to generate the key
                    9a - PIN can be provided programmatically
                    9c - PIN is always required
    -m, --mgmt      Yubikey management key file
    -p, --pin       Yubikey PIV PIN file
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG="help,algo:,length:,nocrypt,pkcs8,out:,yubikey,slot:,mgmt:,pin:"
OPTSSHORT="ha:l:o:s:m:p:"
OPTS=$(getopt -l "${OPTSLONG}" -o "${OPTSSHORT}" -a -- "$@")
eval set -- "$OPTS"
declare PKEYALGO PKEYLEN PKEYCRYPT=true PKEYOUT PKEYYUBIKEY=false
declare PKEYYUBIKEYSLOT PKEYYUBIKEYMGMT PKEYYUBIKEYPIN PKEYPKCS8=false
while true; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -a|--algo)      shift; PKEYALGO=$1 ;;
        -l|--length)    shift; PKEYLEN=$1 ;;
        --nocrypt)      PKEYCRYPT=false ;;
        --pkcs8)        PKEYPKCS8=true ;;
        -o|--out)       shift; PKEYOUT=$1 ;;
        --yubikey)      PKEYYUBIKEY=true ;;
        -s|--slot)      shift; PKEYYUBIKEYSLOT=$1 ;;
        -m|--mgmt)      shift; PKEYYUBIKEYMGMT=$1 ;;
        -p|--pin)       shift; PKEYYUBIKEYPIN=$1 ;;
        --)             shift; break ;;
    esac; shift
done
if [[ -z $PKEYALGO ]] || [[ -z $PKEYLEN ]]; then
    echo "missing required arguments"
    usage; exit 1
fi
if [[ $PKEYALGO != "ec" ]] && [[ $PKEYALGO != "rsa" ]]; then
    echo "unknown algorithm"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ -z $PKEYYUBIKEYMGMT ]]; then
    echo "Yubikey management key file must be specified"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ ! -r $PKEYYUBIKEYMGMT ]]; then
    echo "'${PKEYYUBIKEYMGMT}' does not exist or is not readable"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ -z $PKEYYUBIKEYPIN ]]; then
    echo "Yubikey PIN file must be specified"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ ! -r $PKEYYUBIKEYPIN ]]; then
    echo "'${PKEYYUBIKEYPIN}' does not exist or is not readable"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ -z $PKEYYUBIKEYSLOT ]]; then
    echo "Yubikey slot must be specified"
    usage; exit 1
fi
if [[ $PKEYYUBIKEY == true ]] && [[ ! -z $PKEYOUT ]]; then
    echo "'yubikey' and 'out' arguments are mutually exclusive"
    usage; exit 1
fi
if [[ $PKEYCRYPT == false ]] && [[ $PKEYPKCS8 == true ]]; then
    echo "'nocrypt' and 'pkcs8' arguments are mutually exclusive"
    usage; exit 1
fi

if [[ $PKEYYUBIKEY == true ]]; then
    /usr/lib/rootca/yubikey-init.sh
    if [[ $PKEYALGO == "ec" ]]; then
        YKMANALGO="ECCP${PKEYLEN}"
    else
        YKMANALGO="RSA${PKEYLEN}"
    fi
    ykman piv keys generate \
        -m $(cat $PKEYYUBIKEYMGMT) \
        -P $(cat $PKEYYUBIKEYPIN) \
        -a $YKMANALGO \
        $PKEYYUBIKEYSLOT - >/dev/null
else
    if [[ $PKEYALGO == "ec" ]]; then
        OSSLOPTS="-algorithm ec -pkeyopt ec_paramgen_curve:P-${PKEYLEN}"
        OSSLOPTS+=" -pkeyopt ec_param_enc:named_curve"
    else
        OSSLOPTS="-algorithm rsa -pkeyopt rsa_keygen_bits:${PKEYLEN}"
    fi
    CRYPT=
    if [[ $PKEYCRYPT == true ]]; then
        if [[ $PKEYPKCS8 == true ]]; then
            CRYPT="-aes256"
        else
            if [[ $PKEYALGO == "ec" ]]; then
                CRYPT="| openssl ec -aes256"
            else
                CRYPT="| openssl rsa -aes256 -traditional"
            fi
        fi
    fi
    if [[ ! -z $PKEYOUT ]]; then
        CRYPT+=" -out ${PKEYOUT}"
    fi
    echo "$OSSLOPTS"
    eval "openssl genpkey -quiet ${OSSLOPTS} ${CRYPT}"
fi