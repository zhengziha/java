#!/bin/bash
# Kafka 集群停止脚本（虚拟机端）
# 用于停止 ZooKeeper 和 Kafka 服务

# 配置 Java 环境
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 日志文件
LOG_DIR="/opt/kafka/logs"
ZK_LOG="/opt/zookeeper/logs/zookeeper-stop.log"
KAFKA_LOG="/opt/kafka/logs/kafka-stop.log"

# 停止 Kafka
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping Kafka..." >> $KAFKA_LOG
/opt/kafka/bin/kafka-server-stop.sh >> $KAFKA_LOG 2>&1

# 等待 Kafka 停止完成
sleep 5

# 停止 ZooKeeper
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping ZooKeeper..." >> $ZK_LOG
/opt/zookeeper/bin/zkServer.sh stop >> $ZK_LOG 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All services stopped" >> $ZK_LOG