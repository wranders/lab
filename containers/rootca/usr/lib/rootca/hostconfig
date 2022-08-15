#!/bin/bash

check_root() {
    if [ $EUID -ne 0 ]; then
        echo 'requires root/sudo permissions'
        exit 1
    fi
}

check_pgms() {
    PGMS=$1
    MISSING_PGMS=()
    for pgm in ${PGMS[@]}; do
        if ! command -v $pgm &> /dev/null; then
            MISSING_PGMS+=($pgm)
        fi
    done
    if [[ ${#MISSING_PGMS[@]} != 0 ]]; then
        echo "the following commands are required and missing:"
        echo -e "\t${MISSING_PGMS[@]}"
        echo "exiting..."
        exit 1
    fi
}

install_selpolicy() {
    check_root
    declare -a PGMS=(mktemp cat semodule rm)
    for pgm in ${PGMS[@]}; do
        command -v $pgm $>/dev/null
        if [ $? -ne 0 ]; then echo "program ${pgm} required; exiting..."; exit 1; fi
    done
    DIR=$(mktemp -d)
    FILE="workbox_container_usb.cil"
    cat <<EOF > $DIR/$FILE
(typeattributeset cil_gen_require container_t)
(typeattributeset cil_gen_require usb_device_t)
(allow container_t usb_device_t (chr_file (getattr ioctl open read write)))
EOF
    echo "Installing SELinux policy for container USB access..."
    semodule -i $DIR/$FILE
    rm -rf $DIR
    exit 0
}

install_udevrule() {
    check_root
    declare -a PGMS=(cat udevadm)
    for pgm in ${PGMS[@]}; do
        command -v $pgm $>/dev/null
        if [ $? -ne 0 ]; then echo "program ${pgm} required; exiting..."; exit 1; fi
    done
    FILE="/etc/udev/rules.d/99-yubikey-user-write.rules"
    echo "Writing udev rule to '${FILE}' ..."
    cat <<'EOF' > $FILE
SUBSYSTEM=="usb", \
    ATTRS{idVendor}=="1050", \
    ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
    SYMLINK+="yubikey$attr{serial}", \
    MODE="0666"
EOF
    udevadm control --reload
    udevadm trigger
    exit 0
}

format_cadata() {
    if [ $# -eq 0 ]; then usage; exit 1; fi
    check_root
    declare -a PGMS=(lsblk wipefs fdisk cryptsetup mkfs.exfat)
    check_pgms $PGMS
    DEV=$1
    EXISTS=$(lsblk $DEV &>/dev/null)
    if [ $? -ne 0 ]; then echo "there was an error accessing ${DEV}"; exit 1; fi
    declare -a PARTS=()
    read -sp 'Enter passphrase for YUBISEC volume:' YUBISEC_PASSWD
    echo
    PARTS+=("YUBISEC ${YUBISEC_PASSWD}")
    read -p 'Create encrypted volume to store Root CA private key? [y/N]' yn
    if [[ "$yn" == [Yy]* ]]; then
        read -sp 'Enter passphrase for ROOTCAKEY volume:' ROOTCAKEY_PASSWD
        echo
        PARTS+=("ROOTCAKEY ${ROOTCAKEY_PASSWD}")
    fi
    LUKS_GUID="CA7D7CCB-63ED-4C53-861C-1742536059CC"
    EXFAT_GUID="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
    wipefs -af ${DEV}* 1>/dev/null
    echo 'device wiped...'
    FDISKDO="g\nn\n\n\n+64M\nt\n${LUKS_GUID}\n"
    if [[ "$ROOTCAKEY_PASSWD" != "" ]]; then
        FDISKDO+="n\n\n\n+64M\nt\n\n${LUKS_GUID}\n"
    fi
    FDISKDO+="n\n\n\n\nt\n\n${EXFAT_GUID}\nw\n"
    echo -ne "$FDISKDO" | fdisk $DEV 1>/dev/null
    echo 'partitions created...'
    for i in ${!PARTS[@]}; do
        read -a p <<< "${PARTS[$i]}"
        local PARTNUM=$(($i+1))
        echo -n "${p[0]} creating..."
        echo -n ${p[1]} | cryptsetup -q luksFormat --label ${p[0]} ${DEV}${PARTNUM} -d -
        echo -n "created..."
        local UUID=$(cryptsetup luksUUID ${DEV})
        echo -n ${p[1]} | cryptsetup open ${DEV}${PARTNUM} "luks-${UUID}" -d -
        echo -n "opened..."
        mkfs.exfat -L ${p[0]} "/dev/mapper/luks-${UUID}" 1>/dev/null
        echo -n "formatted..."
        cryptsetup close "luks-${UUID}" &>/dev/null
        echo "closed"
    done
    mkfs.exfat -L ROOTCA "${DEV}$((${#PARTS[@]}+1))" 1>/dev/null
    echo 'ROOTCA formatted...'
    unset YUBISEC_PASSWD ROOTCAKEY_PASSWD parts
}

mount_cadata() {
    if [ $# -eq 0 ]; then usage; exit 1; fi
    check_root
    declare -a PGMS=(lsblk mkdir mount cryptsetup)
    check_pgms $PGMS
    DEV=$1
    lsblk $DEV &>/dev/null
    if [ $? -ne 0 ]; then echo "there was an error accessing ${DEV}"; exit 1; fi
    USER=$(who | awk '{print $1}')
    RUNDIR="/run/media/$USER"
    mkdir -p $RUNDIR
    chown $USER:$USER $RUNDIR
    declare -a PARTS=()
    for p in $DEV*[0-9]; do
        cryptsetup isLuks $p
        if [[ $? -eq 0 ]]; then
            LUKSLABEL=$(cryptsetup luksDump $p | grep Label | cut -f2)
            read -sp "Enter password for '${LUKSLABEL}' [leave empty to skip]:" PASSWD
            echo
            if [[ ${PASSWD+x} && $PASSWD ]]; then
                PARTS+=("true $p $PASSWD")
            fi
        else
            PARTS+=("false $p none")
        fi
    done
    for part in ${!PARTS[@]}; do
        read -a p <<< "${PARTS[$part]}"
        if [[ ${p[0]} == true ]]; then
            UUID=$(cryptsetup luksUUID ${p[1]})
            echo -n ${p[2]} | cryptsetup open ${p[1]} --type=luks "luks-${UUID}" -d -
            BLK="/dev/mapper/luks-${UUID}"
        else
            BLK=${p[1]}
        fi
        LABEL=$(lsblk -noLABEL $BLK)
        mkdir -p $RUNDIR/$LABEL
        mount $BLK $RUNDIR/$LABEL -o uid=$USER -o gid=$USER
        echo "'${LABEL}' mounted to '${RUNDIR}/${LABEL}'"
    done
}

umount_cadata() {
    if [ $# -eq 0 ]; then usage; exit 1; fi
    check_root
    declare -a PGMS=(lsblk umount cryptsetup rm)
    check_pgms $PGMS
    DEV=$1
    EXISTS=$(lsblk $DEV &>/dev/null)
    if [ $? -ne 0 ]; then echo "there was an error accessing ${DEV}"; exit 1; fi
    RUNDIR="/run/media/$(who | awk '{print $1}')"
    for p in $DEV*[0-9]; do
        cryptsetup isLuks $p
        if [[ $? -eq 0 ]]; then
            UUID=$(cryptsetup luksUUID $p)
            cryptsetup status "luks-${UUID}" &> /dev/null
            if [[ $? -eq 0 ]]; then
                MOUNTPOINT=$(lsblk -noMOUNTPOINTS "/dev/mapper/luks-${UUID}")
                LABEL=$(lsblk -noLABEL "/dev/mapper/luks-${UUID}")
                if [[ ${#MOUNTPOINT} -ne 0 ]]; then
                    umount $MOUNTPOINT
                    rm -rf $MOUNTPOINT
                fi
                cryptsetup close "luks-${UUID}"
                echo "$p ('${LABEL}') unmounted"
            fi
        else
            MOUNTPOINT=$(lsblk -noMOUNTPOINTS $p)
            if [[ ${#MOUNTPOINT} -ne 0 ]]; then
                LABEL=$(lsblk -noLABEL $p)
                umount $MOUNTPOINT
                rm -rf $MOUNTPOINT
                echo "$p ('${LABEL}') unmounted"
            fi
        fi
        
    done
}

usage() {
    cat << EOF
usage: $0 [CMD]
commands:
    install-selpolicy   install SELinux policy allowing containers to access USB
                        devices
    install-udevrule    install udev rule to set predictable names for Yubikey
                        devices
    format-cadata [DEV] format a block device for use to store Yubikey secrets
                        and Root CA data
    mount-cadata [DEV]  mount Root CA data device. empty passwords skip mounting
                        LUKS partitions
    umount-cadata [DEV] unmount Root CA data device
arguments:
    DEV                 root block device path (eg. /dev/sdb)
EOF
}

if [ $# -eq 0 ]; then
    usage
    exit 1;
fi
case "$1" in
    install-selpolicy) install_selpolicy ;;
    install-udevrule) install_udevrule ;;
    format-cadata)
        shift
        format_cadata "$@" ;;
    mount-cadata)
        shift
        mount_cadata "$@" ;;
    umount-cadata)
        shift
        umount_cadata "$@" ;;
    *)
        echo "unknown command '$1'"; usage; exit 1
esac
