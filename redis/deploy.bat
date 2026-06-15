@echo off
REM Redis哨兵集群部署脚本 (Windows版本)
REM 使用方法: deploy.bat [node1|node2|node3]

setlocal enabledelayedexpansion

set NODE1_IP=192.168.56.106
set NODE2_IP=192.168.56.107
set NODE3_IP=192.168.56.108
set SSH_USER=root
set SSH_PASSWORD=root

set CURRENT_NODE=%1

if "%CURRENT_NODE%"=="" (
    echo 错误: 请指定要部署的节点 ^(node1^|node2^|node3^)
    echo 使用方法: %0 [node1^|node2^|node3]
    exit /b 1
)

REM 根据节点获取IP
if "%CURRENT_NODE%"=="node1" (
    set NODE_IP=%NODE1_IP%
    set ROLE=master
) else if "%CURRENT_NODE%"=="node2" (
    set NODE_IP=%NODE2_IP%
    set ROLE=slave
) else if "%CURRENT_NODE%"=="node3" (
    set NODE_IP=%NODE3_IP%
    set ROLE=slave
) else (
    echo 错误: 无效的节点名称 %CURRENT_NODE%
    echo 支持的节点: node1, node2, node3
    exit /b 1
)

echo ========================================
echo 开始部署Redis哨兵集群 - %CURRENT_NODE%
echo ========================================
echo 节点IP: %NODE_IP%
echo 角色: %ROLE%
echo.

REM 检查是否安装了plink (PuTTY命令行工具)
where plink >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未找到plink工具
    echo 请先安装PuTTY或使用WSL运行deploy.sh脚本
    echo 下载地址: https://www.putty.org/
    exit /b 1
)

REM 检查是否安装了pscp (PuTTY SCP工具)
where pscp >nul 2>&1
if %errorlevel% neq 0 (
    echo 错误: 未找到pscp工具
    echo 请先安装PuTTY或使用WSL运行deploy.sh脚本
    exit /b 1
)

echo 步骤1: 检查并安装Redis...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "which redis-server || (yum install -y epel-release && yum install -y redis)"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "which redis-cli || yum install -y redis"
echo Redis已安装
echo.

echo 步骤2: 创建必要的目录...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "mkdir -p /var/log/redis"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "mkdir -p /var/lib/redis"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "chown -R redis:redis /var/log/redis /var/lib/redis"
echo 目录创建完成
echo.

echo 步骤3: 上传配置文件...
if "%ROLE%"=="master" (
    pscp -pw %SSH_PASSWORD% redis-master.conf %SSH_USER%@%NODE_IP%:/etc/redis/redis.conf
    echo 主节点配置文件已上传
) else (
    REM 创建临时从节点配置文件
    echo replicaof %NODE1_IP% 6379 > redis-slave-temp.conf
    type redis-slave.conf >> redis-slave-temp.conf
    pscp -pw %SSH_PASSWORD% redis-slave-temp.conf %SSH_USER%@%NODE_IP%:/etc/redis/redis.conf
    del redis-slave-temp.conf
    echo 从节点配置文件已上传
)

pscp -pw %SSH_PASSWORD% sentinel.conf %SSH_USER%@%NODE_IP%:/etc/redis/sentinel.conf
echo Sentinel配置文件已上传
echo.

echo 步骤4: 配置防火墙...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "firewall-cmd --permanent --add-port=6379/tcp || true"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "firewall-cmd --permanent --add-port=26379/tcp || true"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "firewall-cmd --reload || true"
echo 防火墙配置完成
echo.

echo 步骤5: 启动Redis服务...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "systemctl restart redis"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "systemctl enable redis"
echo Redis服务已启动
echo.

echo 步骤6: 启动Sentinel服务...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "redis-server /etc/redis/sentinel.conf --sentinel"
echo Sentinel服务已启动
echo.

echo 步骤7: 验证服务状态...
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "systemctl status redis | head -n 5"
plink -ssh -pw %SSH_PASSWORD% %SSH_USER%@%NODE_IP% "redis-cli -a redis123456 ping"
echo.

echo ========================================
echo 部署完成！%CURRENT_NODE% 部署成功
echo ========================================

endlocal