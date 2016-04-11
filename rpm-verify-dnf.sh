#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
# Mirrored on https://fedoraproject.org/wiki/User:Fenris02/Distribution_upgrades_and_cleaning_up_after_them
# Trimmed to remove any features DNF lacks.

LANG=C
if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

DS=$(/bin/date +%Y%m%d)
TMPDIR=$(/bin/mktemp -d "${TMPDIR:-/tmp}/${0##*/}-XXXXX.log")
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

if [ -f /etc/sysconfig/prelink ]; then
  echo "Updating prelink info ..."
  . /etc/sysconfig/prelink \
  time /usr/sbin/prelink -av $PRELINK_OPTS >> /var/log/prelink/prelink.log 2>&1
fi

/sbin/ldconfig

# Remove temporary files
/bin/rm /var/lib/rpm/__db.00?

echo "rpm-Va: This may take 12mins or longer, please wait ... (Might be a good time for coffee)"
time /bin/rpm -Va > "${TMPDIR}/rpm-va2_${DS}.txt" 2>&1
# Filter out prelink messages, kmod files, and kernel-devel files:
/bin/egrep -v '^(prelink: /|S\..\.\.\.\.\.\.    /|.{9}    /lib/modules/.*/modules\.|.{9}    /usr/src/kernels/)' \
  "${TMPDIR}/rpm-va2_${DS}.txt > ${TMPDIR}/RPM-VA2_${DS}.txt"

echo "Generating reports ..."
/bin/egrep -v '^.{9}  c /' "${TMPDIR}/RPM-VA2_${DS}.txt" > "${TMPDIR}/URGENT-REVIEW_${DS}.txt"
/bin/egrep '^.{9}  c /' "${TMPDIR}/RPM-VA2_${DS}.txt" > "${TMPDIR}/REVIEW-CONFIGS_${DS}.txt"
/bin/find /etc -name '*.rpm?*' > "${TMPDIR}/REVIEW-OBSOLETE-CONFIGS_${DS}.txt"

echo "Requesting extra reporting tools to be installed ..."
dnf install fpaste rpmdevtools policycoreutils-python

if [ -x /usr/sbin/semanage ]; then
  echo "Reporting SELinux policy ..."
  TMPF=$(/bin/mktemp -u "/tmp/${0##*/}-XXXXX.txt")
  /usr/sbin/semanage -o "$TMPF"
  /bin/mv "$TMPF" "${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt"
fi

if [ -x /usr/bin/rpmdev-rmdevelrpms ]; then
  echo "Reporting devel packages"
  /usr/bin/rpmdev-rmdevelrpms -l > "${TMPDIR}/SHOW-DEVELRPMS_${DS}.txt"
fi

echo "Reporting Problem RPMs"
/bin/rpm -Va --nofiles --noscripts > "${TMPDIR}/PROBLEM-PACKAGES_${DS}.txt"

echo "Collect list of enabled repos"
/usr/bin/dnf repolist > "${TMPDIR}/YUM-REPOLIST_${DS}.txt"

echo "Collecting distribution-synchronization differences"
echo n |\
  /usr/bin/dnf distro-sync |\
  /bin/sed -e '1,/Dependencies Resolved/d;' > "${TMPDIR}/YUM-DISTROSYNC_${DS}.txt"

/bin/cat - <<EOT
==========
TMPDIR = ${TMPDIR}
==========
##### The following all break fpaste, so concatenate below instead:
#/usr/bin/fpaste ${TMPDIR}/[A-Z]*_${DS}.txt
## (excluding ${TMPDIR}/RPM-VA2_${DS}.txt to avoid duplicate info)
#/usr/bin/fpaste ${TMPDIR}/{REVIEW,SHOW,URGENT}*_${DS}.txt
==========
EOT

for fp in ${TMPDIR}/{YUM-REPOLIST,YUM-DISTROSYNC,URGENT-REVIEW,REVIEW-CONFIGS,PROBLEM-PACKAGES,DUPLICATE-PACKAGES,ORPHANED-PACKAGES,REVIEW-OBSOLETE-CONFIGS,SELINUX-CUSTOM-CONFIG,SHOW-DEVELRPMS,SHOW-EXTERNAL,SHOW-LEAVES,SHOW-INSTALLED2}*_${DS}.txt; do
  if [ -s "$fp" ]; then
    /bin/cat - >> "${TMPDIR}/fpaste-output_${DS}.txt" <<EOT
===============================================================================
===== $fp
===============================================================================
EOT
    ### Limit each output file to 1000 lines to prevent excessive flooding.
    WCL=$(/usr/bin/wc -l "$fp" |/usr/bin/gawk '{print$1}')
    if [ "$WCL" -gt 1000 ]; then
      echo "*** File $fp truncated to 1000 lines, was $WCL lines. ***"
      echo "*** File $fp truncated to 1000 lines, was $WCL lines. ***" >> "${TMPDIR}/fpaste-output_${DS}.txt"
    fi
    /usr/bin/head -n1000 "$fp" >> "${TMPDIR}/fpaste-output_${DS}.txt"
  fi
done
echo "fpaste ${TMPDIR}/fpaste-output_${DS}.txt"

if [ "x$1" != "xNOPOST" ]; then
  /usr/bin/fpaste "${TMPDIR}/fpaste-output_${DS}.txt"
fi

#EOF
