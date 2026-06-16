# Redis哨兵集群部署指南

## 集群架构

```
┌─────────────────────────────────────────────────────────┐
│                    Redis哨兵集群                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐      ┌──────────────┐                │
│  │   node1      │      │   node2      │                │
│  │ 192.168.56.106│     │ 192.168.56.107│               │
│  │              │      │              │                │
│  │ Redis Master │◄─────│ Redis Slave  │                │
│  │   (6379)     │      │   (6379)     │                │
│  │              │      │              │                │
│  │   Sentinel   │      │   Sentinel   │                │
│  │   (26379)    │      │   (26379)    │                │
│  └──────────────┘      └──────────────┘                │
│         │                      │                        │
│         └──────────┬───────────┘                        │
│                    │                                    │
│         ┌──────────▼───────────┐                        │
│         │   node3              │                        │
│         │ 192.168.56.108       │                        │
│         │                      │                        │
│         │  Redis Slave         │                        │
│         │   (6379)             │                        │
│         │                      │                        │
│         │  Sentinel            │                        │
│         │   (26379)            │                        │
│         └──────────────────────┘                        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 节点规划

| 节点 | IP地址 | Redis角色 | Sentinel端口 |
|------|--------|-----------|--------------|
| node1 | 192.168.56.106 | 主节点 | 26379 |
| node2 | 192.168.56.107 | 从节点 | 26379 |
| node3 | 192.168.56.108 | 从节点 | 26379 |

## 部署步骤

### 前置要求

1. 确保所有节点可以互相SSH连接
2. 确保所有节点已安装CentOS 7
3. 确保root账号密码为root

### 方法一：使用部署脚本（推荐）

#### Linux/Mac用户

```bash
# 1. 安装sshpass工具
sudo apt-get install sshpass  # Ubuntu/Debian
sudo yum install sshpass      # CentOS/RHEL

# 2. 按顺序部署每个节点
chmod +x deploy.sh
./deploy.sh node1
./deploy.sh node2
./deploy.sh node3

# 3. 测试集群
chmod +x test-cluster.sh
./test-cluster.sh
```

#### Windows用户

```cmd
REM 1. 安装PuTTY工具
REM 下载地址: https://www.putty.org/

REM 2. 按顺序部署每个节点
deploy.bat node1
deploy.bat node2
deploy.bat node3

REM 3. 测试集群（需要WSL或Git Bash）
bash test-cluster.sh
```

### 方法二：手动部署

#### 在node1上部署主节点

```bash
# SSH连接到node1
ssh root@192.168.56.106

# 安装Redis
yum install -y epel-release
yum install -y redis

# 创建目录
mkdir -p /var/log/redis /var/lib/redis
chown -R redis:redis /var/log/redis /var/lib/redis

# 上传配置文件
# 将redis-master.conf上传到/etc/redis/redis.conf

# 配置防火墙
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --permanent --add-port=26379/tcp
firewall-cmd --reload

# 启动Redis
systemctl restart redis
systemctl enable redis

# 启动Sentinel
redis-server /etc/redis/sentinel.conf --sentinel
```

#### 在node2上部署从节点

```bash
# SSH连接到node2
ssh root@192.168.56.107

# 安装Redis
yum install -y epel-release
yum install -y redis

# 创建目录
mkdir -p /var/log/redis /var/lib/redis
chown -R redis:redis /var/log/redis /var/lib/redis

# 上传配置文件
# 将redis-slave.conf上传到/etc/redis/redis.conf
# 确保配置文件中有: replicaof 192.168.56.106 6379

# 配置防火墙
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --permanent --add-port=26379/tcp
firewall-cmd --reload

# 启动Redis
systemctl restart redis
systemctl enable redis

# 启动Sentinel
redis-server /etc/redis/sentinel.conf --sentinel
```

#### 在node3上部署从节点

```bash
# SSH连接到node3
ssh root@192.168.56.108

# 安装Redis
yum install -y epel-release
yum install -y redis

# 创建目录
mkdir -p /var/log/redis /var/lib/redis
chown -R redis:redis /var/log/redis /var/lib/redis

# 上传配置文件
# 将redis-slave.conf上传到/etc/redis/redis.conf
# 确保配置文件中有: replicaof 192.168.56.106 6379

# 配置防火墙
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --permanent --add-port=26379/tcp
firewall-cmd --reload

# 启动Redis
systemctl restart redis
systemctl enable redis

# 启动Sentinel
redis-server /etc/redis/sentinel.conf --sentinel
```

## 配置说明

### Redis配置

- **端口**: 6379
- **密码**: redis123456
- **持久化**: RDB + AOF
- **最大内存**: 无限制（可根据需要调整）

### Sentinel配置

- **端口**: 26379
- **监控名称**: mymaster
- **quorum**: 2（需要2个sentinel同意才进行故障转移）
- **下线判断时间**: 5000ms
- **故障转移超时**: 60000ms

## 验证部署

### 检查Redis服务

```bash
# 在每个节点上执行
redis-cli -a redis123456 ping
# 应该返回: PONG
```

### 检查主从复制

```bash
# 在主节点上
redis-cli -a redis123456 info replication

# 在从节点上
redis-cli -a redis123456 info replication
```

### 检查Sentinel状态

```bash
# 在每个节点上
redis-cli -p 26379 sentinel masters
redis-cli -p 26379 sentinel slaves mymaster
```

### 测试数据同步

```bash
# 在主节点写入数据
redis-cli -a redis123456 SET test_key "hello_world"

# 在从节点读取数据
redis-cli -a redis123456 GET test_key
# 应该返回: hello_world
```

## 故障转移测试

### 模拟主节点故障

```bash
# 在node1上停止Redis
systemctl stop redis

# 观察Sentinel日志
tail -f /var/log/redis/sentinel.log

# 检查新的主节点
redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
```

### 恢复故障节点

```bash
# 在node1上启动Redis
systemctl start redis

# 检查是否自动成为从节点
redis-cli -a redis123456 info replication
```

## 常见问题

### 1. 从节点无法连接主节点

检查防火墙设置和网络连通性：
```bash
# 检查端口是否开放
firewall-cmd --list-ports

# 测试网络连通性
telnet 192.168.56.106 6379
```

### 2. Sentinel无法进行故障转移

检查：
- 是否至少有2个Sentinel正常运行
- quorum设置是否正确
- 网络是否正常

### 3. 数据同步延迟

检查：
- 网络带宽
- Redis配置中的repl-backlog-size
- 主节点负载情况

## 维护建议

1. **定期备份**: 定期备份RDB文件
2. **监控告警**: 配置Redis和Sentinel的监控
3. **日志轮转**: 配置日志轮转避免磁盘占满
4. **安全加固**: 
   - 修改默认密码
   - 限制bind地址
   - 配置防火墙规则
5. **性能优化**: 根据实际负载调整配置参数

## 连接信息

- **主节点**: 192.168.56.106:6379
- **从节点1**: 192.168.56.107:6379
- **从节点2**: 192.168.56.108:6379
- **Sentinel**: 每个节点的26379端口
- **密码**: redis123456

## 应用连接示例

### Java (Jedis)

```java
Set<String> sentinels = new HashSet<>();
sentinels.add("192.168.56.106:26379");
sentinels.add("192.168.56.107:26379");
sentinels.add("192.168.56.108:26379");

JedisSentinelPool pool = new JedisSentinelPool(
    "mymaster", 
    sentinels,
    "redis123456"
);

try (Jedis jedis = pool.getResource()) {
    jedis.set("key", "value");
    String value = jedis.get("key");
}
```

### Python (redis-py)

```python
from redis.sentinel import Sentinel

sentinel = Sentinel([
    ('192.168.56.106', 26379),
    ('192.168.56.107', 26379),
    ('192.168.56.108', 26379)
], password='redis123456')

master = sentinel.master_for('mymaster', password='redis123456')
slave = sentinel.slave_for('mymaster', password='redis123456')

master.set('key', 'value')
value = slave.get('key')
```

## 卸载

如需卸载集群，在每个节点执行：

```bash
# 停止服务
systemctl stop redis
pkill redis-server

# 删除文件
rm -rf /etc/redis
rm -rf /var/lib/redis
rm -rf /var/log/redis

# 卸载Redis
yum remove -y redis
```