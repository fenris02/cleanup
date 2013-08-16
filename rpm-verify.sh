#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
LANG=C
if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

DS=$(/bin/date +%Y%m%d)
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

if [ \! -f /var/lib/yum/groups/installed ]; then
  # "group mark convert" converts the automatic data you get without using groups
  # as objects into groups as objects data. This makes it much easier to convert
  # to groups as objects without having to reinstall.
  if [ 0$(rpm -qf /etc/redhat-release --qf '%{version}\n') -gt 18 ]; then
    echo "F19 hack to help from upgrades"
    yum group mark convert
  fi
fi

echo "Requesting extra reporting tools to be installed ..."
# yum -q install fpaste yum-utils rpmdevtools policycoreutils-python
/usr/bin/yum -q install \
  /usr/bin/fpaste \
  /usr/bin/package-cleanup /usr/bin/repoquery /usr/bin/show-installed /usr/sbin/yumdb \
  /usr/bin/rpmdev-rmdevelrpms \
  /usr/sbin/semanage \
  #

if [ -x /usr/sbin/semanage ]; then
  echo "Reporting SELinux policy ..."
  TMPF=$(/bin/mktemp -u /tmp/${0##*/}-XXXXX.txt)
  /usr/sbin/semanage -o $TMPF
  /bin/mv $TMPF ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
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
  /usr/sbin/yumdb --noplugins unset from_repo > ${TMPDIR}/SHOW-EXTERNAL_${DS}.txt
fi

echo "Reporting Problem RPMs"
if [ -x /usr/bin/package-cleanup ]; then
  /usr/bin/package-cleanup -q --problems > ${TMPDIR}/PROBLEM-PACKAGES_${DS}.txt
else
  /bin/rpm -Va --nofiles --noscripts > ${TMPDIR}/PROBLEM-PACKAGES_${DS}.txt
fi

if [ -x /usr/bin/package-cleanup ]; then
  echo "Reporting Duplicate RPMs"
  /usr/bin/package-cleanup -q --dupes > ${TMPDIR}/DUPLICATE-PACKAGES_${DS}.txt
fi

if [ -x /usr/bin/package-cleanup ]; then
  echo "Reporting Orphan RPMs"
  /usr/bin/package-cleanup -q --orphans > ${TMPDIR}/ORPHANED-PACKAGES_${DS}.txt
fi

if [ -x /usr/bin/repoquery ]; then
  echo "Collect leaf RPMs"
  /usr/bin/repoquery --installed --qf "%{nvra} - %{yumdb_info.reason}" \
    `/usr/bin/package-cleanup --leaves -q --all` \
    |/bin/grep '\- dep' \
    |while read n a a; do \
      echo remove $n
    done > ${TMPDIR}/SHOW-LEAVES_${DS}.txt
fi

echo "Collect list of enabled repos"
yum repolist > ${TMPDIR}/YUM-REPOLIST_${DS}.txt

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

for fp in ${TMPDIR}/{YUM-REPOLIST,URGENT-REVIEW,REVIEW-CONFIGS,PROBLEM-PACKAGES,DUPLICATE-PACKAGES,ORPHANED-PACKAGES,REVIEW-OBSOLETE-CONFIGS,SELINUX-CUSTOM-CONFIG,SHOW-DEVELRPMS,SHOW-EXTERNAL,SHOW-LEAVES,SHOW-INSTALLED2}*_${DS}.txt; do
  if [ -s $fp ]; then
    /bin/cat - >> ${TMPDIR}/fpaste-output_${DS}.txt <<EOT
===============================================================================
===== $fp
===============================================================================
EOT
    /bin/cat $fp >> ${TMPDIR}/fpaste-output_${DS}.txt
  fi
done
echo fpaste ${TMPDIR}/fpaste-output_${DS}.txt

if [ "x$1" != "xNOPOST" ]; then
  /usr/bin/fpaste ${TMPDIR}/fpaste-output_${DS}.txt
fi

#EOF
