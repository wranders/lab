#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config init <ARGUMENT>
arguments:
    -h,--help       show this dialog
    -s,--subj       Root CA subject, OpenSSL formatted (required)
    -y,--years      number of years Root Certificate is valid for (required)
    -a,--aia        subordinate CA Authority Info Access URL (required)
    -c,--cdp        subordinate CA CRL Distribution Point URL (required)
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG="help,subj:,years:,aia:,cdp:"
OPTSSHORT="hs:y:a:c:"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare SUBJECT YEARS AIAURL CDPURL
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        -s|--subj)  shift; SUBJECT=$1 ;;
        -y|--years) shift; YEARS=$1 ;;
        -a|--aia)   shift; AIAURL=$1 ;;
        -c|--cdp)   shift; CDPURL=$1 ;;
        --) shift; break ;;
    esac; shift
done
if [[ -z $SUBJECT ]] || [[ -z $YEARS ]] || \
    [[ -z $AIAURL ]] || [[ -z $CDPURL ]]; then
    echo "one or more required arguments are missing"; usage; exit 1
fi
if [[ ! -d /media/ROOTCA ]]; then
    echo "Root CA Data Directory '/media/ROOTCA' does not exist"; usage; exit 1
fi
if [[ ! -d /media/ROOTCAKEY ]]; then
    echo "'/media/ROOTCAKEY' is required to store the private key backup"
    usage; exit 1
fi
ykman piv info >/dev/null
if [ $? -ne 0 ]; then echo "no yubikey device found"; usage; exit 1; fi
if [[ ! -f /media/YUBISEC/KEY ]] || [[ ! -f /media/YUBISEC/PIN ]]; then
    echo "Yubikey secret files do not exist"
    echo "'/media/YUBISEC/KEY' and '/media/YUBISEC/PIN' are required"
    usage; exit 1
fi
if [[ ! -r /media/YUBISEC/KEY ]] || [[ ! -r /media/YUBISEC/PIN ]]; then
    echo "Yubikey secret files are not readable"
    echo "'/media/YUBISEC/KEY' and '/media/YUBISEC/PIN' are required"
    usage; exit 1
fi

# Prepare the Root CA data directory
mkdir /media/ROOTCA/{ca,certs,crl,db}
export LC_CTYPE=C
< /dev/urandom | tr -d '[:lower:]' | tr -cd '[:xdigit:]' | \
    fold -w40 | head -1 > /media/ROOTCA/db/root_ca.crt.srl
echo 1000 > /media/ROOTCA/db/root_ca.crl.srl
touch /media/ROOTCA/db/root_ca.db
cat <<EOF > /media/ROOTCA/openssl.cnf
[default]
ROOTCA_DIR   = .
dir          = \$ENV::ROOTCA_DIR
openssl_conf = openssl_def

[openssl_def]
engines = engines_def

[engines_def]
pkcs11 = pkcs11_def

[pkcs11_def]
engine_id   = pkcs11
MODULE_PATH = /usr/lib64/libykcs11.so.2

[ca]
default_ca = root_ca

[root_ca]
certificate      = \$dir/ca/root_ca.crt.pem
private_key      = "pkcs11:id=%01;type=private"
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

[match_pol]
domainComponent        = supplied
countryName            = match
stateOrProvinceName    = optional
localityName           = optional
organizationName       = match
organizationalUnitName = optional
commonName             = supplied

[crl_ext]
authorityKeyIdentifier = keyid:always

[root_ca_ext]
keyUsage               = critical,keyCertSign,cRLSign
basicConstraints       = critical,CA:true,pathlen:1
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always

[issuing_ca_ext]
keyUsage               = critical,keyCertSign,cRLSign
basicConstraints       = critical,CA:true,pathlen:0
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always
authorityInfoAccess    = @issuing_ca_aia
crlDistributionPoints  = @issuing_ca_cdp

[issuing_ca_aia]
caIssuers;URI.0 = $AIAURL

[issuing_ca_cdp]
URI.0 = $CDPURL
EOF

. "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")/yubikey-init.sh"

openssl genpkey -quiet \
    -algorithm ec \
    -pkeyopt ec_paramgen_curve:P-384 \
    -pkeyopt ec_param_enc:named_curve | \
        openssl ec -aes256 -out /media/ROOTCAKEY/root_ca.key
ykman piv keys import \
    -P $(cat /media/YUBISEC/PIN) \
    -m $(cat /media/YUBISEC/KEY) \
    9a /media/ROOTCAKEY/root_ca.key
ykman piv keys export 9a /media/ROOTCA/ca/root_ca.pub.pem
ykman piv certificates request \
    -P $(cat /media/YUBISEC/PIN) \
    -s "$(echo $SUBJECT | sed -e 's/^\///' | sed -e 's/\//,/g')" \
    -a SHA256 \
    9a \
    /media/ROOTCA/ca/root_ca.pub.pem \
    /media/ROOTCA/ca/root_ca.csr.pem

STARTDATE="$(date +'%Y-%m')-01"
CADATESTART=$(date -d $STARTDATE +'%Y%m%d%H%M%SZ')
CADATEEND=$(datefudge $STARTDATE date -d "$CAYEARS years" +'%Y%m%d%H%M%SZ')
# If the number of years is invalid or cannot be interpreted by `date` the error
#   will render and it's return code will return.
RC=$?; if [[ $RC -ne 0 ]]; then exit $RC; fi

pushd /media/ROOTCA >/dev/null

openssl ca -config openssl.cnf -engine pkcs11 -keyform engine \
    -selfsign -notext -batch -passin file:/media/YUBISEC/PIN \
    -in ca/root_ca.csr.pem -out ca/root_ca.crt.pem -extensions root_ca_ext \
    -startdate $CADATESTART -enddate $CADATEEND
RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi
openssl x509 -in ca/root_ca.crt.pem -outform der -out ca/root_ca.crt
RC=$?
popd >/dev/null
if [[ $RC -ne 0 ]]; then exit $RC; fi

ykman piv certificates import \
    -P $(cat /media/YUBISEC/PIN) \
    -m $(cat /media/YUBISEC/KEY) \
    9a /media/ROOTCA/ca/root_ca.crt.pem
