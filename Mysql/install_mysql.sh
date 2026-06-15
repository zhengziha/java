#!/bin/bash
# MySQL 7 安装脚本 - CentOS 7
# 使用方法: bash install_mysql.sh

set -e

echo "开始安装 MySQL 7..."

# 安装依赖
yum install -y wget libaio numactl

# 添加 MySQL 7 YUM 仓库
cat > /etc/yum.repos.d/mysql-community.repo << 'EOF'
[mysql70-community]
name=MySQL 7.0 Community Server
baseurl=http://repo.mysql.com/yum/mysql-7.0-community/el/7/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
EOF

# 导入 GPG key
wget -q -O /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql https://repo.mysql.com/RPM-GPG-KEY-mysql

# 安装 MySQL 7
echo "安装 MySQL 7..."
yum install -y mysql-community-server-7.0.*

# 启动 MySQL 并设置开机启动
echo "启动 MySQL..."
systemctl start mysqld
systemctl enable mysqld

# 获取初始密码
INIT_PASS=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
echo "初始密码: $INIT_PASS"

# 设置密码策略为低强度
echo "设置密码策略..."
mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "SET GLOBAL validate_password_policy=LOW; SET GLOBAL validate_password_length=4;"

# 修改 root 密码为 root
echo "修改密码..."
mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

# 允许远程登录
echo "开启远程登录..."
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"

# 重启服务
systemctl restart mysqld

echo ""
echo "MySQL 7 安装完成！"
echo "端口: 3306"
echo "账号: root"
echo "密码: root"
echo "远程登录已开启"
