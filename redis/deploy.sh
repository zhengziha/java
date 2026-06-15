#!/bin/bash

# Redis哨兵集群部署脚本
# 使用方法: ./deploy.sh [node1|node2|node3]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 服务器信息
NODE1_IP="192.168.56.106"
NODE2_IP="192.168.56.107"
NODE3_IP="192.168.56.108"
SSH_USER="root"
SSH_PASSWORD="root"

# 当前节点
CURRENT_NODE=$1

if [ -z "$CURRENT_NODE" ]; then
    echo -e "${RED}错误: 请指定要部署的节点 (node1|node2|node3)${NC}"
    echo "使用方法: $0 [node1|node2|node3]"
    exit 1
fi

# 根据节点获取IP
case $CURRENT_NODE in
    node1)
        NODE_IP=$NODE1_IP
        ROLE="master"
        ;;
    node2)
        NODE_IP=$NODE2_IP
        ROLE="slave"
        ;;
    node3)
        NODE_IP=$NODE3_IP
        ROLE="slave"
        ;;
    *)
        echo -e "${RED}错误: 无效的节点名称 $CURRENT_NODE${NC}"
        echo "支持的节点: node1, node2, node3"
        exit 1
        ;;
esac

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始部署Redis哨兵集群 - $CURRENT_NODE${NC}"
echo -e "${GREEN}========================================${NC}"
echo "节点IP: $NODE_IP"
echo "角色: $ROLE"
echo ""

# SSH连接函数
ssh_exec() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "$SSH_USER@$NODE_IP" "$1"
}

# SCP传输函数
scp_file() {
    sshpass -p "$SSH_PASSWORD" scp -o StrictHostKeyChecking=no "$1" "$SSH_USER@$NODE_IP:$2"
}

echo -e "${YELLOW}步骤1: 检查并安装Redis...${NC}"
ssh_exec "which redis-server || (yum install -y epel-release && yum install -y redis)"
ssh_exec "which redis-cli || yum install -y redis"
echo -e "${GREEN}✓ Redis已安装${NC}"
echo ""

echo -e "${YELLOW}步骤2: 创建必要的目录...${NC}"
ssh_exec "mkdir -p /var/log/redis"
ssh_exec "mkdir -p /var/lib/redis"
ssh_exec "chown -R redis:redis /var/log/redis /var/lib/redis"
echo -e "${GREEN}✓ 目录创建完成${NC}"
echo ""

echo -e "${YELLOW}步骤3: 上传配置文件...${NC}"
if [ "$ROLE" == "master" ]; then
    scp_file "redis-master.conf" "/etc/redis/redis.conf"
    echo -e "${GREEN}✓ 主节点配置文件已上传${NC}"
else
    # 上传从节点配置并设置主节点IP
    sed "s/replicaof <masterip> <masterport>/replicaof $NODE1_IP 6379/" redis-slave.conf > /tmp/redis-slave-temp.conf
    sshpass -p "$SSH_PASSWORD" scp -o StrictHostKeyChecking=no /tmp/redis-slave-temp.conf "$SSH_USER@$NODE_IP:/etc/redis/redis.conf"
    rm /tmp/redis-slave-temp.conf
    echo -e "${GREEN}✓ 从节点配置文件已上传${NC}"
fi

# 上传Sentinel配置
scp_file "sentinel.conf" "/etc/redis/sentinel.conf"
echo -e "${GREEN}✓ Sentinel配置文件已上传${NC}"
echo ""

echo -e "${YELLOW}步骤4: 配置防火墙...${NC}"
ssh_exec "firewall-cmd --permanent --add-port=6379/tcp || true"
ssh_exec "firewall-cmd --permanent --add-port=26379/tcp || true"
ssh_exec "firewall-cmd --reload || true"
echo -e "${GREEN}✓ 防火墙配置完成${NC}"
echo ""

echo -e "${YELLOW}步骤5: 启动Redis服务...${NC}"
ssh_exec "systemctl restart redis"
ssh_exec "systemctl enable redis"
echo -e "${GREEN}✓ Redis服务已启动${NC}"
echo ""

echo -e "${YELLOW}步骤6: 启动Sentinel服务...${NC}"
ssh_exec "redis-server /etc/redis/sentinel.conf --sentinel"
echo -e "${GREEN}✓ Sentinel服务已启动${NC}"
echo ""

echo -e "${YELLOW}步骤7: 验证服务状态...${NC}"
ssh_exec "systemctl status redis | head -n 5"
ssh_exec "redis-cli -a redis123456 ping"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成！$CURRENT_NODE 部署成功${NC}"
echo -e "${GREEN}========================================${NC}"