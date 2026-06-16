<#
.SYNOPSIS
停止 Kafka 集群
#>

$nodes = @("192.168.56.106", "192.168.56.107", "192.168.56.108")
$user = "root"

Write-Host "`n========== 停止 Kafka 集群 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "停止 $node 的 Kafka..." -ForegroundColor Yellow
    ssh $user@$node "/opt/kafka/bin/kafka-server-stop.sh"
    Start-Sleep -Seconds 2
}

Write-Host "`n========== 停止 ZooKeeper 集群 ==========" -ForegroundColor Cyan
foreach ($node in $nodes) {
    Write-Host "停止 $node 的 ZooKeeper..." -ForegroundColor Yellow
    ssh $user@$node "/opt/zookeeper/bin/zkServer.sh stop"
    Start-Sleep -Seconds 1
}

Write-Host "`n集群已停止！" -ForegroundColor Green