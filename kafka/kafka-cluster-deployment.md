# Kafka 集群部署文档

## 环境信息

| 节点 | IP 地址 | 角色 |
|------|---------|------|
| node1 | 192.168.56.106 | ZooKeeper + Kafka |
| node2 | 192.168.56.107 | ZooKeeper + Kafka |
| node3 | 192.168.56.108 | ZooKeeper + Kafka |

**系统**: CentOS 7  
**用户名**: root  
**密码**: root

---

## 本地文件路径

| 文件 | 路径 |
|------|------|
| JDK 1.8 | `F:\fsdownload\jdk1.8.0_192.tar.gz` |
| Kafka | `F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz` |
| ZooKeeper | `F:\文档\16-kafka\zookeeper-3.4.6.tar.gz` |

---

## 部署脚本结构

```
java/kafka/scripts/
├── Deploy-Kafka-Cluster.ps1    # PowerShell 一键部署（推荐）
├── Deploy-Kafka-Simple.ps1     # PowerShell 分步部署
├── Start-Cluster.ps1           # PowerShell 启动集群
├── Stop-Cluster.ps1            # PowerShell 停止集群
├── deploy-kafka-cluster.sh     # Linux 一键部署脚本
├── start-all.sh                # Linux 一键启动
├── stop-all.sh                 # Linux 一键停止
└── check-cluster.bat           # Windows 集群状态检查
```

---

## Windows 环境准备

### 1. 安装 OpenSSH

**方法一：使用 Windows 设置**
1. 打开「设置」→「应用」→「可选功能」
2. 点击「添加功能」
3. 搜索「OpenSSH 客户端」并安装

**方法二：使用 PowerShell**
```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### 2. 配置 SSH 密钥登录（推荐）

```powershell
# 生成 SSH 密钥（一路回车即可）
ssh-keygen -t rsa

# 将公钥复制到所有节点
ssh-copy-id root@192.168.56.106
ssh-copy-id root@192.168.56.107
ssh-copy-id root@192.168.56.108
```

### 3. 测试 SSH 连接

```powershell
ssh root@192.168.56.106 "hostname"
```

---

## 部署步骤（Windows）

### 方法一：一键部署（推荐）

```powershell
# 打开 PowerShell（以管理员身份运行）
cd F:\m-knowledge\java\kafka\scripts

# 执行一键部署脚本
.\Deploy-Kafka-Cluster.ps1
```

### 方法二：分步部署

```powershell
# 打开 PowerShell
cd F:\m-knowledge\java\kafka\scripts

# 部署 node1
.\Deploy-Kafka-Simple.ps1 -Node "192.168.56.106" -NodeId 1

# 部署 node2
.\Deploy-Kafka-Simple.ps1 -Node "192.168.56.107" -NodeId 2

# 部署 node3
.\Deploy-Kafka-Simple.ps1 -Node "192.168.56.108" -NodeId 3
```

---

## 启动和停止集群

### 启动集群

```powershell
cd F:\m-knowledge\java\kafka\scripts
.\Start-Cluster.ps1
```

### 停止集群

```powershell
cd F:\m-knowledge\java\kafka\scripts
.\Stop-Cluster.ps1
```

---

## 部署步骤（Linux 手动）

### 1. 安装 Java 环境（所有节点）

```bash
mkdir -p /usr/local
tar -xzf /usr/local/jdk1.8.0_192.tar.gz -C /usr/local/
echo 'export JAVA_HOME=/usr/local/jdk1.8.0_192' >> /etc/profile
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /etc/profile
source /etc/profile
```

### 2. 安装 ZooKeeper（所有节点）

```bash
mkdir -p /opt/zookeeper/{data,logs}
tar -xzf /opt/zookeeper-3.4.6.tar.gz -C /opt/zookeeper --strip-components=1

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

# 设置 myid（每个节点不同）
# node1: echo "1" > /opt/zookeeper/data/myid
# node2: echo "2" > /opt/zookeeper/data/myid
# node3: echo "3" > /opt/zookeeper/data/myid
```

### 3. 安装 Kafka（所有节点）

```bash
mkdir -p /opt/kafka/logs
tar -xzf /opt/kafka_2.11-2.3.1.tar.gz -C /opt/kafka --strip-components=1

cat > /opt/kafka/config/server.properties << EOF
broker.id=1  # node2: 2, node3: 3
listeners=PLAINTEXT://192.168.56.106:9092  # 对应节点IP
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

### 4. 启动服务

```bash
# 启动 ZooKeeper（所有节点）
/opt/zookeeper/bin/zkServer.sh start

# 启动 Kafka（所有节点）
source /etc/profile && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
```

---

## 验证集群

### 创建测试 Topic

```bash
/opt/kafka/bin/kafka-topics.sh --create \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092,192.168.56.107:9092,192.168.56.108:9092 \
    --partitions 3 \
    --replication-factor 3
```

### 查看 Topic 信息

```bash
/opt/kafka/bin/kafka-topics.sh --describe \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092
```

### 发送消息

```bash
/opt/kafka/bin/kafka-console-producer.sh \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092
```

### 消费消息

```bash
/opt/kafka/bin/kafka-console-consumer.sh \
    --topic test-topic \
    --bootstrap-server 192.168.56.106:9092 \
    --from-beginning
```

---

## 目录结构

```
/opt/
├── zookeeper/
│   ├── bin/              # 执行脚本
│   ├── conf/
│   │   └── zoo.cfg       # 配置文件
│   ├── data/
│   │   └── myid          # 节点标识
│   └── logs/             # 日志目录
└── kafka/
    ├── bin/              # 执行脚本
    ├── config/
    │   └── server.properties  # 配置文件
    └── logs/             # 日志目录
```

---

## 注意事项

1. **防火墙配置**：确保开放以下端口
   - ZooKeeper: 2181, 2888, 3888
   - Kafka: 9092

2. **SELinux**：建议关闭或配置适当规则

3. **时间同步**：确保所有节点时间同步

4. **内存配置**：建议每个节点至少 2GB 内存

5. **SSH 密钥**：推荐配置 SSH 密钥登录，避免每次输入密码