#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

DS=$(/bin/date +%Y%m%d)
LANG=C
TMPDIR=$(/bin/mktemp -d ${TMPDIR:-/tmp}/${0##*/}-XXXXX.log)
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"
YSHELL=${TMPDIR}/YUM-SHELL_${DS}.txt

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

[ -x /usr/bin/package-cleanup ] || yum install -y yum-utils

# Locate installed leaves packages that were installed as a dep of some other package
repoquery --installed --qf "%{nvra} - %{yumdb_info.reason}" \
  `package-cleanup --leaves -q --all` \
  |grep '\- dep' \
  |while read n a a; do \
    echo remove $n
  done > $YSHELL

if [ -s $YSHELL ]; then
  echo "Leaf packages:"
  cat $YSHELL

  echo ""
  echo "run" >> $YSHELL
  echo "To remove auto-detected leaf packages: yum shell $YSHELL"
else
  rm $YSHELL
  echo "No leaf packages detected."
fi

#EOF
