# 三大 MQ（RocketMQ / Kafka / RabbitMQ）完整使用教程

> 独立专题笔记，汇总入口见 [java学习笔记汇总](./java学习笔记汇总.md)  
> 消费失败 / 积压 / 死信 → [MQ消费失败与消息积压处理](./MQ消费失败与消息积压处理.md)

---

## 一、选型速览

| 维度 | RocketMQ | Kafka | RabbitMQ |
|------|----------|-------|----------|
| 定位 | 业务消息、事务消息、延迟消息 | 高吞吐日志流、大数据管道 | 灵活路由、企业集成 |
| 吞吐 | 高 | 极高 | 中 |
| 延迟消息 | ✅ 18 档内置 | ❌ 需自建 | ✅ TTL / 延迟插件 |
| 事务消息 | ✅ 半事务消息 | ✅ 事务 Producer | ❌ 需 Outbox |
| 内置死信 | ✅ 16 次后进 DLQ | ❌ 自建 DLQ Topic | ✅ DLX |
| 消费模式 | Push（长轮询） | Pull | Push |
| 注册中心 | NameServer | ZooKeeper / KRaft | 无（内置） |
| Java 生态 | rocketmq-spring | spring-kafka | spring-amqp |

**选型建议**：
- 电商/金融订单、事务消息、延迟关单 → **RocketMQ**
- 日志采集、埋点、CDC、流式计算 → **Kafka**
- 复杂路由、多 Exchange、轻量任务队列 → **RabbitMQ**

---

## 二、通用使用流程（任何 MQ 都适用）

```
1. 创建 Topic / Exchange + Queue
2. 配置 Producer（确认机制、重试、序列化）
3. 配置 Consumer（消费组、ACK 模式、并发度）
4. 业务代码：幂等 + 区分可重试/不可重试异常
5. 监控：发送成功率、消费 TPS、Lag、失败率
6. 兜底：死信队列 + 告警 + 人工回放
```

### 四大经典问题（落地必答）

| 问题 | 本质 | 通用对策 |
|------|------|----------|
| **消息丢失** | 生产/存储/消费任一环节未确认 | 同步发送 + 持久化 + 手动 ACK |
| **重复消费** | 重试、Rebalance、网络抖动 | **消费端幂等**（唯一键/状态机） |
| **顺序消费** | 多线程/多分区并行 | 同 key 路由同一 Queue/Partition + 单线程消费 |
| **消息积压** | 生产 TPS > 消费 TPS | 扩容消费者、批量消费、隔离毒消息 |

---

## 三、RocketMQ

### 1. Maven 依赖

```xml
<dependency>
    <groupId>org.apache.rocketmq</groupId>
    <artifactId>rocketmq-spring-boot-starter</artifactId>
    <version>2.3.1</version>
</dependency>
```

### 2. 配置（application.yml）

```yaml
rocketmq:
  name-server: 127.0.0.1:9876
  producer:
    group: order-producer-group          # 生产者组，事务消息必填
    send-message-timeout: 3000           # 发送超时 ms
    retry-times-when-send-failed: 2      # 同步发送失败重试
    retry-times-when-send-async-failed: 2
  consumer:
    pull-batch-size: 32
```

### 3. 普通消息 — 生产者

```java
@Service
@RequiredArgsConstructor
public class OrderRocketProducer {

    private final RocketMQTemplate rocketMQTemplate;

    /**
     * 同步发送 — 重要业务（下单通知、支付回调）
     * destination 格式：topic:tag
     */
    public void sendSync(OrderCreatedEvent event) {
        SendResult result = rocketMQTemplate.syncSend(
                "order-topic:created",
                MessageBuilder.withPayload(event)
                        .setHeader(RocketMQHeaders.KEYS, event.getOrderId())  // 业务 key，便于排查
                        .build()
        );
        if (result.getSendStatus() != SendStatus.SEND_OK) {
            throw new BizException("RocketMQ 发送失败: " + result.getSendStatus());
        }
    }

    /** 异步发送 — 非核心通知，回调里处理失败 */
    public void sendAsync(OrderCreatedEvent event) {
        rocketMQTemplate.asyncSend("order-topic:created", event, new SendCallback() {
            @Override
            public void onSuccess(SendResult sendResult) {
                log.info("send ok, msgId={}", sendResult.getMsgId());
            }

            @Override
            public void onException(Throwable e) {
                log.error("send fail, orderId={}", event.getOrderId(), e);
                // 落库补偿 / 告警
            }
        });
    }

    /** 单向发送 — 日志、埋点等允许丢失的场景 */
    public void sendOneWay(OrderCreatedEvent event) {
        rocketMQTemplate.sendOneWay("order-topic:created", event);
    }
}
```

### 4. 普通消息 — 消费者（Spring 注解方式）

```java
@Slf4j
@Service
@RocketMQMessageListener(
        topic = "order-topic",
        selectorExpression = "created",           // Tag 过滤，* 表示全部
        consumerGroup = "order-consumer-group",
        consumeMode = ConsumeMode.CONCURRENTLY,   // CONCURRENTLY 并发 / ORDERLY 顺序
        messageModel = MessageModel.CLUSTERING    // CLUSTERING 集群 / BROADCASTING 广播
)
public class OrderCreatedConsumer implements RocketMQListener<OrderCreatedEvent> {

    private final OrderService orderService;
    private final IdempotentService idempotentService;

    public OrderCreatedConsumer(OrderService orderService, IdempotentService idempotentService) {
        this.orderService = orderService;
        this.idempotentService = idempotentService;
    }

    @Override
    public void onMessage(OrderCreatedEvent event) {
        String bizKey = event.getOrderId() + ":created";

        // 1. 幂等：已处理直接返回（框架视为 CONSUME_SUCCESS）
        if (idempotentService.isProcessed(bizKey)) {
            return;
        }

        try {
            orderService.processCreated(event);
            idempotentService.markProcessed(bizKey);
        } catch (RetryableException e) {
            // 2. 临时失败：抛出让框架返回 RECONSUME_LATER，Broker 自动延迟重试
            throw e;
        } catch (BizException e) {
            // 3. 永久失败：吞掉异常并自行进 DLQ，避免无限重试
            log.error("不可重试, bizKey={}", bizKey, e);
            // dlqService.send(event);
            // 不抛异常 → CONSUME_SUCCESS
        }
    }
}
```

### 5. 消费者 — 原生 Push 方式（精细控制重试）

```java
@Component
public class OrderPushConsumer implements InitializingBean {

    @Value("${rocketmq.name-server}")
    private String nameServer;

    @Override
    public void afterPropertiesSet() throws Exception {
        DefaultMQPushConsumer consumer = new DefaultMQPushConsumer("order-consumer-group");
        consumer.setNamesrvAddr(nameServer);
        consumer.subscribe("order-topic", "created");
        consumer.setConsumeFromWhere(ConsumeFromWhere.CONSUME_FROM_LAST_OFFSET);
        consumer.setMaxReconsumeTimes(16);  // 最大重试次数，超限进 %DLQ%消费组

        consumer.registerMessageListener((MessageListenerConcurrently) (msgs, ctx) -> {
            for (MessageExt msg : msgs) {
                try {
                    OrderCreatedEvent event = JSON.parseObject(msg.getBody(), OrderCreatedEvent.class);
                    // 业务处理...
                } catch (RetryableException e) {
                    return ConsumeConcurrentlyStatus.RECONSUME_LATER;  // 延迟重试
                } catch (Exception e) {
                    // 永久失败也返回 SUCCESS，自行投递 DLQ
                    return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
                }
            }
            return ConsumeConcurrentlyStatus.CONSUME_SUCCESS;
        });
        consumer.start();
    }
}
```

### 6. 延迟消息

```java
/** delayLevel：1=1s, 2=5s, 3=10s, 4=30s ... 18=2h（固定 18 档） */
public void sendDelayCloseOrder(OrderCreatedEvent event, int delayLevel) {
    Message<OrderCreatedEvent> message = MessageBuilder.withPayload(event).build();
    rocketMQTemplate.syncSend("order-topic:close", message, 3000, delayLevel);
}
```

### 7. 顺序消息（同一 orderId 进同一 Queue）

```java
// 生产：hashKey 相同 → 同一 Queue
public void sendOrdered(OrderCreatedEvent event) {
    rocketMQTemplate.syncSendOrderly(
            "order-topic:status",
            event,
            event.getOrderId()   // hashKey
    );
}

// 消费：consumeMode = ORDERLY，同一 Queue 单线程顺序处理
@RocketMQMessageListener(
        topic = "order-topic",
        selectorExpression = "status",
        consumerGroup = "order-status-group",
        consumeMode = ConsumeMode.ORDERLY
)
public class OrderStatusConsumer implements RocketMQListener<OrderCreatedEvent> {
    @Override
    public void onMessage(OrderCreatedEvent event) {
        // 同一 Queue 内严格有序
    }
}
```

### 8. RocketMQ 注意事项

| 要点 | 说明 |
|------|------|
| **Producer Group** | 事务消息必须配置；普通消息也建议配置便于排查 |
| **Tag 过滤** | 减少无效投递；`*` 订阅全部 Tag |
| **Keys** | 设置业务 key（orderId），Console 可按 key 查消息 |
| **重试** | `RECONSUME_LATER` → Broker 16 档延迟重试 → `%DLQ%消费组名` |
| **不阻塞同 Queue** | 重试消息回 Broker，不阻塞同 Queue 其他消息（优于 Kafka 毒消息场景） |
| **广播消费** | `MessageModel.BROADCASTING`，每个实例都收到，**无重试/DLQ** |
| **零丢失组合** | 同步发送 + 同步刷盘 + 同步复制 + 消费成功再 ACK |
| **顺序消息** | 生产有序 + 同一 key + ORDERLY 消费；失败重试可能局部乱序 |

---

## 四、Kafka

### 1. Maven 依赖

```xml
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
</dependency>
```

### 2. 配置（application.yml）

```yaml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      acks: all                          # 0/1/all，生产可靠用 all
      retries: 3
      enable-idempotence: true           # 幂等 Producer（需 acks=all）
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
    consumer:
      group-id: order-consumer-group
      enable-auto-commit: false          # 手动提交 offset
      auto-offset-reset: earliest        # 无 offset：earliest / latest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "com.example.order.dto"
    listener:
      ack-mode: manual_immediate         # 配合 Acknowledgment 手动 ack
```

### 3. Kafka 配置类（手动 ACK）

```java
@Configuration
@EnableKafka
public class KafkaConsumerConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, OrderCreatedEvent> kafkaListenerContainerFactory(
            ConsumerFactory<String, OrderCreatedEvent> consumerFactory) {
        ConcurrentKafkaListenerContainerFactory<String, OrderCreatedEvent> factory =
                new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory);
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);
        factory.setConcurrency(3);  // ≤ Partition 数
        return factory;
    }
}
```

### 4. 普通消息 — 生产者

```java
@Service
@RequiredArgsConstructor
public class OrderKafkaProducer {

    private final KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate;

    public void send(OrderCreatedEvent event) {
        // key = orderId → 同一 Partition，保证局部有序
        CompletableFuture<SendResult<String, OrderCreatedEvent>> future =
                kafkaTemplate.send("order-topic", event.getOrderId(), event);

        future.whenComplete((result, ex) -> {
            if (ex != null) {
                log.error("Kafka send fail, orderId={}", event.getOrderId(), ex);
                throw new BizException("Kafka 发送失败", ex);
            }
            log.info("send ok, partition={}, offset={}",
                    result.getRecordMetadata().partition(),
                    result.getRecordMetadata().offset());
        });
    }

    /** 同步等待发送结果（关键业务） */
    public void sendSync(OrderCreatedEvent event) {
        try {
            kafkaTemplate.send("order-topic", event.getOrderId(), event).get(3, TimeUnit.SECONDS);
        } catch (Exception e) {
            throw new BizException("Kafka 同步发送失败", e);
        }
    }
}
```

### 5. 普通消息 — 消费者

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class OrderKafkaConsumer {

    private final OrderService orderService;
    private final IdempotentService idempotentService;
    private final DlqService dlqService;

    @KafkaListener(topics = "order-topic", groupId = "order-consumer-group")
    public void onMessage(
            @Payload OrderCreatedEvent event,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment ack) {

        String bizKey = event.getOrderId() + ":created";
        log.info("consume partition={}, offset={}, key={}", partition, offset, key);

        if (idempotentService.isProcessed(bizKey)) {
            ack.acknowledge();
            return;
        }

        try {
            orderService.processCreated(event);
            idempotentService.markProcessed(bizKey);
            ack.acknowledge();                    // 成功才提交 offset

        } catch (RetryableException e) {
            // 不 ack → 下次 poll 重新消费（注意：会卡住整个 Partition！）
            log.warn("retryable fail, partition={}, offset={}", partition, offset, e);
            throw e;  // 或投递 retry topic 后 ack

        } catch (BizException e) {
            log.error("poison message, send DLQ, bizKey={}", bizKey, e);
            dlqService.sendToDlq("order-dlq-topic", event, e.getMessage());
            ack.acknowledge();                    // 毒消息必须 ack，否则分区永久阻塞
        }
    }
}
```

### 6. 批量消费（提高吞吐）

```java
@KafkaListener(topics = "order-topic", groupId = "order-batch-group")
public void onBatch(List<OrderCreatedEvent> events, Acknowledgment ack) {
    try {
        orderService.processBatch(events);
        ack.acknowledge();
    } catch (Exception e) {
        // 批量失败策略：整批重试 or 逐条拆分，需业务设计
        throw e;
    }
}

// 配置：spring.kafka.listener.type=batch
// factory.setBatchListener(true);
```

### 7. Kafka 注意事项

| 要点 | 说明 |
|------|------|
| **acks** | `all` + `min.insync.replicas=2` 防 Leader 宕机丢消息 |
| **enable.idempotence** | 防 Producer 重试导致重复写入（≠ 消费幂等） |
| **手动 commit** | `enable-auto-commit=false`，业务成功后再 `ack.acknowledge()` |
| **毒消息** | 单条反复失败不 commit → **整 Partition 卡死**，必须进 DLQ 后 ack |
| **并行度** | 消费者数 ≤ Partition 数；要扩容先加 Partition |
| **Rebalance** | 消费者上下线会暂停消费重新分配，避免频繁扩缩 |
| **无内置 DLQ** | 自建 `order-dlq-topic`，失败消息自行 send |
| **无延迟消息** | 用 Redis ZSET / 多 retry topic / 外部调度 |
| **顺序** | 同 key 同 Partition + 单消费者线程；多 Partition 只保证分区内有序 |

---

## 五、RabbitMQ

### 1. Maven 依赖

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-amqp</artifactId>
</dependency>
```

### 2. 配置（application.yml）

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    virtual-host: /
    publisher-confirm-type: correlated   # 发送确认
    publisher-returns: true              # 路由失败回调
    template:
      mandatory: true                    # 不可路由时触发 return callback
    listener:
      simple:
        acknowledge-mode: manual         # 手动 ACK
        prefetch: 10                     # 每个消费者预取条数，防堆积在客户端
        concurrency: 2
        max-concurrency: 5
```

### 3. Exchange / Queue / Binding 声明

```java
@Configuration
public class RabbitMqConfig {

    public static final String ORDER_EXCHANGE = "order.exchange";
    public static final String ORDER_QUEUE = "order.queue";
    public static final String ORDER_ROUTING_KEY = "order.created";

    // 死信交换机 & 队列
    public static final String DLX_EXCHANGE = "order.dlx.exchange";
    public static final String DLQ_QUEUE = "order.dlq.queue";

    @Bean
    public DirectExchange orderExchange() {
        return ExchangeBuilder.directExchange(ORDER_EXCHANGE).durable(true).build();
    }

    @Bean
    public Queue orderQueue() {
        return QueueBuilder.durable(ORDER_QUEUE)
                .deadLetterExchange(DLX_EXCHANGE)       // 死信路由
                .deadLetterRoutingKey("order.dead")
                .build();
    }

    @Bean
    public Binding orderBinding() {
        return BindingBuilder.bind(orderQueue()).to(orderExchange()).with(ORDER_ROUTING_KEY);
    }

    @Bean
    public DirectExchange dlxExchange() {
        return ExchangeBuilder.directExchange(DLX_EXCHANGE).durable(true).build();
    }

    @Bean
    public Queue dlqQueue() {
        return QueueBuilder.durable(DLQ_QUEUE).build();
    }

    @Bean
    public Binding dlqBinding() {
        return BindingBuilder.bind(dlqQueue()).to(dlxExchange()).with("order.dead");
    }
}
```

### 4. 普通消息 — 生产者

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderRabbitProducer {

    private final RabbitTemplate rabbitTemplate;

    @PostConstruct
    public void initCallbacks() {
        // 消息到达 Exchange 确认
        rabbitTemplate.setConfirmCallback((correlationData, ack, cause) -> {
            if (!ack) {
                log.error("消息未到达 Exchange, id={}, cause={}",
                        correlationData != null ? correlationData.getId() : null, cause);
            }
        });
        // 消息无法路由到 Queue
        rabbitTemplate.setReturnsCallback(returned -> {
            log.error("消息路由失败: exchange={}, routingKey={}, reply={}",
                    returned.getExchange(), returned.getRoutingKey(), returned.getReplyText());
        });
    }

    public void send(OrderCreatedEvent event) {
        CorrelationData correlationData = new CorrelationData(event.getOrderId());
        rabbitTemplate.convertAndSend(
                RabbitMqConfig.ORDER_EXCHANGE,
                RabbitMqConfig.ORDER_ROUTING_KEY,
                event,
                message -> {
                    message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                    message.getMessageProperties().setMessageId(event.getOrderId());
                    return message;
                },
                correlationData
        );
    }
}
```

### 5. 普通消息 — 消费者

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class OrderRabbitConsumer {

    private final OrderService orderService;
    private final IdempotentService idempotentService;

    @RabbitListener(queues = RabbitMqConfig.ORDER_QUEUE)
    public void onMessage(
            OrderCreatedEvent event,
            Channel channel,
            @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) throws IOException {

        String bizKey = event.getOrderId() + ":created";

        if (idempotentService.isProcessed(bizKey)) {
            channel.basicAck(deliveryTag, false);
            return;
        }

        try {
            orderService.processCreated(event);
            idempotentService.markProcessed(bizKey);
            channel.basicAck(deliveryTag, false);           // 成功 ACK

        } catch (RetryableException e) {
            // requeue=true：重回队列（注意无限重试风险，建议加 x-death 计数）
            channel.basicNack(deliveryTag, false, true);

        } catch (BizException e) {
            // requeue=false：进入 DLX → DLQ
            log.error("poison message, bizKey={}", bizKey, e);
            channel.basicNack(deliveryTag, false, false);
        }
    }
}
```

### 6. 延迟重试（TTL + 死信）

```java
/** 延迟队列：消息 TTL 到期后转发到业务 Exchange 重新消费 */
@Bean
public Queue retryQueue() {
    return QueueBuilder.durable("order.retry.queue")
            .withArgument("x-message-ttl", 30000)              // 30s
            .withArgument("x-dead-letter-exchange", ORDER_EXCHANGE)
            .withArgument("x-dead-letter-routing-key", ORDER_ROUTING_KEY)
            .build();
}

public void sendToRetry(OrderCreatedEvent event) {
    rabbitTemplate.convertAndSend("order.retry.exchange", "order.retry", event);
}
```

### 7. RabbitMQ 注意事项

| 要点 | 说明 |
|------|------|
| **持久化** | Exchange / Queue `durable=true` + 消息 `deliveryMode=PERSISTENT` |
| **publisher confirm** | 确认到达 Exchange；`returns` 捕获路由失败 |
| **手动 ACK** | 成功 `basicAck`；失败 `basicNack` |
| **requeue=true 风险** | 毒消息无限循环，应配合 **x-death 头** 计数或延迟队列 |
| **prefetch** | 限制未 ACK 消息数，防止消费者 OOM |
| **DLX** | `basicNack(requeue=false)` 或 TTL 过期 → 死信队列 |
| **无原生分区** | 并行靠多 Queue + 多消费者；顺序用单 Queue 单消费者 |
| **镜像队列 / Quorum Queue** | 生产环境用 Quorum Queue 保证高可用 |

---

## 六、三大 MQ 生产/消费对照

### 发送方式对照

| 语义 | RocketMQ | Kafka | RabbitMQ |
|------|----------|-------|----------|
| 同步可靠 | `syncSend` | `send().get()` | `convertAndSend` + confirm |
| 异步 | `asyncSend` | `send().whenComplete()` | `convertAndSend` + callback |
| 单向/fire-and-forget | `sendOneWay` | `send` 不等待 | 默认异步，需 confirm 才可靠 |
| 延迟 | `delayLevel` 参数 | 不支持 | TTL + DLX / 延迟插件 |
| 顺序 | `syncSendOrderly` | 同 key 同 Partition | 单 Queue |
| 事务 | 半事务消息 | `KafkaTransactionManager` | Outbox 模式 |

### 消费 ACK 对照

| MQ | 成功 | 临时失败 | 永久失败（毒消息） |
|----|------|----------|-------------------|
| **RocketMQ** | 正常返回 / `CONSUME_SUCCESS` | 抛异常 / `RECONSUME_LATER` | 吞异常 + 自建 DLQ → `CONSUME_SUCCESS` |
| **Kafka** | `ack.acknowledge()` | 不 ack（或 retry topic 后 ack） | 送 DLQ Topic 后 **必须 ack** |
| **RabbitMQ** | `basicAck` | `basicNack(requeue=true)` 或延迟队列 | `basicNack(requeue=false)` → DLX |

### 死信机制对照

```
RocketMQ：Broker 自动 16 次重试 → Topic: %DLQ%消费组名
Kafka：    应用自建 order-dlq-topic，自行 send
RabbitMQ：DLX + DLQ，或 TTL 过期进死信
```

---

## 七、统一消费模板（三 MQ 通用）

```java
public void consume(MessageContext ctx) {
    String bizKey = ctx.getBizKey();

    // Step 1：幂等
    if (idempotentService.isProcessed(bizKey)) {
        ctx.ack();
        return;
    }

    try {
        // Step 2：业务
        businessService.handle(ctx.getPayload());

        // Step 3：记录幂等
        idempotentService.markProcessed(bizKey);
        ctx.ack();

    } catch (RetryableException e) {
        // Step 4a：临时失败 → 各 MQ 对应的重试机制
        ctx.retry();

    } catch (BizException e) {
        // Step 4b：永久失败 → DLQ + 告警
        log.error("poison: {}", bizKey, e);
        dlqService.send(ctx.getPayload(), e.getMessage());
        ctx.ack();   // Kafka 尤其重要：不 ack 会卡分区
    }
}
```

---

## 八、完整落地 Checklist

### 基础设施

- [ ] Topic / Exchange / Queue 命名规范（业务.动作，如 `order.created`）
- [ ] 生产与消费分离集群或 vhost（避免测试污染生产）
- [ ] 监控：发送 TPS、消费 TPS、Lag、P99 耗时、失败率

### 生产者

- [ ] 关键业务用同步发送 + 确认机制（RocketMQ sync / Kafka acks=all / Rabbit confirm）
- [ ] 消息体设业务 key（orderId）和 traceId
- [ ] 发送失败有补偿（落库 / 定时重扫 / 告警）

### 消费者

- [ ] **幂等**（唯一索引 / 状态机 / Redis SETNX）
- [ ] 区分 `RetryableException` vs `BizException`
- [ ] 有限重试 + 退避，超限进 DLQ
- [ ] 手动 ACK，业务成功后再确认
- [ ] 毒消息快速隔离（详见 [消费失败专题](./MQ消费失败与消息积压处理.md)）

### 容量与并行

- [ ] 消费者数 ≤ RocketMQ Queue 数 / Kafka Partition 数
- [ ] 积压时有扩容脚本和降级开关
- [ ] 核心与非核心 Topic 拆分，独立消费组

---

## 九、面试高频 Q&A

| 问题 | 要点 |
|------|------|
| 三个 MQ 怎么选？ | 业务消息 RocketMQ；日志流 Kafka；灵活路由 RabbitMQ |
| 如何保证不丢消息？ | 生产确认 + 持久化 + 消费手动 ACK |
| 如何保证不重复？ | 消费端幂等，不靠 MQ 去重 |
| Kafka 毒消息危害？ | 不 commit offset 卡死整个 Partition |
| RocketMQ 死信？ | 16 次重试后进 `%DLQ%消费组` |
| RabbitMQ 如何实现延迟？ | TTL + DLX，或延迟消息插件 |
| 顺序消息怎么实现？ | 同 key → 同 Queue/Partition + 单线程消费 |
| 积压怎么扩容？ | 加消费者，但并行度上限 = Queue/Partition 数 |

---

## 十、复习串联

```
选型
  RocketMQ → 业务/事务/延迟
  Kafka    → 日志/流式/超高吞吐
  RabbitMQ → 路由灵活/企业集成

代码三板斧
  生产：同步/异步 + 业务 key + 发送确认
  消费：幂等 → 业务 → 手动 ACK
  失败：可重试 vs 毒消息 → DLQ → 告警 → 回放

四大问题
  丢失 → 确认 + 持久化 + 手动 ACK
  重复 → 消费幂等
  顺序 → 同 key 同分区/队列
  积压 → 扩容 + 批量 + 隔离毒消息（见专题笔记）
```

---

> **关联阅读**  
> - [MQ消费失败与消息积压处理](./MQ消费失败与消息积压处理.md)  
> - [java学习笔记汇总 - MQ](./java学习笔记汇总.md)
