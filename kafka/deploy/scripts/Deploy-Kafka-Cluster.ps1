<#
.SYNOPSIS
Kafka 集群一键部署脚本（PowerShell 版本）

.DESCRIPTION
此脚本用于在 CentOS 7 虚拟机集群上部署 Kafka + ZooKeeper
需要在 Windows 10/11 上运行，且已安装 OpenSSH

.NOTES
作者: Auto Deploy
日期: 2024
#>

# ==================== 配置参数 ====================
$localJdkPath = "F:\fsdownload\jdk1.8.0_192.tar.gz"
$localKafkaPath = "F:\文档\16-kafka\kafka_2.11-2.3.1.tar.gz"
$localZookeeperPath = "F:\文档\16-kafka\zookeeper-3.4.6.tar.gz"

$remoteUser = "root"
$remotePass = "root"

$nodes = @(
    "192.168.56.106",
    "192.168.56.107",
    "192.168.56.108"
)

$jdkDir = "/usr/local/jdk1.8.0_192"
$zookeeperDir = "/opt/zookeeper"
$kafkaDir = "/opt/kafka"

# ==================== 辅助函数 ====================
function Write-Info {
    param([string]$message)
    Write-Host "`n[INFO] $message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$message)
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
}

function Write-Error {
    param([string]$message)
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

function Invoke-SshCommand {
    param(
        [string]$node,
        [string]$command
    )
    $encodedPass = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remotePass))
    $sshCommand = "sshpass -p $remotePass ssh -o StrictHostKeyChecking=no $remoteUser@$node `"$command`""
    Write-Host "执行: $sshCommand"
    Invoke-Expression $sshCommand
}

function Invoke-ScpFile {
    param(
        [string]$localPath,
        [string]$node,
        [string]$remotePath
    )
    $scpCommand = "sshpass -p $remotePass scp -o StrictHostKeyChecking=no `"$localPath`" $remoteUser@$node:`"$remotePath`""
    Write-Host "执行: $scpCommand"
    Invoke-Expression $scpCommand
}

# ==================== 主部署流程 ====================
Clear-Host
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "        Kafka 集群部署脚本 (PowerShell)" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow

# 1. 检查依赖
Write-Info "检查依赖..."
if (-not (Get-Command "sshpass" -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 sshpass，请先安装！"
    Write-Info "安装方法：使用 Chocolatey 安装 choco install sshpass"
    exit 1
}
Write-Success "sshpass 已安装"

# 2. 检查本地文件
Write-Info "检查本地安装包..."
if (-not (Test-Path $localJdkPath)) {
    Write-Error "JDK 文件不存在: $localJdkPath"
    exit 1
}
if (-not (Test-Path $localKafkaPath)) {
    Write-Error "Kafka 文件不存在: $localKafkaPath"
    exit 1
}
if (-not (Test-Path $localZookeeperPath)) {
    Write-Error "ZooKeeper 文件不存在: $localZookeeperPath"
    exit 1
}
Write-Success "所有本地文件检查通过"

# 3. 部署到每个节点
for ($i = 0; $i -lt $nodes.Length; $i++) {
    $node = $nodes[$i]
    $nodeId = $i + 1
    
    Write-Info "========== 正在部署 node$nodeId ($node) =========="
    
    # 3.1 创建目录结构
    Write-Info "创建目录结构..."
    Invoke-SshCommand -node $node -command "mkdir -p /opt/zookeeper/{data,logs} /opt/kafka/logs /usr/local"
    
    # 3.2 上传并解压 JDK
    Write-Info "上传并解压 JDK..."
    Invoke-ScpFile -localPath $localJdkPath -node $node -remotePath "/usr/local/"
    Invoke-SshCommand -node $node -command "tar -xzf /usr/local/jdk1.8.0_192.tar.gz -C /usr/local/"
    
    # 3.3 配置 Java 环境变量
    Write-Info "配置 Java 环境变量..."
    Invoke-SshCommand -node $node -command "echo 'export JAVA_HOME=/usr/local/jdk1.8.0_192' >> /etc/profile && echo 'export PATH=\$JAVA_HOME/bin:\$PATH' >> /etc/profile"
    
    # 3.4 上传并解压 ZooKeeper
    Write-Info "上传并解压 ZooKeeper..."
    Invoke-ScpFile -localPath $localZookeeperPath -node $node -remotePath "/opt/"
    Invoke-SshCommand -node $node -command "tar -xzf /opt/zookeeper-3.4.6.tar.gz -C /opt/zookeeper --strip-components=1"
    
    # 3.5 配置 ZooKeeper
    Write-Info "配置 ZooKeeper..."
    $zooCfg = @'
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/opt/zookeeper/data
dataLogDir=/opt/zookeeper/logs
clientPort=2181
server.1=192.168.56.106:2888:3888
server.2=192.168.56.107:2888:3888
server.3=192.168.56.108:2888:3888
'@
    Invoke-SshCommand -node $node -command "cat > /opt/zookeeper/conf/zoo.cfg << 'EOF'`n$zooCfg`nEOF"
    Invoke-SshCommand -node $node -command "echo $nodeId > /opt/zookeeper/data/myid"
    
    # 3.6 上传并解压 Kafka
    Write-Info "上传并解压 Kafka..."
    Invoke-ScpFile -localPath $localKafkaPath -node $node -remotePath "/opt/"
    Invoke-SshCommand -node $node -command "tar -xzf /opt/kafka_2.11-2.3.1.tar.gz -C /opt/kafka --strip-components=1"
    
    # 3.7 配置 Kafka
    Write-Info "配置 Kafka..."
    $serverProps = @"
broker.id=$nodeId
listeners=PLAINTEXT://$node:9092
advertised.listeners=PLAINTEXT://$node:9092
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
"@
    Invoke-SshCommand -node $node -command "cat > /opt/kafka/config/server.properties << EOF`n$serverProps`nEOF"
    
    Write-Success "node$nodeId ($node) 部署完成"
}

# 4. 启动 ZooKeeper 集群
Write-Info "========== 启动 ZooKeeper 集群 =========="
foreach ($node in $nodes) {
    Write-Info "启动 ZooKeeper on $node..."
    Invoke-SshCommand -node $node -command "source /etc/profile && /opt/zookeeper/bin/zkServer.sh start"
    Start-Sleep -Seconds 2
}
Write-Success "ZooKeeper 集群启动完成"

# 5. 验证 ZooKeeper 状态
Write-Info "========== 验证 ZooKeeper 状态 =========="
foreach ($node in $nodes) {
    Invoke-SshCommand -node $node -command "/opt/zookeeper/bin/zkServer.sh status"
}

# 6. 启动 Kafka 集群
Write-Info "========== 启动 Kafka 集群 =========="
foreach ($node in $nodes) {
    Write-Info "启动 Kafka on $node..."
    Invoke-SshCommand -node $node -command "source /etc/profile && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties"
    Start-Sleep -Seconds 3
}
Write-Success "Kafka 集群启动完成"

# 7. 验证 Kafka 集群
Write-Info "========== 验证 Kafka 集群 =========="
Start-Sleep -Seconds 5
Invoke-SshCommand -node $nodes[0] -command "source /etc/profile && /opt/kafka/bin/kafka-topics.sh --create --topic test-topic --bootstrap-server 192.168.56.106:9092,192.168.56.107:9092,192.168.56.108:9092 --partitions 3 --replication-factor 3"
Invoke-SshCommand -node $nodes[0] -command "source /etc/profile && /opt/kafka/bin/kafka-topics.sh --describe --topic test-topic --bootstrap-server 192.168.56.106:9092"

Write-Host "`n==============================================" -ForegroundColor Yellow
Write-Host "          Kafka 集群部署完成！" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "`n集群信息："
Write-Host "  ZooKeeper: $($nodes -join ', ') :2181"
Write-Host "  Kafka: $($nodes -join ', ') :9092"
Write-Host "`n测试命令："
Write-Host "  创建Topic: /opt/kafka/bin/kafka-topics.sh --create --topic test --bootstrap-server 192.168.56.106:9092 --partitions 3 --replication-factor 3"
Write-Host "  发送消息: /opt/kafka/bin/kafka-console-producer.sh --topic test --bootstrap-server 192.168.56.106:9092"
Write-Host "  消费消息: /opt/kafka/bin/kafka-console-consumer.sh --topic test --bootstrap-server 192.168.56.106:9092 --from-beginning"