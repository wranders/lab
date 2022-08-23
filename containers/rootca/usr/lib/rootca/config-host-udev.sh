#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host udev <ARGUMENT>
    print udev rule to create symbolic links to Yubikey devices in '/dev'
arguments:
    -h,--help   show this dialog
    --install   install rule
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
    echo 'cannot install and uninstall rule'
fi

rule() {
    cat <<'EOF'
SUBSYSTEM=="usb", \
    ATTRS{idVendor}=="1050", \
    ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
    SYMLINK+="yubikey$attr{serial}", \
    TAG+="uaccess"
EOF
}

if [[ $INSTALL == true ]]; then
    cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
command -v udevadm &>/dev/null
if [ \$? -ne 0 ]; then echo 'command "udevadm" not found'; exit 1; fi
cat <<EOD > /etc/udev/rules.d/99-rootca-yubikey.rules
$(rule)
EOD
udevadm control --reload
udevadm trigger
EOF
elif [[ $UNINSTALL == true ]]; then
    cat <<EOF
if [ \$EUID -ne 0 ]; then echo 'requires root/sudo permissions'; exit 1; fi
command -v udevadm &>/dev/null
if [ \$? -ne 0 ]; then echo 'command "udevadm" not found'; exit 1; fi
rm /etc/udev/rules.d/99-rootca-yubikey.rules
udevadm control --reload
udevadm trigger
EOF
else
    echo "By using the '--install' argument, the following rule will be installed:"
    echo
    cat <<'EOF'
    SUBSYSTEM=="usb", \
        ATTRS{idVendor}=="1050", \
        ATTRS{idProduct}=="0401|0402|0403|0404|0405|0406|0407", \
        SYMLINK+="yubikey$attr{serial}", \
        TAG+="uaccess"
EOF
    echo
    echo "To install, run 'rootca config host udev --install | sudo bash'"
    exit 0
fi
