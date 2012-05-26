#!/bin/bash

# Script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

# Do not set TMPDIR to any tmpfs mount, these files should remain after boot.
TMPDIR=/root/tmp
DEBUG=''
VERBOSE='1'
LOG_ALL='1'

LANG=C
DS=$(date +%Y%d%m)

if [ "$(whoami)" != "root" ]; then
  echo "Must be run as root."
  exit 1
fi

ping -c3 -q 8.8.8.8 > /dev/null
if [ $? -eq 1 ]; then
  echo "Please ensure you have network connectivity."
  exit 2
fi

if [ $(runlevel |awk '{print$NF}') != "3" ]; then
  echo "Must be run from runlevel 3."
  exit 3
fi

cat -<<EOT
Press ^C now if you do not have a good backup of your system.

Please make sure you are not running on battery power.  This cleanup may take
30mins of heavy I/O and this may cause problems if you lose power.

If you press enter, this script will try to auto-clean your system.  Once
complete, you will need to reboot.

EOT
read

#
[ -n "$DEBUG" ] && VERBOSE='1'
[ -n "$VERBOSE" ] && set -x

#
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

# needs to be above logging start
[ -n "$VERBOSE" ] && echo 'Set selinux to permissive mode'
[ -n "$DEBUG" ] && read
setenforce 0

# Log all output to a file if LOG_ALL is set
if [ -n "$LOG_ALL" ]; then
  PIPEFILE=$(mktemp -u ${TMPDIR}/${0##*/}-XXXXX.pipe)
  mkfifo --context user_tmp_t $PIPEFILE
  LOGFILE=$(mktemp ${TMPDIR}/${0##*/}-XXXXX.log)
  tee -a $LOGFILE < $PIPEFILE &
  TEEPID=$!

  [[ -t 1 ]] && echo "Writing to logfile '$LOGFILE'."
  exec > $PIPEFILE 2>&1
  #exec < /dev/null 2<&1
fi

#
[ -n "$VERBOSE" ] && echo 'Cleaning up yumdb'
[ -n "$DEBUG" ] && read
rm /var/lib/rpm/__db.00?
yum clean all
yum-complete-transaction

#
[ -n "$VERBOSE" ] && echo 'Removing old packages from cache directories'
[ -n "$DEBUG" ] && read
DIST=$(rpm --eval '%{dist}')
for D in /var/cache/yum /var/lib/yum/plugins/local; do
  [ -d $D ] \
    && find $D -type f -name \*.rpm \
      |grep -v $DIST \
      |xargs rm -f
done

#
[ -n "$VERBOSE" ] && echo 'Repairing permissions'
[ -n "$DEBUG" ] && read
[ -n "$VERBOSE" ] && echo 'This may take a few minutes, resetting user/group ownership'
time rpm -a --setugids > /dev/null 2>&1
[ -n "$VERBOSE" ] && echo 'This may take a few minutes, resetting permissions'
time rpm -a --setperms > /dev/null 2>&1

[ -x /usr/bin/package-cleanup ] || yum install -y yum-utils

YSHELL=${TMPDIR}/YUM-SHELL_${DS}.txt
YSHELL2=${TMPDIR}/YUM-SHELL2_${DS}.txt
# Reinstall desktops and sync
YSHELL3=${TMPDIR}/YUM-SHELL3_${DS}.txt

# Locate installed leaves packages that were installed as a dep of some other package
repoquery --installed --qf "%{nvra} - %{yumdb_info.reason}" \
  `package-cleanup --leaves -q --all` \
  |grep '\- dep' \
  |while read n a a; do \
    echo remove $n
  done > $YSHELL

# reinstall duplicate packages, might clean them without breaking
package-cleanup -q --dupes > ${TMPDIR}/DUPLICATE-PACKAGES_${DS}.txt
[ -s ${TMPDIR}/DUPLICATE-PACKAGES_${DS}.txt ] && \
  cat ${TMPDIR}/DUPLICATE-PACKAGES_${DS}.txt | \
    while reaad PKGNAME; do
      rpm -q --qf 'reinstall %{name}.%{arch}\n' $PKGNAME >> $YSHELL
    done

# Add default package sets
cat ->> $YSHELL <<EOT
reinstall policycoreutils*
reinstall selinux*
install fpaste
install redhat-lsb
install rpmconf
install yum-plugin-local
EOT

# Break out non-essential groups so that yum succeeds even on rawhide
cat ->> $YSHELL2 <<EOT
install @admin-tools
install @base
install @base-x
install @core
install @dial-up
install @fonts
install @hardware-support
install @input-methods
install @printing
install memtest86+
EOT

# Locate installed desktops -- Hack around broken depsolver
yum grouplist -v \
  |sed '1,/^Installed/d;/^Available/,$d;s/[^()]*//;s/(//;s/)//;' \
  |grep desktop \
  |while read GROUP; do
    echo "remove @${GROUP}" >> $YSHELL3
    echo "install @${GROUP}" >> $YSHELL3
  done

# Add default package sets
echo 'run' >> $YSHELL
# Break out non-essential groups so that yum succeeds even on rawhide
echo 'run' >> $YSHELL2
# Locate installed desktops -- Hack around broken depsolver
echo 'run' >> $YSHELL3

#
echo 'Generate package list before package-updates'
[ -x /usr/bin/show-installed ] || yum install -y yum-utils
show-installed > ${TMPDIR}/SHOW-INSTALLED1_${DS}.txt

[ -n "$VERBOSE" ] && echo 'Importing Keys for Fedora versions: https://fedoraproject.org/keys'
[ -n "$DEBUG" ] && read
curl -s https://fedoraproject.org/keys |\
  grep fedoraproject.org/static |\
  cut -f2 -d\" |\
  while read URL; do
    rpm --import $URL
  done

#
[ -n "$VERBOSE" ] && echo 'Removing dependency leaves and installing default package sets'
[ -n "$DEBUG" ] && read
[ -x /usr/sbin/semanage ] || yum install policycoreutils-python
semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
mkdir -p /etc/selinux/targeted
time yum update -y \*-release
time yum update -y yum rpm
time yum shell $YSHELL2 -y --disableplugin=presto --skip-broken
time yum shell $YSHELL3 -y --disableplugin=presto --skip-broken
time yum distribution-synchronization -y --disableplugin=presto --skip-broken
time yum shell $YSHELL -y --disableplugin=presto --skip-broken

[ -f /etc/PackageKit/CommandNotFound.conf ] \
  && sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf

# Something went around above if this directory does not exist
[ -n "$VERBOSE" ] && echo 'Resetting local selinux policy'
[ -n "$DEBUG" ] && read
[ -d /etc/selinux/targeted/policy ] || yum reinstall -y selinux-policy-targeted
semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

#
[ -n "$VERBOSE" ] && echo 'Remove duplicate packages if any found.'
[ -n "$DEBUG" ] && read
package-cleanup --cleandupes

#
echo 'Generate package list after package-updates'
[ -x /usr/bin/show-installed ] || yum install yum-utils
show-installed > ${TMPDIR}/SHOW-INSTALLED2_${DS}.txt

#
[ -n "$VERBOSE" ] && echo "Moving ~/.config/ directories to ~/.config.${DS}"
[ -n "$DEBUG" ] && read
getent passwd \
  |while IFS=: read userName passWord userID groupID geCos homeDir userShell; do
    [ -d "${homeDir}/.config" ] \
      && mv "${homeDir}/.config" "${homeDir}/.config.${DS}"
  done

#
[ -n "$VERBOSE" ] && echo 'Correct labels.'
[ -n "$DEBUG" ] && read
[ -x /sbin/fixfiles ] || yum install -y policycoreutils
time fixfiles -R -a restore

#
[ -n "$VERBOSE" ] && echo 'Merge *.rpmnew files semi-automatically.'
[ -n "$DEBUG" ] && read
[ -x /usr/sbin/rpmconf ] || yum install -y rpmconf
rpmconf -a

#
[ -n "$VERBOSE" ] && echo 'Build problem report.'
[ -n "$DEBUG" ] && read
[ -f /etc/sysconfig/prelink ] \
  && . /etc/sysconfig/prelink \
  && /usr/sbin/prelink -av $PRELINK_OPTS >> /var/log/prelink/prelink.log 2>&1

#
[ -n "$VERBOSE" ] && echo 'configure dynamic linker run-time bindings'
/sbin/ldconfig

#
[ -n "$VERBOSE" ] && echo 'Verify all installed packages'
[ -n "$DEBUG" ] && read
time rpm -Va > ${TMPDIR}/RPM-VA_${DS}.txt 2>&1

# Need a better way to fix caps
[ -n "$VERBOSE" ] && echo 'Reset file capabilities'
[ -n "$DEBUG" ] && read
egrep '^.{8}P ' ${TMPDIR}/RPM-VA_${DS}.txt \
  |awk '{print$NF}' \
  |xargs rpm --filecaps -qf \
  |grep '= cap' \
  |while read fileName eq fileCaps; do
    rpm --qf '%{name}.%{arch}\n' -qf "${fileName}" >> ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt
    setcap "${fileCaps}" "${fileName}"
  done
sort -u -o ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt
#yum reinstall -y $(cat ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt)

#
[ -n "$VERBOSE" ] && echo 'Generate reports'
[ -n "$DEBUG" ] && read
time rpm -Va > ${TMPDIR}/RPM-VA2_${DS}.txt 2>&1
egrep -v '^.{9}  (c /|  /lib/modules/.*/modules\.)' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/URGENT-REVIEW_${DS}.txt
egrep '^.{9}  c /' ${TMPDIR}/RPM-VA2_${DS}.txt > ${TMPDIR}/REVIEW-CONFIGS_${DS}.txt
find /etc -name '*.rpm?*' > ${TMPDIR}/REVIEW-OBSOLETE-CONFIGS_${DS}.txt

# Stop logging.  No changes below this point.
if [ -n "$LOG_ALL" ]; then
  echo "Kill off logger"
  #exec 1>&- 2>&-
  #kill $TEEPID
  rm $PIPEFILE
  #wait $TEEPID
fi

# Reboot script that works even when init has changed
cat -> ${TMPDIR}/raising-elephants.sh <<EOT
#/bin/bash

# Try this first:
shutdown -r now

sysctl -w kernel.sysrq=1 || echo 1 > /proc/sys/kernel/sysrq

#https://secure.wikimedia.org/wikipedia/en/wiki/Magic_SysRq_key#.22Raising_Elephants.22_mnemonic_device
# "Raising Elephants Is So Utterly Boring"
for ST in r e i s s s u b; do
  echo \$ST > /proc/sysrq-trigger
done

#EOF
EOT
chmod 0700 ${TMPDIR}/raising-elephants.sh

# Done
echo "Verify packages are installed the way you want and then type ${TMPDIR}/raising-elephants.sh"

echo 'If you have questions, share this link.'
[ -x /usr/bin/fpaste ] || yum install -y fpaste
for E in ${TMPDIR}/[A-Z]*_${DS}.txt; do
  [ -s $E ] || rm $E
done
fpaste ${TMPDIR}/[A-Z]*_${DS}.txt
echo ''

if [ -n "$LOG_ALL" ]; then
  echo "Detailed log can be found in $LOGFILE"
fi

#EOF
