# Nacos 集群搭建教程

## 一、环境准备

### 1.1 硬件要求

| 配置项 | 最低配置 | 推荐配置 |
| :--- | :--- | :--- |
| CPU | 2核 | 4核 |
| 内存 | 4GB | 8GB |
| 磁盘 | 20GB | 50GB |

### 1.2 软件要求

| 软件 | 版本 | 说明 |
| :--- | :--- | :--- |
| JDK | 1.8+ | 推荐 JDK 11 |
| MySQL | 5.7+ | 用于存储配置数据和集群元数据 |
| Nacos | 2.1.0 | 本教程使用版本 |

### 1.3 节点规划

本教程以3节点集群为例：

| 节点 | IP地址 | 端口 | 角色 |
| :--- | :--- | :--- | :--- |
| node1 | 192.168.56.106 | 8848 | Leader/Follower |
| node2 | 192.168.56.107 | 8848 | Follower |
| node3 | 192.168.56.108 | 8848 | Follower |

---

## 二、MySQL 数据库配置

### 2.1 创建数据库和用户

```sql
-- 创建数据库
CREATE DATABASE nacos_config CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户（替换为实际密码）
CREATE USER 'nacos'@'%' IDENTIFIED BY 'nacos_password';
GRANT ALL PRIVILEGES ON nacos_config.* TO 'nacos'@'%';
FLUSH PRIVILEGES;
```

### 2.2 导入初始化脚本

解压 `nacos-server-2.1.0.tar.gz` 后，执行 SQL 脚本：

```bash
mysql -u nacos -p nacos_config < nacos/conf/nacos-mysql.sql
```

---

## 三、Nacos 集群部署

### 3.1 解压安装包（所有节点执行）

```bash
# 创建安装目录
# mkdir -p /opt/nacos
cd /opt
# 解压到指定目录
tar -zxvf nacos-server-2.1.0.tar.gz -C /opt

# 重命名目录（可选）
# mv /opt/nacos/nacos-server-2.1.0 /opt/nacos/cluster
```

### 3.2 修改配置文件

#### 3.2.1 修改 `application.properties`

```bash
vim /opt/nacos/cluster/conf/application.properties
```

配置内容：

```properties
# 数据库配置
spring.datasource.platform=mysql
db.num=1
db.url.0=jdbc:mysql://192.168.1.200:3306/nacos_config?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=Asia/Shanghai
db.user.0=nacos
db.password.0=nacos_password

# 关闭嵌入式数据库
nacos.standalone=false

# 集群模式
nacos.core.auth.enabled=false
```

#### 3.2.2 修改 `cluster.conf`

```bash
vim /opt/nacos/cluster/conf/cluster.conf
```

添加所有节点信息：

```
192.168.56.106:8848
192.168.56.107:8848
192.168.56.108:8848
```

#### 3.2.3 修改 JVM 参数（可选）

```bash
vim /opt/nacos/cluster/bin/startup.sh
```

调整内存配置（根据服务器配置调整）：

```bash
JAVA_OPT="${JAVA_OPT} -server -Xms4g -Xmx4g -Xmn2g -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=320m"
```

### 3.3 分发到其他节点

```bash
# 使用 scp 分发到 node2
scp -r /opt/nacos/cluster root@192.168.56.107:/opt/nacos/

# 使用 scp 分发到 node3
scp -r /opt/nacos/cluster root@192.168.56.108:/opt/nacos/
```

---

## 四、启动集群

### 4.1 启动命令（所有节点执行）

```bash
cd /opt/nacos/cluster/bin
./startup.sh
```

### 4.2 检查启动状态

```bash
# 查看日志
tail -f /opt/nacos/cluster/logs/nacos.log

# 查看进程
ps -ef | grep nacos
```

### 4.3 验证集群状态

访问任意节点的控制台：
```
http://192.168.56.106:8848/nacos
```

默认用户名密码：`nacos` / `nacos`

---

## 五、集群管理

### 5.1 关闭集群

```bash
# 在每个节点上执行
cd /opt/nacos/cluster/bin
./shutdown.sh
```

### 5.2 查看集群节点状态

```bash
curl http://192.168.56.106:8848/nacos/v1/ns/operator/cluster
```

### 5.3 切换 Leader

```bash
# 手动触发 Leader 选举
curl -X POST http://192.168.56.106:8848/nacos/v1/ns/operator/switches?entry=leader&value=192.168.56.107:8848
```

---

## 六、负载均衡配置（可选）

### 6.1 Nginx 配置示例

```nginx
http {
    upstream nacos_cluster {
        server 192.168.56.106:8848;
        server 192.168.56.107:8848;
        server 192.168.56.108:8848;
    }

    server {
        listen 80;
        server_name nacos.example.com;

        location / {
            proxy_pass http://nacos_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
```

---

## 七、常见问题排查

### 7.1 端口冲突

确保 `8848`, `9848`, `9849` 端口未被占用：

```bash
netstat -tlnp | grep 8848
netstat -tlnp | grep 9848
netstat -tlnp | grep 9849
```

### 7.2 数据库连接失败

检查数据库配置和网络连通性：

```bash
telnet 192.168.1.200 3306
```

### 7.3 集群节点无法通信

检查防火墙设置：

```bash
# 开放端口
firewall-cmd --zone=public --add-port=8848/tcp --permanent
firewall-cmd --zone=public --add-port=9848/tcp --permanent
firewall-cmd --zone=public --add-port=9849/tcp --permanent
firewall-cmd --reload
```

---

## 八、监控与运维

### 8.1 日志管理

```bash
# 查看启动日志
tail -f /opt/nacos/cluster/logs/nacos.log

# 查看访问日志
tail -f /opt/nacos/cluster/logs/access.log

# 查看 raft 日志
tail -f /opt/nacos/cluster/logs/raft.log
```

### 8.2 健康检查脚本

```bash
#!/bin/bash

NACOS_NODES=("192.168.56.106:8848" "192.168.56.107:8848" "192.168.56.108:8848")

for node in "${NACOS_NODES[@]}"; do
    if curl -s "http://${node}/nacos/v1/ns/operator/metrics" > /dev/null; then
        echo "Node ${node}: ✓ Healthy"
    else
        echo "Node ${node}: ✗ Unhealthy"
    fi
done
```

---

## 附录：目录结构

```
/opt/nacos/cluster/
├── bin/                    # 启动脚本目录
│   ├── startup.sh          # Linux/Mac 启动脚本
│   ├── startup.cmd         # Windows 启动脚本
│   ├── shutdown.sh         # Linux/Mac 停止脚本
│   └── shutdown.cmd        # Windows 停止脚本
├── conf/                   # 配置文件目录
│   ├── application.properties   # 应用配置
│   ├── cluster.conf            # 集群配置
│   ├── nacos-logback.xml       # 日志配置
│   └── mysql-schema.sql        # MySQL 初始化脚本
├── logs/                   # 日志目录
└── target/                 # 编译后的 jar 包
```

---

## 参考链接

- [Nacos 官方文档](https://nacos.io/zh-cn/docs/cluster-mode-quick-start.html)
- [Nacos GitHub](https://github.com/alibaba/nacos)