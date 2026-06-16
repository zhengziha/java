#!/bin/bash
# Kafka 集群启动脚本（虚拟机端）
# 用于启动 ZooKeeper 和 Kafka 服务

# 配置 Java 环境
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 日志文件
LOG_DIR="/opt/kafka/logs"
ZK_LOG="/opt/zookeeper/logs/zookeeper-startup.log"
KAFKA_LOG="/opt/kafka/logs/kafka-startup.log"

# 启动 ZooKeeper
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting ZooKeeper..." >> $ZK_LOG
/opt/zookeeper/bin/zkServer.sh start >> $ZK_LOG 2>&1

# 等待 ZooKeeper 启动完成
sleep 5

# 启动 Kafka
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Kafka..." >> $KAFKA_LOG
/opt/kafka/bin/kafka-server-start.sh -daemon /opt/kafka/config/server.properties >> $KAFKA_LOG 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All services started" >> $KAFKA_LOG