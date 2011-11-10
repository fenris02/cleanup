#!/bin/bash

LANG=C
DS=$(date +%Y%d%m)
TMPDIR=/root/tmp
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

[ -x /usr/sbin/semanage ] || yum install -y policycoreutils-python
[ -x /usr/sbin/setenforce ] || yum install -y libselinux-utils

semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
setenforce 0

mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
install -d -m 0755 -o root -g root /etc/selinux/targeted
yum reinstall -y selinux-policy-targeted selinux-policy

semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
setenforce 1

#EOF
