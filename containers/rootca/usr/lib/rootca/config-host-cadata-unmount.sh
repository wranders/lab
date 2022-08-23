#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata unmount <DEVICE> <ARGUMENT>
arguments:
    -h,--help   show this dialog
EOF
}

if [ $# -eq 0 ]; then usage; exit 1; fi
OPTSLONG='help'
OPTSSHORT='h'
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
while true; do
    case $1 in
        -h|--help)  usage; exit 0   ;;
        --)         shift; break    ;;
    esac; shift
done

cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
declare -a PGMS=(lsblk umount cryptsetup rm)
MPGMS=()
for pgm in \${PGMS[@]}; do
    if ! command -v \$pgm &>/dev/null; then MPGMS+=(\$pgm); fi
done
if [[ \${#MPGMS[@]} -ne 0 ]]; then
    echo 'the following commands are required and missing:' >$(tty)
    echo -e "\\t\${MPGMS[@]}"; echo 'exiting...' >$(tty)
    exit 1
fi
lsblk $1 &>/dev/null
if [ \$? -ne 0 ]; then
    echo "there was an error accessing $1" >$(tty)
    exit 1
fi
RUNDIR="/run/media/$(who | awk '{print $1}')"
for p in $1*[0-9]; do
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
EOF
