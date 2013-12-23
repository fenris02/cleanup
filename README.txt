#
# README for dist-cleaup.sh
# $Id$
#

Script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup
Mirrored on https://fedoraproject.org/wiki/User:Fenris02/Distribution_upgrades_and_cleaning_up_after_them

Access URLs:
Git-Web:     http://fedorapeople.org/cgit/fenris02/public_git/cleanup.git/tree/
Read-Write:  git://fedorapeople.org/home/fedora/fenris02/public_git/cleanup.git
Read-Only:   http://fedorapeople.org/gitrepos/fenris02/public_git/cleanup.git
Last Resort: ssh://fedorapeople.org/home/fedora/fenris02/public_git/cleanup.git

Frequently asked for files:
http://fedorapeople.org/cgit/fenris02/public_git/cleanup.git/plain/rpm-verify.sh
http://fedorapeople.org/cgit/fenris02/public_git/cleanup.git/plain/raising-elephants.sh

QUICKSTART (if you already have current backups):

su -
telinit 3

# Login as root and identify your primary network device
nmcli con up id 'System eth0'
curl -s http://fedorapeople.org/cgit/fenris02/public_git/cleanup.git/plain/distro-clean.sh \
  |dos2unix > /root/distro-clean.sh
chmod 0700 /root/distro-clean.sh

# Double check your backups exits and are current.
time ./distro-clean.sh

# Inspect the system, review transaction log, ...
/root/tmp/raising-elephants.sh

