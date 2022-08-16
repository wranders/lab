#!/bin/bash

usage() {
    cat <<EOF
usage: $0 sign-subca [ARGS]
arguments:
    -h,--help       show this dialog
    -d,--dir        Root CA data directory (defaults to \$ROOTCA_DIR)
    -P,--passin     private key file passphrase; see 'openssl-passphrase-options'
                    only 'file', 'fd', and 'stdin' accepted
    -i,--in         file to read certificate signing request from
    -o,--out        file to write sign certificate to
    --yubikey       use Yubikey device
    -p,--pin        Yubikey PIV PIN file (required with '--yubikey')
EOF
}

if [ $# -eq 0 ]; then usage; exit 0; fi
OPTSLONG="help,dir:,passin:,in:,out:,yubikey,pin:"
OPTSSHORT="hd:P:i:o:p:"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare CADIR CAKEYPASS CAYUBIKEY=false CAYUBIKEYPIN CACSRIN CACRTOUT
while true; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -d,--dir)       shift; CADIR=$1 ;;
        -P|--passin)    shift; CAKEYPASS=$1 ;;
        -i|--in)        shift; CACSRIN=$(realpath $1) ;;
        -o|--out)       shift; CACRTOUT=$(realpath $1) ;;
        --yubikey)      CAYUBIKEY=true ;;
        -p|--pin)       shift; CAYUBIKEYPIN=$1 ;;
        --)             shift; break ;;
    esac; shift
done

if [[ -z $CADIR ]]; then CADIR=$ROOTCA_DIR; fi
if [ ! -d $CADIR ]; then
    echo "directory '$(realpath $CADIR)' does not exist"; usage; exit 1
elif [ ! -w $CADIR ]; then
    echo "directory '$(realpath $CADIR)' is not writable"; usage; exit 1
fi
if [[ $CAYUBIKEY == true ]]; then
    if [[ -z $CAYUBIKEYPIN ]] || [[ ! -r $CAYUBIKEYPIN ]]; then
        echo 'a file containing the yubikey PIV PIN is required to use the'
        echo 'yubikey'; usage; exit 1
    fi
fi
if [[ ! -z $CAKEYPASS ]] && \
    [[ $CAKEYPASS != pass:* ]] && \
    [[ $CAKEYPASS != fd:* ]] && \
    [[ $CAKEYPASS != stdin ]]; then
    echo "invalid key passphrase source"
    echo "only 'file', 'fd', and 'stdin' supported"; usage; exit 1
fi
if [[ ! -f "$CADIR/openssl.cnf" ]] || [[ ! -r "$CADIR/openssl.cnf" ]]; then
    echo 'openssl configuration file does not exist or is not readable.'
    echo "execute 'rootca init [DIR]' to initialize the CA data directory"
    usage; exit 1
fi

declare CAENGINETMPL CAPASSTMPL
if [[ $CAYUBIKEY == true ]]; then
    /usr/lib/rootca/yubikey-init.sh
    CAENGINETMPL="-engine pkcs11 -keyform engine"
    CAPASSTMPL="-passin file:$CAYUBIKEYPIN"
else 
    CAPASSTMPL="-passin $CAKEYPASS"
fi

pushd $CADIR >/dev/null
eval "openssl ca -config openssl.cnf $CAENGINETMPL $CAPASSTMPL -notext \
        -extensions issuing_ca_ext -in $CACSRIN -out $CACRTOUT"
RC=$?
popd >/dev/null
exit $RC