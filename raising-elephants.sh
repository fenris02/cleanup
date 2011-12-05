#/bin/bash

LANG=C

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

# Try this first:
shutdown -r now

sysctl -w kernel.sysrq=1 || echo 1 > /proc/sys/kernel/sysrq

#https://secure.wikimedia.org/wikipedia/en/wiki/Magic_SysRq_key#.22Raising_Elephants.22_mnemonic_device
# "Raising Elephants Is So Utterly Boring"
for ST in r e i s s s u b; do
  echo $ST > /proc/sysrq-trigger
done

#EOF
