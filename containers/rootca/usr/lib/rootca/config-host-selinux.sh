#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host selinux <ARGUMENT>
    print SELinux policy to allow containers to mount USB devices
arguments:
    -h,--help   show this dialog
    --install   install policy
EOF
}

OPTSLONG="help,install,uninstall"
OPTSSHORT="h"
OPTS=$(getopt -l "$OPTSLONG" -o "$OPTSSHORT" -a -- "$@")
eval set -- "$OPTS"
declare INSTALL=false UNINSTALL=false
while true; do
    case $1 in
        -h,--help)      usage; exit 0 ;;
        --install)      INSTALL=true ;;
        --uninstall)    UNINSTALL=true ;;
        --)             shift; break ;;
    esac; shift
done
if [[ $INSTALL == true ]] && [[ $UNINSTALL == true ]]; then
    echo 'cannot install and uninstall rule'; exit 1
fi

policy() {
    cat <<EOF
(typeattributeset cil_gen_require container_t)
(typeattributeset cil_gen_require usb_device_t)
(allow container_t usb_device_t (chr_file (getattr ioctl open read write)))
EOF
}

if [[ $INSTALL == true ]]; then
    cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
command -v semodule &>/dev/null
if [ \$? -ne 0 ]; then echo 'command "semodule" not found'; exit 1; fi
policy() {
    cat <<EOD
$(policy)
EOD
}
DIR=\$(mktemp -d)
policy > \$DIR/container_usb.cil
semodule -i \$DIR/container_usb.cil
rm -rf \$DIR
EOF
elif [[ $UNINSTALL == true ]]; then
    cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
command -v semodule &>/dev/null
if [ \$? -ne 0 ]; then echo 'command "semodule" not found'; exit 1; fi
semodule -r container_usb
EOF
else
    echo "By using the '--install' argument, the following policy will be installed:"
    echo
    cat <<EOF
    (typeattributeset cil_gen_require container_t)
    (typeattributeset cil_gen_require usb_device_t)
    (allow container_t usb_device_t (chr_file (getattr ioctl open read write)))
EOF
    echo
    echo 'If the CIL format is unfamiliar, this is the TE implementation of the above:'
    echo
    cat <<EOF
    module container_usb 1.0;
    require {
        type container_t;
        type usb_device_t;
        class chr_file { getattr ioctl open read write };
    }
    allow container_t usb_device_t:chr_file { getattr ioctl open read write };
EOF
    echo
    echo "To install, run 'rootca config host selinux --install | sudo bash'"
    exit 0
fi
