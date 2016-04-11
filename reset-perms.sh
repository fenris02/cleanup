#!/bin/bash

# Partial script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
# Mirrored on https://fedoraproject.org/wiki/User:Fenris02/Distribution_upgrades_and_cleaning_up_after_them

VERBOSE=1
#DS=$(/bin/date +%Y%m%d)
LANG=C
TMPDIR=$(/bin/mktemp -d "${TMPDIR:-/tmp}/${0##*/}-XXXXX.log")
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

if [ "$(/usr/bin/whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

[ -x /usr/sbin/setenforce ] || yum install -y /usr/sbin/setenforce
/usr/sbin/setenforce 0

[ -n "$VERBOSE" ] && echo 'This may take a few minutes, resetting user/group ownership'                                 
time rpm -a --setugids > /dev/null 2>&1                                                                                 
[ -n "$VERBOSE" ] && echo 'This may take a few minutes, resetting permissions'                                          
time rpm -a --setperms > /dev/null 2>&1

[ -n "$VERBOSE" ] && echo 'This may take a few minutes, resetting file capabilities'
time rpm -Va > "${TMPDIR}/rpm-Va0.txt" 2>&1;
awk '/^.{8}P /{print$NF}' "${TMPDIR}/rpm-Va0.txt" \
  |xargs rpm --filecaps -qf \
  |grep '= cap' \
  |while read -r fileName eq fileCaps; do
    setcap "${fileCaps}" "${fileName}"
  done

/usr/sbin/setenforce 1

echo 'You should likely reboot now.'

#EOF
