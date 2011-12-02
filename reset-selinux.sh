#!/bin/bash

LANG=C
DS=$(date +%Y%d%m)
TMPDIR=/root/tmp
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

[ -x /usr/sbin/semanage ] || yum install -y policycoreutils-python
[ -x /usr/sbin/setenforce ] || yum install -y libselinux-utils

setenforce 0
semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
install -d -m 0755 -o root -g root /etc/selinux/targeted
yum reinstall -y selinux-policy{,-targeted} policycoreutils{,-newrole,-restorecond,-sandbox}

semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
setenforce 1

#EOF
