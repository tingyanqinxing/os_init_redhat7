#!/bin/bash
##current dir
SHELL_FOLDER=$(dirname $(readlink -f "$0"))
###常用软件
commonSoft=('vim' 'net-tools' 'iptables-services' 'wget' 'ntpdate')
zabbixServer="129.204.93.132,223.119.51.10"
ngx_install_prefix="/usr/local/nginx"
php_install_prefix="/usr/local/php7"

installCommonSoft(){
	for i in ${commonSoft[@]}
	do 
		echo "installing common soft..."
		yum install -y ${i} > /dev/null
	done

	systemctl enable iptables
	systemctl start iptables
	systemctl disable NetworkManager
	systemctl stop NetworkManager
	systemctl disable firewalld
	systemctl stop firewalld
	systemctl stop postfix
	systemctl disable postfix
	systemctl stop chronyd
	systemctl disable chronyd
	
}

###检测操作系统版本
getOSVersion(){
	grep "CentOS Linux release 7" /etc/redhat-release* > /dev/null 2>&1
	retCode=$?
	if [ $retCode -eq 0 ]
	then
		echo "RHEL7"
	else
		echo "other verson"
	fi
}

###操作系统常用配置
osBaseConfig(){
	#修改时区,配置时间同步
	echo 'ZONE="Asia/Shanghai"' > /etc/sysconfig/clock
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
	
	grep "##### update server time #####" /var/spool/cron/root > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "##### update server time #####" >> /var/spool/cron/root
		echo "*/10 * * * * /usr/sbin/ntpdate cn.pool.ntp.org > /dev/null 2>&1 && /sbin/clock -w > /dev/null 2>&1" >> /var/spool/cron/root
	fi
	
	
	###关闭selinux
	sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config 

	###vim设置
	vimConf="/root/.vimrc"
	if [ ! -f ${vimConf} ]
	then
		echo "start config vimrc"
		echo 'syntax on' > ${vimConf}
		echo 'set ai' >> ${vimConf}
		echo 'set hls' >> ${vimConf}
		echo 'set ignorecase' >> ${vimConf}
		echo 'set tabstop=4' >> ${vimConf}
	else
		echo "${vimConf} existed,skip..."
	fi
	###set ulimit
	echo "start set ulimit"
	echo "*                     soft     nofile             60000" >> /etc/security/limits.conf
	echo "*                     hard     nofile             65535" >> /etc/security/limits.conf
	###set sysctl
	sysconf="/etc/sysctl.conf" 

	###脚本向/etc/sysctl.conf写入配置前插入识别字符串INITOSSCRIPTINSEREDIT,脚本执行时如果检测到文件中包含此字符串，跳过此步骤
	grep "INITOSSCRIPTINSEREDIT" ${sysconf} > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "start set sysctl"
		echo "###INITOSSCRIPTINSEREDIT" >> ${sysconf}
		echo "net.ipv4.tcp_tw_reuse = 1" >> ${sysconf}
		echo "net.ipv4.tcp_tw_recycle = 1" >> ${sysconf}

		echo "net.ipv4.tcp_syn_retries = 1" >> ${sysconf}
		echo "net.ipv4.tcp_fin_timeout = 30" >> ${sysconf}
		echo "net.ipv4.tcp_keepalive_time = 600" >> ${sysconf}
		echo "net.ipv4.tcp_syncookies = 1" >> ${sysconf}
		echo "net.ipv4.ip_local_port_range = 1024 65535" >> ${sysconf}
		echo "net.ipv4.tcp_max_syn_backlog = 65535" >> ${sysconf}
		echo "net.ipv4.tcp_max_tw_buckets = 65535" >> ${sysconf}
		echo "net.core.wmem_default = 8388608" >> ${sysconf}
		echo "net.core.rmem_default = 8388608" >> ${sysconf}
		echo "net.core.rmem_max = 16777216" >> ${sysconf}
		echo "net.core.wmem_max = 16777216" >> ${sysconf}
		echo "net.core.netdev_max_backlog = 131070" >> ${sysconf}
		echo "net.core.somaxconn = 20480" >> ${sysconf}
		echo "net.netfilter.nf_conntrack_max = 120000" >> ${sysconf}
		echo "net.netfilter.nf_conntrack_tcp_timeout_established = 3600" >> ${sysconf}
		/sbin/sysctl -p
	else
		echo "sysctl has configured,skip..."
	fi

	###添加用户qqc，用户已存在，跳过此步骤
	id qqc > /dev/null 2>&1
	if [  $? -ne 0 ]
	then
		echo "start create user: qqc"
		useradd qqc
		echo "0@m}dukd0B03" | passwd qqc --stdin
	else
		echo "user qqc has existed,skip..."
	fi
	###设置sshd,
	ssh_cf="/etc/ssh/sshd_config"
	echo "start config sshd"
	#sed -i "s/#Port 22/Port 30000/" $ssh_cf
	sed -i "s/#UseDNS yes/UseDNS no/" $ssh_cf
	sed -i "/X11Forwarding yes/d" $ssh_cf
	sed -i "s/#X11Forwarding no/X11Forwarding no/g" $ssh_cf
	sed -i "s/#PrintMotd yes/PrintMotd no/g" $ssh_cf
	sed -i "s/#PrintLastLog yes/PrintLastLog no/g" $ssh_cf
	#sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' $ssh_cf
	echo "OS basic config end---"

	#deluser
	userdel uucp
	userdel operator
	userdel games
	userdel gopher


}

####install zabbix agent
installZabbixAgent(){
	zabbixRepo="http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm"
	###判断是否已经运行zabbix
	ps aux | grep -i zabbix | grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		rpm -ivh ${zabbixRepo}
		yum install -y zabbix-agent
		sed -i "s/Server=127.0.0.1/Server=${zabbixServer}/" /etc/zabbix/zabbix_agentd.conf
		sed -i "s/ServerActive=127.0.0.1/ServerActive=${zabbixServer}/" /etc/zabbix/zabbix_agentd.conf   
		echo "Include=/etc/zabbix/zabbix_agentd.d/*.conf" >> /etc/zabbix/zabbix_agentd.conf
		
		mkdir /etc/zabbix/zabbix_agentd.d
		cp zabbix/* /etc/zabbix/zabbix_agentd.d/
		
		systemctl restart zabbix-agent.service
		systemctl enable zabbix-agent.service

		###添加防火墙规则，放通10050端口
		grep " 10050 " /etc/sysconfig/iptables > /dev/null 2>&1
		if [ $? -ne 0 ]
		then
			sed -i '/-A INPUT -i lo -j ACCEPT/a-A INPUT -p tcp --dport 10050 -j ACCEPT' /etc/sysconfig/iptables
			iptables-restore /etc/sysconfig/iptables
		fi
		
	else
		echo "zabbix already installed"
	fi
	
}

installNginx1_14_2(){
	###判断是否已经运行nginx，如果已经有实例运行，不安装
	ps aux | grep -i "nginx: master process"  | grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		##download software
		wget http://nginx.org/download/nginx-1.14.2.tar.gz
		wget "http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz"
	
		##add group and user
		groupadd www
		useradd -s /sbin/nologin -M -g www www
		##install dependency
		yum install -y GeoIP-devel gcc pcre-dev openssl-devel 
		
		tar -xf nginx-1.14.2.tar.gz
		tar -xf ngx_cache_purge-2.3.tar.gz
		
		cd nginx-1.14.2
		./nginx-1.14.2/configure --user=www --group=www --prefix=${ngx_install_prefix} --with-http_v2_module --with-http_ssl_module --with-http_sub_module --with-http_flv_module --with-http_stub_status_module --with-http_gzip_static_module --with-pcre  --with-http_realip_module  --with-http_geoip_module  --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --add-module=ngx_cache_purge-2.3
		
		make &&  make install
		cd ..
		
		
		cat>/lib/systemd/system/nginx.service<<EOF
[Unit]
	Description=nginx
	After=network.target

	[Service]
	Type=forking
	ExecStart=${ngx_install_prefix}/sbin/nginx
	ExecReload=${ngx_install_prefix}/sbin/nginx -s reload
	ExecStop=${ngx_install_prefix}/sbin/nginx -s quit
	PrivateTmp=true

	[Install]
	WantedBy=multi-user.target

EOF
		systemctl enable nginx
	else
		echo "nginx already installed"
	fi
}

installPHP7_2_0(){
	###判断是否已经运行PHP，如果已经有实例运行，不安装
	ps aux | grep -i "php-fpm: master process"  | grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		yum install -y gcc libxml2-devel libjpeg-turbo-devel libpng-devel libxslt libxslt-devel libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel curl curl-devel openssl openssl-devel  bzip2  bzip2-devel  libxslt libxslt-devel  libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel curl curl-devel openssl openssl-devel perl perl-devel httpd-devel
		wget http://am1.php.net/distributions/php-7.2.0.tar.bz2
		tar -xf php-7.2.0.tar.bz2
		cd php-7.2.0
		./configure --prefix=${php_install_prefix} --with-curl --with-freetype-dir --with-gd --with-gettext --with-iconv-dir --with-kerberos --with-libdir=lib64 --with-libxml-dir --with-mysqli --with-openssl --with-pcre-regex --with-pdo-mysql --with-pdo-sqlite --with-pear --with-png-dir --with-xmlrpc --with-xsl --with-zlib --enable-fpm --enable-bcmath -enable-inline-optimization --enable-gd-native-ttf --enable-mbregex --enable-mbstring --enable-opcache --enable-pcntl --enable-shmop --enable-soap --enable-sockets --enable-sysvsem --enable-xml --enable-zip --enable-pcntl --with-curl --with-fpm-user=www --enable-ftp --enable-session --enable-xml --with-apxs2=/bin/apxs
		
		make && make install
		cd ..
		
		
		cp php-7.2.0/php.ini-production ${php_install_prefix}/etc/php.ini
		
		mv ${php_install_prefix}/etc/php-fpm.conf.default ${php_install_prefix}/etc/php-fpm.conf
		mv ${php_install_prefix}/etc/php-fpm.d/www.conf.default ${php_install_prefix}/etc/php-fpm.d/www.conf
		\cp -f php-7.2.0/sapi/fpm/php-fpm.service /usr/lib/systemd/system/php-fpm.service
		
		systemctl enable php-fpm
		systemctl start php-fpm
		
	else
		echo "PHP already installed"
	fi
}

installMysql5_7(){
	###判断是否已经运行PHP，如果已经有实例运行，不安装
	ps aux | grep -i "mysqld"  | grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		rpm -ivh https://repo.mysql.com//mysql80-community-release-el7-2.noarch.rpm
		yum install -y yum-utils
		yum-config-manager --disable mysql80-community
		yum-config-manager --enable mysql57-community
		yum install -y mysql-community-server
		
		systemctl start mysqld.service
		systemctl enable mysqld.service
		
	else
	
	fi

}

main(){
	echo "check OS version..."
	checkOSVersion=$(getOSVersion)
	echo ${checkOSVersion}
	if [ "${checkOSVersion}" == "RHEL7" ]
	then
		echo "os version OK"
		read -p""
		read -p"Install nginx1.14.2 or not[y|n]: " -n 1 choice_install_nginx
		read -p"Install php7.2.0 or not[y|n]: " -n 1 choice_install_php
		
		
		installCommonSoft
		echo "start OS basic config..."
		osBaseConfig
		installZabbixAgent
		
		
		case "${choice}" in 
			y) installNginx1_14_2;;
			n) echo "skip installing nginx...";;
			*) echo "skip installing nginx...";;
		esac
		
		

	fi
}

main
