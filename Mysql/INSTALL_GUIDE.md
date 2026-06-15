# MySQL 5.7.42 离线安装指南

## 概述

本指南详细记录了在三个 CentOS 7 虚拟机上安装 MySQL 5.7.42 的完整过程。

---

## 环境信息

### 虚拟机配置

| 节点 | IP地址 | SSH账号 | SSH密码 |
|------|--------|---------|---------|
| node1 | 192.168.56.106 | root | root |
| node2 | 192.168.56.107 | root | root |
| node3 | 192.168.56.108 | root | root |

### 安装包信息

- **安装包路径**: `E:\dev tools\linux安装包\mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz`
- **版本**: MySQL Community Server 5.7.42
- **类型**: Linux 通用二进制包（无需编译）

---

## 安装步骤

### 步骤 1: 复制安装包到虚拟机

```bash
# 复制到 node1
scp "E:\dev tools\linux安装包\mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz" root@192.168.56.106:/root/

# 复制到 node2
scp "E:\dev tools\linux安装包\mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz" root@192.168.56.107:/root/

# 复制到 node3
scp "E:\dev tools\linux安装包\mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz" root@192.168.56.108:/root/
```

### 步骤 2: 解压安装包

```bash
tar -zxf mysql-5.7.42-linux-glibc2.12-x86_64.tar.gz
mv mysql-5.7.42-linux-glibc2.12-x86_64 /usr/local/mysql
```

### 步骤 3: 创建用户和组

```bash
groupadd -f mysql
useradd -r -s /sbin/nologin -g mysql mysql 2>/dev/null || true
```

### 步骤 4: 创建数据目录和日志目录

```bash
mkdir -p /data/mysql
chown -R mysql:mysql /data/mysql
chmod -R 755 /data/mysql

mkdir -p /var/log
touch /var/log/mysqld.log
chown mysql:mysql /var/log/mysqld.log

mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
```

### 步骤 5: 创建配置文件

```bash
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

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

[client]
socket=/tmp/mysql.sock
default-character-set=utf8mb4
EOF
```

### 步骤 6: 初始化数据库

```bash
cd /usr/local/mysql
./bin/mysqld --initialize --user=mysql --datadir=/data/mysql --log-error=/var/log/mysqld.log
```

### 步骤 7: 获取初始密码

```bash
grep 'temporary password' /var/log/mysqld.log
```

### 步骤 8: 启动 MySQL 服务

```bash
/usr/local/mysql/bin/mysqld_safe --defaults-file=/etc/my.cnf &
```

### 步骤 9: 设置密码和远程登录

```bash
# 将 INIT_PASS 替换为实际的初始密码
INIT_PASS="初始密码"

# 修改 root 密码为 root
/usr/local/mysql/bin/mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

# 允许远程登录
/usr/local/mysql/bin/mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"
```

### 步骤 10: 配置开机启动

```bash
cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
chmod +x /etc/init.d/mysqld
chkconfig --add mysqld
chkconfig mysqld on
```

---

## 各节点初始密码记录

| 节点 | 初始密码 |
|------|----------|
| node1 | FsdfjuXmd4_2 |
| node2 | i.=Ye&=si8+e |
| node3 | RuiAePK_z8zr |

---

## 验证安装

### 检查服务状态

```bash
ps aux | grep mysqld
```

### 测试本地连接

```bash
mysql -uroot -proot -e "SELECT VERSION();"
```

### 测试远程连接

```bash
# 从其他节点或主机连接
mysql -h 192.168.56.106 -uroot -proot
mysql -h 192.168.56.107 -uroot -proot
mysql -h 192.168.56.108 -uroot -proot
```

---

## 最终配置

### MySQL 配置信息

| 项目 | 值 |
|------|-----|
| 端口 | 3306 |
| 账号 | root |
| 密码 | root |
| 数据目录 | /data/mysql |
| 日志目录 | /var/log/mysqld.log |
| 套接字文件 | /tmp/mysql.sock |
| 远程访问 | 已开启 (root@%) |
| 开机启动 | 已启用 |

### 服务管理命令

```bash
# 启动服务
/etc/init.d/mysqld start

# 停止服务
/etc/init.d/mysqld stop

# 重启服务
/etc/init.d/mysqld restart

# 查看状态
/etc/init.d/mysqld status
```

---

## 故障排除

### 常见问题

1. **数据目录已存在文件**
   ```bash
   rm -rf /data/mysql/*
   ./bin/mysqld --initialize --user=mysql --datadir=/data/mysql
   ```

2. **端口占用**
   ```bash
   netstat -tlnp | grep 3306
   ```

3. **日志查看**
   ```bash
   tail -50 /var/log/mysqld.log
   ```

---

## 文件清单

### 创建的文件

| 文件 | 路径 | 说明 |
|------|------|------|
| MySQL安装目录 | /usr/local/mysql | MySQL主程序目录 |
| 数据目录 | /data/mysql | 数据库数据存储 |
| 配置文件 | /etc/my.cnf | MySQL配置文件 |
| 启动脚本 | /etc/init.d/mysqld | 服务启动脚本 |
| 日志文件 | /var/log/mysqld.log | 错误日志 |

### 本地脚本文件

| 文件 | 路径 | 说明 |
|------|------|------|
| install_mysql.sh | f:\m-knowledge\java\Mysql\ | 在线安装脚本 |
| install_mysql_offline.sh | f:\m-knowledge\java\Mysql\ | 离线安装脚本 |
| install_mysql.ps1 | f:\m-knowledge\java\Mysql\ | PowerShell远程脚本 |
| README.md | f:\m-knowledge\java\Mysql\ | 使用说明 |
| INSTALL_GUIDE.md | f:\m-knowledge\java\Mysql\ | 本安装指南 |

---

## 安装时间线

| 时间 | 节点 | 操作 | 状态 |
|------|------|------|------|
| 2026-06-15 22:27 | node1 | MySQL安装完成 | ✅ 成功 |
| 2026-06-15 22:31 | node2 | MySQL安装完成 | ✅ 成功 |
| 2026-06-15 22:33 | node3 | MySQL安装完成 | ✅ 成功 |

---

**文档版本**: v1.0  
**创建时间**: 2026-06-15  
**适用版本**: MySQL 5.7.42