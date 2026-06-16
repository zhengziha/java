# Redis 哨兵集群搭建文档

## 一、集群架构规划

### 1.1 架构设计

本集群采用 **1主2从 + 3哨兵** 的高可用架构：

| 节点 | IP地址 | 角色 | Redis端口 | 哨兵端口 |
|------|--------|------|----------|----------|
| node1 | 192.168.56.106 | 主节点 + 哨兵 | 6379 | 26379 |
| node2 | 192.168.56.107 | 从节点 + 哨兵 | 6379 | 26379 |
| node3 | 192.168.56.108 | 从节点 + 哨兵 | 6379 | 26379 |

### 1.2 架构说明

- **主节点**：处理所有写操作，负责数据同步到从节点
- **从节点**：只读副本，提供读负载均衡，主节点故障时可被选举为新主节点
- **哨兵节点**：监控主从状态，自动进行故障检测和故障转移

---

## 二、环境准备

### 2.1 服务器信息

服务器信息存储在 `server.txt` 文件中：
```
node1:192.168.56.106
node2:192.168.56.107
node3:192.168.56.108
```

### 2.2 SSH免密登录配置

```powershell
# 生成SSH密钥
ssh-keygen -t ed25519 -N "" -f $env:USERPROFILE\.ssh\id_ed25519

# 复制密钥到各节点
ssh-copy-id root@192.168.56.106
ssh-copy-id root@192.168.56.107
ssh-copy-id root@192.168.56.108
```

### 2.3 网络配置（解决外网访问问题）

```bash
# 配置DNS
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 114.114.114.114' >> /etc/resolv.conf

# 配置外网接口（enp0s3）
dhclient enp0s3

# 验证网络
ping -c 2 8.8.8.8
ping -c 2 baidu.com
```

### 2.4 Yum源配置（CentOS 7）

由于CentOS 7官方源已失效，替换为Vault仓库：

```ini
[base]
name=CentOS-7.6 - Base
baseurl=http://vault.centos.org/7.6.1810/os/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[updates]
name=CentOS-7.6 - Updates
baseurl=http://vault.centos.org/7.6.1810/updates/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

[extras]
name=CentOS-7.6 - Extras
baseurl=http://vault.centos.org/7.6.1810/extras/x86_64/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
```

---

## 三、Redis编译安装

### 3.1 安装依赖

```bash
yum install -y gcc make
```

### 3.2 下载并编译Redis

```bash
# 上传源码包到各节点
scp redis-7.0.15.tar.gz root@192.168.56.106:/tmp/
scp redis-7.0.15.tar.gz root@192.168.56.107:/tmp/
scp redis-7.0.15.tar.gz root@192.168.56.108:/tmp/

# 解压编译（每个节点执行）
cd /tmp
tar zxf redis-7.0.15.tar.gz
cd redis-7.0.15
make distclean
make -j4 MALLOC=libc
make install
```

> **注意**：使用 `MALLOC=libc` 避免 jemalloc 依赖问题

---

## 四、主节点配置

### 4.1 创建目录和用户

```bash
mkdir -p /etc/redis /var/log/redis /var/lib/redis
useradd -M redis
chown -R redis:redis /var/log/redis /var/lib/redis
```

### 4.2 主节点配置文件 `/etc/redis/redis.conf`

```ini
port 6379
bind 0.0.0.0
daemonize yes
logfile "/var/log/redis/redis.log"
dir /var/lib/redis
databases 16

# RDB持久化
save 900 1
save 300 10
save 60 10000
dbfilename dump.rdb

# AOF持久化
appendonly yes
appendfilename "appendonly.aof"

# 密码设置
requirepass "redis123456"
masterauth "redis123456"

# 最大客户端连接数
maxclients 10000

# 内存淘汰策略
maxmemory-policy allkeys-lru

# 慢查询日志
slowlog-log-slower-than 10000
slowlog-max-len 128
```

### 4.3 启动主节点

```bash
redis-server /etc/redis/redis.conf
```

---

## 五、从节点配置

### 5.1 从节点配置文件 `/etc/redis/redis.conf`

```ini
port 6379
bind 0.0.0.0
daemonize yes
logfile "/var/log/redis/redis-slave.log"
dir /var/lib/redis
databases 16

# RDB持久化
save 900 1
save 300 10
save 60 10000
dbfilename dump-slave.rdb

# AOF持久化
appendonly yes
appendfilename "appendonly-slave.aof"

# 密码设置
requirepass "redis123456"
masterauth "redis123456"

# 配置为从节点
replicaof 192.168.56.106 6379
replica-read-only yes

# 最大客户端连接数
maxclients 10000

# 内存淘汰策略
maxmemory-policy allkeys-lru
```

### 5.2 启动从节点

```bash
redis-server /etc/redis/redis.conf
```

---

## 六、哨兵配置

### 6.1 哨兵配置文件 `/etc/redis/sentinel.conf`（所有节点相同）

```ini
port 26379
bind 0.0.0.0
daemonize yes
logfile "/var/log/redis/sentinel.log"
dir /var/lib/redis

# 监控主节点
sentinel monitor mymaster 192.168.56.106 6379 2

# 主节点密码
sentinel auth-pass mymaster redis123456

# 故障判定时间（毫秒）
sentinel down-after-milliseconds mymaster 30000

# 故障转移超时时间（毫秒）
sentinel failover-timeout mymaster 180000

# 并行同步的从节点数
sentinel parallel-syncs mymaster 1
```

### 6.2 启动哨兵

```bash
redis-sentinel /etc/redis/sentinel.conf
```

---

## 七、集群验证

### 7.1 验证主从复制状态

```bash
# 在主节点执行
redis-cli -a redis123456 INFO replication
```

预期输出：
```
# Replication
role:master
connected_slaves:2
slave0:ip=192.168.56.107,port=6379,state=online,offset=xxx,lag=0
slave1:ip=192.168.56.108,port=6379,state=online,offset=xxx,lag=1
```

### 7.2 验证哨兵状态

```bash
redis-cli -p 26379 INFO sentinel
```

预期输出：
```
# Sentinel
sentinel_masters:1
master0:name=mymaster,status=ok,address=192.168.56.106:6379,slaves=2,sentinels=3
```

### 7.3 验证数据复制

```bash
# 主节点写入数据
redis-cli -h 192.168.56.106 -a redis123456 SET testkey "Hello Redis Sentinel!"

# 从节点读取数据
redis-cli -h 192.168.56.107 -a redis123456 GET testkey
redis-cli -h 192.168.56.108 -a redis123456 GET testkey
```

---

## 八、故障转移测试

### 8.1 模拟主节点故障

```bash
# 在主节点执行，模拟宕机
redis-cli -a redis123456 DEBUG sleep 60
```

### 8.2 验证故障转移

```bash
# 等待30秒后检查哨兵状态
redis-cli -p 26379 INFO sentinel

# 检查新主节点
redis-cli -h 192.168.56.107 -a redis123456 INFO replication
redis-cli -h 192.168.56.108 -a redis123456 INFO replication
```

### 8.3 故障转移说明

1. 哨兵检测到主节点不可达
2. 超过 `down-after-milliseconds`（30秒）后标记为主观下线
3. 超过quorum（2个）哨兵同意后标记为客观下线
4. 选举新主节点
5. 其他从节点指向新主节点
6. 原主节点恢复后自动成为从节点

---

## 九、常用运维命令

### 9.1 查看Redis进程

```bash
ps aux | grep redis
```

### 9.2 查看日志

```bash
# Redis日志
tail -f /var/log/redis/redis.log

# 哨兵日志
tail -f /var/log/redis/sentinel.log
```

### 9.3 连接Redis

```bash
# 连接主节点
redis-cli -h 192.168.56.106 -a redis123456

# 连接哨兵
redis-cli -h 192.168.56.106 -p 26379
```

### 9.4 哨兵命令

```bash
# 获取主节点信息
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster

# 获取从节点列表
redis-cli -p 26379 SENTINEL slaves mymaster

# 获取哨兵列表
redis-cli -p 26379 SENTINEL sentinels mymaster
```

---

## 十、注意事项

1. **防火墙配置**：确保6379和26379端口对外开放
2. **时间同步**：各节点时间需同步，建议配置NTP
3. **内存配置**：根据实际业务需求调整 `maxmemory` 参数
4. **持久化策略**：根据数据重要性选择RDB和AOF策略
5. **备份策略**：定期备份RDB和AOF文件
6. **监控告警**：建议配置Prometheus + Grafana监控

---

## 附录：部署脚本说明

### 脚本列表

| 脚本文件 | 用途 |
|----------|------|
| `setup-ssh.ps1` | SSH免密登录配置 |
| `fix-network.ps1` | 网络配置修复 |
| `deploy-full.ps1` | 完整部署脚本 |
| `redis-master.conf` | 主节点配置模板 |
| `redis-slave.conf` | 从节点配置模板 |
| `sentinel.conf` | 哨兵配置模板 |

---

**文档生成时间**：2026年6月15日  
**Redis版本**：7.0.15  
**集群状态**：✅ 已成功部署