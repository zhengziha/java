# Canal 使用与搭建教程

## 一、Canal 是什么

Canal 是阿里巴巴开源的 MySQL Binlog 增量订阅与消费组件，本质上是模拟 MySQL Slave 协议去拉取主库的 Binlog，再把变更数据解析成结构化事件，供下游程序消费。

它常用于以下场景：

- 数据库与缓存双写后的异步修正
- MySQL 到 Elasticsearch 的数据同步
- MySQL 到 Kafka、RocketMQ 的变更投递
- 业务审计、数据订阅、异构系统同步
- 分库分表后的增量数据汇聚

---

## 二、Canal 核心原理

### 2.1 工作流程

```text
MySQL -> Binlog -> Canal Server -> Canal Client -> 业务系统
```

完整链路如下：

1. MySQL 开启 Binlog，并使用 `ROW` 模式记录数据变更。
2. Canal Server 伪装成 MySQL 从库连接主库。
3. Canal Server 持续拉取 Binlog 并解析为 `INSERT`、`UPDATE`、`DELETE` 等事件。
4. Canal Client 从 Canal Server 拉取解析后的数据。
5. 业务程序根据事件内容进行缓存刷新、索引同步、消息投递等处理。

### 2.2 关键角色

| 角色 | 说明 |
|------|------|
| MySQL | 产生 Binlog 的数据源 |
| Canal Server | 拉取并解析 Binlog |
| Destination | Canal 中的实例名，类似一个订阅通道 |
| Canal Client | 订阅 Destination 并消费变更 |
| Position | 消费位点，表示已消费到哪个 Binlog 文件和偏移量 |

### 2.3 为什么要求 Binlog 使用 ROW 模式

Canal 依赖行级变更数据来准确识别每一条记录的新增、修改和删除，因此一般要求：

- `binlog_format=ROW`
- `binlog_row_image=FULL`

如果使用 `STATEMENT` 或 `MIXED`，可能导致字段级变化不完整，影响下游同步准确性。

---

## 三、适用场景与优缺点

### 3.1 适用场景

- 需要监听数据库表变更
- 需要将 MySQL 数据同步到搜索引擎
- 需要异步驱动缓存更新
- 需要构建轻量级 CDC 链路
- 下游只关心增量变更，不需要定时全量扫描

### 3.2 优点

- 对业务代码侵入小
- 延迟低，通常为毫秒到秒级
- 可按库表精确订阅
- 支持直接消费或投递到 MQ
- 适合与 Java 生态集成

### 3.3 局限

- 主要面向 MySQL Binlog 场景
- 对数据库配置有前置要求
- 下游消费逻辑需要自己保证幂等
- 大事务、高峰写入时会放大下游消费压力

---

## 四、搭建前的环境准备

### 4.1 版本建议

为了减少兼容性问题，建议优先采用以下组合：

| 组件 | 推荐版本 |
|------|----------|
| MySQL | 5.7 / 8.0 |
| Canal | 1.1.7 或同系列稳定版本 |
| JDK | 1.8 或 11 |

### 4.2 机器与端口

默认情况下常见端口如下：

| 端口 | 用途 |
|------|------|
| `11111` | Canal Server 默认客户端连接端口 |
| `3306` | MySQL 服务端口 |

### 4.3 前置条件

在开始前，请确认：

- MySQL 已正常运行
- Canal 所在机器可以访问 MySQL
- 防火墙已放通对应端口
- MySQL 用户有读取 Binlog 和复制权限
- 数据库表必须存在主键或可唯一标识记录

---

## 五、MySQL 端配置

Canal 能否正常工作，最关键的是 MySQL 的 Binlog 配置。

### 5.1 查看当前配置

执行以下 SQL：

```sql
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'binlog_row_image';
SHOW MASTER STATUS;
```

预期结果：

- `log_bin=ON`
- `binlog_format=ROW`
- `binlog_row_image=FULL`

### 5.2 修改 MySQL 配置文件

Linux 常见配置文件为 `/etc/my.cnf` 或 `/etc/mysql/my.cnf`，参考配置如下：

```ini
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
binlog_row_image=FULL
expire_logs_days=7
max_binlog_size=512M
```

参数说明：

- `server-id`：MySQL 实例唯一标识，Canal 以“伪从库”方式连接时会用到复制能力
- `log_bin`：开启 Binlog
- `binlog_format=ROW`：使用行模式
- `binlog_row_image=FULL`：更新前后镜像更完整，便于解析

修改后重启 MySQL：

```bash
systemctl restart mysqld
```

### 5.3 创建 Canal 专用账号

建议单独为 Canal 创建账号，不要直接使用业务超级管理员账号。

```sql
CREATE USER 'canal'@'%' IDENTIFIED BY 'canal123456';

GRANT SELECT, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'canal'@'%';

FLUSH PRIVILEGES;
```

如果你的 MySQL 版本较高，也可以根据实际情况补充：

```sql
SHOW GRANTS FOR 'canal'@'%';
```

### 5.4 验证 Binlog 是否正常产生

创建测试表并执行操作：

```sql
CREATE DATABASE IF NOT EXISTS canal_demo;
USE canal_demo;

CREATE TABLE IF NOT EXISTS user_info (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_name VARCHAR(64) NOT NULL,
    age INT DEFAULT 0,
    status TINYINT DEFAULT 1,
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO user_info(user_name, age, status) VALUES ('alice', 18, 1);
UPDATE user_info SET age = 20 WHERE id = 1;
DELETE FROM user_info WHERE id = 1;
```

如果 MySQL 已开启 Binlog，这些操作会写入 Binlog 文件。

---

## 六、Canal Server 搭建教程

### 6.1 下载并解压

将 Canal 安装包上传到服务器后解压：

```bash
mkdir -p /opt/canal
tar -zxvf canal.deployer-1.1.7.tar.gz -C /opt/canal
```

解压后常见目录结构如下：

```text
/opt/canal
├── bin
├── conf
│   ├── canal.properties
│   └── example
│       └── instance.properties
├── lib
└── logs
```

### 6.2 配置服务端总配置

编辑 `conf/canal.properties`：

```properties
canal.port = 11111
canal.ip =
canal.metrics.pull.port = 11112
canal.destinations = example
canal.instance.tsdb.enable = true
canal.auto.scan = true
```

说明：

- `canal.port`：客户端连接端口
- `canal.destinations`：实例名列表，多个实例可用逗号分隔
- `canal.auto.scan=true`：自动扫描实例目录

### 6.3 配置具体实例

编辑 `conf/example/instance.properties`：

```properties
# 需要连接的 MySQL 地址
canal.instance.mysql.slaveId=1234
canal.instance.master.address=127.0.0.1:3306
canal.instance.dbUsername=canal
canal.instance.dbPassword=canal123456

# 指定默认库名，可不配
canal.instance.defaultDatabaseName=canal_demo

# 订阅规则，格式：库名.表名
canal.instance.filter.regex=canal_demo\\..*

# 排除系统库
canal.instance.filter.black.regex=mysql\\..*,sys\\..*,information_schema\\..*,performance_schema\\..*

# Binlog 位点策略
canal.instance.connectionCharset=UTF-8
canal.instance.detectingEnable=true
canal.instance.detectingSQL=SELECT 1

# 开启 GTID 时可结合实际配置
canal.instance.gtidon=false
```

重点说明：

- `slaveId`：Canal 模拟从库时使用，必须避免与真实从库重复
- `master.address`：MySQL 主库地址
- `filter.regex`：只订阅你关心的库表，避免无意义流量

### 6.4 启动 Canal

```bash
cd /opt/canal
sh bin/startup.sh
```

停止命令：

```bash
sh bin/stop.sh
```

重启命令：

```bash
sh bin/restart.sh
```

### 6.5 查看日志

Canal 是否启动成功，优先看日志：

```bash
tail -f /opt/canal/logs/canal/canal.log
tail -f /opt/canal/logs/example/example.log
```

常见成功标志：

- 成功连接 MySQL
- 成功订阅到 `example`
- 成功定位到某个 Binlog 文件和 offset

---

## 七、Docker 搭建方式

如果你只是本地学习或测试，Docker 部署更快。

### 7.1 拉取镜像

```bash
docker pull canal/canal-server:v1.1.7
```

### 7.2 创建挂载目录

```bash
mkdir -p /opt/canal-docker/conf/example
mkdir -p /opt/canal-docker/logs
```

将 `canal.properties` 和 `instance.properties` 放到挂载目录中。

### 7.3 启动容器

```bash
docker run -d \
  --name canal-server \
  -p 11111:11111 \
  -v /opt/canal-docker/conf:/home/admin/canal-server/conf \
  -v /opt/canal-docker/logs:/home/admin/canal-server/logs \
  canal/canal-server:v1.1.7
```

查看日志：

```bash
docker logs -f canal-server
```

---

## 八、Canal 使用教程

Canal 的使用分为两部分：

1. 服务端正确订阅 MySQL Binlog
2. 客户端消费解析后的变更数据

下面重点讲 Java 客户端如何接入。

### 8.1 引入 Maven 依赖

```xml
<dependency>
    <groupId>com.alibaba.otter</groupId>
    <artifactId>canal.client</artifactId>
    <version>1.1.7</version>
</dependency>
```

如果你使用的是 Spring Boot 项目，一般也只需要这个依赖即可。

### 8.2 Java 客户端基础示例

下面是一个最常见的直连 Canal Server 的示例：

```java
import com.alibaba.otter.canal.client.CanalConnector;
import com.alibaba.otter.canal.client.CanalConnectors;
import com.alibaba.otter.canal.protocol.CanalEntry;
import com.alibaba.otter.canal.protocol.Message;

import java.net.InetSocketAddress;
import java.util.List;

/**
 * Canal 客户端示例。
 * 作用：连接 Canal Server，订阅库表变更，并把增量事件输出到控制台。
 */
public class CanalClientDemo {

    public static void main(String[] args) {
        // 创建单机连接，参数分别是服务地址、端口、destination、用户名、密码。
        CanalConnector connector = CanalConnectors.newSingleConnector(
                new InetSocketAddress("127.0.0.1", 11111),
                "example",
                "",
                ""
        );

        int batchSize = 100;

        try {
            connector.connect();

            // 订阅指定库表，若为 .*\\..* 表示订阅所有库表。
            connector.subscribe("canal_demo\\\\.user_info");

            // 回滚到未确认的位置，避免首次连接时位点不一致。
            connector.rollback();

            while (true) {
                // 批量拉取数据，不自动确认。
                Message message = connector.getWithoutAck(batchSize);
                long batchId = message.getId();
                int size = message.getEntries().size();

                if (batchId == -1 || size == 0) {
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        break;
                    }
                    continue;
                }

                try {
                    printEntry(message.getEntries());

                    // 业务处理成功后确认，Canal 才会推进消费位点。
                    connector.ack(batchId);
                } catch (Exception e) {
                    // 业务处理失败时回滚本批次，便于稍后重新消费。
                    connector.rollback(batchId);
                    e.printStackTrace();
                }
            }
        } finally {
            connector.disconnect();
        }
    }

    /**
     * 解析并输出 Canal 事件。
     */
    private static void printEntry(List<CanalEntry.Entry> entries) throws Exception {
        for (CanalEntry.Entry entry : entries) {
            // 事务开始与结束事件通常不参与业务处理。
            if (entry.getEntryType() == CanalEntry.EntryType.TRANSACTIONBEGIN
                    || entry.getEntryType() == CanalEntry.EntryType.TRANSACTIONEND) {
                continue;
            }

            CanalEntry.RowChange rowChange = CanalEntry.RowChange.parseFrom(entry.getStoreValue());
            CanalEntry.EventType eventType = rowChange.getEventType();

            System.out.println("==========");
            System.out.println("schema: " + entry.getHeader().getSchemaName());
            System.out.println("table : " + entry.getHeader().getTableName());
            System.out.println("event : " + eventType);

            for (CanalEntry.RowData rowData : rowChange.getRowDatasList()) {
                if (eventType == CanalEntry.EventType.DELETE) {
                    printColumns("before", rowData.getBeforeColumnsList());
                } else if (eventType == CanalEntry.EventType.INSERT) {
                    printColumns("after", rowData.getAfterColumnsList());
                } else {
                    printColumns("before", rowData.getBeforeColumnsList());
                    printColumns("after", rowData.getAfterColumnsList());
                }
            }
        }
    }

    /**
     * 输出字段列表，并标记是否为主键、是否被更新。
     */
    private static void printColumns(String type, List<CanalEntry.Column> columns) {
        System.out.println(type + " columns:");
        for (CanalEntry.Column column : columns) {
            System.out.println(
                    column.getName() + "=" + column.getValue()
                            + ", updated=" + column.getUpdated()
                            + ", isKey=" + column.getIsKey()
            );
        }
    }
}
```

### 8.3 消费结果说明

当你对 `user_info` 表执行增删改后，客户端通常能拿到以下信息：

- 库名
- 表名
- 事件类型：`INSERT`、`UPDATE`、`DELETE`
- 变更前字段值
- 变更后字段值
- 哪些字段发生了更新
- 主键信息

### 8.4 ACK 与回滚机制

这部分非常重要：

- `getWithoutAck()`：拉取数据但不确认
- `ack(batchId)`：处理成功后确认消费
- `rollback(batchId)`：处理失败时回滚批次

建议生产环境始终遵循如下原则：

1. 先执行业务逻辑
2. 业务逻辑成功后再 `ack`
3. 业务逻辑失败则 `rollback`
4. 下游逻辑必须保证幂等

否则会出现重复消费或数据丢失风险。

---

## 九、Spring Boot 中的典型用法

很多项目会把 Canal 客户端做成一个后台线程，在服务启动后持续消费。

### 9.1 简单配置示例

`application.yml`：

```yaml
canal:
  host: 127.0.0.1
  port: 11111
  destination: example
  filter: canal_demo\\.user_info
```

### 9.2 配置类

```java
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * Canal 连接配置。
 */
@Component
@ConfigurationProperties(prefix = "canal")
public class CanalProperties {

    /**
     * Canal Server 地址。
     */
    private String host;

    /**
     * Canal Server 端口。
     */
    private Integer port;

    /**
     * 实例名，对应 canal.destinations 中的某个 destination。
     */
    private String destination;

    /**
     * 订阅规则，格式通常为 库名\\.表名。
     */
    private String filter;

    public String getHost() {
        return host;
    }

    public void setHost(String host) {
        this.host = host;
    }

    public Integer getPort() {
        return port;
    }

    public void setPort(Integer port) {
        this.port = port;
    }

    public String getDestination() {
        return destination;
    }

    public void setDestination(String destination) {
        this.destination = destination;
    }

    public String getFilter() {
        return filter;
    }

    public void setFilter(String filter) {
        this.filter = filter;
    }
}
```

### 9.3 监听服务

```java
import com.alibaba.otter.canal.client.CanalConnector;
import com.alibaba.otter.canal.client.CanalConnectors;
import com.alibaba.otter.canal.protocol.CanalEntry;
import com.alibaba.otter.canal.protocol.Message;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;

import java.net.InetSocketAddress;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Canal 消费服务。
 * 作用：项目启动后异步拉取 Binlog 变更，并在本地执行业务处理。
 */
@Service
public class CanalConsumeService {

    private final CanalProperties canalProperties;

    /**
     * 单线程消费更容易保证顺序性，适合大多数表同步场景。
     */
    private final ExecutorService executorService = Executors.newSingleThreadExecutor();

    private volatile boolean running = true;

    private CanalConnector connector;

    public CanalConsumeService(CanalProperties canalProperties) {
        this.canalProperties = canalProperties;
    }

    /**
     * Spring 容器启动完成后初始化 Canal 连接并开始消费。
     */
    @PostConstruct
    public void start() {
        connector = CanalConnectors.newSingleConnector(
                new InetSocketAddress(canalProperties.getHost(), canalProperties.getPort()),
                canalProperties.getDestination(),
                "",
                ""
        );

        executorService.submit(this::consume);
    }

    /**
     * 后台持续拉取 Canal 数据。
     */
    private void consume() {
        connector.connect();
        connector.subscribe(canalProperties.getFilter());
        connector.rollback();

        while (running) {
            Message message = connector.getWithoutAck(100);
            long batchId = message.getId();

            if (batchId == -1 || message.getEntries().isEmpty()) {
                sleepQuietly(1000);
                continue;
            }

            try {
                handleEntries(message.getEntries());
                connector.ack(batchId);
            } catch (Exception e) {
                connector.rollback(batchId);
            }
        }
    }

    /**
     * 在这里编写你的业务处理逻辑，例如刷新缓存、同步 ES、投递 MQ。
     */
    private void handleEntries(List<CanalEntry.Entry> entries) throws Exception {
        for (CanalEntry.Entry entry : entries) {
            if (entry.getEntryType() != CanalEntry.EntryType.ROWDATA) {
                continue;
            }

            CanalEntry.RowChange rowChange = CanalEntry.RowChange.parseFrom(entry.getStoreValue());
            String tableName = entry.getHeader().getTableName();
            CanalEntry.EventType eventType = rowChange.getEventType();

            System.out.println("监听到表变更: table=" + tableName + ", eventType=" + eventType);
        }
    }

    /**
     * 容器销毁前安全关闭连接和线程池。
     */
    @PreDestroy
    public void destroy() {
        running = false;

        if (connector != null) {
            connector.disconnect();
        }

        executorService.shutdownNow();
    }

    /**
     * 安静休眠，避免空轮询占满 CPU。
     */
    private void sleepQuietly(long millis) {
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
```

### 9.4 业务落地建议

Canal 在 Spring Boot 里最常见的几类处理方式：

- 更新 Redis 缓存
- 同步 Elasticsearch 索引
- 构建操作审计日志
- 将 Binlog 事件再次投递到 Kafka/RabbitMQ
- 驱动本地搜索、推荐、统计任务更新

---

## 十、Canal 消息结构解读

一条典型变更事件通常会包含：

| 字段 | 说明 |
|------|------|
| schemaName | 库名 |
| tableName | 表名 |
| eventType | 事件类型 |
| beforeColumnsList | 变更前字段 |
| afterColumnsList | 变更后字段 |
| executeTime | 事件执行时间 |
| logfileName | Binlog 文件名 |
| logfileOffset | Binlog 偏移量 |

`UPDATE` 场景最常用，因为它同时包含：

- 修改前值
- 修改后值
- 某个字段是否发生变化

这很适合做精准缓存删除和索引局部更新。

---

## 十一、常见使用场景示例

### 11.1 同步 Redis 缓存

推荐做法：

1. 监听商品表、用户表、库存表
2. 捕获变更事件
3. 根据主键删除对应缓存
4. 由后续读请求触发缓存重建

这样通常比“直接更新缓存”更稳妥。

### 11.2 同步 Elasticsearch

推荐流程：

1. 监听业务表变更
2. 将变更对象转为 ES 文档
3. 新增时写入索引
4. 修改时局部更新
5. 删除时删除文档

### 11.3 构建审计日志

适合记录：

- 谁修改了哪张表
- 修改前是什么
- 修改后是什么
- 修改时间和主键

如果业务还需要操作人，可以结合业务表字段或应用侧上下文补充。

---

## 十二、生产环境最佳实践

### 12.1 精确订阅库表

不要直接订阅全部库表，建议只订阅业务必需的表：

```properties
canal.instance.filter.regex=mall\\.(product|sku_info|stock) 
```

这样可以降低：

- 无效 Binlog 解析成本
- 网络传输成本
- 客户端处理压力

### 12.2 下游逻辑必须幂等

Canal 客户端可能因为网络抖动、重试、回滚等原因出现重复消费，因此业务侧必须幂等。

常见做法：

- 以主键 + 更新时间做覆盖更新
- 以业务唯一键去重
- 记录消费日志表
- 使用版本号控制更新

### 12.3 不要在消费线程里写重逻辑

不建议在单个消费线程中直接执行：

- 大批量远程调用
- 复杂聚合计算
- 慢 SQL
- 大量同步 IO

推荐做法：

1. Canal 负责捕获变更
2. 先快速转为内部消息
3. 再异步投递给 MQ 或线程池处理

### 12.4 关注大事务与批量更新

如果上游存在：

- 一次更新几十万行
- 长事务
- 批量导入

那么 Canal 与下游都会承受较大压力。需要提前评估：

- 拉取延迟
- 消费堆积
- 内存占用
- 下游限流能力

### 12.5 建议保留全量同步能力

Canal 更擅长增量同步，但生产环境中通常还需要：

- 初始化全量导入
- 异常后的全量修复
- 指定表重建索引

所以完整方案通常是：

```text
全量初始化 + Canal 增量订阅
```

---

## 十三、常见问题与排查

### 13.1 Canal 启动后无法连接 MySQL

排查方向：

- MySQL 地址或端口不通
- 用户名密码错误
- 复制权限不足
- 防火墙未放通

建议先手动测试连接：

```bash
mysql -h127.0.0.1 -P3306 -ucanal -p
```

### 13.2 Canal 没有收到数据

优先检查：

1. MySQL 是否真的开启 Binlog
2. `binlog_format` 是否为 `ROW`
3. 订阅规则是否写错
4. 当前操作的表是否在订阅范围内
5. 是否连接到了错误的数据库实例

### 13.3 更新事件字段不完整

通常是因为：

- `binlog_row_image` 不是 `FULL`
- 客户端解析逻辑只读取了部分列

建议检查：

```sql
SHOW VARIABLES LIKE 'binlog_row_image';
```

### 13.4 客户端反复重复消费

大概率原因：

- 业务处理成功后没有 `ack`
- 处理异常后总是回滚
- 程序频繁重启，位点没有正常推进

处理思路：

- 确保成功才 `ack`
- 失败必须记录错误日志
- 消费逻辑设计为幂等

### 13.5 MySQL 8 权限问题

如果连接认证失败，要注意：

- 账号认证插件
- 授权主机范围
- 密码加密方式

必要时检查：

```sql
SELECT user, host, plugin FROM mysql.user WHERE user = 'canal';
```

---

## 十四、常用命令

### 14.1 MySQL 相关

```sql
SHOW MASTER STATUS;
SHOW BINARY LOGS;
SHOW VARIABLES LIKE 'log_bin';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'binlog_row_image';
```

### 14.2 Canal 相关

```bash
# 启动
sh /opt/canal/bin/startup.sh

# 停止
sh /opt/canal/bin/stop.sh

# 重启
sh /opt/canal/bin/restart.sh

# 查看主日志
tail -f /opt/canal/logs/canal/canal.log

# 查看实例日志
tail -f /opt/canal/logs/example/example.log
```

### 14.3 Docker 相关

```bash
docker ps
docker logs -f canal-server
docker restart canal-server
docker stop canal-server
```

---

## 十五、推荐落地方案

如果你是在 Java 项目中使用 Canal，推荐按下面方式落地：

### 方案一：Canal + Java Client + Redis

适合：

- 监听数据变更后删除缓存
- 实现数据库和缓存最终一致

### 方案二：Canal + Java Client + Elasticsearch

适合：

- 商品搜索
- 用户搜索
- 内容检索

### 方案三：Canal + MQ + 多下游系统

适合：

- 一个变更事件需要驱动多个系统
- 希望业务处理彻底解耦
- 需要更强的削峰填谷能力

此时建议：

```text
MySQL -> Canal -> MQ -> 多个消费者
```

---

## 十六、学习与实战顺序建议

建议你按照下面顺序学习和搭建：

1. 先理解 MySQL Binlog 和主从复制基础
2. 本地单机搭建 MySQL + Canal Server
3. 用 Java 客户端打印增删改事件
4. 再做 Redis 或 ES 同步
5. 最后再引入 MQ、集群、高可用等增强方案

这样更容易定位问题，也更适合逐步演进到生产方案。

---

## 十七、总结

Canal 的本质可以概括为一句话：

```text
监听 MySQL Binlog，并把数据库增量变更实时交给下游系统处理
```

真正落地时，最重要的不是“能否接收到数据”，而是以下几点：

- MySQL Binlog 配置是否正确
- 订阅范围是否足够精确
- 客户端 ACK 机制是否安全
- 下游逻辑是否幂等
- 是否具备全量修复和故障重放能力

只要这几个核心点处理好，Canal 就非常适合作为 Java 生态中的轻量级增量同步方案。

---

## 参考资料

- Canal GitHub: https://github.com/alibaba/canal
- Canal Wiki: https://github.com/alibaba/canal/wiki
- MySQL Binlog 官方文档: https://dev.mysql.com/doc/
