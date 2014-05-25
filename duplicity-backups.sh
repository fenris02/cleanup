#!/bin/bash
#
# This script was created to make Duplicity backups. Full backups are made on
# Sundays. Then incremental backups are made on the other days.
#
# Basic rule: dont backup packaged data, only unpackaged files, and changed config files
#
# Step 1) sudo yum install duplicity gnupg openssh-clients
# Step 2) Create /root/.passphrase with some phrase you will remember.
# Step 3) Edit the BACKUP_URL below.
# Step 4) sudo install -c -m 0755 -o root $THIS_FILE /etc/cron.daily/

# User settings:
# Where to upload the backups
BACKUP_URL="sftp://User@BackupHost.local.lan//home/duplicity/$HOSTNAME/"

# Extra duplicity options
EXTRA_DUPLICITY="
--allow-source-mismatch \
--archive-dir /root/.cache/duplicity \
--full-if-older-than 7D \
--log-file /var/log/duplicity.log \
--verbosity notice \
--volsize 250 \
"
# Additional TMP space needed, but may make it faster: --asynchronous-upload \

# Loading the day of the month in a variable.
export TMPDIR=/var/tmp

# Check to see if we have a SSH key
if [ ! -e /root/.ssh/id_rsa ]; then
  /bin/cat - <<EOT
Create an SSH key first.  An example method:
  /usr/bin/ssh-keygen -t rsa -N ''
  /usr/bin/ssh-copy-id -i ~/.ssh/id_rsa.pub user@backup.host.name
EOT
  exit 1
fi

# Check to see if we have a passphrase
if [ ! -e /root/.passphrase ]; then
  /bin/cat - <<EOT
Create /root/.passphrase first.  Add any long phrase you can remember easily.

Always keep your passphrase secret! 

Even if your secret key is accessed by someone else, they will be unable to use
it without your passphrase. Do not choose a passphrase that someone else might
easily guess. Do not use single words (in any language), strings of numbers
such as your telephone number or an official document number, or biographical
data about yourself or your family for a passphrase. The most secure
passphrases are very long and contain a mixture of uppercase and lowercase
letters, numbers, digits, and symbols. Choose a passphrase that you will be
able to remember, however, since writing this passphrase down anywhere makes it
immediately less secure.
EOT
  exit 1
fi

# Setting the pass phrase to encrypt the backup files.
export PASSPHRASE=$(/bin/cat /root/.passphrase |/usr/bin/sha512sum |/bin/awk '{print$1}')

# Create gnupg keys if they do not already exist
if [ ! -e /root/.gnupg ]; then
  echo "Create a GNUPG keychain first"
  /bin/cat -> /root/tmp/gnupg-batch.txt <<EOT
     %echo Generating a standard key
     Key-Type: RSA
     Key-Length: 4096
     Subkey-Type: RSA
     Subkey-Length: 4096
     Name-Real: Root of all Evil
     Name-Comment: with stupid passphrase
     Name-Email: root@$HOSTNAME
     Expire-Date: 0
     Passphrase: $PASSPHRASE
     # %pubring foo.pub
     # %secring foo.sec
     # Do a commit here, so that we can later print "done" :-)
     %commit
     %echo done
EOT
  /usr/bin/gpg --gen-key --batch /root/tmp/gnupg-batch.txt
  /usr/bin/gpg --export-secret-keys --armor root@$HOSTNAME > /root/.gnupg/root-privkey.asc
  /bin/chmod 0400 /root/.gnupg/root-privkey.asc
  /usr/bin/gpg --export --armor root@$HOSTNAME > /root/.gnupg/root-pubkey.asc
  /bin/rm /root/tmp/gnupg-batch.txt
  exit 1
fi

# Generate some base OS configs
[ -d "${TMPDIR}" ] || mkdir -p "${TMPDIR}"
/usr/bin/show-installed -f kickstart -o ${TMPDIR}/SHOW-INSTALLED2.txt
/usr/bin/yum repolist > ${TMPDIR}/YUM-REPOLIST.txt
/usr/sbin/semanage -o ${TMPDIR}/SELINUX-CUSTOM-CONFIG.txt

# Directories to backup
/bin/cat - > ${TMPDIR}/duplicity-backups.txt <<EOT
+ /
- /bin
- /boot
- /dev
+ /etc
+ /home
- /home/lost+found
- /lib
- /lib64
- /lost+found
- /media
- /mnt
+ /opt
- /proc
+ /root
- /run
- /sbin
+ /srv
- /sys
- /usr
+ /usr/local
- /var
+ /var/lib/libvirt
+ /var/lib/lxc
+ /var/lib/znc
+ /var/www
EOT

date --rfc-3339=seconds >> /var/log/duplicity.log
/usr/bin/duplicity $EXTRA_DUPLICITY --no-encryption /root/.gnupg $BACKUP_URL/keys
/usr/bin/duplicity $EXTRA_DUPLICITY --include-filelist ${TMPDIR}/duplicity-backups.txt / $BACKUP_URL

# Check http://www.nongnu.org/duplicity/duplicity.1.html for all the options
# available for Duplicity.

# Deleting old backups
/usr/bin/duplicity remove-older-than 1M --force $BACKUP_URL/keys
/usr/bin/duplicity remove-older-than 1M --force $BACKUP_URL

# Unsetting the confidential variables so they are gone for sure.
unset PASSPHRASE

exit 0
#EOF
