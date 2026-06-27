# Seata 使用教程

## 一、Seata 核心概念

### 1.1 分布式事务问题

在微服务架构中，一个业务操作可能涉及多个服务的数据库操作，传统的本地事务无法保证跨服务的数据一致性。Seata 提供了分布式事务解决方案。

### 1.2 Seata 三大组件

| 组件 | 英文 | 职责 |
|------|------|------|
| **TC** | Transaction Coordinator | 事务协调器，管理全局事务的提交和回滚 |
| **TM** | Transaction Manager | 事务管理器，定义全局事务的范围 |
| **RM** | Resource Manager | 资源管理器，管理分支事务，与 TC 通信 |

### 1.3 事务模式对比

| 模式 | 适用场景 | 侵入性 | 性能 | 一致性 |
|------|---------|--------|------|--------|
| **AT** | 大多数业务场景 | 低 | 高 | 强一致 |
| **TCC** | 需要自定义业务逻辑 | 高 | 高 | 最终一致 |
| **SAGA** | 长事务场景 | 中 | 中 | 最终一致 |
| **XA** | 需要强一致性场景 | 低 | 低 | 强一致 |

---

## 二、客户端接入

### 2.1 添加依赖

**Maven 依赖**：

```xml
<!-- Seata Spring Boot Starter -->
<dependency>
    <groupId>io.seata</groupId>
    <artifactId>seata-spring-boot-starter</artifactId>
    <version>1.7.0</version>
</dependency>

<!-- Nacos Discovery (如需使用 Nacos 注册) -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
    <version>2022.0.0.0</version>
</dependency>

<!-- MySQL 驱动 -->
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
    <version>8.0.33</version>
</dependency>
```

### 2.2 配置文件

**application.yml**：

```yaml
server:
  port: 8080

spring:
  application:
    name: order-service
  datasource:
    url: jdbc:mysql://localhost:3306/example_db?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
    username: root
    password: root
    driver-class-name: com.mysql.cj.jdbc.Driver

# Seata 配置
seata:
  enabled: true
  application-id: ${spring.application.name}
  tx-service-group: default_tx_group
  
  # 注册中心配置
  registry:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
      application: seata-server
  
  # 配置中心配置
  config:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
  
  # 服务配置
  service:
    vgroup-mapping:
      default_tx_group: default
    grouplist:
      default: 192.168.56.106:8091,192.168.56.107:8092,192.168.56.108:8093
```

### 2.3 创建 undo_log 表（AT 模式必需）

在业务数据库中创建：

```sql
CREATE TABLE IF NOT EXISTS `undo_log` (
    `branch_id` BIGINT NOT NULL COMMENT '分支事务ID',
    `xid` VARCHAR(128) NOT NULL COMMENT '全局事务ID',
    `context` VARCHAR(128) NOT NULL COMMENT '上下文信息',
    `rollback_info` LONGBLOB NOT NULL COMMENT '回滚数据',
    `log_status` INT NOT NULL COMMENT '状态: 0-正常, 1-防御',
    `log_created` DATETIME(6) NOT NULL COMMENT '创建时间',
    `log_modified` DATETIME(6) NOT NULL COMMENT '修改时间',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT ='AT事务回滚日志表';
```

---

## 三、AT 模式使用（推荐）

### 3.1 基本用法

**在发起全局事务的服务中使用 `@GlobalTransactional` 注解**：

```java
import io.seata.spring.annotation.GlobalTransactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class OrderService {
    
    @Autowired
    private OrderMapper orderMapper;
    
    @Autowired
    private AccountFeignClient accountFeignClient;
    
    @Autowired
    private StorageFeignClient storageFeignClient;
    
    /**
    * 创建订单，涉及订单、账户、库存三个服务
    */
    @GlobalTransactional(name = "createOrder", rollbackFor = Exception.class)
    public void createOrder(OrderDTO orderDTO) {
        // 1. 创建订单
        Order order = new Order();
        order.setUserId(orderDTO.getUserId());
        order.setProductId(orderDTO.getProductId());
        order.setCount(orderDTO.getCount());
        order.setMoney(orderDTO.getMoney());
        order.setStatus(0); // 0-待支付
        orderMapper.insert(order);
        
        // 2. 扣减账户余额（调用账户服务）
        accountFeignClient.decrease(orderDTO.getUserId(), orderDTO.getMoney());
        
        // 3. 扣减库存（调用库存服务）
        storageFeignClient.decrease(orderDTO.getProductId(), orderDTO.getCount());
        
        // 如果以上任何一步失败，全局事务将回滚
    }
}
```

### 3.2 分支事务服务

**账户服务（被调用方）**：

```java
@Service
public class AccountService {
    
    @Autowired
    private AccountMapper accountMapper;
    
    /**
    * 扣减账户余额
    */
    public void decrease(Long userId, BigDecimal money) {
        Account account = accountMapper.selectByUserId(userId);
        if (account == null) {
            throw new RuntimeException("账户不存在");
        }
        if (account.getBalance().compareTo(money) < 0) {
            throw new RuntimeException("余额不足");
        }
        
        // 扣减余额
        accountMapper.decrease(userId, money);
    }
}
```

**库存服务（被调用方）**：

```java
@Service
public class StorageService {
    
    @Autowired
    private StorageMapper storageMapper;
    
    /**
    * 扣减库存
    */
    public void decrease(Long productId, Integer count) {
        Storage storage = storageMapper.selectByProductId(productId);
        if (storage == null) {
            throw new RuntimeException("商品不存在");
        }
        if (storage.getStock() < count) {
            throw new RuntimeException("库存不足");
        }
        
        // 扣减库存
        storageMapper.decrease(productId, count);
    }
}
```

### 3.3 事务传播行为

```java
@GlobalTransactional(
    name = "myTransaction",
    rollbackFor = Exception.class,
    timeoutMills = 300000  // 超时时间，默认60秒
)
public void businessMethod() {
    // 业务逻辑
}
```

---

## 四、TCC 模式使用

### 4.1 TCC 三阶段

| 阶段 | 方法 | 职责 |
|------|------|------|
| **Try** | `@TwoPhaseBusinessAction(commitMethod, rollbackMethod)` | 预留资源，检查业务条件 |
| **Confirm** | commitMethod | 确认执行，真正提交 |
| **Cancel** | rollbackMethod | 取消执行，释放预留资源 |

### 4.2 实现示例

```java
import io.seata.rm.tcc.api.BusinessActionContext;
import io.seata.rm.tcc.api.LocalTCC;
import io.seata.rm.tcc.api.TwoPhaseBusinessAction;

@LocalTCC
public interface AccountTccService {
    
    /**
    * Try: 冻结账户余额
    */
    @TwoPhaseBusinessAction(
        name = "accountFreeze",
        commitMethod = "confirm",
        rollbackMethod = "cancel"
    )
    void freeze(
        BusinessActionContext context,
        @BusinessActionContextParameter(paramName = "userId") Long userId,
        @BusinessActionContextParameter(paramName = "amount") BigDecimal amount
    );
    
    /**
    * Confirm: 扣减余额
    */
    void confirm(BusinessActionContext context);
    
    /**
    * Cancel: 解冻余额
    */
    void cancel(BusinessActionContext context);
}
```

**实现类**：

```java
@Service
public class AccountTccServiceImpl implements AccountTccService {
    
    @Autowired
    private AccountMapper accountMapper;
    
    @Override
    public void freeze(BusinessActionContext context, Long userId, BigDecimal amount) {
        // 冻结金额（增加冻结字段）
        accountMapper.freeze(userId, amount);
    }
    
    @Override
    public void confirm(BusinessActionContext context) {
        Long userId = Long.parseLong(context.getActionContext("userId").toString());
        BigDecimal amount = new BigDecimal(context.getActionContext("amount").toString());
        
        // 扣减余额，同时解冻
        accountMapper.confirmFreeze(userId, amount);
    }
    
    @Override
    public void cancel(BusinessActionContext context) {
        Long userId = Long.parseLong(context.getActionContext("userId").toString());
        BigDecimal amount = new BigDecimal(context.getActionContext("amount").toString());
        
        // 解冻金额
        accountMapper.unfreeze(userId, amount);
    }
}
```

---

## 五、SAGA 模式使用

### 5.1 适用场景

- 长事务场景（流程可能跨越多个步骤）
- 需要人工干预的业务流程
- 异步执行的业务场景

### 5.2 配置方式

**saga模式配置**：

```yaml
seata:
  service:
    vgroup-mapping:
      default_tx_group: default
  saga:
    enabled: true
    registry-type: nacos
    nacos-server-addr: 192.168.56.106:8848
    nacos-namespace: seate
```

**定义状态机 JSON**：

```json
{
"name": "orderSaga",
"instanceId": "${spring.application.name}",
"expression": "${orderStatus}",
"status": {
    "INIT": {
    "submitOrder": {
        "target": "orderService.submit",
        "compensate": "orderService.cancel",
        "next": "PAID"
    }
    },
    "PAID": {
    "deductStock": {
        "target": "storageService.deduct",
        "compensate": "storageService.revert",
        "next": "DONE"
    }
    },
    "DONE": {}
}
}
```

---

## 六、XA 模式使用

### 6.1 适用场景

- 需要强一致性保证
- 多数据库类型混合场景（Oracle、SQL Server等）

### 6.2 配置方式

```yaml
seata:
  store:
    mode: xa
  service:
    vgroup-mapping:
      default_tx_group: default
```

---

## 七、实战示例：订单创建流程

### 7.1 数据库表设计

**订单表（order_db）**：

```sql
CREATE TABLE `orders` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL,
    `product_id` BIGINT NOT NULL,
    `count` INT NOT NULL DEFAULT 0,
    `money` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `status` TINYINT NOT NULL DEFAULT 0 COMMENT '0-待支付, 1-已支付, 2-已取消',
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**账户表（account_db）**：

```sql
CREATE TABLE `account` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL UNIQUE,
    `balance` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `frozen_balance` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**库存表（storage_db）**：

```sql
CREATE TABLE `storage` (
    `id` BIGINT PRIMARY KEY AUTO_INCREMENT,
    `product_id` BIGINT NOT NULL UNIQUE,
    `stock` INT NOT NULL DEFAULT 0,
    `frozen_stock` INT NOT NULL DEFAULT 0,
    `create_time` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `update_time` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 7.2 完整业务流程

```java
@Service
public class OrderService {
    
    @Autowired
    private OrderMapper orderMapper;
    
    @Autowired
    private AccountClient accountClient;
    
    @Autowired
    private StorageClient storageClient;
    
    /**
    * 创建订单完整流程
    */
    @GlobalTransactional(name = "createOrder", rollbackFor = Exception.class)
    public OrderResponse createOrder(OrderRequest request) {
        // 1. 创建订单记录
        Order order = buildOrder(request);
        orderMapper.insert(order);
        
        try {
            // 2. 扣减账户余额
            accountClient.decreaseBalance(request.getUserId(), request.getTotalAmount());
            
            // 3. 扣减库存
            storageClient.decreaseStock(request.getProductId(), request.getQuantity());
            
            // 4. 更新订单状态为已支付
            orderMapper.updateStatus(order.getId(), 1);
            
            return OrderResponse.success(order.getId());
            
        } catch (Exception e) {
            // 事务会自动回滚
            log.error("订单创建失败: {}", e.getMessage());
            throw new BusinessException("订单创建失败", e);
        }
    }
    
    private Order buildOrder(OrderRequest request) {
        Order order = new Order();
        order.setUserId(request.getUserId());
        order.setProductId(request.getProductId());
        order.setCount(request.getQuantity());
        order.setMoney(request.getTotalAmount());
        order.setStatus(0);
        return order;
    }
}
```

---

## 八、事务配置详解

### 8.1 全局事务注解参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `name` | String | "" | 事务名称 |
| `rollbackFor` | Class<? extends Throwable>[] | RuntimeException | 需要回滚的异常类型 |
| `rollbackForClassName` | String[] | {} | 需要回滚的异常类名 |
| `noRollbackFor` | Class<? extends Throwable>[] | {} | 不需要回滚的异常类型 |
| `noRollbackForClassName` | String[] | {} | 不需要回滚的异常类名 |
| `timeoutMills` | long | 60000 | 超时时间（毫秒） |
| `propagation` | Propagation | REQUIRED | 事务传播行为 |

### 8.2 服务分组配置

```yaml
seata:
  service:
    vgroup-mapping:
      # 格式: 服务组名 -> 集群名
      order_tx_group: default
      payment_tx_group: default
    grouplist:
      # 格式: 集群名 -> 地址列表
      default: 192.168.56.106:8091,192.168.56.107:8092
```

---

## 九、监控与调试

### 9.1 Seata 控制台

访问地址：`http://192.168.31.100:7091`（通过端口转发）

**功能：**
- 全局事务列表查询
- 事务详情查看
- 事务统计分析
- 异常事务处理

### 9.2 日志配置

```yaml
logging:
  level:
    io.seata: DEBUG
    io.seata.core: DEBUG
```

### 9.3 常用查询命令

```bash
# 查询全局事务列表
curl -s 'http://192.168.31.100:8848/nacos/v2/ns/instance/list?serviceName=seata-server&groupName=SEATA_GROUP&namespaceId=seate'

# 查询服务列表
curl -s 'http://192.168.31.100:8848/nacos/v2/ns/service/list?pageNo=1&pageSize=10&namespaceId=seate'
```

---

## 十、性能优化

### 10.1 连接池配置

```yaml
spring:
  datasource:
    hikari:
      minimum-idle: 10
      maximum-pool-size: 50
      idle-timeout: 300000
      connection-timeout: 20000
      max-lifetime: 1200000
```

### 10.2 事务超时设置

```yaml
seata:
  timeout:
    # 全局事务超时时间
    global: 300000
    # 分支事务超时时间
    branch: 60000
```

### 10.3 异步提交优化

```yaml
seata:
  enable-auto-data-source-proxy: true
  config:
    shutdown:
      wait: 30
  service:
    max-commit-retry-timeout: -1
    max-rollback-retry-timeout: -1
```

---

## 十一、常见问题

### 11.1 事务不回滚

**原因**：
- `@GlobalTransactional` 注解未正确添加
- 异常被捕获但未重新抛出
- 方法内部调用（非代理调用）

**解决方案**：
```java
// 错误：内部调用不会触发事务
public void outerMethod() {
    innerMethod(); // 不会触发事务
}

@GlobalTransactional
public void innerMethod() {
    // ...
}

// 正确：通过代理调用
@Autowired
private OrderService self;

public void outerMethod() {
    self.innerMethod(); // 通过代理调用
}

@GlobalTransactional
public void innerMethod() {
    // ...
}
```

### 11.2 锁冲突

**原因**：并发事务修改同一数据

**解决方案**：
- 使用乐观锁
- 调整事务隔离级别
- 优化业务流程

### 11.3 连接池耗尽

**原因**：事务未正确关闭，连接未释放

**解决方案**：
- 检查数据库连接池配置
- 确保事务正确提交或回滚
- 设置合理的超时时间

### 11.4 Nacos 注册失败

**原因**：
- Nacos 地址配置错误
- 命名空间配置错误
- 网络不通

**解决方案**：
```yaml
seata:
  registry:
    nacos:
      server-addr: 192.168.56.106:8848  # 使用虚拟机内部IP
      namespace: seate
      group: SEATA_GROUP
```

### 11.5 序列化异常

**原因**：实体类未实现 Serializable 接口

**解决方案**：
```java
public class Order implements Serializable {
    // ...
}
```

---

## 十二、最佳实践

### 12.1 事务边界

- 尽量缩小事务范围
- 避免在事务中调用外部系统（如远程 API）
- 异步操作应在事务外执行

### 12.2 异常处理

```java
@GlobalTransactional(rollbackFor = Exception.class)
public void businessMethod() {
    try {
        // 业务逻辑
    } catch (BusinessException e) {
        // 业务异常，回滚事务
        throw e;
    } catch (Exception e) {
        // 系统异常，记录日志并回滚
        log.error("系统异常", e);
        throw new RuntimeException("系统异常", e);
    }
}
```

### 12.3 幂等性设计

```java
public void createOrder(OrderRequest request) {
    // 检查是否已处理过
    if (orderMapper.existsByRequestId(request.getRequestId())) {
        return;
    }
    
    // 执行业务逻辑
    // ...
}
```

### 12.4 分布式锁

在高并发场景下使用分布式锁保护临界资源：

```java
public void decreaseStock(Long productId, Integer count) {
    String lockKey = "stock:" + productId;
    
    try (RLock lock = redissonClient.getLock(lockKey)) {
        if (lock.tryLock(30, TimeUnit.SECONDS)) {
            // 执行库存扣减
            storageMapper.decrease(productId, count);
        }
    }
}
```

---

## 十三、Seata 版本升级

### 13.1 注意事项

- 备份配置文件和数据库
- 逐步升级，先升级测试环境
- 注意 API 兼容性

### 13.2 升级步骤

1. 停止所有 Seata 服务
2. 备份数据库（主要是 undo_log、global_table、branch_table、lock_table）
3. 升级 Seata Server
4. 升级客户端依赖
5. 验证功能正常

---

## 附录

### A. 常用命令

```bash
# 查看 Seata Server 进程
ps aux | grep seata-server

# 查看日志
tail -f /var/log/seata-server.log

# 重启服务
pkill -f seata-server.jar
sleep 3
nohup java -jar /opt/seata-1.7.0/target/seata-server.jar -m db > /var/log/seata-server.log 2>&1 &
```

### B. 参考链接

- [Seata 官方文档](https://seata.io/docs/)
- [Seata GitHub](https://github.com/seata/seata)
- [Seata Spring Boot Starter](https://github.com/seata/seata/tree/develop/spring-boot-starter)