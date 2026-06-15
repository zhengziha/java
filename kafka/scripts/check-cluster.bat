@echo off
chcp 65001 >nul
echo ==============================================
echo          Kafka 集群状态检查脚本
echo ==============================================
echo.

:menu
echo 请选择操作：
echo 1. 检查 ZooKeeper 状态
echo 2. 检查 Kafka 状态
echo 3. 查看 Topic 列表
echo 4. 创建测试 Topic
echo 5. 发送测试消息
echo 6. 消费测试消息
echo 0. 退出
echo.
set /p choice=请输入选择：

if "%choice%"=="1" goto check_zookeeper
if "%choice%"=="2" goto check_kafka
if "%choice%"=="3" goto list_topics
if "%choice%"=="4" goto create_topic
if "%choice%"=="5" goto send_message
if "%choice%"=="6" goto consume_message
if "%choice%"=="0" exit /b 0

echo 无效选择，请重新输入！
goto menu

:check_zookeeper
echo.
echo 检查 ZooKeeper 状态...
ssh root@192.168.56.106 "/opt/zookeeper/bin/zkServer.sh status"
ssh root@192.168.56.107 "/opt/zookeeper/bin/zkServer.sh status"
ssh root@192.168.56.108 "/opt/zookeeper/bin/zkServer.sh status"
goto end_menu

:check_kafka
echo.
echo 检查 Kafka 状态...
ssh root@192.168.56.106 "jps | grep Kafka"
ssh root@192.168.56.107 "jps | grep Kafka"
ssh root@192.168.56.108 "jps | grep Kafka"
goto end_menu

:list_topics
echo.
echo Topic 列表：
ssh root@192.168.56.106 "/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server 192.168.56.106:9092"
goto end_menu

:create_topic
echo.
set /p topic_name=请输入 Topic 名称：
set /p partitions=请输入分区数（默认3）：
if "%partitions%"=="" set partitions=3
set /p replication=请输入副本数（默认3）：
if "%replication%"=="" set replication=3
ssh root@192.168.56.106 "/opt/kafka/bin/kafka-topics.sh --create --topic %topic_name% --bootstrap-server 192.168.56.106:9092 --partitions %partitions% --replication-factor %replication%"
echo Topic 创建成功！
goto end_menu

:send_message
echo.
set /p topic_name=请输入要发送消息的 Topic：
if "%topic_name%"=="" set topic_name=test-topic
echo 正在连接到生产者，请输入消息（Ctrl+C 退出）：
ssh root@192.168.56.106 "/opt/kafka/bin/kafka-console-producer.sh --topic %topic_name% --bootstrap-server 192.168.56.106:9092"
goto end_menu

:consume_message
echo.
set /p topic_name=请输入要消费的 Topic：
if "%topic_name%"=="" set topic_name=test-topic
echo 正在消费消息（Ctrl+C 退出）：
ssh root@192.168.56.106 "/opt/kafka/bin/kafka-console-consumer.sh --topic %topic_name% --bootstrap-server 192.168.56.106:9092 --from-beginning"
goto end_menu

:end_menu
echo.
pause
goto menu