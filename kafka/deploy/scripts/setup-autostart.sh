#!/bin/bash
# Kafka 集群开机启动配置脚本
# 在每个虚拟机节点上执行此脚本

echo "=========================================="
echo "  Kafka 集群开机启动配置脚本"
echo "=========================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 用户执行此脚本"
    exit 1
fi

# 1. 复制启动脚本到系统目录
echo "[1/5] 复制启动脚本..."
cp /opt/kafka/scripts/start-all-services.sh /usr/local/bin/start-kafka-cluster
cp /opt/kafka/scripts/stop-all-services.sh /usr/local/bin/stop-kafka-cluster
chmod +x /usr/local/bin/start-kafka-cluster
chmod +x /usr/local/bin/stop-kafka-cluster

# 2. 复制 systemd 服务文件
echo "[2/5] 复制 systemd 服务文件..."
cp /opt/kafka/scripts/zookeeper.service /etc/systemd/system/
cp /opt/kafka/scripts/kafka.service /etc/systemd/system/

# 3. 重新加载 systemd 配置
echo "[3/5] 重新加载 systemd 配置..."
systemctl daemon-reload

# 4. 启用开机自启动
echo "[4/5] 启用开机自启动..."
systemctl enable zookeeper.service
systemctl enable kafka.service

# 5. 启动服务
echo "[5/5] 启动服务..."
systemctl start zookeeper.service
sleep 5
systemctl start kafka.service

# 验证服务状态
echo ""
echo "=========================================="
echo "  服务状态检查"
echo "=========================================="
echo ""
echo "ZooKeeper 状态："
systemctl status zookeeper.service --no-pager -l | head -10
echo ""
echo "Kafka 状态："
systemctl status kafka.service --no-pager -l | head -10
echo ""
echo "=========================================="
echo "  配置完成！"
echo "=========================================="
echo ""
echo "常用命令："
echo "  启动服务: systemctl start zookeeper kafka"
echo "  停止服务: systemctl stop kafka zookeeper"
echo "  重启服务: systemctl restart kafka zookeeper"
echo "  查看状态: systemctl status zookeeper kafka"
echo "  禁用开机启动: systemctl disable zookeeper kafka"
echo "  启用开机启动: systemctl enable zookeeper kafka"
echo ""
echo "快速启动/停止："
echo "  start-kafka-cluster   # 启动所有服务"
echo "  stop-kafka-cluster    # 停止所有服务"