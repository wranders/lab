#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata mount <DEVICE> <ARGUMENT>
arguments:
    -a,--all    mount all partitions
                by default, only ROOTCASEC and ROOTCA are mount
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG='help,all'
OPTSSHORT='h'
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare ALL=false
while true; do
    case $1 in
        -h|--help)  usage; exit 0   ;;
        --all)      ALL=true        ;;
        --)         shift; break    ;;
    esac; shift
done

cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
declare -a PGMS=(lsblk mkdir mount cryptsetup)
MPGMS=()
for pgm in \${PGMS[@]}; do
    if ! command -v \$pgm &>/dev/null; then MPGMS+=(\$pgm); fi
done
if [[ \${#MPGMS[@]} -ne 0 ]]; then
    echo 'the following commands are required and missing:'
    echo -e "\\t\${MPGMS[@]}"; echo 'exiting...'; exit 1
fi
lsblk $1 &>/dev/null
if [ \$? -ne 0 ]; then echo "there was an error accessing $1"; exit 1; fi
USER=\$(who | awk '{print \$1}')
RUNDIR="/run/media/\$USER"
mkdir -p \$RUNDIR
chown \$USER:\$USER \$RUNDIR
declare -a PARTS=()
for p in $1*[0-9]; do
    cryptsetup isLuks \$p
    if [[ \$? -eq 0 ]]; then
        LABEL=\$(cryptsetup luksDump \$p | grep Label | cut -f2)
        if [[ $ALL == false ]]; then
            if [[ \$LABEL == "YUBISEC" ]] || [[ \$LABEL == "ROOTCAKEY" ]] ; then
                continue
            fi
        fi
        PASSWD=\$(pinentry-curses -T $(tty) -C UTF-8 <<<"
SETDESC Please enter a passphrase for the \${LABEL} volume [leave empty to skip]
SETPROMPT Passphrase:
GETPIN
" | sed -nr '0,/^D (.+)/s//\1/p' )
        if [[ \${PASSWD+x} && \$PASSWD ]]; then
            PARTS+=("true \$p \$PASSWD")
        fi
    else
        PARTS+=("false \$p none")
    fi
done
for part in \${!PARTS[@]}; do
    read -a p <<< "\${PARTS[\$part]}"
    if [[ \${p[0]} == true ]]; then
        UUID=\$(cryptsetup luksUUID \${p[1]})
        echo -n \${p[2]} | \
            cryptsetup open \${p[1]} --type=luks "luks-\${UUID}" -d -
        BLK="/dev/mapper/luks-\${UUID}"
    else
        BLK=\${p[1]}
    fi
    LABEL=\$(lsblk -noLABEL \$BLK)
    mkdir -p \$RUNDIR/\$LABEL
    mount \$BLK \$RUNDIR/\$LABEL -o uid=\$USER -o gid=\$USER
    echo "'\${LABEL}' mounted to '\${RUNDIR}/\${LABEL}'"
done
EOF
