#$/bin/bash

###常用软件
commonSoft=('vim' 'net-tools' 'iptables-services' 'wget' 'ntpdate')
zabbixServer="129.204.93.132,223.119.51.10"

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
	
	ps aux | grep -i zabbix | grep -v grep > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		rpm -ivh ${zabbixRepo}
		yum install -y zabbix-agent
		sed -i "s/Server=127.0.0.1/Server=${zabbixServer}/" /etc/zabbix/zabbix_agentd.conf
		sed -i "s/ServerActive=127.0.0.1/ServerActive=${zabbixServer}/" /etc/zabbix/zabbix_agentd.conf   
		echo "Include=/etc/zabbix/zabbix_agentd.conf.d/*.conf" >> /etc/zabbix/zabbix_agentd.conf
		
		
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

main(){
	echo "check OS version..."
	checkOSVersion=$(getOSVersion)
	echo ${checkOSVersion}
	if [ "${checkOSVersion}" == "RHEL7" ]
	then
		echo "os version OK"
		installCommonSoft
		echo "start OS basic config..."
		osBaseConfig
		installZabbixAgent

	fi
}

main
