# ShardingSphere / Sharding-JDBC 详解

> 独立专题笔记，汇总入口见 [java学习笔记汇总](java学习笔记汇总.md)  
> 关联阅读：[分布式事务 2PC / 3PC 详解](分布式事务-2PC与3PC详解.md)（分库分表后的跨库事务）

---

## 一、背景：为什么需要分库分表？

单库单表在数据量、并发写、存储容量上涨后会遇到瓶颈：

| 瓶颈 | 表现 |
|------|------|
| 存储 | 单表亿级行，索引树变深，维护成本高 |
| 性能 | 热点行锁竞争、Buffer Pool 装不下热数据 |
| 连接 | 单库连接数有上限，应用实例多时成为瓶颈 |
| 可用性 | 单点故障影响全业务 |

### 两种拆分方式

```
垂直拆分                          水平拆分（分库分表）
─────────                          ─────────────────
按业务拆库/拆表                    同一张表按规则拆到多库多表
user_db / order_db                 t_order_0 ~ t_order_15
大字段拆到扩展表                   每片数据量可控，写可扩展
```

| 方式 | 目标 | 典型场景 |
|------|------|----------|
| **垂直拆分** | 业务解耦、冷热分离 | 用户库、订单库、商品库 |
| **水平拆分** | 分摊数据与写压力 | 订单表按 `user_id` 分 16 张 |

**面试一句话**：先垂直拆业务，单表仍扛不住再水平分片；**不要过早分库分表**（先优化 SQL、索引、缓存、读写分离）。

---

## 二、ShardingSphere 是什么？

**Apache ShardingSphere** 是一套开源的**分布式数据库生态**，在应用与数据库之间提供增强能力，核心包括：

| 能力 | 说明 |
|------|------|
| **数据分片** | 分库分表、分布式主键 |
| **读写分离** | 写主读从、负载均衡 |
| **数据加密** | 列级加解密，对应用透明 |
| **影子库** | 压测流量路由到影子库 |
| **联邦查询** | 跨库聚合（高版本） |

### 产品形态

```
                    ┌─────────────────────────┐
                    │   Apache ShardingSphere  │
                    └───────────┬─────────────┘
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
   ShardingSphere-JDBC   ShardingSphere-Proxy   (Sidecar 已弱化)
   （客户端 JDBC 增强）    （独立代理进程，类 MySQL 协议）
```

| 产品 | 接入方式 | 特点 |
|------|----------|------|
| **ShardingSphere-JDBC** | Jar 嵌入应用，替换 DataSource | 无额外部署、性能高、与 Spring/MyBatis 无缝；**原 Sharding-JDBC 演进而来** |
| **ShardingSphere-Proxy** | 应用连 Proxy（如 3307），Proxy 再连 DB | 对应用零改造（任意语言）；多一层网络 hop，需独立运维 |

### 名称演进（面试常问）

```
Sharding-JDBC（当当开源）
        │
        ▼
Apache ShardingSphere（捐赠并入 Apache）
        │
        ├─ ShardingSphere-JDBC  ← 原 Sharding-JDBC
        └─ ShardingSphere-Proxy
```

---

## 三、核心概念

### 1. 逻辑表 vs 真实表

```
逻辑表 t_order（应用 SQL 中写的表名）
        │
        ├─ ds0.t_order_0
        ├─ ds0.t_order_1
        ├─ ds1.t_order_0
        └─ ds1.t_order_1
```

应用只写 `SELECT * FROM t_order WHERE user_id = 100`，框架负责路由到具体分片。

### 2. 数据节点（Data Node）

数据节点的表达式：`数据源名.表名`，如 `ds_${0..1}.t_order_${0..3}` 表示 2 库 × 4 表 = 8 个分片。

### 3. 分片键（Sharding Key）

决定数据落在哪个分片的列，例如 `user_id`、`order_id`。

**选型原则**：
- 查询条件**高频携带**分片键（避免全库扫描）
- 数据分布**尽量均匀**（避免热点分片）
- 业务上**不易变更**

### 4. 分片算法 + 分片策略

| 概念 | 含义 |
|------|------|
| **分片策略** | 用哪些列做路由（标准 / 复合 / Hint） |
| **分片算法** | 具体怎么算分片下标（取模、范围、自定义类） |

---

## 四、分片策略

| 策略 | 类名 | 适用 |
|------|------|------|
| **标准分片** | `StandardShardingStrategy` | 单列分片键 |
| **复合分片** | `ComplexShardingStrategy` | 多列组合（如 `user_id` + `order_time`） |
| **Hint 分片** | `HintShardingStrategy` | 无分片键时由代码强制指定路由（运维、补数） |
| **不分片** | `NoneShardingStrategy` | 广播表 / 单表 |

### Inline 行表达式（配置常用）

```yaml
# 分库：user_id % 2 → ds0 / ds1
database-strategy:
  standard:
    sharding-column: user_id
    sharding-algorithm-name: db-inline

sharding-algorithms:
  db-inline:
    type: INLINE
    props:
      algorithm-expression: ds_${user_id % 2}
```

```yaml
# 分表：user_id % 4 → t_order_0 ~ t_order_3
table-strategy:
  standard:
    sharding-column: user_id
    sharding-algorithm-name: table-inline

sharding-algorithms:
  table-inline:
    type: INLINE
    props:
      algorithm-expression: t_order_${user_id % 4}
```

---

## 五、内置分片算法

| 算法 | 说明 | 场景 |
|------|------|------|
| `MOD` / `HASH_MOD` | 取模 / 哈希取模 | 最常用，数据均匀 |
| `VOLUME_RANGE` / `BOUNDARY_RANGE` | 范围分片 | 按 ID 段、时间归档 |
| `AUTO_INTERVAL` | 按时间间隔自动分表 | 日志、流水按月/日 |
| `CLASS_BASED` | 自定义 Java 类 | 复杂业务规则 |

### 取模分片示意（2 库 4 表）

```
user_id = 1005
  分库：1005 % 2 = 1  → ds1
  分表：1005 % 4 = 1  → t_order_1
  最终：ds1.t_order_1
```

---

## 六、绑定表与广播表

### 1. 绑定表（Binding Table）

**主从关联表使用相同分片键、相同分片算法**，可避免跨分片笛卡尔积。

```
t_order   按 user_id 分片
t_order_item  按 user_id 分片（相同算法）
→ 同一 user_id 的订单与明细落在同一库表，JOIN 在单分片内完成
```

```
❌ 未绑定：t_order JOIN t_order_item
   每个 order 分片 × 每个 item 分片 → 笛卡尔积，路由到 N×M 个节点

✅ 绑定后：相同 sharding key 对齐到同一分片，单节点 JOIN
```

### 2. 广播表（Broadcast Table）

数据量小、变更少的字典表（省市区、类目），**在每个分片库都存一份完整副本**。

```yaml
broadcast-tables:
  - t_region
  - t_category
```

任意分片上的 SQL 都可本地 JOIN 广播表，无需跨库。

---

## 七、SQL 执行流程（核心原理）

ShardingSphere-JDBC 作为 **JDBC 增强层**，拦截 SQL 后经历五步法：

```mermaid
flowchart LR
    A[应用 SQL] --> B[解析 Parse]
    B --> C[路由 Route]
    C --> D[改写 Rewrite]
    D --> E[执行 Execute]
    E --> F[归并 Merge]
    F --> G[返回结果]
```

| 阶段 | 做什么 |
|------|--------|
| **Parse** | 解析 SQL 为抽象语法树，识别逻辑表、条件、聚合 |
| **Route** | 根据分片键计算目标 DataSource + 真实表 |
| **Rewrite** | 逻辑表名改真实表名；分页改写（跨片 LIMIT） |
| **Execute** | 向各分片并行发 SQL |
| **Merge** | 归并结果：排序、分组、聚合、分页裁剪 |

### 路由类型

| 类型 | 条件 | 性能 |
|------|------|------|
| **标准路由** | WHERE 含分片键 | ⭐⭐⭐ 单片或少量分片 |
| **全库路由** | 无分片键、广播表 | ⭐ 扫所有分片 |
| **笛卡尔路由** | 多表关联未绑定 | ⭐ 最差，尽量避免 |

---

## 八、读写分离

可与分片叠加使用：

```yaml
dataSources:
  ds_0:
    dataSourceClassName: com.zaxxer.hikari.HikariDataSource
    props:
      jdbcUrl: jdbc:mysql://master:3306/db_0
  ds_0_slave_0:
    props:
      jdbcUrl: jdbc:mysql://slave:3306/db_0

rules:
  - !READWRITE_SPLITTING
    dataSourceGroups:
      ds_0:
        writeDataSourceName: ds_0
        readDataSourceNames: [ds_0_slave_0]
        loadBalancerName: round_robin
```

```
写请求 ──→ Master
读请求 ──→ Slave（轮询 / 随机 / 权重）
```

**注意**：主从延迟导致读不到刚写入的数据 → 强一致读走主库或 Hint 强制主库。

---

## 九、分布式主键

分库分表后，数据库自增 ID **无法保证全局唯一**，常用：

| 方案 | 说明 |
|------|------|
| **Snowflake（雪花）** | ShardingSphere 内置 `SNOWFLAKE`，64 位趋势递增 |
| **UUID** | 全局唯一但无序，索引性能差 |
| **号段模式** | 从 ID 服务批量取号（Leaf、美团等） |
| **Redis INCR** | 简单，需高可用 Redis |

```yaml
keyGenerators:
  snowflake:
    type: SNOWFLAKE
    props:
      worker-id: 1   # 多实例部署时 worker-id 不能冲突
```

雪花结构（了解）：`1bit 符号 + 41bit 时间戳 + 10bit 机器 + 12bit 序列号`。

---

## 十、分布式事务

单分片 SQL 走**本地事务**即可；跨分片写需要分布式事务。

| 类型 | 实现 | 特点 |
|------|------|------|
| **LOCAL**（默认） | 各分片独立提交 | 性能最好；跨片**不保证**原子性 |
| **XA** | 2PC，JTA | 强一致；性能差、锁持有长 |
| **BASE** | Seata AT 等 | 最终一致；生产较常用 |

```yaml
rules:
  - !TRANSACTION
    defaultType: XA          # 或 BASE
    providerType: Atomikos  # XA 事务管理器
```

**工程建议**：
- 架构上**尽量避免跨分片事务**（按分片键设计业务流程）
- 实在不行用 **Seata AT / TCC / 消息最终一致**
- 详见 [分布式事务 2PC / 3PC 详解](分布式事务-2PC与3PC详解.md)

---

## 十一、Spring Boot 配置示例

```yaml
spring:
  shardingsphere:
    datasource:
      names: ds0,ds1
      ds0:
        type: com.zaxxer.hikari.HikariDataSource
        driver-class-name: com.mysql.cj.jdbc.Driver
        jdbc-url: jdbc:mysql://127.0.0.1:3306/db0
        username: root
        password: root
      ds1:
        type: com.zaxxer.hikari.HikariDataSource
        jdbc-url: jdbc:mysql://127.0.0.1:3306/db1
        username: root
        password: root
    rules:
      sharding:
        tables:
          t_order:
            actual-data-nodes: ds$->{0..1}.t_order_$->{0..3}
            table-strategy:
              standard:
                sharding-column: user_id
                sharding-algorithm-name: t-order-mod
            database-strategy:
              standard:
                sharding-column: user_id
                sharding-algorithm-name: db-mod
            key-generate-strategy:
              column: order_id
              key-generator-name: snowflake
        sharding-algorithms:
          db-mod:
            type: MOD
            props:
              sharding-count: 2
          t-order-mod:
            type: MOD
            props:
              sharding-count: 4
        key-generators:
          snowflake:
            type: SNOWFLAKE
    props:
      sql-show: true   # 打印路由后的真实 SQL，排查必备
```

### Java 接入（概念）

```java
// ShardingSphere-JDBC 包装后仍是 DataSource
// Spring Boot 自动配置后，MyBatis/JPA 无感知使用
@Autowired
private OrderMapper orderMapper;

public void createOrder(Order order) {
    // SQL 中的 t_order 由 ShardingSphere 路由
    orderMapper.insert(order);
}
```

---

## 十二、常见限制与踩坑

| 问题 | 原因 | 应对 |
|------|------|------|
| 跨分片 JOIN 性能差 | 多片查询 + 内存归并 | 绑定表、冗余字段、应用层组装 |
| 不带分片键查询慢 | 全库路由 | 查询必须带分片键；二级索引表 |
| 全局排序 / 分页复杂 | 各片 LIMIT 后再归并 | 禁止深分页；用游标 / 搜索中间件 |
| `COUNT(*)` / `SUM` 跨片 | 多分片聚合 | 框架支持归并，但成本高 |
| 分布式主键冲突 | worker-id 重复 | 部署时分配唯一 worker-id |
| 主从延迟读不到新数据 | 异步复制 | 写后读走主库 |
| 扩容迁移痛苦 | 取模算法与分片数绑定 | 预留分片、一致性哈希、双写迁移方案 |
| 跨片事务性能差 | 2PC 锁 | 业务按分片键聚合，减少跨片写 |

### 扩容示例（取模从 4 表扩到 8 表）

```
旧：user_id % 4 → 大量数据需重分布
常见方案：双写 + 存量迁移 + 灰度切读 + 停双写
```

---

## 十三、JDBC vs Proxy vs MyCat

| 维度 | ShardingSphere-JDBC | ShardingSphere-Proxy | MyCat |
|------|---------------------|----------------------|-------|
| 部署 | 嵌入应用 Jar | 独立进程 | 独立中间件 |
| 语言 | Java 为主 | 任意（MySQL 协议） | 任意 |
| 性能 | 高（少一跳） | 中 | 中 |
| 改造量 | 依赖 + 配置 | 改连接地址 | 改连接地址 |
| 生态 | Apache 活跃 | 同项目 | 社区版 |

---

## 十四、何时引入 ShardingSphere？

```
数据量 / QPS 评估
    │
    ├─ 单库 + 索引 + 缓存可扛？ → 暂不拆分
    │
    ├─ 读多写少？ → 读写分离（可先不用分片）
    │
    ├─ 单表千万级 / 写入瓶颈？ → 水平分库分表
    │       │
    │       └─ Java 技术栈 → ShardingSphere-JDBC（首选）
    │           多语言 / 零侵入 → ShardingSphere-Proxy
    │
    └─ 跨分片事务不可避免？ → Seata + 业务补偿，慎用 XA
```

---

## 十五、面试高频 Q&A

| 问题 | 答案要点 |
|------|----------|
| Sharding-JDBC 和 ShardingSphere 什么关系？ | Sharding-JDBC 是前身；现并入 Apache ShardingSphere，对应产品 **ShardingSphere-JDBC** |
| JDBC 和 Proxy 怎么选？ | Java 应用、追求性能 → JDBC；多语言 / 不改代码 → Proxy |
| 分片键怎么选？ | 高频出现在 WHERE、分布均匀、不易变更 |
| 绑定表解决什么问题？ | 关联表同分片规则，避免 JOIN 笛卡尔积 |
| 广播表是什么？ | 小字典表全分片复制，本地 JOIN |
| SQL 执行流程？ | 解析 → 路由 → 改写 → 执行 → 归并 |
| 分布式 ID 怎么做？ | 雪花、号段、Redis；不用数据库自增 |
| 跨分片事务怎么办？ | 尽量避免；必要时 XA / Seata / 消息最终一致 |
| 不带分片键查询会怎样？ | **全库路由**，所有分片都查，性能差 |
| 如何排查路由是否正确？ | 开启 `sql-show: true` 看真实 SQL |
| 分库分表后还能用本地事务吗？ | 单分片操作可以；跨分片需分布式事务 |

---

## 十六、复习串联

```
为什么拆
  单库瓶颈：存储 / 写 / 连接 / 单点
  垂直拆业务 → 水平拆数据

ShardingSphere 产品
  ShardingSphere-JDBC（嵌入，原 Sharding-JDBC）
  ShardingSphere-Proxy（代理，MySQL 协议）

核心概念
  逻辑表 → 真实表（ds.t_order_n）
  分片键 + 分片策略 + 分片算法

关键配置
  actual-data-nodes
  binding-tables / broadcast-tables
  读写分离 + 雪花主键

执行链路
  Parse → Route → Rewrite → Execute → Merge

踩坑
  无分片键 = 全库扫
  跨片 JOIN / 深分页 / 跨片事务
  扩容迁移要提前规划

选型
  Java → JDBC
  多语言 → Proxy
  少跨片事务，多绑定表
```

---

> **关联阅读**  
> - [java学习笔记汇总](java学习笔记汇总.md) — 高并发架构、MySQL 主从  
> - [分布式事务 2PC / 3PC 详解](分布式事务-2PC与3PC详解.md) — XA 与跨库事务原理
