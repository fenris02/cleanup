#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

TMPDIR=$(/bin/mktemp -d ${TMPDIR:-/tmp}/${0##*/}-XXXXX.log)
LANG=C
DS=$(/bin/date +%Y%d%m)

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

echo "This may take up to 7.5mins, please wait ..."
time /bin/rpm -Va > ${TMPDIR}/RPM-VA2_${DS}.txt 2>&1
/bin/egrep -v '^.{9}  (c /|  /lib/modules/.*/modules\.)' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/URGENT-REVIEW_${DS}.txt
/bin/egrep '^.{9}  c /' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/REVIEW-CONFIGS_${DS}.txt
/bin/find /etc -name '*.rpm?*' > ${TMPDIR}/REVIEW-OBSOLETE-CONFIGS_${DS}.txt

/usr/bin/fpaste ${TMPDIR}/[A-Z]*_${DS}.txt

#EOF
