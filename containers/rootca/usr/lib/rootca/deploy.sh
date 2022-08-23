#!/bin/bash

usage() {
    cat <<EOF
usage: rootca deploy <COMMAND> <ARGUMENT>
commands:
    
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
declare DEPLOY_CRT=false DEPLOY_CRL=false DEPLOY_ALL=false
case $1 in
    certificate)
        DEPLOY_CRT=true ;;
    crl)
        DEPLOY_CRL=true ;;
    all)
        DEPLOY_ALL=true
        DEPLOY_CRT=true
        DEPLOY_CRL=true ;;
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
if [[ ! -r /media/ROOTCA ]]; then
    echo "'/media/ROOTCA' directory is not readable"
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
. "$(dirname -- "$(readlink -f "${BASH_SOURCE}")")/yubikey-init.sh"
ykman piv info 1>/dev/null
if [[ $? -ne 0 ]]; then 
    echo "there was an error detecting a Yubikey device"
    exit 1
fi
ykman piv certificates export 9d - 1>/dev/null
if [[ $? -ne 0 ]]; then
    echo "there was an error detecting an installed Github App certificate"
    echo "is deploy configured? 'rootca config deploy --help'"
    exit 1
fi

. /media/ROOTCA/deploy.env


b64enc(){ openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json(){ jq -c . | LC_CTYPE=C tr -d '\n'; }
OSSLCNF=$(mktemp)
cat <<EOF > $OSSLCNF
[default]
openssl_conf = openssl_def
[openssl_def]
engines = engine_def
[engine_def]
pkcs11 = pkcs11_def
[pkcs11_def]
engine_id = pkcs11
MODULE_PATH = /usr/lib64/libykcs11.so.2
EOF

HEADER='{"alg":"RS256","typ":"JWT"}'
IAT=$(date -ud '60 seconds ago' +'%s')
EXP=$(date -ud '10 minutes' +'%s')
PAYLOAD="{\"iat\":$IAT,\"exp\":$EXP,\"iss\":\"$DEPLOY_APPID\"}"
CONTENT="$(json <<< $HEADER | b64enc).$(json <<< $PAYLOAD | b64enc)"
SIG=$(
    printf %s $CONTENT | \
    OPENSSL_CONF=$OSSLCNF openssl dgst -engine pkcs11 -keyform engine \
        -binary -sha256 -sign "pkcs11:id=%03;type=private" \
        -passin file:/media/ROOTCASEC/PIN | \
    b64enc)
rm $OSSLCNF
JWT=$(printf '%s.%s\n' $CONTENT $SIG)
APP_SLUG=$(curl -s -X GET \
    -H "Authorization: Bearer ${JWT}" \
    https://api.github.com/app | \
    jq -r '.slug'
)
INSTALLATION=$(curl -s -X GET \
    -H "Authorization: Bearer ${JWT}" \
    https://api.github.com/app/installations | \
    jq -r \
        --arg user $(echo $DEPLOY_REPO | cut -d'/' -f1) \
        '.[] | select(.accout.login="$user") | .id'
)
TOKEN=$(curl -s -X POST \
    -H "Authorization: Bearer $JWT" \
    https://api.github.com/app/installations/${INSTALLATION}/access_tokens | \
    jq -r '.token')
BRANCH_SHA=$(curl -s -X GET \
    -H "Authorization: token $TOKEN" \
    https://api.github.com/repos/${DEPLOY_REPO}/git/ref/heads/${DEPLOY_BRANCH} | \
    jq -r '.object.sha'
)
declare BRNAME PRTITLE PRBODY
if [[ $DEPLOY_ALL == true ]]; then
    PRTITLE="update certificate and certificate revocation list"
    PRBODY="deploy new certificate and revocation list to Pages"
    BRNAME="${APP_SLUG}/update-crt-crl"
elif [[ $DEPLOY_CRT == true ]]; then
    PRTITLE="update certificate"
    PRBODY="deploy new certificate to Pages"
    BRNAME="${APP_SLUG}/update-crt"
elif [[ $DEPLOY_CRL == true ]]; then
    PRTITLE="update certificate revocation list"
    PRBODY="deploy new revocation list to Pages"
    BRNAME="${APP_SLUG}/update-crl"
fi

curl -s -X POST \
    -H "Authorization: token $TOKEN" \
    https://api.github.com/repos/${DEPLOY_REPO}/git/refs \
    -d "$(jq -nc \
        --arg sha "$BRANCH_SHA" \
        --arg branch "refs/heads/$BRNAME" \
        '{
            "ref": $branch,
            "sha": $sha
        }'
    )"
if [[ $DEPLOY_ALL == true ]] || [[ $DEPLOY_CRT == true ]]; then
    EXISTING_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
        -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/${DEPLOY_REPO}/contents/${DEPLOY_AIAFILE}?ref=$BRNAME"
    )
    if [[ $EXISTING_CODE == 200 ]]; then
        EXISTING_SHA=$(curl -s -X GET \
            -H "Authorization: token $TOKEN" \
            "https://api.github.com/repos/${DEPLOY_REPO}/contents/${DEPLOY_AIAFILE}?ref=$BRNAME" | \
            jq -r '.sha'
        )
        curl -s -X PUT \
            -H "Authorization: token $TOKEN" \
            https://api.github.com/repos/${DEPLOY_REPO}/contents/$DEPLOY_AIAFILE \
            -d "$(jq -nc \
                --arg content "$(base64 /media/ROOTCA/ca/root_ca.crt)" \
                --arg branch "$BRNAME" \
                --arg sha "$EXISTING_SHA" \
                '{
                    "message":"update root certificate",
                    "branch":$branch,
                    "content":$content,
                    "sha":$sha
                }'
            )"
    else 
        curl -s -X PUT \
            -H "Authorization: token $TOKEN" \
            https://api.github.com/repos/${DEPLOY_REPO}/contents/$DEPLOY_AIAFILE \
            -d "$(jq -nc \
                --arg content "$(base64 /media/ROOTCA/ca/root_ca.crt)" \
                --arg branch "$BRNAME" \
                '{
                    "message":"update root certificate",
                    "branch":$branch,
                    "content":$content
                }'
            )"
    fi
fi

if [[ $DEPLOY_ALL == true ]] || [[ $DEPLOY_CRL == true ]]; then
    EXISTING_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
        -H "Authorization: token $TOKEN" \
        "https://api.github.com/repos/${DEPLOY_REPO}/contents/${DEPLOY_CDPFILE}?ref=$BRNAME"
    )
    if [[ $EXISTING_CODE == 200 ]]; then
        EXISTING_SHA=$(curl -s -X GET \
            -H "Authorization: token $TOKEN" \
            "https://api.github.com/repos/${DEPLOY_REPO}/contents/${DEPLOY_CDPFILE}?ref=$BRNAME" | \
            jq -r '.sha'
        )
        curl -s -X PUT \
            -H "Authorization: token $TOKEN" \
            https://api.github.com/repos/${DEPLOY_REPO}/contents/$DEPLOY_CDPFILE \
            -d "$(jq -nc \
                --arg content "$(base64 /media/ROOTCA/crl/root_ca.crl)" \
                --arg branch "$BRNAME" \
                --arg sha "$EXISTING_SHA" \
                '{
                    "message":"update certificate revocation list",
                    "branch":$branch,
                    "content":$content,
                    "sha":$sha
                }'
            )"
    else
        curl -s -X PUT \
            -H "Authorization: token $TOKEN" \
            https://api.github.com/repos/${DEPLOY_REPO}/contents/${DEPLOY_CDPFILE} \
            -d "$(jq -nc \
                --arg content "$(base64 /media/ROOTCA/crl/root_ca.crl)" \
                --arg branch "$BRNAME" \
                '{
                    "message":"update certificate revocation list",
                    "branch":$branch,
                    "content":$content
                }'
            )"
    fi
fi

curl -s -X POST \
    -H "Authorization: token $TOKEN" \
    https://api.github.com/repos/${DEPLOY_REPO}/pulls \
    -d "$(jq -nc \
        --arg title "$PRTITLE" \
        --arg body "$PRBODY" \
        --arg branch "$BRNAME" \
        --arg base "$DEPLOY_BRANCH" \
        '{
            "title":$title,
            "body":$body,
            "head":$branch,
            "base":$base
        }'
    )"
