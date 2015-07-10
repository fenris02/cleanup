#!/bin/bash

DC=$(/bin/date +%Y%m%d)
BK_DIR="$HOME/MySQL/mysql-backup-$DC"

##mysqldump -A --opt --add-drop-database --order-by-primary --hex-blob |gzip -9 > mysql-backup-$DC.sql.gz

[ -d $BK_DIR ] || mkdir -p $BK_DIR
cd $BK_DIR

for TBL in $( mysql -e 'show databases;' |cat ) ; do
    echo "Backing up $TBL"
    /usr/bin/mysqldump --opt --add-drop-database --order-by-primary --hex-blob $TBL > $BK_DIR/$TBL.sql
done

cd $BK_DIR/..
echo "Archiving to mysql-backup-$DC"
zip -9myroq $BK_DIR mysql-backup-$DC

#EOF
