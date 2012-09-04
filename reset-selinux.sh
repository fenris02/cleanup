#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

DS=$(/bin/date +%Y%m%d)
LANG=C
TMPDIR=$(/bin/mktemp -d ${TMPDIR:-/tmp}/${0##*/}-XXXXX.log)
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

[ -x /usr/sbin/setenforce ] || yum install -y libselinux-utils
/usr/sbin/setenforce 0

[ -x /usr/sbin/semanage ] || yum install -y policycoreutils-python
/usr/sbin/semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

/bin/mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
/usr/bin/install -d -m 0755 -o root -g root /etc/selinux/targeted
/usr/bin/yum reinstall -y \
  libselinux{,-python,utils} \
  policycoreutils{,-newrole,-restorecond,-sandbox} \
  selinux-policy{,-targeted} \
  #

/usr/sbin/semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

[ -x /sbin/fixfiles ] || yum install -y policycoreutils
echo "Resetting selinux labels for packaged files ... this may take some time."
time /sbin/fixfiles -R -a restore

/usr/sbin/setenforce 1

#EOF
