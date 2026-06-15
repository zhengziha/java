#!/bin/bash

# Redis哨兵集群测试脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务器信息
NODE1_IP="192.168.56.106"
NODE2_IP="192.168.56.107"
NODE3_IP="192.168.56.108"
SSH_USER="root"
SSH_PASSWORD="root"
REDIS_PASSWORD="redis123456"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Redis哨兵集群测试${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# SSH连接函数
ssh_exec() {
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "$SSH_USER@$1" "$2"
}

# 测试1: 检查Redis服务状态
echo -e "${YELLOW}测试1: 检查Redis服务状态${NC}"
for node in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
    echo -n "检查 $node: "
    result=$(ssh_exec "$node" "redis-cli -a $REDIS_PASSWORD ping 2>/dev/null")
    if [ "$result" == "PONG" ]; then
        echo -e "${GREEN}✓ 正常${NC}"
    else
        echo -e "${RED}✗ 异常${NC}"
    fi
done
echo ""

# 测试2: 检查主从复制状态
echo -e "${YELLOW}测试2: 检查主从复制状态${NC}"
echo "主节点信息:"
ssh_exec "$NODE1_IP" "redis-cli -a $REDIS_PASSWORD info replication | grep -E 'role|connected_slaves|master_link_status'"
echo ""

echo "从节点1 ($NODE2_IP) 信息:"
ssh_exec "$NODE2_IP" "redis-cli -a $REDIS_PASSWORD info replication | grep -E 'role|master_host|master_link_status'"
echo ""

echo "从节点2 ($NODE3_IP) 信息:"
ssh_exec "$NODE3_IP" "redis-cli -a $REDIS_PASSWORD info replication | grep -E 'role|master_host|master_link_status'"
echo ""

# 测试3: 检查Sentinel状态
echo -e "${YELLOW}测试3: 检查Sentinel状态${NC}"
for node in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
    echo "Sentinel $node 状态:"
    ssh_exec "$node" "redis-cli -p 26379 sentinel masters" | grep -A 10 mymaster
    echo ""
done

# 测试4: 测试数据同步
echo -e "${YELLOW}测试4: 测试数据同步${NC}"
echo "在主节点写入测试数据..."
ssh_exec "$NODE1_IP" "redis-cli -a $REDIS_PASSWORD SET test_key 'hello_from_master'"
echo "写入完成"
echo ""

echo "等待2秒..."
sleep 2

echo "验证从节点数据同步:"
echo "从节点1 ($NODE2_IP):"
result1=$(ssh_exec "$NODE2_IP" "redis-cli -a $REDIS_PASSWORD GET test_key")
echo "  test_key = $result1"

echo "从节点2 ($NODE3_IP):"
result2=$(ssh_exec "$NODE3_IP" "redis-cli -a $REDIS_PASSWORD GET test_key")
echo "  test_key = $result2"
echo ""

if [ "$result1" == "hello_from_master" ] && [ "$result2" == "hello_from_master" ]; then
    echo -e "${GREEN}✓ 数据同步正常${NC}"
else
    echo -e "${RED}✗ 数据同步异常${NC}"
fi
echo ""

# 测试5: 检查集群信息
echo -e "${YELLOW}测试5: 检查集群信息${NC}"
echo "主节点集群信息:"
ssh_exec "$NODE1_IP" "redis-cli -a $REDIS_PASSWORD info server | grep -E 'redis_version|os|process_id'"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}测试完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "集群信息:"
echo "  主节点: $NODE1_IP:6379"
echo "  从节点1: $NODE2_IP:6379"
echo "  从节点2: $NODE3_IP:6379"
echo "  Sentinel: 每个节点 26379"
echo ""
echo "连接信息:"
echo "  密码: $REDIS_PASSWORD"
echo "  Sentinel监控名称: mymaster"