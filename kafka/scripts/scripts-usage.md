# Kafka 集群脚本文件说明

## 目录结构

```
f:\m-knowledge\java\kafka\scripts\
├── Deploy-Kafka-Cluster.ps1      # Windows端：一键部署脚本
├── Start-Cluster.ps1             # Windows端：启动集群脚本
├── Stop-Cluster.ps1              # Windows端：停止集群脚本
├── check-cluster.bat             # Windows端：检查集群状态
├── kafka.service                 # 虚拟机端：Kafka systemd 服务文件
├── zookeeper.service             # 虚拟机端：ZooKeeper systemd 服务文件
├── setup-autostart.sh            # 虚拟机端：开机启动配置脚本
├── start-all-services.sh         # 虚拟机端：启动所有服务脚本
└── stop-all-services.sh          # 虚拟机端：停止所有服务脚本
```

---

## Windows 端脚本

### 1. Deploy-Kafka-Cluster.ps1

**用途：** 一键部署 Kafka 集群到 CentOS 7 虚拟机

**功能：**
- 自动上传 JDK、ZooKeeper、Kafka 安装包
- 自动解压和安装软件
- 自动配置环境变量
- 自动配置 ZooKeeper 集群
- 自动配置 Kafka 集群
- 自动启动所有服务

**使用方法：**
```powershell
# 在 PowerShell 中执行
.\Deploy-Kafka-Cluster.ps1
```

**配置参数：**
```powershell
$localJdkPath = "F:\fsdownload\jdk1.8.0_192.tar.gz"
$localKafkaPath = "F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz"
$localZookeeperPath = "F:\文档\16-kafka\zookeeper-3.4.6.tar.gz"

$nodes = @(
    "192.168.56.106",
    "192.168.56.107",
    "192.168.56.108"
)
```

**前置条件：**
- Windows 已安装 OpenSSH 客户端
- 虚拟机已启动并可 SSH 连接
- 虚拟机防火墙已关闭
- 本地安装包文件存在

---

### 2. Start-Cluster.ps1

**用途：** 远程启动所有节点的 ZooKeeper 和 Kafka 服务

**功能：**
- 通过 SSH 远程连接到所有节点
- 启动 ZooKeeper 服务
- 等待 ZooKeeper 启动完成
- 启动 Kafka 服务
- 检查服务状态

**使用方法：**
```powershell
# 在 PowerShell 中执行
.\Start-Cluster.ps1
```

**执行流程：**
1. 连接到 node1, node2, node3
2. 启动 ZooKeeper（等待 5 秒）
3. 启动 Kafka（等待 10 秒）
4. 检查进程状态

---

### 3. Stop-Cluster.ps1

**用途：** 远程停止所有节点的 Kafka 和 ZooKeeper 服务

**功能：**
- 通过 SSH 远程连接到所有节点
- 停止 Kafka 服务
- 等待 Kafka 停止完成
- 停止 ZooKeeper 服务
- 检查服务状态

**使用方法：**
```powershell
# 在 PowerShell 中执行
.\Stop-Cluster.ps1
```

**执行流程：**
1. 连接到 node1, node2, node3
2. 停止 Kafka（等待 5 秒）
3. 停止 ZooKeeper（等待 3 秒）
4. 检查进程状态

---

### 4. check-cluster.bat

**用途：** 检查集群状态和进程信息

**功能：**
- 检查所有节点的 Java 进程
- 检查 ZooKeeper 和 Kafka 运行状态
- 检查端口监听情况

**使用方法：**
```batch
# 在命令提示符或 PowerShell 中执行
.\check-cluster.bat
```

**输出信息：**
- 每个节点的 Java 进程列表
- ZooKeeper 进程状态
- Kafka 进程状态
- 端口监听状态

---

## 虚拟机端脚本

### 5. zookeeper.service

**用途：** ZooKeeper systemd 服务配置文件

**功能：**
- 定义 ZooKeeper 为 systemd 服务
- 配置服务启动、停止、重启命令
- 配置环境变量
- 配置自动重启策略

**使用方法：**
```bash
# 复制服务文件到系统目录
cp /opt/kafka/scripts/zookeeper.service /etc/systemd/system/

# 重新加载 systemd 配置
systemctl daemon-reload

# 启用开机启动
systemctl enable zookeeper.service

# 启动服务
systemctl start zookeeper.service

# 查看服务状态
systemctl status zookeeper.service
```

**服务配置：**
```ini
[Unit]
Description=Apache ZooKeeper Service
After=network.target

[Service]
Type=forking
User=root
Environment="JAVA_HOME=/usr/local/jdk1.8.0_192"
ExecStart=/opt/zookeeper/bin/zkServer.sh start
ExecStop=/opt/zookeeper/bin/zkServer.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

### 6. kafka.service

**用途：** Kafka systemd 服务配置文件

**功能：**
- 定义 Kafka 为 systemd 服务
- 配置服务启动、停止、重启命令
- 配置环境变量
- 配置自动重启策略
- 配置服务依赖关系（依赖 ZooKeeper）

**使用方法：**
```bash
# 复制服务文件到系统目录
cp /opt/kafka/scripts/kafka.service /etc/systemd/system/

# 重新加载 systemd 配置
systemctl daemon-reload

# 启用开机启动
systemctl enable kafka.service

# 启动服务
systemctl start kafka.service

# 查看服务状态
systemctl status kafka.service
```

**服务配置：**
```ini
[Unit]
Description=Apache Kafka Service
After=network.target zookeeper.service
Requires=zookeeper.service

[Service]
Type=forking
User=root
Environment="JAVA_HOME=/usr/local/jdk1.8.0_192"
ExecStart=/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

### 7. setup-autostart.sh

**用途：** 一键配置开机启动脚本

**功能：**
- 复制启动脚本到系统目录
- 复制 systemd 服务文件
- 重新加载 systemd 配置
- 启用开机自启动
- 启动所有服务
- 检查服务状态

**使用方法：**
```bash
# 在每个虚拟机节点上执行
bash /opt/kafka/scripts/setup-autostart.sh
```

**执行流程：**
1. 复制启动脚本到 `/usr/local/bin/`
2. 复制服务文件到 `/etc/systemd/system/`
3. 重新加载 systemd 配置
4. 启用 zookeeper 和 kafka 服务
5. 启动 zookeeper 和 kafka 服务
6. 显示服务状态

**注意事项：**
- 需要以 root 用户执行
- 所有节点都需要执行此脚本
- 执行前确保 ZooKeeper 和 Kafka 已正确配置

---

### 8. start-all-services.sh

**用途：** 启动 ZooKeeper 和 Kafka 服务

**功能：**
- 配置 Java 环境
- 启动 ZooKeeper
- 等待 ZooKeeper 启动完成
- 启动 Kafka
- 记录启动日志

**使用方法：**
```bash
# 在虚拟机上执行
bash /opt/kafka/scripts/start-all-services.sh

# 或者使用快速命令（配置开机启动后）
start-kafka-cluster
```

**执行流程：**
1. 设置 JAVA_HOME 环境变量
2. 启动 ZooKeeper（记录日志）
3. 等待 5 秒
4. 启动 Kafka（记录日志）
5. 输出启动完成信息

**日志位置：**
- ZooKeeper 启动日志：`/opt/zookeeper/logs/zookeeper-startup.log`
- Kafka 启动日志：`/opt/kafka/logs/kafka-startup.log`

---

### 9. stop-all-services.sh

**用途：** 停止 Kafka 和 ZooKeeper 服务

**功能：**
- 配置 Java 环境
- 停止 Kafka
- 等待 Kafka 停止完成
- 停止 ZooKeeper
- 记录停止日志

**使用方法：**
```bash
# 在虚拟机上执行
bash /opt/kafka/scripts/stop-all-services.sh

# 或者使用快速命令（配置开机启动后）
stop-kafka-cluster
```

**执行流程：**
1. 设置 JAVA_HOME 环境变量
2. 停止 Kafka（记录日志）
3. 等待 5 秒
4. 停止 ZooKeeper（记录日志）
5. 输出停止完成信息

**日志位置：**
- ZooKeeper 停止日志：`/opt/zookeeper/logs/zookeeper-stop.log`
- Kafka 停止日志：`/opt/kafka/logs/kafka-stop.log`

---

## 使用场景

### 场景1：首次部署集群

```powershell
# Windows 端执行
cd f:\m-knowledge\java\kafka\scripts
.\Deploy-Kafka-Cluster.ps1
```

### 场景2：配置开机启动

```bash
# 在每个虚拟机节点上执行
bash /opt/kafka/scripts/setup-autostart.sh
```

### 场景3：日常启动/停止集群

**Windows 端：**
```powershell
# 启动集群
.\Start-Cluster.ps1

# 停止集群
.\Stop-Cluster.ps1

# 检查状态
.\check-cluster.bat
```

**虚拟机端：**
```bash
# 启动集群（每个节点）
start-kafka-cluster

# 停止集群（每个节点）
stop-kafka-cluster

# 使用 systemd 管理
systemctl start zookeeper kafka
systemctl stop kafka zookeeper
systemctl status zookeeper kafka
```

### 场景4：检查集群状态

```batch
# Windows 端执行
.\check-cluster.bat
```

### 场景5：重启单个服务

```bash
# 在虚拟机上执行
systemctl restart zookeeper
systemctl restart kafka
```

---

## 脚本依赖关系

```
Deploy-Kafka-Cluster.ps1 (部署)
    ↓
setup-autostart.sh (配置开机启动)
    ↓
zookeeper.service + kafka.service (服务定义)
    ↓
start-all-services.sh + stop-all-services.sh (启动/停止)
```

---

## 文件上传位置

### Windows 端脚本位置

```
本地路径：f:\m-knowledge\java\kafka\scripts\
```

### 虚拟机端脚本位置

```
虚拟机路径：/opt/kafka/scripts/
系统服务：/etc/systemd/system/
快速命令：/usr/local/bin/
```

---

## 注意事项

1. **执行顺序**
   - 首次部署：先执行 `Deploy-Kafka-Cluster.ps1`
   - 配置开机启动：在每个节点执行 `setup-autostart.sh`
   - 日常管理：使用 systemd 命令或快速命令

2. **环境要求**
   - Windows：需要 OpenSSH 客户端
   - 虚拟机：需要 Java 环境、关闭防火墙

3. **权限要求**
   - Windows：普通用户即可
   - 虚拟机：需要 root 权限

4. **网络要求**
   - Windows 和虚拟机之间网络互通
   - 虚拟机节点之间网络互通
   - SSH 连接正常

5. **日志位置**
   - Windows 端：PowerShell 输出
   - 虚拟机端：`/opt/zookeeper/logs/` 和 `/opt/kafka/logs/`

---

## 快速命令参考

### Windows 端

```powershell
# 部署集群
.\Deploy-Kafka-Cluster.ps1

# 启动集群
.\Start-Cluster.ps1

# 停止集群
.\Stop-Cluster.ps1

# 检查状态
.\check-cluster.bat
```

### 虚拟机端

```bash
# 快速命令（配置开机启动后可用）
start-kafka-cluster          # 启动所有服务
stop-kafka-cluster           # 停止所有服务

# Systemd 命令
systemctl start zookeeper kafka     # 启动服务
systemctl stop kafka zookeeper      # 停止服务
systemctl restart kafka zookeeper   # 重启服务
systemctl status zookeeper kafka    # 查看状态
systemctl enable zookeeper kafka    # 启用开机启动
systemctl disable zookeeper kafka   # 禁用开机启动

# 手动启动（未配置开机启动时）
bash /opt/kafka/scripts/start-all-services.sh
bash /opt/kafka/scripts/stop-all-services.sh
```

---

## 总结

本脚本集提供了完整的 Kafka 集群管理功能：

- ✅ **一键部署**：`Deploy-Kafka-Cluster.ps1`
- ✅ **远程管理**：`Start-Cluster.ps1`、`Stop-Cluster.ps1`
- ✅ **状态检查**：`check-cluster.bat`
- ✅ **开机启动**：`setup-autostart.sh`、服务文件
- ✅ **服务管理**：`start-all-services.sh`、`stop-all-services.sh`

所有脚本都已优化，去除了重复和无用的文件，保持了最小必要的脚本集合。