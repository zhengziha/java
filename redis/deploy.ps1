# Redis哨兵集群部署脚本
# 使用方式: .\deploy.ps1 -Node node1 -Step install

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("node1", "node2", "node3")]
    [string]$Node,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("test", "install", "config", "start", "validate")]
    [string]$Step
)

# 服务器信息
$NODE1_IP = "192.168.56.106"
$NODE2_IP = "192.168.56.107"
$NODE3_IP = "192.168.56.108"
$SSH_USER = "root"
$REDIS_PASSWORD = "redis123456"

# 根据节点获取IP
switch ($Node) {
    "node1" {
        $NODE_IP = $NODE1_IP
        $ROLE = "master"
    }
    "node2" {
        $NODE_IP = $NODE2_IP
        $ROLE = "slave"
    }
    "node3" {
        $NODE_IP = $NODE3_IP
        $ROLE = "slave"
    }
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Redis哨兵集群部署 - $Node ($ROLE)" -ForegroundColor Green
Write-Host "节点IP: $NODE_IP" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# SSH执行函数
function Invoke-SSHCommand {
    param([string]$Command)
    Write-Host "执行: $Command" -ForegroundColor Cyan
    $result = ssh -o StrictHostKeyChecking=no "${SSH_USER}@${NODE_IP}" $Command 2>&1
    Write-Host $result
    Write-Host ""
    return $result
}

# SCP传输函数
function Copy-FileToRemote {
    param([string]$LocalPath, [string]$RemotePath)
    Write-Host "上传: $LocalPath -> $RemotePath" -ForegroundColor Cyan
    scp -o StrictHostKeyChecking=no $LocalPath "${SSH_USER}@${NODE_IP}:${RemotePath}" 2>&1 | Out-Null
    return $?
}

# 执行步骤
switch ($Step) {
    "test" {
        Write-Host "测试SSH连接..." -ForegroundColor Yellow
        $result = Invoke-SSHCommand "echo 'SSH连接成功' && hostname && ip addr | grep inet"
        if ($result -match "SSH连接成功") {
            Write-Host "✓ SSH连接测试通过" -ForegroundColor Green
        } else {
            Write-Host "✗ SSH连接失败" -ForegroundColor Red
            exit 1
        }
    }
    
    "install" {
        Write-Host "步骤1: 创建用户和目录..." -ForegroundColor Yellow
        Invoke-SSHCommand "useradd redis || true"
        Invoke-SSHCommand "mkdir -p /var/log/redis /var/lib/redis /etc/redis /var/run"
        Invoke-SSHCommand "chown -R redis:redis /var/log/redis /var/lib/redis"
        
        Write-Host "步骤2: 安装编译工具..." -ForegroundColor Yellow
        Invoke-SSHCommand "yum install -y gcc make"
        
        Write-Host "步骤3: 上传并解压Redis源码..." -ForegroundColor Yellow
        Copy-FileToRemote "redis-7.0.15.tar.gz" "/tmp/redis-7.0.15.tar.gz"
        Invoke-SSHCommand "cd /tmp && tar -xzf redis-7.0.15.tar.gz"
        
        Write-Host "步骤4: 编译安装Redis..." -ForegroundColor Yellow
        Invoke-SSHCommand "cd /tmp/redis-7.0.15 && make distclean && make -j4 MALLOC=libc && make install"
        
        Write-Host "步骤5: 验证安装..." -ForegroundColor Yellow
        $result = Invoke-SSHCommand "redis-server --version"
        if ($result -match "Redis server v=") {
            Write-Host "✓ Redis安装成功" -ForegroundColor Green
        } else {
            Write-Host "✗ Redis安装失败" -ForegroundColor Red
            exit 1
        }
    }
    
    "config" {
        Write-Host "步骤1: 上传Redis配置文件..." -ForegroundColor Yellow
        
        if ($ROLE -eq "master") {
            Copy-FileToRemote "redis-master.conf" "/etc/redis/redis.conf"
        } else {
            $tempSlaveConfig = Get-Content "redis-slave.conf" -Raw
            $tempSlaveConfig = $tempSlaveConfig -replace "# replicaof 192.168.56.106 6379", "replicaof $NODE1_IP 6379"
            $tempSlaveConfig | Out-File -FilePath "redis-slave-temp.conf" -Encoding ASCII
            Copy-FileToRemote "redis-slave-temp.conf" "/etc/redis/redis.conf"
            Remove-Item "redis-slave-temp.conf" -Force
        }
        
        Write-Host "步骤2: 上传哨兵配置文件..." -ForegroundColor Yellow
        Copy-FileToRemote "sentinel.conf" "/etc/redis/sentinel.conf"
        
        Write-Host "步骤3: 创建systemd服务文件..." -ForegroundColor Yellow
        
        $redisService = @"
[Unit]
Description=Redis persistent key-value database
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli -a $REDIS_PASSWORD shutdown
Restart=always
LimitNOFILE=65536
Type=forking
PIDFile=/var/run/redis_6379.pid

[Install]
WantedBy=multi-user.target
"@

        $sentinelService = @"
[Unit]
Description=Redis Sentinel
After=network.target

[Service]
User=redis
Group=redis
ExecStart=/usr/local/bin/redis-server /etc/redis/sentinel.conf --sentinel
ExecStop=/usr/local/bin/redis-cli -p 26379 shutdown
Restart=always
LimitNOFILE=65536
Type=forking

[Install]
WantedBy=multi-user.target
"@

        $redisService | Out-File -FilePath "temp_redis.service" -Encoding ASCII
        $sentinelService | Out-File -FilePath "temp_sentinel.service" -Encoding ASCII
        
        Copy-FileToRemote "temp_redis.service" "/etc/systemd/system/redis.service"
        Copy-FileToRemote "temp_sentinel.service" "/etc/systemd/system/sentinel.service"
        
        Remove-Item "temp_redis.service" -Force
        Remove-Item "temp_sentinel.service" -Force
        
        Invoke-SSHCommand "systemctl daemon-reload"
        
        Write-Host "✓ 配置完成" -ForegroundColor Green
    }
    
    "start" {
        Write-Host "步骤1: 配置防火墙..." -ForegroundColor Yellow
        Invoke-SSHCommand "firewall-cmd --permanent --add-port=6379/tcp 2>/dev/null || true"
        Invoke-SSHCommand "firewall-cmd --permanent --add-port=26379/tcp 2>/dev/null || true"
        Invoke-SSHCommand "firewall-cmd --reload 2>/dev/null || true"
        
        Write-Host "步骤2: 启动Redis服务..." -ForegroundColor Yellow
        Invoke-SSHCommand "systemctl restart redis && systemctl enable redis"
        Start-Sleep -Seconds 2
        
        Write-Host "步骤3: 启动Sentinel服务..." -ForegroundColor Yellow
        Invoke-SSHCommand "systemctl restart sentinel && systemctl enable sentinel"
        Start-Sleep -Seconds 2
        
        Write-Host "✓ 服务启动完成" -ForegroundColor Green
    }
    
    "validate" {
        Write-Host "验证Redis服务..." -ForegroundColor Yellow
        Invoke-SSHCommand "systemctl status redis | head -n 5"
        
        Write-Host ""
        Write-Host "验证Redis连接..." -ForegroundColor Yellow
        $result = Invoke-SSHCommand "redis-cli -a $REDIS_PASSWORD ping"
        if ($result -match "PONG") {
            Write-Host "✓ Redis连接成功" -ForegroundColor Green
        } else {
            Write-Host "✗ Redis连接失败" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "验证哨兵服务..." -ForegroundColor Yellow
        Invoke-SSHCommand "redis-cli -p 26379 INFO sentinel"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "$Step 步骤完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
