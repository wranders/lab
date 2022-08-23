#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config deploy <ARGUMENT>
arguments:
    -h,--help       show this dialog
    -r,--repo       Github repository (required)
    -b,--branch     Destination branch deployment Pull Requests will be made 
                    against (required)
    -a,--app-id     Github App ID (required)
    -k,--key        Github App Private Key file (required)
EOF
}

getrepo() {
    local URL=$1
    local PROTO URL_NO_PROTO USERPASS HOSTPORT HOST PORT PAT
    PROTO=$(echo $URL | grep "://" | sed -e 's,^\(.*://\).*,\1,g')
    URL_NO_PROTO=$(echo "${URL/$PROTO/}")
    PATH=$(echo $URL_NO_PROTO | grep "/" | cut -d"/" -f2-)
    echo "${PATH%'.git'}"
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG='help,repo:,branch:,app-id:,key:'
OPTSSHORT='hr:b:a:k:'
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare REPO BRANCH APPID KEYFILE
while true; do
    case $1 in
        -h|--help)      usage; exit 0 ;;
        -r|--repo)      shift; REPO=$1 ;;
        -b|--branch)    shift; BRANCH=$1 ;;
        -a|--app-id)    shift; APPID=$1 ;;
        -k|--key)       shift; KEYFILE=$(realpath "${1}") ;;
        --)             shift; break ;;
    esac; shift
done

if [[ -z $REPO ]] || [[ -z $APPID ]] || \
    [[ -z $KEYFILE ]] || [[ -z $BRANCH ]]; then
    echo "one or more required arguments are missing"; usage; exit 1
fi
if [[ ! -d /media/ROOTCA ]]; then
    echo "Root CA Data Directory '/media/ROOTCA' does not exist"
    echo "was '$0 config init' run?"; usage; exit 1
fi

ykman piv info >/dev/null
if [ $? -ne 0 ]; then echo "no yubikey device found"; usage; exit 1; fi
if [[ ! -f /media/ROOTCA/openssl.cnf ]]; then
    echo "'openssl.cnf' not found in ROOTCA directory"
    echo "was '$0 config init' run?"; usage; exit 1
fi
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
openssl pkey -noout -in "${KEYFILE}" &>/dev/null
if [ $? -ne 0 ]; then echo "unable to read private key"; usage; exit 1; fi

# Generate JWT from App's private key to query the API for the App's name
HEADER='{"alg":"RS256","typ":"JWT"}'
IAT=$(date -ud '60 seconds ago' +'%s')
EXP=$(date -ud '10 minutes' +'%s')
PAYLOAD="{\"iat\":$IAT,\"exp\":$EXP,\"iss\":\"$APPID\"}"
b64enc(){ openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json(){ jq -c . | LC_CTYPE=C tr -d '\n'; }
CONTENT="$(json <<< $HEADER | b64enc).$(json <<< $PAYLOAD | b64enc)"
SIG=$(printf %s $CONTENT | openssl dgst -binary -sha256 -sign "${KEYFILE}" | b64enc)
JWT=$(printf '%s.%s\n' $CONTENT $SIG)

# Get App name from API
APPNAME=$(curl -s -X GET \
    -H "Authorization: Bearer $JWT" \
    https://api.github.com/app | jq -r '.name'
)
# If offline or otherwise cannot get App name, set a default
if [[ -z $APPNAME ]]; then APPNAME="Github App"; fi

# Import private key file to Key Management slot (9d). This is so it can be used
#   with the PIV PIN file just like the Root CA key in the Authentication slot
#   (9a).
ykman piv keys import \
    -P $(cat /media/YUBISEC/PIN) \
    -m $(cat /media/YUBISEC/KEY) \
    9d "${KEYFILE}"
# Self sign a certificate. This certificate will never be used for anything
#   other than to identify that the PIV slot is occupied.
openssl req -key "${KEYFILE}" -subj "/CN=$APPNAME/O=Github App" -x509 -days 3650 | \
    ykman piv certificates import \
        -P $(cat /media/YUBISEC/PIN) \
        -m $(cat /media/YUBISEC/KEY) 9d -
set -x
declare AIA CDP
REPO=$(getrepo $REPO)
# Get certificate and CRL file names from AIA and CDP in OpenSSL configuration
AIAFILE=$(basename $(grep caIssuers /media/ROOTCA/openssl.cnf | cut -d= -f2))
CDPFILE=$(basename $(
    awk '/\[issuing_ca_cdp\]/{getline;print}' /media/ROOTCA/openssl.cnf | \
    cut -d= -f2
))
cat <<EOF > /media/ROOTCA/deploy.env
DEPLOY_REPO="$REPO"
DEPLOY_BRANCH="$BRANCH"
DEPLOY_APPID="$APPID"
DEPLOY_AIAFILE="$AIAFILE"
DEPLOY_CDPFILE="$CDPFILE"
EOF
set +x