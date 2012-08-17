#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
LANG=C
if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

DS=$(/bin/date +%Y%d%m)
TMPDIR=$(/bin/mktemp -d ${TMPDIR:-/tmp}/${0##*/}-XXXXX.log)
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

if [ -f /etc/sysconfig/prelink ]; then
  echo "Updating prelink info ..."
  . /etc/sysconfig/prelink \
  time /usr/sbin/prelink -av $PRELINK_OPTS >> /var/log/prelink/prelink.log 2>&1
fi

/sbin/ldconfig

echo "rpm-Va: This may take 12mins or longer, please wait ... (Might be a good time for coffee)"
time /bin/rpm -Va > ${TMPDIR}/rpm-va2_${DS}.txt 2>&1
# Filter out prelink messages, kmod files, and kernel-devel files:
/bin/egrep -v '^(prelink: /|S\..\.\.\.\.\.\.    /|.{9}    /lib/modules/.*/modules\.|.{9}    /usr/src/kernels/)' \
  ${TMPDIR}/rpm-va2_${DS}.txt > ${TMPDIR}/RPM-VA2_${DS}.txt
echo "Generating reports ..."
/bin/egrep -v '^.{9}  c /' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/URGENT-REVIEW_${DS}.txt
/bin/egrep '^.{9}  c /' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/REVIEW-CONFIGS_${DS}.txt
/bin/find /etc -name '*.rpm?*' > ${TMPDIR}/REVIEW-OBSOLETE-CONFIGS_${DS}.txt

echo "Requesting extra reporting tools to be installed ..."
/usr/bin/yum -q install /usr/sbin/semanage /usr/bin/rpmdev-rmdevelrpms /usr/bin/show-installed /usr/sbin/yumdb

if [ -x /usr/sbin/semanage ]; then
  echo "Reporting SELinux policy ..."
  /usr/sbin/semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
fi

if [ -x /usr/bin/rpmdev-rmdevelrpms ]; then
  echo "Reporting devel packages"
  /usr/bin/rpmdev-rmdevelrpms -l > ${TMPDIR}/SHOW-DEVELRPMS_${DS}.txt
fi

echo "Finding installed packages ..."
if [ -x /usr/bin/show-installed ]; then
  /usr/bin/show-installed -f kickstart -e -o ${TMPDIR}/SHOW-INSTALLED2_${DS}.txt
else
  $(dirname $0)/show-installed -f kickstart -e -o ${TMPDIR}/SHOW-INSTALLED2_${DS}.txt
fi
/bin/sort -o ${TMPDIR}/SHOW-INSTALLED2_${DS}.txt ${TMPDIR}/SHOW-INSTALLED2_${DS}.txt

if [ -x /usr/sbin/yumdb ]; then
  echo "Locating rpm packages that were installed without yum ..."
  /usr/sbin/yumdb unset from_repo > ${TMPDIR}/SHOW-EXTERNAL_${DS}.txt
fi

cat - <<EOT
==========
TMPDIR = ${TMPDIR}
==========
##### The following all break fpaste, so concatenate below instead:
#/usr/bin/fpaste ${TMPDIR}/[A-Z]*_${DS}.txt
## (excluding ${TMPDIR}/RPM-VA2_${DS}.txt to avoid duplicate info)
#/usr/bin/fpaste ${TMPDIR}/{REVIEW,SHOW,URGENT}*_${DS}.txt
==========
EOT

for fp in ${TMPDIR}/{REVIEW,SELINUX,SHOW,URGENT}*_${DS}.txt; do
  /bin/cat - >> ${TMPDIR}/fpaste-output_${DS}.txt <<EOT
===============================================================================
===== $fp
===============================================================================
EOT
  /bin/cat $fp >> ${TMPDIR}/fpaste-output_${DS}.txt
done
echo fpaste ${TMPDIR}/fpaste-output_${DS}.txt
/usr/bin/fpaste ${TMPDIR}/fpaste-output_${DS}.txt

#EOF
