#!/bin/bash

usage() {
    cat <<EOF
usage: rootca config host cadata format <DEVICE> <ARGUMENT>
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
declare -a PGMS=(lsblk wipefs fdisk cryptsetup mkfs.exfat)
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

getanswer() { sed -nr '0,/^D (.+)/s//\1/p'; }

getpasswd() {
    PASSWD1=\$(pinentry-curses -T $(tty) -C UTF-8 <<<"
SETDESC Please enter a passphrase for the \$1 volume
SETPROMPT Passphrase:
GETPIN
" | getanswer )
    if [[ -z \$PASSWD1 ]]; then
        echo "Passphrase was empty or operation cancelled" > $(tty)
        return 1
    fi
    PASSWD2=\$(pinentry-curses -T $(tty) -C UTF-8 <<<"
SETDESC Please re-enter the passphrase for the \$1 volume
SETPROMPT Passphrase:
GETPIN
" | getanswer )
    if [[ -z \$PASSWD2 ]]; then
        echo "Passphrase was empty or operation cancelled" > $(tty)
        return 1
    fi
    if [[ \$PASSWD1 != \$PASSWD2 ]]; then
        echo "\$1 passphrases do not match" > $(tty)
        return 1
    else
        echo \$PASSWD1
        return 0
    fi
}

YUBISEC_PASSWD=\$(getpasswd YUBISEC)
[ \$? -ne 0 ] && exit 1;
ROOTCAKEY_PASSWD=\$(getpasswd ROOTCAKEY)
[ \$? -ne 0 ] && exit 1;
ROOTCASEC_PASSWD=\$(getpasswd ROOTCASEC)
[ \$? -ne 0 ] && exit 1;

declare -a PARTS=()
PARTS+=("YUBISEC \${YUBISEC_PASSWD}")
PARTS+=("ROOTCAKEY \${ROOTCAKEY_PASSWD}")
PARTS+=("ROOTCASEC \${ROOTCASEC_PASSWD}")

LUKS_GUID="CA7D7CCB-63ED-4C53-861C-1742536059CC"
EXFAT_GUID="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
wipefs -af ${1}* 1>/dev/null
echo 'device wiped...'
FDISKDO="g\nn\n\n\n+64M\nt\n\${LUKS_GUID}\n"
FDISKDO+="n\n\n\n+64M\nt\n\n\${LUKS_GUID}\n"
FDISKDO+="n\n\n\n+64M\nt\n\n\${LUKS_GUID}\n"
FDISKDO+="n\n\n\n\nt\n\n\${EXFAT_GUID}\nw\n"
echo -ne \$FDISKDO | fdisk $1 1>/dev/null
echo 'partitions created...'
for i in \${!PARTS[@]}; do
    read -a p <<< "\${PARTS[\$i]}"
    declare PARTNUM=\$((\$i+1))
    echo -n "\${p[0]} creating..."
    echo -n \${p[1]} | cryptsetup -q luksFormat --label \${p[0]} $1\${PARTNUM} -d -
    echo -n "created..."
    declare UUID=\$(cryptsetup luksUUID $1\${PARTNUM})
    echo -n \${p[1]} | cryptsetup open $1\${PARTNUM} "luks-\${UUID}" -d -
    echo -n "opened..."
    mkfs.exfat -L \${p[0]} "/dev/mapper/luks-\${UUID}" 1>/dev/null
    echo -n "formatted..."
    cryptsetup close "luks-\${UUID}" &>/dev/null
    echo "closed"
done
mkfs.exfat -L ROOTCA "$1\$((\${#PARTS[@]}+1))" 1>/dev/null
echo 'ROOTCA formatted...'
EOF
