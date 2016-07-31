#!/bin/bash

#
# Backup mysql / mariadb databases by using LVM snapshots
#
# This will make the table-lock time very brief, allowing you to safely backup
# large databases
#
# BUGS:
# $TMPDIR remains behind after the script is run. (uncomment rm line near bottom to fix)
#
# Likely more effecient to run a slave db and backup from that instead.
#

# Setup environment
DC="$(/bin/date +%Y%m%dT%H%M)"
SELF="${0##*/}"
TMPDIR="$( /bin/mktemp -d "/var/tmp/${SELF}.XXXXXXXXXX" )" || { echo "mktemp failed" >&2 ; exit 1 ; };
lockfile="${TMPDIR}/${SELF}.lockfile"

# Configure options
BK_DIR="${HOME}/MySQL/mysql-backup-${DC}"
MYSQLUSER="root"
MYSQLPASS="secret-password"
MYSQLCNF="${TMPDIR}/my.cnf"
MYSQLPARAMS="-h localhost --my-config=${MYSQLCNF}"

# Ensure backup directory exists
[ -d "${BK_DIR}" ] || mkdir -p "${BK_DIR}"
cd "${BK_DIR}" || exit 1

# locate the dbms directory
DATADIR="$( /bin/mysqladmin "${MYSQLPARAMS}" variables |/bin/awk '/datadir/{print$4}' )"
BLOCKDEV="$( /bin/df --no-sync "${DATADIR}" |/bin/awk 'END{print$1}' )"
LVM="${BLOCKDEV##*/}"
VG="${LVM%-*}"
LV="${LVM#*-}"

# trap set to clean lockfile
clean_house () {
  /bin/rm -f "${lockfile}"
  exit $?
}

# Ensure a clean exit
if ( set -o noclobber; echo "$$" > "${lockfile}") 2> /dev/null; then
  trap clean_house INT TERM EXIT

  # Create credentials file
  /bin/cat - > "${MYSQLCNF}" <<EOT
[client]
user=${MYSQLUSER}
password=${MYSQLPASS}
EOT

  # lock dbms
  /usr/bin/mysql "${MYSQLPARAMS}" -e 'FLUSH TABLES WITH READ LOCK;'

  # Create snapshot
  /usr/sbin/lvcreate --extents 100%FREE --snapshot --name "snap-${DC}" "/dev/${VG}/${LV}"

  # unlock dbms
  /usr/bin/mysql "${MYSQLPARAMS}" -e 'UNLOCK TABLES;'

  # Mount snapshot
  mkdir -p "${TMPDIR}/snap"
  /usr/bin/mount "/dev/${VG}/snap-${DC}" "${TMPDIR}/snap"

  # run dbms from snapshot
  echo 'select 1;' | /usr/bin/mysqld_safe \
    --bootstrap \
    --datadir="${TMPDIR}/snap/${DATADIR}" \
    --pid-file="${TMPDIR}/${SELF}.pid" \
    --skip-grant \
    --skip-ndbcluster \
    --skip-networking \
    --skip-slave-start \
    --socket="${TMPDIR}/${SELF}.sock" \
    #

  # dump from snapshot
  /usr/bin/mysqldump "${MYSQLPARAMS}" \
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
    --socket="${TMPDIR}/${SELF}.sock" \
    --triggers \
    | /usr/bin/lzop > "${BK_DIR}/mysql-backup-${DC}.sql.lzo"
    #| /usr/bin/gzip > "${BK_DIR}/mysql-backup-${DC}.sql.gz"

  # stop dbms from snapshot
  /usr/bin/mysqladmin "${MYSQLPARAMS}" --socket="${TMPDIR}/${SELF}.sock" -p shutdown

  # Remove snapshot
  /usr/bin/umount "${TMPDIR}/snap"
  /usr/sbin/lvremove "/dev/${VG}/snap-${DC}"

  # Remove TMPDIR
  cd "${TMPDIR}/.." || { echo "something went horribly wrong" >&2; exit 1; };
  echo /bin/rm -rf "${TMPDIR}"

  # remove lockfile
  clean_house;

  trap - INT TERM EXIT
else
  echo "Failed to acquire lockfile: ${lockfile}."
  echo -n "Held by "
  /bin/cat "${lockfile}"
  echo ""
fi

#EOF
