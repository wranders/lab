#!/bin/bash

usage() {
    cat <<EOF
usage: rootca crl revoke <REASON> <SERIAL>
reason:
    unspecified                 no special reason
    key-compromise <TIME>       associated private key was exposed
    ca-compromise <TIME>        associated CA private key was exposed
    affiliation-changed         certificate DN is no longer accurate
    superseded                  certificate is replaced
    cessation-of-operation      CA is decommissioned or no longer used
    certificate-hold <REASON>   CA will not vouch for the certificate at this
                                time. Reasons are 'none', 'call-issuer', and
                                'reject'
    remove-from-crl             vouch for the validity of a certificate marked
                                with 'certificate-hold'
arguments:
    -h,--help                   show this dialog
EOF
}

OPTS=$(getopt -l "help" -o "h" -a -- "$@")
eval set -- "$OPTS"
while true; do
    case $1 in
        -h|--help)  usage; exit 0 ;;
        --)         shift; break ;;
    esac; shift
done

if [ $# -eq 0 ]; then usage; exit 1; fi
declare REASON SERIAL OPTCOM
case $1 in
    unspecified)
        shift
        REASON='unspecified'
        SERIAL=$1
        ;;
    key-compromise)
        shift
        REASON='keyCompromise'
        SERIAL=$2
        datetest -i '%Y%m%d%H%M%SZ' --isvalid $1
        if [[ $? -ne 0 ]]; then
            echo 'date does not conform to expected format YYYYMMDDhhmmssZ'
            exit 1
        fi
        OPTCOM="-crl_compromise ${1}"
        ;;
    ca-compromise)
        shift
        REASON='CACompromise'
        SERIAL=$2
        datetest -i '%Y%m%d%H%M%SZ' --isvalid $1
        if [[ $? -ne 0 ]]; then
            echo 'date does not conform to expected format YYYYMMDDhhmmssZ'
            exit 1
        fi
        OPTCOM="-crl_CA_compromise ${1}"
        ;;
    affiliation-changed)
        shift
        REASON='affiliationChanged'
        SERIAL=$1
        ;;
    superseded)
        shift
        REASON='superseded'
        SERIAL=$1
        ;;
    cessation-of-operation)
        shift
        REASON='cessationOfOperation'
        SERIAL=$1
        ;;
    certificate-hold)
        shift
        REASON='certificateHold'
        SERIAL=$2
        declare INST
        case $1 in
            none) INST='holdInstructionNone' ;;
            call-issuer) INST='holdInstructionCallIssuer' ;;
            reject) INST='holstInstructionReject';;
            *)
                echo "reason 'certificate-hold' reasons can only be one of the"
                echo "following: 'none', 'call-issuer', or 'reject'"
                exit 1
            ;;
        esac
        OPTCOM="-crl_hold ${INST}"
        ;;
    remove-from-crl)
        shift
        REASON='removeFromCRL'
        SERIAL=$1
        # this option isnt really useful, but here for completeness
        # this may modify the database in the future to set a certifiate
        # to valid and remove the revoke date and reason
        ;;
    *)
        OPTS=$(getopt -l "help" -o "h" -a -- "$@")
        eval set -- "$OPTS"
        while true; do
            case $1 in
                -h|--help)  usage; exit 0 ;;
                --)         shift; break ;;
            esac; shift
        done
        echo "unknown command '$1'"; usage; exit 1 ;;
esac

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

SERIALUPPER=$(echo $SERIAL | tr '[:lower:]' '[:upper:]')
FILE="/media/ROOTCA/certs/${SERIALUPPER}.pem"
if [[ ! -f $FILE ]]; then
    echo "certificate with serial number ${SERIAL} was not found" >$(tty)
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
        -passin file:/media/ROOTCASEC/PIN -revoke ${FILE} \
        -crl_reason ${REASON} ${OPTCOM}"
RC=$?
popd >/dev/null
exit $RC
