#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
# Mirrored on https://fedoraproject.org/wiki/User:Fenris02/Distribution_upgrades_and_cleaning_up_after_them
# From http://fedorapeople.org/cgit/fenris02/public_git/cleanup.git/plain/reset-selinux-dnf.sh

DS=$(/bin/date +%Y%m%d)
LANG=C
TMPDIR=$(/bin/mktemp -d ${TMPDIR:-/tmp}/${0##*/}-XXXXX.log)
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

# Collect default selinux mode before beginning
SELINUX=1
[ -f /etc/selinux/config ] && . /etc/selinux/config

[ -x /usr/sbin/setenforce ] || dnf install -y libselinux-utils
/usr/sbin/setenforce 0

[ -x /usr/sbin/semanage ] || dnf install -y policycoreutils-python
/usr/sbin/semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

/bin/mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
/usr/bin/install -d -m 0755 -o root -g root /etc/selinux/targeted
/usr/bin/dnf reinstall -y --noplugins --enablerepo=updates-testing \
  libselinux{,-python,-utils} \
  policycoreutils{,-newrole,-restorecond,-sandbox} \
  selinux-policy{,-targeted} \
  #

/usr/sbin/semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

/usr/sbin/semodule -B

[ -x /sbin/fixfiles ] || dnf install -y policycoreutils
echo "Resetting selinux labels for packaged files ... this may take some time."
time /sbin/fixfiles -R -a restore

echo "Remember to review /etc/selinux/semanage.conf for settings like handle-unknown=deny"

/usr/sbin/setenforce $SELINUX
echo "Rebooting now."

reboot

#EOF
