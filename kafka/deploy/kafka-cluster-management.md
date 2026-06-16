# Kafka 集群管理文档

## 集群状态

| 节点 | IP | ZooKeeper | Kafka | 开机启动 |
|------|----|-----------|-------|---------|
| node1 | 192.168.56.106 | ✅ 运行中 | ✅ 运行中 | ✅ 已启用 |
| node2 | 192.168.56.107 | ✅ 运行中 | ✅ 运行中 | ✅ 已启用 |
| node3 | 192.168.56.108 | ✅ 运行中 | ✅ 运行中 | ✅ 已启用 |

## 虚拟机端启动命令

### 快速启动/停止脚本

```bash
# 启动所有服务
start-kafka-cluster

# 停止所有服务
stop-kafka-cluster
```

### Systemd 服务管理

```bash
# 启动服务
systemctl start zookeeper kafka

# 停止服务
systemctl stop kafka zookeeper

# 重启服务
systemctl restart kafka zookeeper

# 查看服务状态
systemctl status zookeeper kafka

# 查看服务日志
journalctl -u zookeeper -f
journalctl -u kafka -f

# 启用开机启动
systemctl enable zookeeper kafka

# 禁用开机启动
systemctl disable zookeeper kafka
```

## 虚拟机端手动启动命令

### ZooKeeper

```bash
# 启动 ZooKeeper
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH
/opt/zookeeper/bin/zkServer.sh start

# 停止 ZooKeeper
/opt/zookeeper/bin/zkServer.sh stop

# 查看 ZooKeeper 状态
/opt/zookeeper/bin/zkServer.sh status
```

### Kafka

```bash
# 启动 Kafka
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties

# 停止 Kafka
/opt/kafka/bin/kafka-server-stop.sh
```

## 常用 Kafka 命令

### Topic 管理

```bash
# 创建 Topic
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH
/opt/kafka/bin/kafka-topics.sh --create \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092,192.168.56.107:9092,192.168.56.108:9092 \
    --partitions 3 \
    --replication-factor 3

# 查看 Topic 列表
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server 192.168.56.106:9092

# 查看 Topic 详情
/opt/kafka/bin/kafka-topics.sh --describe --topic test-topic --bootstrap-server 192.168.56.106:9092

# 删除 Topic
/opt/kafka/bin/kafka-topics.sh --delete --topic test-topic --bootstrap-server 192.168.56.106:9092
```

### 消息生产与消费

```bash
# 发送消息
/opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server 192.168.56.106:9092

# 消费消息（从头开始）
/opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --bootstrap-server 192.168.56.106:9092 --from-beginning

# 消费消息（从最新开始）
/opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --bootstrap-server 192.168.56.106:9092
```

### 消费者组管理

```bash
# 查看消费者组列表
/opt/kafka/bin/kafka-consumer-groups.sh --list --bootstrap-server 192.168.56.106:9092

# 查看消费者组详情
/opt/kafka/bin/kafka-consumer-groups.sh --describe --group test-group --bootstrap-server 192.168.56.106:9092

# 重置消费者组 offset
/opt/kafka/bin/kafka-consumer-groups.sh --reset-offsets --group test-group --topic test-topic --to-earliest --execute --bootstrap-server 192.168.56.106:9092
```

## 进程检查

```bash
# 查看所有 Java 进程
/usr/local/jdk1.8.0_192/bin/jps

# 预期输出：
# QuorumPeerMain  (ZooKeeper)
# Kafka           (Kafka Broker)
```

## 日志文件位置

```
ZooKeeper 日志：
  /opt/zookeeper/logs/zookeeper-startup.log
  /opt/zookeeper/logs/zookeeper-stop.log

Kafka 日志：
  /opt/kafka/logs/kafka-startup.log
  /opt/kafka/logs/kafka-stop.log
  /opt/kafka/logs/server.log
```

## 端口说明

| 服务 | 端口 | 说明 |
|------|------|------|
| ZooKeeper | 2181 | 客户端连接端口 |
| ZooKeeper | 2888 | 集群内部通信端口 |
| ZooKeeper | 3888 | 集群选举端口 |
| Kafka | 9092 | 客户端连接端口 |

## 故障排查

### 服务无法启动

1. 检查 Java 环境：
   ```bash
   java -version
   echo $JAVA_HOME
   ```

2. 检查端口占用：
   ```bash
   ss -tlnp | grep 2181
   ss -tlnp | grep 9092
   ```

3. 查看服务日志：
   ```bash
   journalctl -u zookeeper -n 50
   journalctl -u kafka -n 50
   ```

4. 查看应用日志：
   ```bash
   tail -f /opt/kafka/logs/server.log
   ```

### 集群连接问题

1. 检查网络连通性：
   ```bash
   ping 192.168.56.106
   ping 192.168.56.107
   ping 192.168.56.108
   ```

2. 检查防火墙：
   ```bash
   systemctl status firewalld
   systemctl stop firewalld
   systemctl disable firewalld
   ```

3. 检查 ZooKeeper 集群状态：
   ```bash
   /opt/zookeeper/bin/zkServer.sh status
   ```

## Windows 端管理脚本

### PowerShell 脚本

```powershell
# 启动集群
.\Start-Cluster.ps1

# 停止集群
.\Stop-Cluster.ps1

# 检查集群状态
.\check-cluster.bat
```

## 配置文件位置

```
ZooKeeper 配置：
  /opt/zookeeper/conf/zoo.cfg

Kafka 配置：
  /opt/kafka/config/server.properties

Systemd 服务配置：
  /etc/systemd/system/zookeeper.service
  /etc/systemd/system/kafka.service
```

## 注意事项

1. **启动顺序**：必须先启动 ZooKeeper，再启动 Kafka
2. **停止顺序**：必须先停止 Kafka，再停止 ZooKeeper
3. **环境变量**：确保 JAVA_HOME 和 PATH 正确设置
4. **防火墙**：确保防火墙已关闭或开放必要端口
5. **时间同步**：确保所有节点时间同步
6. **内存配置**：建议每个节点至少 2GB 内存