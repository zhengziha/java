#!/bin/bash
# MySQL 5.7.42 离线安装脚本 - CentOS 7
# 支持重复执行

set -e

echo "开始安装 MySQL 5.7.42..."

# 停止现有服务（如果存在）
if [ -f /etc/init.d/mysqld ]; then
    echo "停止现有 MySQL 服务..."
    /etc/init.d/mysqld stop 2>/dev/null || true
fi

# 清理旧安装（如果存在）
if [ -d /usr/local/mysql ]; then
    echo "清理旧安装..."
    rm -rf /usr/local/mysql
fi

if [ -d /data/mysql ]; then
    rm -rf /data/mysql
fi

# 创建用户和组
groupadd -f mysql
useradd -r -s /sbin/nologin -g mysql mysql 2>/dev/null || true

# 解压安装包
cd /root
if [ ! -f mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz ]; then
    echo "错误：未找到安装包 mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz"
    exit 1
fi

tar -zxf mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz
mv mysql-5.7.42-linux-glibc2.12-x86_64 /usr/local/mysql

# 创建数据目录
mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql
chmod -R 755 /data/mysql

# 创建日志目录
mkdir -p /var/log
touch /var/log/mysqld.log
chown mysql:mysql /var/log/mysqld.log

# 创建配置文件
cat > /etc/my.cnf << 'EOF'
[mysqld]
user=mysql
datadir=/data/mysql
basedir=/usr/local/mysql
socket=/tmp/mysql.sock
port=3306
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=1024
wait_timeout=6000
interactive_timeout=6000
explicit_defaults_for_timestamp=1
validate_password=off

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

[client]
socket=/tmp/mysql.sock
default-character-set=utf8mb4
EOF

# 创建启动脚本所需的目录
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# 初始化数据库
cd /usr/local/mysql
./bin/mysqld --initialize --user=mysql --datadir=/data/mysql --log-error=/var/log/mysqld.log

# 复制启动脚本
cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
chmod +x /etc/init.d/mysqld

# 添加到系统服务并设置开机启动
chkconfig --add mysqld
chkconfig mysqld on

# 启动服务
echo "启动 MySQL..."
/etc/init.d/mysqld start
sleep 5

# 获取初始密码
INIT_PASS=$(cat /var/log/mysqld.log | grep 'temporary password' | awk '{print $NF}')
echo "初始密码: $INIT_PASS"

# 修改 root 密码为 root
echo "修改密码..."
/usr/local/mysql/bin/mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

# 允许远程登录
echo "开启远程登录..."
/usr/local/mysql/bin/mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"

echo ""
echo "MySQL 5.7.42 安装完成！"
echo "端口: 3306"
echo "账号: root"
echo "密码: root"
echo "远程登录已开启"
