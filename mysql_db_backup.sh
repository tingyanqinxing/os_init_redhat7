#!/bin/bash
username=
password=
db_name=
###备份目录,不要以/结尾
backupdir=
datetime=`date +%Y%m%d`
oldday=`date -d '5 day ago' +%Y%m%d`
backuplog=${backupdir}/backup_db.log
backup_file_name=${db_name}-${datetime}.sql.gz

echo "`date`:start to backup DB: ${db_name}" >> ${backuplog} 2>&1

if [ -f "${backupdir}/${backup_file_name}" ]
then
	echo "BD backup file is already exists" >> ${backuplog} 2>&1
else
	echo "start to backup db: ${db_name}" >> ${backuplog} 2>&1
	mysqldump -u${username} -p${password}  ${db_name} | gzip > ${backupdir}/${backup_file_name} >> ${backuplog} 2>&1	
	echo "backup db ${db_name} finish"
fi

rm -rf ${backupdir}/${db_name}-${oldday}.sql.gz

