#!/bin/bash

usage() {
    cat <<EOF
usage: $0 init [args]
arguments:
    -h,--help       show this dialog
    -d,--dir        Root CA data directory
    -a,--aia        subordinate CA Authority Info Access URL
    -c,--cdp        subordinate CA CRL Distribution Point URL
    --keyfile       CA private key file (if not using Yubikey)
    --yubikey       use a Yubikey as a storage device
    -s,--slot       Yubikey slot of the Root CA private key
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG="help,dir:,aia:,cdp:,keyfile:,yubikey,slot:"
OPTSSHORT="hd:a:c:s:"
OPTS=$(getopt -l "${OPTSLONG}" -o "${OPTSSHORT}" -a -- "$@")
eval set -- "$OPTS"
declare CADIR CAYUBIKEY=false CAYUBIKEYSLOT CAAIA CACDP CAKEYFILE
declare CAYUBIKEYTMPL CAPRIVATEKEYTMPL ICAAIA ICAAIAEXT ICACDP ICACDPEXT
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        -d|--dir)   shift; CADIR=$1 ;;
        -a|--aia)   shift; CAAIA=$1 ;;
        -c|--cdp)   shift; CACDP=$1 ;;
        --keyfile)  shift; CAKEYFILE=$1 ;;
        --yubikey)  CAYUBIKEY=true ;;
        -s|--slot)  shift; CAYUBIKEYSLOT=$1 ;;
        --)         shift; break ;;
    esac; shift
done
if [[ $CAYUBIKEY == true ]] && [[ -z $CAYUBIKEYSLOT ]]; then
    echo 'slot required if initializing with yubikey'
    usage; exit 1
fi
if [[ $CAYUBIKEY == true ]] && [[ ! -z $CAKEYFILE ]]; then
    echo "'yubikey' and 'keyfile' options are mutually exclusive"
    usage; exit 1
fi
if [[ $CAYUBIKEY == false ]] && [[ -z $CAKEYFILE ]]; then
    echo "either 'yubikey' or 'keyfile' must be specified"
    usage; exit 1
fi
if [[ -z $CADIR ]]; then
    CADIR=$ROOTCA_DIR
fi
if [ ! -d "$CADIR" ]; then
    echo "directory '$(realpath ${CADIR})' does not exist. exiting..."
    exit 1
fi
if [[ $CAYUBIKEY == true ]]; then
    CAYUBIKEYTMPL=$(cat <<EOF
openssl_conf = openssl_def

[ openssl_def ]
engines = engines_def

[ engines_def ]
pkcs11 = pkcs11_def

[ pkcs11_def ]
engine_id   = pkcs11
MODULE_PATH = /usr/lib64/libykcs11.so.2
init        = 0
EOF
)
    if [[ $CAYUBIKEYSLOT == "9a" ]]; then
        CAPRIVATEKEYTMPL='"pkcs11:id=%01;type=private"'
    elif [[ $CAYUBIKEYSLOT == "9c" ]]; then
        CAPRIVATEKEYTMPL='"pkcs11:id=%02;type=private"'
    else
        echo "unsupported Yubikey PIV slot '${CAYUBIKEYSLOT}'"
        usage; exit 1
    fi
else
    CAPRIVATEKEYTMPL=$(realpath $CAKEYFILE)
fi
if [[ ! -z $CAAIA ]]; then
    ICAAIA="authorityInfoAccess    = @issuing_ca_aia"
    ICAAIAEXT=$(cat <<EOF
[ issuing_ca_aia ]
caIssuers;URI.0 = $CAAIA
EOF
)
fi
if [[ ! -z $CACDP ]]; then
    ICACDP="crlDistributionPoints  = @issuing_ca_cdp"
    ICACDPEXT=$(cat <<EOF
[ issuing_ca_cdp ]
URI.0 = $CACDP
EOF
)
fi

mkdir $CADIR/{ca,certs,crl,db}
( \
    LC_CTYPE=C \
    dd if=/dev/urandom 2>/dev/null | \
    tr -d '[:lower:]' | \
    tr -cd '[:xdigit:]' | \
    fold -w40 | \
    head -1 \
) > $CADIR/db/root_ca.crt.srl
echo 1000 > $CADIR/db/root_ca.crl.srl
touch $CADIR/db/root_ca.db
cat <<EOF > $CADIR/openssl.cnf
[ default ]
ROOTCA_DIR   = .
dir          = \$ENV::ROOTCA_DIR
$CAYUBIKEYTMPL

[ ca ]
default_ca = root_ca

[ root_ca ]
certificate      = \$dir/ca/root_ca.crt.pem
private_key      = $CAPRIVATEKEYTMPL
new_certs_dir    = \$dir/certs
serial           = \$dir/db/root_ca.crt.srl
crlnumber        = \$dir/db/root_ca.crl.srl
database         = \$dir/db/root_ca.db
unique_subject   = no
rand_serial      = no
default_days     = 3652
default_md       = sha256
policy           = match_pol
email_in_dn      = no
preserve         = no
name_opt         = ca_default
cert_opt         = ca_default
copy_extensions  = none
default_crl_days = 180
crl_extensions   = crl_ext

[ match_pol ]
domainComponent        = supplied
countryName            = match
stateOrProvinceName    = optional
localityName           = optional
organizationName       = match
organizationalUnitName = optional
commonName             = supplied

[ crl_ext ]
authorityKeyIdentifier = keyid:always

[ root_ca_ext ]
keyUsage               = critical,keyCertSign,cRLSign
basicConstraints       = critical,CA:true,pathlen:1
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always

[ issuing_ca_ext ]
keyUsage               = critical,keyCertSign,cRLSign
basicConstraints       = critical,CA:true,pathlen:0
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always
$ICAAIA
$ICACDP

$ICAAIAEXT

$ICACDPEXT
EOF