# Kafka 集群搭建完整教程

## 目录

1. [环境准备](#环境准备)
2. [软件安装](#软件安装)
3. [ZooKeeper 配置](#zookeeper-配置)
4. [Kafka 配置](#kafka-配置)
5. [服务启动](#服务启动)
6. [开机启动配置](#开机启动配置)
7. [集群验证](#集群验证)
8. [常用命令](#常用命令)
9. [故障排查](#故障排查)

---

## 环境准备

### 1.1 虚拟机环境

| 节点 | IP 地址 | 操作系统 | 内存 | 硬盘 |
|------|---------|----------|------|------|
| node1 | 192.168.56.106 | CentOS 7 | 2GB+ | 20GB+ |
| node2 | 192.168.56.107 | CentOS 7 | 2GB+ | 20GB+ |
| node3 | 192.168.56.108 | CentOS 7 | 2GB+ | 20GB+ |

**用户信息：**
- 用户名：root
- 密码：root

### 1.2 网络配置

确保所有节点之间网络互通：

```bash
# 在每个节点上测试网络连通性
ping 192.168.56.106
ping 192.168.56.107
ping 192.168.56.108
```

### 1.3 关闭防火墙

```bash
# 停止防火墙
systemctl stop firewalld

# 禁用防火墙开机启动
systemctl disable firewalld

# 检查防火墙状态
systemctl status firewalld
```

### 1.4 时间同步

```bash
# 安装 NTP 服务
yum install -y ntp

# 启动 NTP 服务
systemctl start ntpd
systemctl enable ntpd

# 检查时间同步状态
ntpq -p
```

---

## 软件安装

### 2.1 准备安装包

将以下安装包上传到 Windows 本地：

| 软件 | 版本 | 本地路径 |
|------|------|----------|
| JDK | 1.8.0_192 | `F:\fsdownload\jdk1.8.0_192.tar.gz` |
| Kafka | 2.3.1 | `F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz` |
| ZooKeeper | 3.4.6 | `F:\文档\16-kafka\zookeeper-3.4.6.tar.gz` |

### 2.2 安装 JDK（所有节点）

```bash
# 创建目录
mkdir -p /usr/local

# 上传 JDK 安装包
scp F:\fsdownload\jdk1.8.0_192.tar.gz root@192.168.56.106:/usr/local/
scp F:\fsdownload\jdk1.8.0_192.tar.gz root@192.168.56.107:/usr/local/
scp F:\fsdownload\jdk1.8.0_192.tar.gz root@192.168.56.108:/usr/local/

# 解压 JDK
tar -xzf /usr/local/jdk1.8.0_192.tar.gz -C /usr/local/

# 配置环境变量
echo 'export JAVA_HOME=/usr/local/jdk1.8.0_192' >> /etc/profile
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile

# 使环境变量生效
source /etc/profile

# 验证 Java 安装
java -version
```

### 2.3 安装 ZooKeeper（所有节点）

```bash
# 创建目录
mkdir -p /opt/zookeeper/{data,logs}

# 上传 ZooKeeper 安装包
scp "F:\文档\16-kafka\zookeeper-3.4.6.tar.gz" root@192.168.56.106:/opt/
scp "F:\文档\16-kafka\zookeeper-3.4.6.tar.gz" root@192.168.56.107:/opt/
scp "F:\文档\16-kafka\zookeeper-3.4.6.tar.gz" root@192.168.56.108:/opt/

# 解压 ZooKeeper
tar -xzf /opt/zookeeper-3.4.6.tar.gz -C /opt/zookeeper --strip-components=1
```

### 2.4 安装 Kafka（所有节点）

```bash
# 创建目录
mkdir -p /opt/kafka/logs

# 上传 Kafka 安装包
scp "F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz" root@192.168.56.106:/opt/
scp "F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz" root@192.168.56.107:/opt/
scp "F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz" root@192.168.56.108:/opt/

# 解压 Kafka
tar -xzf /opt/kafka_2.11-2.3.1.tar.gz -C /opt/kafka --strip-components=1
```

---

## ZooKeeper 配置

### 3.1 配置 ZooKeeper（所有节点）

```bash
# 创建配置文件
cat > /opt/zookeeper/conf/zoo.cfg << 'EOF'
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/opt/zookeeper/data
dataLogDir=/opt/zookeeper/logs
clientPort=2181
server.1=192.168.56.106:2888:3888
server.2=192.168.56.107:2888:3888
server.3=192.168.56.108:2888:3888
EOF
```

### 3.2 设置 myid（每个节点不同）

```bash
# node1 (192.168.56.106)
echo "1" > /opt/zookeeper/data/myid

# node2 (192.168.56.107)
echo "2" > /opt/zookeeper/data/myid

# node3 (192.168.56.108)
echo "3" > /opt/zookeeper/data/myid
```

### 3.3 验证配置

```bash
# 检查 myid 文件
cat /opt/zookeeper/data/myid

# 检查配置文件
cat /opt/zookeeper/conf/zoo.cfg
```

---

## Kafka 配置

### 4.1 配置 Kafka node1 (192.168.56.106)

```bash
cat > /opt/kafka/config/server.properties << EOF
broker.id=1
listeners=PLAINTEXT://192.168.56.106:9092
advertised.listeners=PLAINTEXT://192.168.56.106:9092
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/opt/kafka/logs
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=192.168.56.106:2181,192.168.56.107:2181,192.168.56.108:2181
zookeeper.connection.timeout.ms=6000
group.initial.rebalance.delay.ms=0
EOF
```

### 4.2 配置 Kafka node2 (192.168.56.107)

```bash
cat > /opt/kafka/config/server.properties << EOF
broker.id=2
listeners=PLAINTEXT://192.168.56.107:9092
advertised.listeners=PLAINTEXT://192.168.56.107:9092
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/opt/kafka/logs
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=192.168.56.106:2181,192.168.56.107:2181,192.168.56.108:2181
zookeeper.connection.timeout.ms=6000
group.initial.rebalance.delay.ms=0
EOF
```

### 4.3 配置 Kafka node3 (192.168.56.108)

```bash
cat > /opt/kafka/config/server.properties << EOF
broker.id=3
listeners=PLAINTEXT://192.168.56.108:9092
advertised.listeners=PLAINTEXT://192.168.56.108:9092
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
log.dirs=/opt/kafka/logs
num.partitions=3
num.recovery.threads.per.data.dir=1
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
zookeeper.connect=192.168.56.106:2181,192.168.56.107:2181,192.168.56.108:2181
zookeeper.connection.timeout.ms=6000
group.initial.rebalance.delay.ms=0
EOF
```

### 4.4 验证配置

```bash
# 检查 broker.id
grep broker.id /opt/kafka/config/server.properties

# 检查监听地址
grep listeners /opt/kafka/config/server.properties

# 检查 ZooKeeper 连接
grep zookeeper.connect /opt/kafka/config/server.properties
```

---

## 服务启动

### 5.1 启动 ZooKeeper 集群

```bash
# 在所有节点上启动 ZooKeeper
ssh root@192.168.56.106 "source /etc/profile && /opt/zookeeper/bin/zkServer.sh start"
ssh root@192.168.56.107 "source /etc/profile && /opt/zookeeper/bin/zkServer.sh start"
ssh root@192.168.56.108 "source /etc/profile && /opt/zookeeper/bin/zkServer.sh start"

# 等待 ZooKeeper 启动完成
sleep 10

# 检查 ZooKeeper 状态
ssh root@192.168.56.106 "/opt/zookeeper/bin/zkServer.sh status"
ssh root@192.168.56.107 "/opt/zookeeper/bin/zkServer.sh status"
ssh root@192.168.56.108 "/opt/zookeeper/bin/zkServer.sh status"
```

### 5.2 启动 Kafka 集群

```bash
# 在所有节点上启动 Kafka
ssh root@192.168.56.106 "export JAVA_HOME=/usr/local/jdk1.8.0_192 && export PATH=\$JAVA_HOME/bin:\$PATH && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties"
ssh root@192.168.56.107 "export JAVA_HOME=/usr/local/jdk1.8.0_192 && export PATH=\$JAVA_HOME/bin:\$PATH && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties"
ssh root@192.168.56.108 "export JAVA_HOME=/usr/local/jdk1.8.0_192 && export PATH=\$JAVA_HOME/bin:\$PATH && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties"

# 等待 Kafka 启动完成
sleep 10

# 检查进程状态
ssh root@192.168.56.106 "/usr/local/jdk1.8.0_192/bin/jps"
ssh root@192.168.56.107 "/usr/local/jdk1.8.0_192/bin/jps"
ssh root@192.168.56.108 "/usr/local/jdk1.8.0_192/bin/jps"
```

### 5.3 预期输出

```bash
# jps 命令应该显示：
QuorumPeerMain  # ZooKeeper 进程
Kafka           # Kafka 进程
Jps             # jps 命令本身
```

---

## 开机启动配置

### 6.1 创建启动脚本

#### 6.1.1 创建启动脚本

```bash
cat > /opt/kafka/scripts/start-all-services.sh << 'EOF'
#!/bin/bash
# Kafka 集群启动脚本（虚拟机端）

# 配置 Java 环境
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 日志文件
LOG_DIR="/opt/kafka/logs"
ZK_LOG="/opt/zookeeper/logs/zookeeper-startup.log"
KAFKA_LOG="/opt/kafka/logs/kafka-startup.log"

# 启动 ZooKeeper
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ZooKeeper..." >> $ZK_LOG
/opt/zookeeper/bin/zkServer.sh start >> $ZK_LOG 2>&1

# 等待 ZooKeeper 启动完成
sleep 5

# 启动 Kafka
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Kafka..." >> $KAFKA_LOG
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties >> $KAFKA_LOG 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All services started" >> $KAFKA_LOG
EOF
```

#### 6.1.2 创建停止脚本

```bash
cat > /opt/kafka/scripts/stop-all-services.sh << 'EOF'
#!/bin/bash
# Kafka 集群停止脚本（虚拟机端）

# 配置 Java 环境
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 日志文件
LOG_DIR="/opt/kafka/logs"
ZK_LOG="/opt/zookeeper/logs/zookeeper-stop.log"
KAFKA_LOG="/opt/kafka/logs/kafka-stop.log"

# 停止 Kafka
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping Kafka..." >> $KAFKA_LOG
/opt/kafka/bin/kafka-server-stop.sh >> $KAFKA_LOG 2>&1

# 等待 Kafka 停止完成
sleep 5

# 停止 ZooKeeper
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping ZooKeeper..." >> $ZK_LOG
/opt/zookeeper/bin/zkServer.sh stop >> $ZK_LOG 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All services stopped" >> $ZK_LOG
EOF
```

### 6.2 创建 systemd 服务文件

#### 6.2.1 创建 ZooKeeper 服务文件

```bash
cat > /opt/kafka/scripts/zookeeper.service << 'EOF'
[Unit]
Description=Apache ZooKeeper Service
After=network.target

[Service]
Type=forking
User=root
Group=root
Environment="JAVA_HOME=/usr/local/jdk1.8.0_192"
Environment="PATH=/usr/local/jdk1.8.0_192/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/zookeeper/bin/zkServer.sh start /opt/zookeeper/conf/zoo.cfg
ExecStop=/opt/zookeeper/bin/zkServer.sh stop /opt/zookeeper/conf/zoo.cfg
ExecReload=/opt/zookeeper/bin/zkServer.sh restart /opt/zookeeper/conf/zoo.cfg
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

#### 6.2.2 创建 Kafka 服务文件

```bash
cat > /opt/kafka/scripts/kafka.service << 'EOF'
[Unit]
Description=Apache Kafka Service
After=network.target zookeeper.service
Requires=zookeeper.service

[Service]
Type=forking
User=root
Group=root
Environment="JAVA_HOME=/usr/local/jdk1.8.0_192"
Environment="PATH=/usr/local/jdk1.8.0_192/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 6.3 配置开机启动

```bash
# 在所有节点上执行以下命令

# 1. 复制启动脚本到系统目录
cp /opt/kafka/scripts/start-all-services.sh /usr/local/bin/start-kafka-cluster
cp /opt/kafka/scripts/stop-all-services.sh /usr/local/bin/stop-kafka-cluster

# 2. 设置执行权限
chmod +x /usr/local/bin/start-kafka-cluster
chmod +x /usr/local/bin/stop-kafka-cluster
chmod +x /opt/kafka/scripts/*.sh

# 3. 复制 systemd 服务文件
cp /opt/kafka/scripts/zookeeper.service /etc/systemd/system/
cp /opt/kafka/scripts/kafka.service /etc/systemd/system/

# 4. 重新加载 systemd 配置
systemctl daemon-reload

# 5. 启用开机自启动
systemctl enable zookeeper.service
systemctl enable kafka.service

# 6. 启动服务
systemctl start zookeeper.service
sleep 5
systemctl start kafka.service

# 7. 检查服务状态
systemctl status zookeeper.service
systemctl status kafka.service
```

### 6.4 验证开机启动

```bash
# 检查服务是否已启用开机启动
systemctl is-enabled zookeeper.service
systemctl is-enabled kafka.service

# 检查服务是否正在运行
systemctl is-active zookeeper.service
systemctl is-active kafka.service
```

---

## 集群验证

### 7.1 检查进程状态

```bash
# 在所有节点上检查 Java 进程
/usr/local/jdk1.8.0_192/bin/jps

# 预期输出：
# QuorumPeerMain  # ZooKeeper 进程
# Kafka           # Kafka 进程
```

### 7.2 检查端口监听

```bash
# 检查 ZooKeeper 端口
ss -tlnp | grep 2181

# 检查 Kafka 端口
ss -tlnp | grep 9092
```

### 7.3 创建测试 Topic

```bash
# 在任意节点上执行
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 创建测试 Topic
/opt/kafka/bin/kafka-topics.sh --create \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092,192.168.56.107:9092,192.168.56.108:9092 \
    --partitions 3 \
    --replication-factor 3
```

### 7.4 查看 Topic 信息

```bash
# 查看 Topic 列表
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server 192.168.56.106:9092

# 查看 Topic 详情
/opt/kafka/bin/kafka-topics.sh --describe --topic test-topic --bootstrap-server 192.168.56.106:9092
```

### 7.5 预期输出

```
Topic:test-topic        PartitionCount:3        ReplicationFactor:3     Configs:segment.bytes=1073741824
        Topic: test-topic       Partition: 0    Leader: 3       Replicas: 3,1,2    Isr: 3,1,2
        Topic: test-topic       Partition: 1    Leader: 1       Replicas: 1,2,3    Isr: 1,2,3
        Topic: test-topic       Partition: 2    Leader: 2       Replicas: 2,3,1    Isr: 2,3,1
```

### 7.6 测试消息发送和接收

```bash
# 终端1：启动生产者
/opt/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server 192.168.56.106:9092

# 输入测试消息：
# Hello Kafka!
# This is a test message.

# 终端2：启动消费者
/opt/kafka/bin/kafka-console-consumer.sh --topic test-topic --bootstrap-server 192.168.56.106:9092 --from-beginning

# 应该能看到生产者发送的消息
```

---

## 常用命令

### 8.1 服务管理命令

```bash
# 快速启动所有服务
start-kafka-cluster

# 快速停止所有服务
stop-kafka-cluster

# Systemd 服务管理
systemctl start zookeeper kafka      # 启动服务
systemctl stop kafka zookeeper       # 停止服务
systemctl restart kafka zookeeper    # 重启服务
systemctl status zookeeper kafka     # 查看状态
systemctl enable zookeeper kafka     # 启用开机启动
systemctl disable zookeeper kafka    # 禁用开机启动
```

### 8.2 ZooKeeper 管理命令

```bash
# 启动 ZooKeeper
/opt/zookeeper/bin/zkServer.sh start

# 停止 ZooKeeper
/opt/zookeeper/bin/zkServer.sh stop

# 重启 ZooKeeper
/opt/zookeeper/bin/zkServer.sh restart

# 查看 ZooKeeper 状态
/opt/zookeeper/bin/zkServer.sh status

# 连接到 ZooKeeper 客户端
export JAVA_HOME=/usr/local/jdk1.8.0_192
/opt/zookeeper/bin/zkCli.sh -server 192.168.56.106:2181
```

### 8.3 Kafka 管理命令

```bash
# 启动 Kafka
export JAVA_HOME=/usr/local/jdk1.8.0_192
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties

# 停止 Kafka
/opt/kafka/bin/kafka-server-stop.sh

# 查看 Topic 列表
/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server 192.168.56.106:9092

# 创建 Topic
/opt/kafka/bin/kafka-topics.sh --create \
    --topic topic-name \
    --bootstrap-server 192.168.56.106:9092 \
    --partitions 3 \
    --replication-factor 3

# 查看 Topic 详情
/opt/kafka/bin/kafka-topics.sh --describe --topic topic-name --bootstrap-server 192.168.56.106:9092

# 删除 Topic
/opt/kafka/bin/kafka-topics.sh --delete --topic topic-name --bootstrap-server 192.168.56.106:9092

# 发送消息
/opt/kafka/bin/kafka-console-producer.sh --topic topic-name --bootstrap-server 192.168.56.106:9092

# 消费消息
/opt/kafka/bin/kafka-console-consumer.sh --topic topic-name --bootstrap-server 192.168.56.106:9092 --from-beginning

# 查看消费者组列表
/opt/kafka/bin/kafka-consumer-groups.sh --list --bootstrap-server 192.168.56.106:9092

# 查看消费者组详情
/opt/kafka/bin/kafka-consumer-groups.sh --describe --group group-name --bootstrap-server 192.168.56.106:9092
```

### 8.4 日志查看命令

```bash
# 查看 ZooKeeper 日志
tail -f /opt/zookeeper/logs/zookeeper-startup.log

# 查看 Kafka 日志
tail -f /opt/kafka/logs/server.log

# 查看 systemd 服务日志
journalctl -u zookeeper -f
journalctl -u kafka -f

# 查看最近的系统日志
journalctl -n 50
```

---

## 故障排查

### 9.1 服务无法启动

#### 9.1.1 检查 Java 环境

```bash
# 检查 Java 版本
java -version

# 检查 JAVA_HOME 环境变量
echo $JAVA_HOME

# 检查 PATH 环境变量
echo $PATH
```

#### 9.1.2 检查端口占用

```bash
# 检查 ZooKeeper 端口
ss -tlnp | grep 2181

# 检查 Kafka 端口
ss -tlnp | grep 9092

# 如果端口被占用，找到占用进程
lsof -i :2181
lsof -i :9092
```

#### 9.1.3 查看服务日志

```bash
# 查看 ZooKeeper 日志
journalctl -u zookeeper -n 50 --no-pager

# 查看 Kafka 日志
journalctl -u kafka -n 50 --no-pager

# 查看 Kafka 应用日志
tail -100 /opt/kafka/logs/server.log
```

### 9.2 集群连接问题

#### 9.2.1 检查网络连通性

```bash
# 测试节点间网络连通性
ping 192.168.56.106
ping 192.168.56.107
ping 192.168.56.108

# 测试端口连通性
telnet 192.168.56.106 2181
telnet 192.168.56.107 9092
```

#### 9.2.2 检查防火墙

```bash
# 检查防火墙状态
systemctl status firewalld

# 停止防火墙
systemctl stop firewalld

# 禁用防火墙
systemctl disable firewalld
```

#### 9.2.3 检查 ZooKeeper 集群状态

```bash
# 在每个节点上检查 ZooKeeper 状态
/opt/zookeeper/bin/zkServer.sh status

# 预期输出：
# Mode: leader 或 Mode: follower
```

### 9.3 Kafka 启动失败

#### 9.3.1 检查 ZooKeeper 连接

```bash
# 检查 ZooKeeper 是否正常
/opt/zookeeper/bin/zkServer.sh status

# 测试 ZooKeeper 连接
export JAVA_HOME=/usr/local/jdk1.8.0_192
/opt/zookeeper/bin/zkCli.sh -server 192.168.56.106:2181 ls /
```

#### 9.3.2 检查 Kafka 配置

```bash
# 检查 broker.id 是否唯一
grep broker.id /opt/kafka/config/server.properties

# 检查监听地址
grep listeners /opt/kafka/config/server.properties

# 检查 ZooKeeper 连接
grep zookeeper.connect /opt/kafka/config/server.properties
```

#### 9.3.3 检查磁盘空间

```bash
# 检查磁盘空间
df -h

# 检查日志目录空间
du -sh /opt/kafka/logs
```

### 9.4 性能问题

#### 9.4.1 检查系统资源

```bash
# 检查 CPU 使用率
top

# 检查内存使用情况
free -h

# 检查磁盘 I/O
iostat -x 1

# 检查网络连接
netstat -an | grep 9092 | wc -l
```

#### 9.4.2 检查 Kafka 性能指标

```bash
# 查看 Kafka 指标
/opt/kafka/bin/kafka-run-class.sh kafka.tools.JmxTool \
  --jmx-url service:jmx:rmi:///jndi/rmi://localhost:9999/jmxrmi \
  --object-name kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec
```

### 9.5 常见错误及解决方案

#### 错误1：ZooKeeper 无法启动

**错误信息：**
```
Error contacting service. It is probably not running.
```

**解决方案：**
```bash
# 检查 myid 文件是否存在
cat /opt/zookeeper/data/myid

# 检查配置文件
cat /opt/zookeeper/conf/zoo.cfg

# 检查端口占用
ss -tlnp | grep 2181

# 查看详细日志
tail -f /opt/zookeeper/logs/zookeeper.out
```

#### 错误2：Kafka 无法连接到 ZooKeeper

**错误信息：**
```
kafka.zookeeper.ZooKeeperClientTimeoutException: Timed out waiting for connection
```

**解决方案：**
```bash
# 检查 ZooKeeper 是否运行
/opt/zookeeper/bin/zkServer.sh status

# 检查网络连通性
ping 192.168.56.106
ping 192.168.56.107
ping 192.168.56.108

# 检查防火墙
systemctl status firewalld

# 检查 ZooKeeper 配置
grep zookeeper.connect /opt/kafka/config/server.properties
```

#### 错误3：Kafka 端口被占用

**错误信息：**
```
java.net.BindException: Address already in use
```

**解决方案：**
```bash
# 查找占用端口的进程
lsof -i :9092

# 停止占用端口的进程
kill -9 <PID>

# 或者修改 Kafka 配置文件中的端口
vim /opt/kafka/config/server.properties
```

#### 错误4：内存不足

**错误信息：**
```
java.lang.OutOfMemoryError: Java heap space
```

**解决方案：**
```bash
# 修改 Kafka 启动脚本中的内存配置
vim /opt/kafka/bin/kafka-server-start.sh

# 找到以下行并修改：
export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
```

---

## 附录

### A. 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| 2181 | ZooKeeper | 客户端连接端口 |
| 2888 | ZooKeeper | 集群内部通信端口 |
| 3888 | ZooKeeper | 集群选举端口 |
| 9092 | Kafka | 客户端连接端口 |

### B. 目录结构

```
/opt/
├── zookeeper/
│   ├── bin/              # ZooKeeper 执行脚本
│   ├── conf/
│   │   └── zoo.cfg       # ZooKeeper 配置文件
│   ├── data/
│   │   └── myid          # 节点标识
│   └── logs/             # ZooKeeper 日志目录
└── kafka/
    ├── bin/              # Kafka 执行脚本
    ├── config/
    │   └── server.properties  # Kafka 配置文件
    ├── logs/             # Kafka 日志目录
    └── scripts/          # 自定义脚本目录
```

### C. 配置文件位置

```
ZooKeeper 配置：/opt/zookeeper/conf/zoo.cfg
Kafka 配置：/opt/kafka/config/server.properties
Systemd 服务：/etc/systemd/system/zookeeper.service
             /etc/systemd/system/kafka.service
```

### D. 日志文件位置

```
ZooKeeper 日志：/opt/zookeeper/logs/zookeeper-startup.log
Kafka 日志：/opt/kafka/logs/kafka-startup.log
Kafka 服务日志：/opt/kafka/logs/server.log
Systemd 日志：journalctl -u zookeeper
              journalctl -u kafka
```

### E. 参考资料

- Kafka 官方文档：https://kafka.apache.org/documentation/
- ZooKeeper 官方文档：https://zookeeper.apache.org/doc/
- CentOS 7 系统管理：https://www.centos.org/docs/

---

## 总结

本教程详细介绍了在 CentOS 7 上搭建 Kafka 集群的完整过程，包括：

1. ✅ 环境准备和系统配置
2. ✅ JDK、ZooKeeper、Kafka 的安装
3. ✅ ZooKeeper 和 Kafka 的配置
4. ✅ 服务启动和验证
5. ✅ 开机自动启动配置
6. ✅ 常用命令和管理方法
7. ✅ 故障排查和问题解决

按照本教程操作后，您将拥有一个高可用、可自动重启的 Kafka 集群，适用于生产环境部署。

**集群信息：**
- 节点数量：3 个
- 默认分区数：3
- 副本因子：3
- 高可用性：✅ 支持
- 自动重启：✅ 支持
- 开机启动：✅ 支持