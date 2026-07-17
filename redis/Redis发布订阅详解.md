# Redis 发布订阅详解

> 独立专题笔记，汇总入口见 [java学习笔记汇总](java学习笔记汇总.md)

---

## 一、什么是发布订阅（Pub/Sub）？

发布订阅是一种消息通信模式，包含两个角色：

| 角色 | 职责 | Redis 命令 |
|------|------|-----------|
| **发布者（Publisher）** | 发送消息到频道 | `PUBLISH channel message` |
| **订阅者（Subscriber）** | 订阅频道并接收消息 | `SUBSCRIBE channel` |

```
发布者A ──PUBLISH──▶ news频道 ◀──SUBSCRIBE── 订阅者1
发布者B ──PUBLISH──▶             ◀──SUBSCRIBE── 订阅者2
                              (消息会被广播给所有订阅者)
```

**核心特点**：
- **一对多广播**：一条消息，多个订阅者都能收到
- **无状态**：订阅者只能收到订阅后发布的消息，历史消息不保留
- **非持久**：Redis 重启后，订阅关系丢失

---

## 二、使用场景

| 场景 | 说明 | 示例 |
|------|------|------|
| **实时通知** | 系统公告、状态变更通知 | 订单状态变更通知 |
| **聊天室** | 多用户实时消息 | 在线聊天、直播弹幕 |
| **分布式锁通知** | 锁释放后通知等待线程 | Redisson 看门狗机制 |
| **缓存失效** | 数据变更通知各节点清除缓存 | Canal + Redis 缓存更新 |
| **日志收集** | 多个服务集中推送日志 | 分布式日志聚合 |

---

## 三、Redis 命令基础

### 1. 发布消息

```bash
# 发布消息到频道
PUBLISH channel1 "Hello, Redis!"
# 返回：订阅者数量（integer）
```

### 2. 订阅频道

```bash
# 订阅单个频道
SUBSCRIBE channel1

# 订阅多个频道
SUBSCRIBE channel1 channel2 channel3

# 模式订阅（通配符）
PSUBSCRIBE news.*      # 订阅所有 news. 开头的频道
PSUBSCRIBE *.error     # 订阅所有 .error 结尾的频道
```

### 3. 取消订阅

```bash
# 取消指定频道订阅
UNSUBSCRIBE channel1

# 取消模式订阅
PUNSUBSCRIBE news.*
```

### 4. 其他命令

```bash
# 查看活跃频道（至少有一个订阅者）
PUBSUB CHANNELS

# 查看指定频道的订阅者数量
PUBSUB NUMSUB channel1

# 查看模式订阅数量
PUBSUB NUMPAT
```

---

## 四、Java 实现（Jedis）

### 1. 添加 Maven 依赖

```xml
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>4.3.1</version>
</dependency>
```

### 2. 发布者示例

```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;

public class Publisher {
    private final JedisPool jedisPool;
    
    public Publisher(JedisPool jedisPool) {
        this.jedisPool = jedisPool;
    }
    
    /**
     * 发布消息到指定频道
     * @param channel 频道名称
     * @param message 消息内容
     * @return 接收到消息的订阅者数量
     */
    public long publish(String channel, String message) {
        try (Jedis jedis = jedisPool.getResource()) {
            long count = jedis.publish(channel, message);
            System.out.println("消息已发布到频道: " + channel + ", 订阅者数量: " + count);
            return count;
        }
    }
    
    /**
     * 发布对象消息（JSON 格式）
     */
    public long publishObject(String channel, Object obj) {
        try (Jedis jedis = jedisPool.getResource()) {
            String json = new Gson().toJson(obj);
            return jedis.publish(channel, json);
        }
    }
    
    public static void main(String[] args) {
        JedisPool pool = new JedisPool("localhost", 6379);
        Publisher publisher = new Publisher(pool);
        
        // 发布简单文本消息
        publisher.publish("news.tech", "Redis 7.0 发布了！");
        
        // 发布 JSON 消息
        Order order = new Order(1001L, "CREATED", System.currentTimeMillis());
        publisher.publishObject("order.status", order);
        
        pool.close();
    }
}
```

### 3. 订阅者示例

```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPubSub;

public class Subscriber {
    private final Jedis jedis;
    private final JedisPubSub jedisPubSub;
    
    public Subscriber(String host, int port) {
        this.jedis = new Jedis(host, port);
        this.jedisPubSub = new JedisPubSub() {
            /**
             * 收到消息时的回调
             */
            @Override
            public void onMessage(String channel, String message) {
                System.out.println("收到消息 - 频道: " + channel + ", 内容: " + message);
                
                // 处理业务逻辑
                handleMessage(channel, message);
            }
            
            /**
             * 订阅成功时的回调
             */
            @Override
            public void onSubscribe(String channel, int subscribedChannels) {
                System.out.println("成功订阅频道: " + channel);
            }
            
            /**
             * 取消订阅时的回调
             */
            @Override
            public void onUnsubscribe(String channel, int subscribedChannels) {
                System.out.println("取消订阅频道: " + channel);
            }
            
            /**
             * 模式订阅的消息回调（PSUBSCRIBE）
             */
            @Override
            public void onPMessage(String pattern, String channel, String message) {
                System.out.println("模式消息 - 模式: " + pattern + ", 频道: " + channel + ", 内容: " + message);
            }
        };
    }
    
    /**
     * 订阅单个频道（阻塞方法）
     */
    public void subscribe(String channel) {
        System.out.println("开始订阅频道: " + channel);
        jedis.subscribe(jedisPubSub, channel);
    }
    
    /**
     * 订阅多个频道
     */
    public void subscribe(String... channels) {
        jedis.subscribe(jedisPubSub, channels);
    }
    
    /**
     * 模式订阅
     */
    public void psubscribe(String pattern) {
        jedis.psubscribe(jedisPubSub, pattern);
    }
    
    /**
     * 取消订阅
     */
    public void unsubscribe() {
        jedisPubSub.unsubscribe();
    }
    
    /**
     * 处理消息的业务逻辑
     */
    private void handleMessage(String channel, String message) {
        switch (channel) {
            case "order.status":
                // 处理订单状态变更
                Order order = new Gson().fromJson(message, Order.class);
                System.out.println("处理订单状态变更: " + order);
                break;
            case "news.tech":
                // 处理技术新闻
                System.out.println("收到技术新闻: " + message);
                break;
            default:
                System.out.println("未知频道消息");
        }
    }
    
    public static void main(String[] args) {
        // 创建订阅者并订阅频道
        Subscriber subscriber = new Subscriber("localhost", 6379);
        
        // 订阅单个频道（阻塞线程）
        subscriber.subscribe("order.status");
        
        // 或者订阅多个频道
        // subscriber.subscribe("order.status", "news.tech", "system.notice");
        
        // 或者模式订阅
        // subscriber.psubscribe("order.*");
    }
}
```

### 4. 订阅者线程管理（生产环境）

```java
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class SubscriberManager {
    private final ExecutorService executorService;
    private final JedisPubSub jedisPubSub;
    
    public SubscriberManager() {
        this.executorService = Executors.newSingleThreadExecutor();
        this.jedisPubSub = new JedisPubSub() {
            @Override
            public void onMessage(String channel, String message) {
                // 消息处理逻辑
                System.out.println(Thread.currentThread().getName() + 
                                 " 收到消息: " + message);
            }
        };
    }
    
    /**
     * 异步订阅（不阻塞主线程）
     */
    public void subscribeAsync(String host, int port, String channel) {
        executorService.submit(() -> {
            try (Jedis jedis = new Jedis(host, port)) {
                System.out.println("开始订阅频道: " + channel);
                jedis.subscribe(jedisPubSub, channel);
            } catch (Exception e) {
                e.printStackTrace();
            }
        });
    }
    
    /**
     * 关闭订阅者
     */
    public void shutdown() {
        jedisPubSub.unsubscribe();
        executorService.shutdown();
        try {
            if (!executorService.awaitTermination(5, TimeUnit.SECONDS)) {
                executorService.shutdownNow();
            }
        } catch (InterruptedException e) {
            executorService.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
    
    public static void main(String[] args) throws InterruptedException {
        SubscriberManager manager = new SubscriberManager();
        
        // 订阅多个频道
        manager.subscribeAsync("localhost", 6379, "order.status");
        manager.subscribeAsync("localhost", 6379, "news.tech");
        
        // 主线程继续执行其他任务
        System.out.println("订阅已启动，主线程继续执行...");
        
        // 模拟运行一段时间后关闭
        Thread.sleep(30000);
        manager.shutdown();
    }
}
```

---

## 五、Java 实现（Redisson）

### 1. 添加 Maven 依赖

```xml
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson</artifactId>
    <version>3.20.1</version>
</dependency>
```

### 2. 发布者示例

```java
import org.redisson.Redisson;
import org.redisson.api.RTopic;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;

public class RedissonPublisher {
    private final RedissonClient redissonClient;
    
    public RedissonPublisher(String address) {
        Config config = new Config();
        config.useSingleServer()
              .setAddress(address);
        this.redissonClient = Redisson.create(config);
    }
    
    /**
     * 发布消息
     */
    public void publish(String channel, String message) {
        RTopic topic = redissonClient.getTopic(channel);
        long listeners = topic.publish(message);
        System.out.println("消息已发布, 监听者数量: " + listeners);
    }
    
    /**
     * 发布对象消息
     */
    public <T> void publishObject(String channel, T message) {
        RTopic<T> topic = redissonClient.getTopic(channel);
        topic.publish(message);
    }
    
    public void close() {
        redissonClient.shutdown();
    }
    
    public static void main(String[] args) {
        RedissonPublisher publisher = new RedissonPublisher("redis://localhost:6379");
        
        // 发布字符串消息
        publisher.publish("order.status", "订单已创建");
        
        // 发布对象消息
        Order order = new Order(1001L, "PAID", System.currentTimeMillis());
        publisher.publishObject("order.status", order);
        
        publisher.close();
    }
}
```

### 3. 订阅者示例

```java
import org.redisson.Redisson;
import org.redisson.api.RTopic;
import org.redisson.api.RedissonClient;
import org.redisson.api.listener.MessageListener;
import org.redisson.config.Config;

public class RedissonSubscriber {
    private final RedissonClient redissonClient;
    
    public RedissonSubscriber(String address) {
        Config config = new Config();
        config.useSingleServer()
              .setAddress(address);
        this.redissonClient = Redisson.create(config);
    }
    
    /**
     * 订阅频道（同步）
     */
    public <T> void subscribe(String channel, Class<T> type) {
        RTopic<T> topic = redissonClient.getTopic(channel);
        
        // 添加监听器
        topic.addListener(new MessageListener<T>() {
            @Override
            public void onMessage(CharSequence channel, T message) {
                System.out.println("收到消息 - 频道: " + channel + ", 内容: " + message);
                handleMessage(message);
            }
        });
        
        System.out.println("已订阅频道: " + channel);
    }
    
    /**
     * 处理消息
     */
    private <T> void handleMessage(T message) {
        if (message instanceof Order) {
            Order order = (Order) message;
            System.out.println("处理订单: " + order.getOrderId());
        }
    }
    
    /**
     * 订阅频道（异步）
     */
    public void subscribeAsync(String channel) {
        RTopic<String> topic = redissonClient.getTopic(channel);
        
        topic.addListenerAsync(new MessageListener<String>() {
            @Override
            public void onMessage(CharSequence channel, String message) {
                // 异步处理消息
                System.out.println("异步处理消息: " + message);
            }
        });
    }
    
    public void close() {
        redissonClient.shutdown();
    }
    
    public static void main(String[] args) throws InterruptedException {
        RedissonSubscriber subscriber = new RedissonSubscriber("redis://localhost:6379");
        
        // 订阅订单状态频道
        subscriber.subscribe("order.status", Order.class);
        
        // 保持运行
        Thread.sleep(60000);
        subscriber.close();
    }
}
```

### 4. 模式订阅（Redisson）

```java
import org.redisson.api.PatternMessageListener;

public class RedissonPatternSubscriber {
    private final RedissonClient redissonClient;
    
    public RedissonPatternSubscriber(String address) {
        Config config = new Config();
        config.useSingleServer().setAddress(address);
        this.redissonClient = Redisson.create(config);
    }
    
    /**
     * 模式订阅
     */
    public void psubscribe(String pattern) {
        RTopic<String> topic = redissonClient.getTopic(pattern);
        
        topic.addListener(new PatternMessageListener() {
            @Override
            public void onMessage(String pattern, String channel, Object message) {
                System.out.println("模式匹配 - 模式: " + pattern + 
                                 ", 频道: " + channel + 
                                 ", 消息: " + message);
            }
        });
        
        System.out.println("已订阅模式: " + pattern);
    }
    
    public static void main(String[] args) throws InterruptedException {
        RedissonPatternSubscriber subscriber = new RedissonPatternSubscriber("redis://localhost:6379");
        
        // 订阅所有 order. 开头的频道
        subscriber.psubscribe("order.*");
        
        Thread.sleep(60000);
    }
}
```

---

## 六、实际应用案例

### 1. 订单状态通知系统

```java
/**
 * 订单发布者：订单状态变更时发布消息
 */
@Service
public class OrderPublisher {
    @Autowired
    private RedissonClient redissonClient;
    
    public void publishOrderStatusChange(Long orderId, String oldStatus, String newStatus) {
        OrderStatusEvent event = new OrderStatusEvent();
        event.setOrderId(orderId);
        event.setOldStatus(oldStatus);
        event.setNewStatus(newStatus);
        event.setTimestamp(System.currentTimeMillis());
        
        RTopic<OrderStatusEvent> topic = redissonClient.getTopic("order.status");
        topic.publish(event);
    }
}

/**
 * 订单订阅者：监听订单状态变更并处理
 */
@Component
public class OrderSubscriber implements InitializingBean {
    @Autowired
    private RedissonClient redissonClient;
    
    @Autowired
    private NotificationService notificationService;
    
    @Autowired
    private DataSyncService dataSyncService;
    
    @Override
    public void afterPropertiesSet() {
        RTopic<OrderStatusEvent> topic = redissonClient.getTopic("order.status");
        
        topic.addListener((channel, event) -> {
            // 1. 发送用户通知
            notificationService.sendOrderNotification(event);
            
            // 2. 同步数据到其他系统
            dataSyncService.syncOrderStatus(event);
            
            // 3. 记录日志
            log.info("订单状态变更: orderId={}, {}→{}", 
                    event.getOrderId(), event.getOldStatus(), event.getNewStatus());
        });
    }
}
```

### 2. 缓存失效通知

```java
/**
 * 数据更新时通知所有节点清除缓存
 */
@Service
public class CacheInvalidationPublisher {
    @Autowired
    private RedissonClient redissonClient;
    
    public void publishCacheInvalidation(String cacheKey) {
        CacheInvalidationEvent event = new CacheInvalidationEvent();
        event.setCacheKey(cacheKey);
        event.setNodeId(getNodeId());
        event.setTimestamp(System.currentTimeMillis());
        
        RTopic<CacheInvalidationEvent> topic = redissonClient.getTopic("cache.invalidate");
        topic.publish(event);
    }
    
    private String getNodeId() {
        return InetAddress.getLocalHost().getHostAddress();
    }
}

/**
 * 监听缓存失效事件并清除本地缓存
 */
@Component
public class CacheInvalidationSubscriber implements InitializingBean {
    @Autowired
    private RedissonClient redissonClient;
    
    @Autowired
    private CacheManager cacheManager;
    
    @Override
    public void afterPropertiesSet() {
        RTopic<CacheInvalidationEvent> topic = redissonClient.getTopic("cache.invalidate");
        
        topic.addListener((channel, event) -> {
            // 忽略自己发出的消息
            if (event.getNodeId().equals(getNodeId())) {
                return;
            }
            
            // 清除本地缓存
            cacheManager.evict(event.getCacheKey());
            log.info("清除本地缓存: key={}, 来源节点: {}", 
                    event.getCacheKey(), event.getNodeId());
        });
    }
    
    private String getNodeId() {
        return InetAddress.getLocalHost().getHostAddress();
    }
}
```

### 3. 分布式锁通知（Redisson 内部使用）

```java
/**
 * Redisson 内部使用 Pub/Sub 实现锁释放通知
 * 当锁持有者释放锁时，通知等待的线程
 */
// Redisson 内部实现示例
private void subscribeLock(String lockName) {
    RTopic<LockMessage> topic = redisson.getTopic("redisson_lock__channel:" + lockName);
    
    topic.addListener((channel, message) -> {
        if (message.getType() == LockMessage.UNLOCK) {
            // 锁被释放，唤醒等待的线程
            notifyWaitingThreads();
        }
    });
}
```

---

## 七、与消息队列对比

| 特性 | Redis Pub/Sub | RabbitMQ | Kafka |
|------|---------------|----------|-------|
| **消息持久化** | ❌ 不持久 | ✅ 支持 | ✅ 支持 |
| **消息回溯** | ❌ 不支持 | ✅ 支持 | ✅ 支持 |
| **消费确认** | ❌ 无 ACK | ✅ ACK 机制 | ✅ Offset 机制 |
| **复杂路由** | ❌ 仅简单模式 | ✅ Exchange/Queue | ✅ Topic/Partition |
| **吞吐量** | 极高（百万级/s） | 中等 | 极高 |
| **可靠性** | 低（可能丢消息） | 高 | 高 |
| **使用复杂度** | 简单 | 中等 | 中等 |
| **适用场景** | 实时通知、简单广播 | 可靠消息传递 | 日志收集、大数据 |

**选型建议**：
- ✅ 用 Redis Pub/Sub：实时通知、缓存失效、简单广播、对丢消息不敏感
- ✅ 用 RabbitMQ：需要可靠消息传递、复杂路由、事务消息
- ✅ 用 Kafka：大数据量、日志收集、流处理

---

## 八、注意事项与最佳实践

### 1. 订阅者断线处理

```java
/**
 * 问题：订阅者断线重连后，会丢失断线期间的消息
 * 解决：需要应用层补偿机制
 */
public class ReliableSubscriber {
    private Jedis jedis;
    private String channel;
    
    // 订阅者上线后主动拉取最新状态
    public void subscribeWithRecovery(String channel) {
        // 1. 先订阅频道
        subscribe(channel);
        
        // 2. 主动拉取最新状态（补偿机制）
        recoverLatestState(channel);
    }
    
    private void recoverLatestState(String channel) {
        // 从数据库或其他存储获取最新状态
        String latestState = fetchLatestStateFromDB(channel);
        
        // 处理最新状态
        processState(latestState);
    }
}
```

### 2. 消息序列化

```java
/**
 * 推荐：使用 JSON 序列化
 */
public class MessageSerializer {
    private final Gson gson = new Gson();
    
    // 发布：对象 → JSON
    public String serialize(Object obj) {
        return gson.toJson(obj);
    }
    
    // 订阅：JSON → 对象
    public <T> T deserialize(String json, Class<T> clazz) {
        return gson.fromJson(json, clazz);
    }
}

/**
 * 不推荐：Java 原生序列化（版本兼容性问题）
 */
// 不推荐的示例
public void publishJavaObject(String channel, Serializable obj) {
    // ❌ Java 序列化有版本兼容问题
    byte[] data = SerializationUtils.serialize(obj);
    jedis.publish(channel.getBytes(), data);
}
```

### 3. 异常处理

```java
/**
 * 订阅者异常处理最佳实践
 */
public class RobustSubscriber extends JedisPubSub {
    @Override
    public void onMessage(String channel, String message) {
        try {
            // 1. 参数校验
            if (StringUtils.isBlank(message)) {
                log.warn("收到空消息, channel: {}", channel);
                return;
            }
            
            // 2. 消息处理
            handleMessage(channel, message);
            
        } catch (JsonSyntaxException e) {
            // JSON 解析异常
            log.error("消息格式错误: {}", message, e);
            
        } catch (BusinessException e) {
            // 业务异常
            log.error("处理消息失败: {}", message, e);
            
        } catch (Exception e) {
            // 其他未知异常
            log.error("未知错误: {}", message, e);
            
        } finally {
            // 3. 记录处理结果
            recordMessageProcess(channel, message);
        }
    }
}
```

### 4. 性能优化

```java
/**
 * 批量发布：减少网络往返
 */
public class BatchPublisher {
    private Jedis jedis;
    
    /**
     * 使用 Pipeline 批量发布
     */
    public void batchPublish(Map<String, String> messages) {
        Pipeline pipeline = jedis.pipelined();
        
        for (Map.Entry<String, String> entry : messages.entrySet()) {
            pipeline.publish(entry.getKey(), entry.getValue());
        }
        
        // 一次性执行所有命令
        pipeline.sync();
        
        log.info("批量发布完成, 数量: {}", messages.size());
    }
}

/**
 * 消息过滤：在应用层过滤，减少网络传输
 */
public class FilteredSubscriber extends JedisPubSub {
    private final String nodeId;
    
    @Override
    public void onMessage(String channel, String message) {
        // 解析消息
        MessageEvent event = parseEvent(message);
        
        // 过滤掉自己发出的消息
        if (event.getSourceNodeId().equals(nodeId)) {
            return;
        }
        
        // 只处理感兴趣的消息
        if (isInterested(event)) {
            processEvent(event);
        }
    }
}
```

---

## 九、常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| **订阅者收不到历史消息** | Redis Pub/Sub 是无状态的，只发送订阅后的消息 | 使用消息队列或自己实现消息持久化 |
| **订阅者断线丢消息** | 网络抖动或重启导致订阅断开 | 实现断线重连 + 状态补偿机制 |
| **消息堆积** | 订阅者处理速度慢于发布速度 | 增加订阅者数量或使用消息队列 |
| **跨实例通知不工作** | Redis 部署模式问题 | 使用正确的 Redis 部署模式 |
| **序列化版本不一致** | Java 原生序列化不兼容 | 使用 JSON 序列化 |
| **订阅者线程阻塞** | 同步处理耗时操作 | 使用异步处理或线程池 |

---

## 十、生产环境检查清单

### 部署前检查

- [ ] Redis 版本是否支持 Pub/Sub（所有版本都支持）
- [ ] 网络连通性测试（发布者和订阅者都能连接 Redis）
- [ ] 订阅者线程池配置合理
- [ ] 消息序列化方案确定（推荐 JSON）
- [ ] 异常处理和日志记录完善
- [ ] 监控指标定义（消息量、处理延迟等）

### 运行时监控

```java
/**
 * 监控指标
 */
public class PubSubMonitor {
    private AtomicLong publishCount = new AtomicLong(0);
    private AtomicLong receiveCount = new AtomicLong(0);
    private AtomicLong errorCount = new AtomicLong(0);
    
    // 发布消息时记录
    public void recordPublish() {
        publishCount.incrementAndGet();
    }
    
    // 收到消息时记录
    public void recordReceive() {
        receiveCount.incrementAndGet();
    }
    
    // 发生错误时记录
    public void recordError() {
        errorCount.incrementAndGet();
    }
    
    // 获取监控数据
    public Map<String, Long> getMetrics() {
        Map<String, Long> metrics = new HashMap<>();
        metrics.put("publish_count", publishCount.get());
        metrics.put("receive_count", receiveCount.get());
        metrics.put("error_count", errorCount.get());
        return metrics;
    }
}
```

---

## 十一、复习串联

```
核心概念
  发布者（PUBLISH） ──▶ 频道（channel） ◀── 订阅者（SUBSCRIBE）
  一对多广播，无状态，不持久

Java 实现
  Jedis：JedisPubSub 回调
  Redisson：RTopic.addListener

使用场景
  实时通知、缓存失效、分布式锁通知、简单消息广播

注意事项
  不持久化、无 ACK、可能丢消息
  需要 JSON 序列化、异常处理、监控

与其他 MQ 对比
  Redis Pub/Sub：实时通知
  RabbitMQ：可靠消息传递
  Kafka：大数据量
```

---

> **关联阅读**  
> - [Redisson分布式锁详解](Redisson分布式锁详解.md) — Redisson 在锁机制中使用 Pub/Sub  
> - [Redis部署模式对比-单机哨兵集群](Redis部署模式对比-单机哨兵集群.md) — Redis 部署模式选择  
> - [java学习笔记汇总](java学习笔记汇总.md) — Java 学习笔记总入口