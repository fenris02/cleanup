#
# README for dist-cleaup.sh
# $Id:$
#

Script version of http://fedorasolved.org/Members/fenris02/post_upgrade_cleanup

Access URLs:
Git-Web:     http://fedorapeople.org/gitweb?p=fenris02/public_git/cleanup.git;a=tree
Read-Write:  git://fedorapeople.org/~fenris02/cleanup.git
Read-Only:   http://fenris02.fedorapeople.org/git/cleanup.git/
Last resort: ssh://fedorapeople.org/~fenris02/public_git/cleanup.git


QUICKSTART (if you already have current backups):

su -
telinit 3

# Login as root and identify your primary network device
nmcli con up id 'System eth0'
yum install git
curl -s 'http://fedorapeople.org/gitweb?p=fenris02/public_git/cleanup.git;a=blob_plain;f=distro-clean.sh;hb=HEAD' > /root/distro-clean.sh
chmod 0700 /root/distro-clean.sh

# Double check your backups exits and are current.
./distro-clean.sh

# Inspect the system, review transaction log, ...
/root/tmp/raising-elephants.sh

