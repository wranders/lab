#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata sync <ARGUMENT>
arguments:
    -h,--help   show this dialog
    --source    source device
    --dest      destination device
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG='help,source:,dest:,all'
OPTSSHORT='h'
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare SOURCE DEST ALL=false
while true; do
    case $1 in
        -h|--help)  usage; exit 0       ;;
        --source)   shift; SOURCE=$1    ;;
        --dest)     shift; DEST=$1      ;;
        --all)      ALL=true            ;;
        --)         shift; break        ;;
    esac; shift
done
if [[ -z $SOURCE ]] || [[ -z $DEST ]]; then
    echo 'both source and destination device must be set'
    usage; exit 1
fi

cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
declare -a PGMS=(lsblk cryptsetup uniq rsync)
MPGMS=()
for pgm in \${PGMS[@]}; do
    if ! command -v \$pgm &>/dev/null; then MPGMS+=(\$pgm); fi
done
if [[ \${#MPGMS[@]} -ne 0 ]]; then
    echo 'the following commands are required and missing:'
    echo -e "\\t\${MPGMS[@]}"; echo 'exiting...'; exit 1
fi
lsblk $SOURCE &>/dev/null
if [ \$? -ne 0 ]; then echo "there was an error accessing $SOURCE"; exit 1; fi
lsblk $DEST &>/dev/null
if [ \$? -ne 0 ]; then echo "there was an error accessing $DEST"; exit 1; fi

printismounted() {
    echo "a partition on device \$1 is mounted" >$(tty)
    echo "unmount it first using 'rootca config host cadata unmount \$1'" >$(tty)
}

isanymounted() {
    for p in \$1*[0-9]; do
        cryptsetup isLuks \$p
        if [[ \$? -eq 0 ]]; then
            UUID=\$(cryptsetup luksUUID \$p)
            PROC=\$(cat /proc/mounts | grep "\$UUID")
            if [[ \$? -eq 0 ]]; then
                printismounted \$1
                return 1
            fi
        else
            PROC=\$(cat /proc/mounts | grep "\$p")
            if [[ \$? -eq 0 ]]; then
                printismounted \$1
                return 1
            fi
        fi
    done
    return 0
}

isanymounted $SOURCE
[ \$? -ne 0 ] && exit 1
isanymounted $DEST
[ \$? -ne 0 ] && exit 1

printincorrectpt() {
    echo "\$1 has incorrect partition structure" >$(tty)
    echo "format device with 'rootca config host cadata format \$1'" >$(tty)
}

isptcorrect() {
    PARTCOUNT=\$(fdisk -l \$1 | grep "\$1" | sed '/^Disk/d' | wc -l)
    if [[ \$PARTCOUNT -ne 4 ]]; then
        printincorrectpt \$1
        return 1
    fi
    for p in \$1*[1-3]; do
        cryptsetup isLuks \$p
        if [[ \$? -ne 0 ]]; then
            printincorrectpt \$1
            return 1
        fi
    done
    DATAFS=\$(lsblk -noFSTYPE \$1*4)
    if [[ \$DATAFS != "exfat" ]]; then
        printincorrectpt \$1
        return 1
    fi
    return 0
}

isptcorrect $SOURCE
[ \$? -ne 0 ] && exit 1
isptcorrect $DEST
[ \$? -ne 0 ] && exit 1

USER=\$(who | awk '{print \$1}')
RUNDIR="/run/media/\${USER}"
mkdir -p \$RUNDIR
chown \${USER}:\${USER} \$RUNDIR
declare -a PARTS=()
declare -a TOSYNC=()

getparts() {
    for p in \$1*[0-9]; do
        cryptsetup isLuks \$p
        if [[ \$? -eq 0 ]]; then
            LABEL=\$(cryptsetup luksDump \$p | grep Label | cut -f2)
            if [[ $ALL == false ]]; then
                if [[ \$LABEL == "YUBISEC" ]] || [[ \$LABEL == "ROOTCAKEY" ]] || [[ \$LABEL == "ROOTCASEC" ]]; then
                    continue
                fi
            fi
            PASSWD=\$(pinentry-curses -T $(tty) -C UTF-8 <<<"
SETDESC Please enter a passphrase for the \${2} \${LABEL} volume [leave empty to skip]
SETPROMPT Passphrase:
GETPIN
" | sed -nr '0,/^D (.+)/s//\1/p' )
            if [[ \${PASSWD+x} && \$PASSWD ]]; then
                PARTS+=("true \$p \$PASSWD \${2}")
                TOSYNC+=("\${LABEL}")
            fi
        else
            PARTS+=("false \$p none \${2}")
            LABEL=\$(lsblk -noLABEL \$p | uniq )
            TOSYNC+=("\${LABEL}")
        fi
    done
}

getparts $SOURCE SOURCE
getparts $DEST DEST

for part in \${!PARTS[@]}; do
    read -a p <<< "\${PARTS[\$part]}"
    if [[ \${p[0]} == true ]]; then
        UUID=\$(cryptsetup luksUUID \${p[1]})
        echo -n "\${p[2]}" | cryptsetup open \${p[1]} --type=luks "luks-\${UUID}" -d -
        BLK="/dev/mapper/luks-\${UUID}"
    else
        BLK=\${p[1]}
    fi
    LABEL=\$(lsblk -noLABEL \$BLK)
    mkdir -p "\${RUNDIR}/\${LABEL}_\${p[3]}"
    mount \$BLK "\${RUNDIR}/\${LABEL}_\${p[3]}" -o uid=\$USER -o gid=\$USER
    echo "\${p[3]} '\${LABEL}' mounted to '\${RUNDIR}/\${LABEL}_\${p[3]}'"
done


for vol in \$(for l in "\${TOSYNC[@]}"; do echo "\${l}"; done | sort -u); do
    rsync -a "\${RUNDIR}/\${vol}_SOURCE/" "\${RUNDIR}/\${vol}_DEST"
    echo "'\${RUNDIR}/\${vol}_SOURCE' syncronized to '\${RUNDIR}/\${vol}_DEST'"
done

unmountdevice() {
    for p in \$1*[0-9]; do
        cryptsetup isLuks \$p
        if [[ \$? -eq 0 ]]; then
            UUID=\$(cryptsetup luksUUID \$p)
            cryptsetup status "luks-\${UUID}" &> /dev/null
            if [[ \$? -eq 0 ]]; then
                MOUNTPOINT=\$(lsblk -noMOUNTPOINTS "/dev/mapper/luks-\${UUID}")
                LABEL=\$(lsblk -noLABEL "/dev/mapper/luks-\${UUID}")
                if [[ \${#MOUNTPOINT} -ne 0 ]]; then
                    umount \$MOUNTPOINT
                    rm -rf \$MOUNTPOINT
                fi
                cryptsetup close "luks-\${UUID}"
                echo "\$p ('\${LABEL}') unmounted" >$(tty)
            fi
        else
            PROC=\$(cat /proc/mounts | grep "\$p")
            if [[ \$? -eq 0 ]]; then
                LABEL=\$(lsblk -noLABEL \$p | uniq)
                MOUNTPOINT=\$(echo \$PROC | cut -d' ' -f2)
                umount \$MOUNTPOINT
                rm -rf \$MOUNTPOINT
                echo "\$p ('\${LABEL}') unmounted" >$(tty)
            fi
        fi
    done
}

unmountdevice $SOURCE
unmountdevice $DEST
EOF
