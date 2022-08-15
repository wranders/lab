#!/bin/bash

usage() {
    cat <<EOF
usage: $0 create-root [ARGS]
arguments:
    -h,--help       show this dialog
    -d,--dir        Root CA data directory (defaults to \$ROOTCA_DIR)
    -S,--subj       Root Certificate subject, OpenSSL formatted (required)
    -y,--years      number of years Root Certificate is valid for (required)
    -k,--key        private key file (incompatible with '--yubikey')
    -P,--passin     private key file passphrase (required with '-k,--key')
                    see 'openssl-passphrase-options', only 'file', 'fd', and
                    'stdin' accepted
    --yubikey       use Yubikey device (incompatible with '-k,--key')
    -s,--slot       Yubikey PIV slot (only '9a' and '9c' supported)
                    (required with '--yubikey')
    -p,--pin        Yubikey PIV PIN file (required with '--yubikey')
    --install       install certificate to yubikey slot
    -m,--mgmt       Yubikey Management Key file (required with '--install')
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG="help,dir:,subj:,years:,key:,passin:,yubikey,slot:,pin:,install,mgmt:"
OPTSSHORT="hd:S:y:k:P:s:p:m:"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare CADIR CASUBJECT CAYEARS CAKEYFILE CAKEYPASS CAYUBIKEY=false CAYUBIKEYSLOT
declare CAYUBIKEYPIN CAYUBIKEYINSTALL=false CAYUBIKEYMGMT
while true; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -d|--dir)       shift; CADIR=$1 ;;
        -S|--subj)      shift; CASUBJECT=$1 ;;
        -y|--years)     shift; CAYEARS=$1 ;;
        -k|--key)       shift; CAKEYFILE=$1 ;;
        -P|--passin)    shift; CAKEYPASS=$1 ;;
        --yubikey)      CAYUBIKEY=true ;;
        -s|--slot)      shift; CAYUBIKEYSLOT=$1 ;;
        -p|--pin)       shift; CAYUBIKEYPIN=$1 ;;
        --install)      CAYUBIKEYINSTALL=true ;;
        -m|--mgmt)      shift; CAYUBIKEYMGMT=$1 ;;
        --)             shift; break ;;
    esac; shift
done

if [[ -z $CADIR ]]; then CADIR=$ROOTCA_DIR; fi
if [ ! -d $CADIR ]; then
    echo "directory '$(realpath $CADIR)' does not exist"
    usage; exit 1
fi
if [ ! -w $CADIR ]; then
    echo "directory '$(realpath $CADIR)' is not writable"
    usage; exit 1
fi
if [[ -z $CASUBJECT ]]; then echo 'subject is required'; exit 1; fi
if [[ -z $CAYEARS ]]; then echo 'years is required'; exit 1; fi
if [[ $CAYUBIKEY == false ]] && [[ -z $CAKEYFILE ]]; then
    echo 'a key file or yubikey are required'; usage; exit 1
fi
if [[ $CAYUBIKEY == true ]] && [[ ! -z $CAKEYFILE ]]; then
    echo 'key file and yubikey are mutually exclusive'; usage; exit 1
fi
if [[ ! -z $CAKEYFILE ]] && [[ ! -r $CAKEYFILE ]]; then
    echo 'key file is not readable'; usage; exit 1
fi
if [[ $CAYUBIKEY == true ]] && [[ -z $CAYUBIKEYSLOT ]]; then
    echo 'yubikey slot is required'; usage; exit 1
fi
if [[ $CAYUBIKEY == true ]]; then
    if [[ -z $CAYUBIKEYPIN ]] || [[ ! -r $CAYUBIKEYPIN ]]; then
        echo 'a file containing the yubikey PIV PIN is required to use the'
        echo 'yubikey'
        usage; exit 1
    fi
fi
if [[ $CAYUBIKEYINSTALL == true ]]; then
    if [[ -z $CAYUBIKEYMGMT ]] || [[ ! -r $CAYUBIKEYMGMT ]]; then
        echo 'a file containing the yubikey management key is required to'
        echo 'install a certificate to the yubikey'
        usage; exit 1
    fi
fi
if [[ ! -z $CAKEYPASS ]] && \
    [[ $CAKEYPASS != pass:* ]] && \
    [[ $CAKEYPASS != fd:* ]] && \
    [[ $CAKEYPASS != stdin ]]; then
    echo "invlid key passphrase source."
    echo "only 'file', 'fd', and 'stdin' supported"; usage; exit 1
fi
if [[ ! -f "$CADIR/openssl.cnf" ]] || [[ ! -r "$CADIR/openssl.cnf" ]]; then
    echo 'openssl configuration file does not exist or is not readable.'
    echo 'execute `rootca init [DIR]` to initialize the CA data directory'
    usage; exit 1
fi

declare CAENGINETMPL CAKEYTMPL CAPASSTMPL
if [[ $CAYUBIKEY == true ]]; then
    declare PIVSLOTID
    if [[ $CAYUBIKEYSLOT == "9a" ]]; then
        PIVSLOTID+='01'
    elif [[ $CAYUBIKEYSLOT == "9c" ]]; then
        PIVSLOTID+='02'
    else 
        echo "unsupported yubikey PIV slot '${CAYUBIKEYSLOT}'"; usage; exit 1
    fi

    

    CAENGINETMPL="-engine pkcs11 -keyform engine"
    CAKEYTMPL="-key \"pkcs11:id=%$PIVSLOTID;type=private\""
    CAPASSTMPL="-passin file:$CAYUBIKEYPIN"
else
    CAKEYTMPL="-key $(realpath $CAKEYFILE)"
    if [[ ! -z $CAKEYPASS ]]; then
        CAPASSTMPL="-passin $CAKEYPASS"
    fi
fi

STARTDATE="$(date +'%Y-%m')-01"
GTFORMAT="%Y%m%d%H%M%SZ"
CADATESTART=$(date -d $STARTDATE +$GTFORMAT)
CADATEEND=$(datefudge $STARTDATE date -d "$CAYEARS years" +$GTFORMAT)
RC=$?; if [[ $RC -ne 0 ]]; then exit $RC; fi

pushd $CADIR >/dev/null
if [[ $CAYUBIKEY == true ]]; then
    /usr/lib/rootca/yubikey-init.sh
    
    eval "ykman piv keys export $CAYUBIKEYSLOT ca/root_ca.pub.pem"
    RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi

    eval "ykman piv certificates request -P $(cat $(realpath $CAYUBIKEYPIN)) \
        -s \"$(echo $CASUBJECT | sed -e 's/^\///' | sed -e 's/\//,/g')\" \
        $CAYUBIKEYSLOT ca/root_ca.pub.pem ca/root_ca.csr.pem"
    RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi
else
    eval "openssl req -new -config openssl.cnf $CAENGINETMPL $CAKEYTMPL \
            $CAPASSTMPL -subj '$CASUBJECT' -out ca/root_ca.csr.pem"
    RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi
    echo "'$CADIR/ca/root_ca.csr.pem' created"
fi
eval "openssl ca -config openssl.cnf $CAENGINETMPL $CAPASSTMPL -selfsign \
        -notext -batch -in ca/root_ca.csr.pem -out ca/root_ca.crt.pem \
        -extensions root_ca_ext -startdate $CADATESTART -enddate $CADATEEND"
RC=$?; if [[ $RC -ne 0 ]]; then popd >/dev/null; exit $RC; fi
echo "'$CADIR/ca/root_ca.crt.pem' created"
eval "openssl x509 -in ca/root_ca.crt.pem -outform der -out ca/root_ca.crt"
RC=$?
popd >/dev/null
if [[ $RC -ne 0 ]]; then exit $RC; fi
echo "'$CADIR/ca/root_ca.crt' created"

if [[ $CAYUBIKEYINSTALL == true ]]; then
    ykman piv certificates import -m $(cat $CAYUBIKEYMGMT) \
        -P $(cat $CAYUBIKEYPIN) $CAYUBIKEYSLOT $CADIR/ca/root_ca.crt.pem && \
    echo "certificate installed on yubikey in slot $CAYUBIKEYSLOT"
fi
