#!/bin/bash

#
# Backup mysql / mariadb databases by using LVM snapshots
#
# This will make the table-lock time very brief, allowing you to safely backup
# large databases
#

# Setup environment
DC="$(/bin/date +%Y%m%dT%H%M)"
TMPDIR="$( /bin/mktemp -d "/var/tmp/${0##*/}.XXXXXXXXXX" )" || { echo "mktemp failed" >&2 ; exit 1 ; };
SELF="${0##*/}"

# Configure options
BK_DIR="$HOME/MySQL/mysql-backup-$DC"
MYSQLPARAMS="-h localhost -u root -p secret-password"

[ -d "$BK_DIR" ] || mkdir -p "$BK_DIR"
cd "$BK_DIR" || exit 1

# locate the dbms directory
DATADIR="$( /bin/mysqladmin "$MYSQLPARAMS" variables |/bin/awk '/datadir/{print$4}' )"
BLOCKDEV="$( /bin/df --no-sync "$DATADIR" |/bin/awk 'END{print$1}' )"
LVM="${BLOCKDEV##*/}"
VG="${LVM%-*}"
LV="${LVM#*-}"

# lock dbms
/usr/bin/mysql "$MYSQLPARAMS" -e 'FLUSH TABLES WITH READ LOCK;'

# Create snapshot
/usr/sbin/lvcreate --extents 100%FREE --snapshot --name "snap-$DC" "/dev/$VG/$LV"

# unlock dbms
/usr/bin/mysql "$MYSQLPARAMS" -e 'UNLOCK TABLES;'

# Mount snapshot
mkdir -p "$TMPDIR/snap"
/usr/bin/mount "/dev/$VG/snap-$DC" "$TMPDIR/snap"

# run dbms from snapshot
echo 'select 1;' | /usr/bin/mysqld_safe 
  --bootstrap \
  --datadir="$TMPDIR/snap/$DATADIR" \
  --pid-file="$TMPDIR/$SELF.pid" \
  --skip-grant \
  --skip-ndbcluster \
  --skip-networking \
  --skip-slave-start \
  --socket="$TMPDIR/$SELF.sock" \
  #

# dump from snapshot
/usr/bin/mysqldump "$MYSQLPARAMS" \
  --add-drop-database \
  --all-databases \
  --comments \
  --create-db \
  --create-info \
  --dump-date \
  --hex-blob \
  --opt \
  --order-by-primary \
  --protocol=SOCKET \
  --routines \
  --socket="$TMPDIR/$SELF.sock" \
  --triggers \
  | /usr/bin/gzip > "$BK_DIR/mysql-backup-$DC.sql.gz"

# stop dbms from snapshot
/usr/bin/mysqladmin "$MYSQLPARAMS" --socket="$TMPDIR/$SELF.sock" -p shutdown

# Remove snapshot
/usr/bin/umount "$TMPDIR/snap"
/usr/sbin/lvremove "/dev/$VG/snap-$DC"

#EOF
