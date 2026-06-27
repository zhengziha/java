# Seata 集群部署教程

## 一、环境说明

### 1.1 服务器信息

| 节点 | 宿主机端口映射 | 虚拟机IP | Seata端口 |
|------|---------------|----------|-----------|
| Node1 | 192.168.31.100:226 | 192.168.56.106 | 7091(HTTP) / 8091(TCP) |
| Node2 | 192.168.31.100:227 | 192.168.56.107 | 7092(HTTP) / 8092(TCP) |
| Node3 | 192.168.31.100:228 | 192.168.56.108 | 7093(HTTP) / 8093(TCP) |

### 1.2 前置条件

- JDK 1.8 已安装（路径：`/usr/local/jdk1.8.0_192`）
- Nacos 2.4.3 已部署（集群模式，默认使用 192.168.56.106:8848）
- MySQL 已部署（192.168.56.106:3306，账号密码：root/root）
- SSH 免密登录已配置

### 1.3 软件版本

- Seata：1.7.0
- Nacos：2.4.3
- MySQL：5.7+
- JDK：1.8.0_192

---

## 二、数据库准备

### 2.1 创建 Seata 数据库

在 MySQL 中创建 `seata` 数据库并初始化表结构：

```sql
-- 创建数据库
CREATE DATABASE seata;

-- 使用数据库
USE seata;

-- 创建全局事务表
CREATE TABLE IF NOT EXISTS `global_table`
(
    `xid`                       VARCHAR(128) NOT NULL,
    `transaction_id`            BIGINT,
    `status`                    TINYINT      NOT NULL,
    `application_id`            VARCHAR(32),
    `transaction_service_group` VARCHAR(32),
    `transaction_name`          VARCHAR(128),
    `timeout`                   INT,
    `begin_time`                BIGINT,
    `application_data`          VARCHAR(2000),
    `gmt_create`                DATETIME(6),
    `gmt_modified`              DATETIME(6),
    PRIMARY KEY (`xid`),
    KEY `idx_status_gmt_modified` (`status` , `gmt_modified`),
    KEY `idx_transaction_id` (`transaction_id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

-- 创建分支事务表
CREATE TABLE IF NOT EXISTS `branch_table`
(
    `branch_id`         BIGINT       NOT NULL,
    `xid`               VARCHAR(128) NOT NULL,
    `transaction_id`    BIGINT,
    `resource_group_id` VARCHAR(32),
    `resource_id`       VARCHAR(256),
    `branch_type`       VARCHAR(8),
    `status`            TINYINT,
    `client_id`         VARCHAR(64),
    `application_data`  VARCHAR(2000),
    `gmt_create`        DATETIME(6),
    `gmt_modified`      DATETIME(6),
    PRIMARY KEY (`branch_id`),
    KEY `idx_xid` (`xid`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;

-- 创建锁表
CREATE TABLE IF NOT EXISTS `lock_table`
(
    `row_key`        VARCHAR(128) NOT NULL,
    `xid`            VARCHAR(128),
    `transaction_id` BIGINT,
    `branch_id`      BIGINT       NOT NULL,
    `resource_id`    VARCHAR(256),
    `table_name`     VARCHAR(32),
    `pk`             VARCHAR(36),
    `status`         TINYINT      NOT NULL DEFAULT '0',
    `gmt_create`     DATETIME(6),
    `gmt_modified`   DATETIME(6),
    PRIMARY KEY (`row_key`),
    KEY `idx_status` (`status`),
    KEY `idx_branch_id` (`branch_id`),
    KEY `idx_xid_and_branch_id` (`xid` , `branch_id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4;
```

---

## 三、Nacos 命名空间配置

### 3.1 创建命名空间

在 Nacos 控制台创建命名空间 `seate`（或通过 API 创建）：

```bash
curl -X POST 'http://192.168.31.100:8848/nacos/v1/console/namespaces' \
  -d 'customNamespaceId=seate&namespaceName=seate&namespaceDesc=Seata集群命名空间'
```

### 3.2 上传 Seata 配置

在 Nacos 的 `seate` 命名空间中创建配置：

- **Data ID**: `seataServer.properties`
- **Group**: `SEATA_GROUP`
- **配置内容**:

```properties
# 存储模式
store.mode=db

# 数据库配置
store.db.datasource=druid
store.db.db-type=mysql
store.db.driver-class-name=com.mysql.cj.jdbc.Driver
store.db.url=jdbc:mysql://192.168.56.106:3306/seata?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
store.db.user=root
store.db.password=root
store.db.min-conn=5
store.db.max-conn=30
store.db.global-table=global_table
store.db.branch-table=branch_table
store.db.lock-table=lock_table
store.db.query-limit=100
store.db.lock-wait-timeout=5000

# 安全配置
security.secretKey=SeataSecretKey0c382ef121d778043159209298fd40bf3850a017
```

---

## 四、Seata 安装与配置

### 4.1 下载并解压 Seata

在每台服务器上执行：

```bash
# 创建目录
mkdir -p /opt

# 下载 Seata（如果服务器无法访问外网，可从本地传输）
cd /opt
# 方式一：直接下载
wget https://github.com/seata/seata/releases/download/v1.7.0/seata-server-1.7.0.zip

# 方式二：从本地传输（使用 SCP）
# 在本地机器执行：
scp -P 226 seata-server-1.7.0.zip root@192.168.31.100:/opt/

# 解压（如果 unzip 不可用，使用 Python 脚本）
unzip seata-server-1.7.0.zip
# 或使用 Python：
python extract_zip.py seata-server-1.7.0.zip /opt/
```

### 4.2 Python 解压脚本（备用）

如果服务器没有 `unzip` 命令，可使用以下 Python 脚本：

```python
#!/usr/bin/env python
import zipfile
import sys

zip_path = sys.argv[1]
extract_to = sys.argv[2]

with zipfile.ZipFile(zip_path, 'r') as zip_ref:
    zip_ref.extractall(extract_to)

print("Extracted successfully")
```

### 4.3 配置 application.yml

#### Node1 (192.168.56.106) 配置

创建 `/opt/seata-1.7.0/conf/application.yml`：

```yaml
server:
  port: 7091

spring:
  application:
    name: seata-server

logging:
  config: classpath:logback-spring.xml
  file:
    path: /logs/seata

console:
  user:
    username: seata
    password: seata

seata:
  registry:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
      application: seata-server
      cluster: default
  store:
    mode: db
    db:
      datasource: druid
      db-type: mysql
      driver-class-name: com.mysql.cj.jdbc.Driver
      url: jdbc:mysql://localhost:3306/seata?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
      user: root
      password: root
      min-conn: 5
      max-conn: 30
      global-table: global_table
      branch-table: branch_table
      lock-table: lock_table
      query-limit: 100
      lock-wait-timeout: 5000
  security:
    secretKey: SeataSecretKey0c382ef121d778043159209298fd40bf3850a017
    tokenValidityInMilliseconds: 1800000
```

#### Node2 (192.168.56.107) 配置

```yaml
server:
  port: 7092

spring:
  application:
    name: seata-server

logging:
  config: classpath:logback-spring.xml
  file:
    path: /logs/seata

console:
  user:
    username: seata
    password: seata

seata:
  registry:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
      application: seata-server
      cluster: default
  store:
    mode: db
    db:
      datasource: druid
      db-type: mysql
      driver-class-name: com.mysql.cj.jdbc.Driver
      url: jdbc:mysql://192.168.56.106:3306/seata?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
      user: root
      password: root
      min-conn: 5
      max-conn: 30
      global-table: global_table
      branch-table: branch_table
      lock-table: lock_table
      query-limit: 100
      lock-wait-timeout: 5000
  security:
    secretKey: SeataSecretKey0c382ef121d778043159209298fd40bf3850a017
    tokenValidityInMilliseconds: 1800000
```

#### Node3 (192.168.56.108) 配置

```yaml
server:
  port: 7093

spring:
  application:
    name: seata-server

logging:
  config: classpath:logback-spring.xml
  file:
    path: /logs/seata

console:
  user:
    username: seata
    password: seata

seata:
  registry:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
      application: seata-server
      cluster: default
  store:
    mode: db
    db:
      datasource: druid
      db-type: mysql
      driver-class-name: com.mysql.cj.jdbc.Driver
      url: jdbc:mysql://192.168.56.106:3306/seata?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai
      user: root
      password: root
      min-conn: 5
      max-conn: 30
      global-table: global_table
      branch-table: branch_table
      lock-table: lock_table
      query-limit: 100
      lock-wait-timeout: 5000
  security:
    secretKey: SeataSecretKey0c382ef121d778043159209298fd40bf3850a017
    tokenValidityInMilliseconds: 1800000
```

---

## 五、启动 Seata 服务

### 5.1 启动命令

在各节点执行启动命令：

```bash
# Node1 (226端口)
cd /opt/seata-1.7.0 && nohup /usr/local/jdk1.8.0_192/bin/java -server \
  -Dloader.path=/opt/seata-1.7.0/lib \
  -Xmx512m -Xms512m \
  -Dspring.config.location=file:/opt/seata-1.7.0/conf/application.yml \
  -jar /opt/seata-1.7.0/target/seata-server.jar -m db \
  > /var/log/seata-server.log 2>&1 &

# Node2 (227端口)
cd /opt/seata-1.7.0 && nohup /usr/local/jdk1.8.0_192/bin/java -server \
  -Dloader.path=/opt/seata-1.7.0/lib \
  -Xmx512m -Xms512m \
  -Dspring.config.location=file:/opt/seata-1.7.0/conf/application.yml \
  -jar /opt/seata-1.7.0/target/seata-server.jar -m db \
  > /var/log/seata-server.log 2>&1 &

# Node3 (228端口)
cd /opt/seata-1.7.0 && nohup /usr/local/jdk1.8.0_192/bin/java -server \
  -Dloader.path=/opt/seata-1.7.0/lib \
  -Xmx512m -Xms512m \
  -Dspring.config.location=file:/opt/seata-1.7.0/conf/application.yml \
  -jar /opt/seata-1.7.0/target/seata-server.jar -m db \
  > /var/log/seata-server.log 2>&1 &
```

### 5.2 查看启动日志

```bash
tail -f /var/log/seata-server.log
```

成功启动的日志标志：

```
Server started, service listen port: 8091
seata server started in XXX millSeconds
```

---

## 六、验证集群状态

### 6.1 检查服务进程

```bash
ps aux | grep java | grep seata
```

### 6.2 查询 Nacos 注册情况

使用 Nacos 2.x API 查询：

```bash
curl -s 'http://192.168.31.100:8848/nacos/v2/ns/instance/list?serviceName=seata-server&groupName=SEATA_GROUP&namespaceId=seate'
```

返回结果示例：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "hosts": [
      {"ip": "192.168.56.106", "port": 8091, "healthy": true},
      {"ip": "192.168.56.107", "port": 8092, "healthy": true},
      {"ip": "192.168.56.108", "port": 8093, "healthy": true}
    ]
  }
}
```

### 6.3 访问 Seata 控制台

- Node1: `http://192.168.31.100:7091`（通过端口转发）
- Node2: `http://192.168.31.100:7092`
- Node3: `http://192.168.31.100:7093`

控制台账号密码：`seata/seata`

---

## 七、常见问题与解决方案

### 7.1 Java 命令未找到

**原因**：JDK 已安装但未配置环境变量

**解决方案**：

```bash
# 临时指定 JAVA_HOME
export JAVA_HOME=/usr/local/jdk1.8.0_192
export PATH=$JAVA_HOME/bin:$PATH

# 或使用绝对路径
/usr/local/jdk1.8.0_192/bin/java -version
```

### 7.2 unzip 命令未找到

**原因**：服务器未安装 unzip 工具

**解决方案**：

```bash
# 安装 unzip
yum install -y unzip

# 或使用 Python 脚本解压
python extract_zip.py seata-server-1.7.0.zip /opt/
```

### 7.3 MySQL 连接失败

**原因**：MySQL 绑定地址或防火墙问题

**解决方案**：

- 检查 MySQL 是否监听正确的地址：
  ```bash
  ss -tlnp | grep 3306
  ```
- 确保 MySQL 用户有远程访问权限
- 检查防火墙是否开放 3306 端口

### 7.4 Nacos 注册失败

**原因**：命名空间配置错误或网络不通

**解决方案**：

- 确认命名空间 ID 正确（`seate`）
- 确认 Nacos 服务地址可达
- 检查 `application.yml` 中 `seata.registry.nacos.namespace` 配置

### 7.5 Seata 使用 file 存储模式而非 db

**原因**：配置未被正确加载

**解决方案**：

- 使用 `-m db` 参数强制指定存储模式
- 使用 `-Dspring.config.location` 明确指定配置文件路径
- 检查配置文件中 `seata.store.mode=db` 是否正确设置

### 7.6 服务启动后立即停止

**原因**：配置文件格式错误或缺少必要配置

**解决方案**：

- 检查 YAML 格式是否正确
- 确保 `seata.security.secretKey` 已配置
- 查看日志文件 `/var/log/seata-server.log` 获取详细错误信息

---

## 八、停止与重启服务

### 8.1 停止服务

```bash
pkill -f seata-server.jar
```

### 8.2 重启服务

```bash
pkill -f seata-server.jar
sleep 3
cd /opt/seata-1.7.0 && nohup /usr/local/jdk1.8.0_192/bin/java -server \
  -Dloader.path=/opt/seata-1.7.0/lib \
  -Xmx512m -Xms512m \
  -Dspring.config.location=file:/opt/seata-1.7.0/conf/application.yml \
  -jar /opt/seata-1.7.0/target/seata-server.jar -m db \
  > /var/log/seata-server.log 2>&1 &
```

---

## 九、客户端接入配置

### 9.1 Spring Boot 客户端配置

```yaml
seata:
  enabled: true
  application-id: your-application
  tx-service-group: default_tx_group
  service:
    vgroup-mapping:
      default_tx_group: default
  registry:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
      application: seata-server
  config:
    type: nacos
    nacos:
      server-addr: 192.168.56.106:8848
      namespace: seate
      group: SEATA_GROUP
```

### 9.2 客户端数据库表（AT 模式）

在每个业务数据库中创建 undo_log 表：

```sql
CREATE TABLE IF NOT EXISTS `undo_log`
(
    `branch_id`     BIGINT       NOT NULL COMMENT 'branch transaction id',
    `xid`           VARCHAR(128) NOT NULL COMMENT 'global transaction id',
    `context`       VARCHAR(128) NOT NULL COMMENT 'undo_log context,such as serialization type',
    `rollback_info` LONGBLOB     NOT NULL COMMENT 'rollback info',
    `log_status`    INT          NOT NULL COMMENT '0:normal status,1:defense status',
    `log_created`   DATETIME(6)  NOT NULL COMMENT 'create datetime',
    `log_modified`  DATETIME(6)  NOT NULL COMMENT 'modify datetime',
    UNIQUE KEY `ux_undo_log` (`xid`, `branch_id`)
) ENGINE = InnoDB
  AUTO_INCREMENT = 1
  DEFAULT CHARSET = utf8mb4 COMMENT ='AT transaction mode undo log table';
```

---

## 十、附录

### 10.1 端口说明

| 端口 | 说明 |
|------|------|
| 7091/7092/7093 | Seata HTTP 端口（控制台） |
| 8091/8092/8093 | Seata TCP 端口（事务通信） |
| 8848 | Nacos 端口 |
| 3306 | MySQL 端口 |

### 10.2 目录结构

```
/opt/seata-1.7.0/
├── bin/                    # 启动脚本
├── conf/                   # 配置文件
│   └── application.yml     # 主配置文件
├── lib/                    # 依赖库
├── logs/                   # 日志目录
├── target/                 # Seata Server JAR
│   └── seata-server.jar
└── LICENSE
```

### 10.3 参考链接

- [Seata 官方文档](https://seata.io/docs/overview/what-is-seata.html)
- [Seata GitHub](https://github.com/seata/seata)
- [Nacos 官方文档](https://nacos.io/docs/what-is-nacos.html)