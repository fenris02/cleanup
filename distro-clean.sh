#!/bin/bash -x

# Script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

# Do not set TMPDIR to any tmpfs mount, these files should remain after boot.
TMPDIR=/root/tmp
DEBUG=""

if [ "$(whoami)" != "root" ]; then
  echo "Must be run as root"
  exit 1
fi

if [ $(runlevel |awk '{print$NF}') != "3" ]; then
  echo "Must be run from runlevel 3"
  exit 1
fi
 
cat -<<EOT
Press ^C now if you do not have a good backup of your system.

If you press enter, this script will try to auto-clean your system.
Once complete, you will need to reboot.

EOT
read

#
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"

# Log all output to a file
PIPEFILE=$(mktemp /root/tmp/${0##*/}-XXXXX.pipe)
mkfifo $PIPEFILE
LOGFILE=$(mktemp /root/tmp/${0##*/}-XXXXX.log)
tee $LOGFILE < $PIPEFILE &
TEEPID=$!

[[ -t 1 ]] && echo "Writing to logfile '$LOG'."
exec > $PIPEFILE 2>&1
#exec < /dev/null 2<&1

DS=$(date +%Y%d%m)
YSHELL=${TMPDIR}/YUM-SHELL_${DS}.txt

setenforce 0

#
echo "Cleaning up yumdb"
rm /var/lib/rpm/__db.00?
yum clean all
yum-complete-transaction

#
echo "Removing old packages from cache directories"
[ -n "$DEBUG" ] && read
DIST=$(rpm --eval '%{dist}')
for D in /var/cache/yum /var/lib/yum/plugins/local; do
  [ -d $D ] \
    && find $D -type f -name \*.rpm \
      |grep -v $DIST \
      |xargs rm -f
done

#
echo "Repairing permissions"
[ -n "$DEBUG" ] && read
rpm -a --setugids; rpm -a --setperms

[ -x /usr/bin/package-cleanup ] || yum install yum-utils

# Locate installed leaves packages that were installed as a dep of some other package
repoquery --installed --qf "%{nvra} - %{yumdb_info.reason}" \
  `package-cleanup --leaves -q --all` \
  |grep '\- dep' \
  |while read n a a; do \
    echo remove $n
  done > $YSHELL

# Locate installed desktops
yum grouplist -v \
  |sed '1,/^Installed/d;/^Available/,$d;s/[^()]*//;s/(//;s/)//;s/^/remove @/' \
  |grep desktop >> $YSHELL

yum grouplist -v \
  |sed '1,/^Installed/d;/^Available/,$d;s/[^()]*//;s/(//;s/)//;s/^/install @/' \
  |grep desktop >> $YSHELL

# Add default package sets
cat ->> $YSHELL <<EOT
reinstall policycoreutils*
reinstall selinux*
install @admin-tools
install @base
install @base-x
install @core
install @dial-up
install @fonts
install @hardware-support
install @input-methods
install @printing
install fpaste
install memtest86+
install policycoreutils
install redhat-lsb
install rpmconf
distribution-synchronization
EOT

echo run >> $YSHELL

#
echo "Removing dependency leaves and installing default package sets"
[ -n "$DEBUG" ] && read
semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt
mv /etc/selinux/targeted ${TMPDIR}/targeted.${DS}
yum shell $YSHELL --disableplugin=presto
semanage -i ${TMPDIR}/SELINUX-CUSTOM-CONFIG_${DS}.txt

# Remove duplicate packages if any found
package-cleanup --dupes > ${TMPDIR}/DUPLICATE-PACKAGES_${DS}.txt
package-cleanup --cleandupes

#
echo "Moving ~/.config/ directories to ~/.config.${DS}"
[ -n "$DEBUG" ] && read
getent passwd \
  |while IFS=: read userName passWord userID groupID geCos homeDir userShell; do
    [ -d "${homeDir}/.config" ] \
      && echo mv "${homeDir}/.config" "${homeDir}/.config.${DS}"
  done

#
echo "Correct labels"
[ -n "$DEBUG" ] && read
[ -x /sbin/fixfiles ] || yum install policycoreutils
fixfiles -R -a restore

# Merge *.rpmnew files semi-automatically
rpmconf -a

#
echo "Build problem report"
[ -n "$DEBUG" ] && read
[ -f /etc/sysconfig/prelink ] \
  && . /etc/sysconfig/prelink \
  && /usr/sbin/prelink -av $PRELINK_OPTS >> /var/log/prelink/prelink.log 2>&1

#
/sbin/ldconfig

# Generate reports
rpm -Va > ${TMPDIR}/RPM-VA_${DS}.txt 2>&1
egrep -v '^.{9}  c /' ${TMPDIR}/RPM-VA_${DS}.txt > ${TMPDIR}/URGENT-REVIEW_${DS}.txt
egrep '^.{9}  c /' ${TMPDIR}/RPM-VA_${DS}.txt > ${TMPDIR}/REVIEW-CONFIGS_${DS}.txt
find /etc /var -name '*.rpm?*' > ${TMPDIR}/REVIEW-OBSOLETE-CONFIGS_${DS}.txt

# Need a better way to fix caps
echo "Reset file capabilities"
[ -n "$DEBUG" ] && read
egrep '^.{8}P ' ${TMPDIR}/RPM-VA.txt \
  |awk '{print$NF}' \
  |xargs rpm --filecaps -qf \
  |grep '= cap' \
  |while read fileName eq fileCaps; do
    rpm --qf '%{name}.%{arch}\n' -qf "${fileName}" >> ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt
    setcap "${fileCaps}" "${fileName}"
  done
sort -u -o ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt
#yum reinstall $(cat ${TMPDIR}/FCAPS-REINSTALL_${DS}.txt)
 
# Stop logging.  No changes below this point.
exec 1>&- 2>&-
wait $TEEPID

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

echo -n "If you have questions, share this link."
fpaste ${TMPDIR}/{YUM-SHELL,DUPLICATE-PACKAGES,RPM-VA,URGENT-REVIEW,REVIEW-CONFIGS,REVIEW-OBSOLETE-CONFIGS,FCAPS-REINSTALL}_${DS}.txt
echo ""

echo "Detailed log can be found in $LOGFILE"

#EOF
