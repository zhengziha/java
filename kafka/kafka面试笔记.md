# kafka面试笔记

## 概念：kafka是一个分布式的消息队列系统，它由Apache Foundation维护。

## 用作：系统间解耦、异步通信、削峰填谷等作用

### kafka的架构如下：
消费者路由到不同的分区，每个分区都有一个消费者组。
每个消费者组都有一个消费者，消费者从分区中读取消息。
消费者从分区中读取消息时，会将消息写入到一个日志中。

Broker 是服务器，分区是数据分片，分区会均匀的分布在不同的Broker上。

#### 消息类型。
广播消息：所有消费者组的消费者都会收到消息。
点对点消息：只有指定的消费者会收到消息。
#### 消息持久化。
使用硬盘存储消息记录，分区中消息是有序的，分区之间的消息是无序的。
主分区负责读写消息，从分区只负责同步消息，0.11版本之前使用水位线机制（每个分区中最后一条消息的下一个位置）保证数据的同步，有问题。
0.11版本之后，使用Leader epoch保证数据同步，一条记录格式：(epoch, startOffset)，epoch一个递增的id存在zookeeper，每次重新选举 Leader 就 +1，每个消息都存在4字节Leader Epoch号，startOffset是本地 LEO ，epoch号与消息offset关联存储在日志目录下Sequence文件中。
消费者消费消息后，会提交偏移量。

auto.offset.reset：earliest（从头）/ latest（最新）/ none（无 offset 报错）

消费端使用KafkaConsumer类。
生产端使用KafkaProducer类。
构造生产者/消费者时，需要指定配置信息如：连接的 broker 地址，序列化器、反序列化器等。

#### 生产端参数
ACKS_CONFIG="acks"：acknowledgment level，确认级别。
- 0：不等待确认，直接返回。
- 1：等待 leader 确认，返回。
- 2：等待所有 follower 确认，返回。
- -1：等待所有 follower 确认，返回。
RETRIES_CONFIG(retries)：重试次数。
- 0：不重试。
 TRANSACTIONAL_ID_CONFIG = "transactional.id"：生产者事务。
 - 事务id，用于唯一标识一个事务。

 ENABLE_IDEMPOTENCE_CONFIG = "enable.idempotence"：是否开启幂等性。
- true：开启。
- false：不开启。
注意:在使用幂等性的时候，要求必须开启retries=true和acks=all。
**一旦开启了事务，默认生产者就已经开启了幂等性**

生产端可以开启事务，事务可以确保消息的顺序性和一致性。

#### 消费者端参数
ENABLE_AUTO_COMMIT_CONFIG="enable.auto.commit"：是否自动提交偏移量。
- true：自动提交偏移量。
- false：手动提交偏移量。
AUTO_COMMIT_INTERVAL_MS_CONFIG = "auto.commit.interval.ms"：自动提交偏移量的时间间隔。
- 默认值：5000（5秒）
- 建议值：根据业务场景和性能需求调整。
消费者可以设置消费组
- 消费者组中只有一个消费者会消费消息。

topic支持设置正则匹配
poll(Duration timeout)方法：从分区中读取消息列表。
不自动提交时，需要手动提交偏移量。
commitAsync(ConsumerRecords<?, ?> records, OffsetAndMetadata[] offsets)方法：异步提交偏移量。
#### 消息拦截器。
实现ProducerInterceptor接口，可以在消息发送前对消息进行处理，添加自定义的头信息。

KafkaAdminClient类用于管理 Kafka 集群，如创建主题、修改主题配置、删除主题等操作。
