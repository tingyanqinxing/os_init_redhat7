#!/bin/bash
uname=root
upwd='adfdAb123%*@12_@1-2*_abd'
datetime=`date +%Y%m%d`
oldday=`date -d '2 day ago' +%Y%m%d`
echo "------------ 备份数据库开始--------------"
echo " "
if [ -f "/home/data/backup/db/all-DB-"$datetime".sql" ]
then
        echo "DB backup file is already!"
else
        echo "backuping..."
        /usr/bin/mysqldump -u$uname -p$upwd --all-databases | gzip > /home/data/backup/all-DB-"$datetime".sql.gz
        echo "back finish!"
fi
sleep 2m
if [ -f "/home/data/backup/db/all-DB-"$datetime".sql.gz" ]
then
        echo "$datetime ll数据库备份成功"|mutt -s "ll备份通知" zoucarson@gmail.com
else
        echo "$datetime ll数据库备份失败"|mutt -s "ll备份通知" zoucarson@gmail.com
echo "备份数据库结束"
fi

/bin/rm -rf /home/data/backup/all-DB-"$oldday".sql
/bin/rm -rf /home/data/backup/all-DB-"$oldday".sql.gz

echo "开始备份web"
#cp -R /home/wwwroot  /home/data/backup/web/$datetime
cd /home
tar zcvf  web_$datetime.tar.gz   --exclude=*/Runtime sese/
mv web_$datetime.tar.gz /home/data/backup/
rm -rf /home/data/backup/web_$oldday.tar.gz
echo "web备份结束"
chown -R qqc:root /home/data/backup/
chmod -R 755 /home/data/backup/
