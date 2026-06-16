<#
.SYNOPSIS
启动 Kafka 集群

.DESCRIPTION
依次启动所有节点的 ZooKeeper 和 Kafka
#>

$nodes = @("192.168.56.106", "192.168.56.107", "192.168.56.108")
$user = "root"

Write-Host "`n========== 启动 ZooKeeper 集群 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "启动 $node 的 ZooKeeper..." -ForegroundColor Yellow
    ssh $user@$node "source /etc/profile && /opt/zookeeper/bin/zkServer.sh start"
    Start-Sleep -Seconds 2
}

Write-Host "`n========== 验证 ZooKeeper 状态 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "`n$node:"
    ssh $user@$node "/opt/zookeeper/bin/zkServer.sh status"
}

Write-Host "`n========== 启动 Kafka 集群 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "启动 $node 的 Kafka..." -ForegroundColor Yellow
    ssh $user@$node "source /etc/profile && /opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties"
    Start-Sleep -Seconds 3
}

Write-Host "`n========== 验证 Kafka 状态 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "`n$node:"
    ssh $user@$node "jps | grep Kafka"
}

Write-Host "`n集群启动完成！" -ForegroundColor Green