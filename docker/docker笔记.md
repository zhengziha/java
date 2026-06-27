# Docker 学习笔记

## 一、Docker 简介

Docker 是一个开源的应用容器引擎，基于 Go 语言开发，可以让开发者打包应用以及依赖包到一个可移植的容器中，然后发布到任何流行的 Linux 机器上。

### Docker 核心概念

| 概念 | 说明 |
|------|------|
| **镜像 (Image)** | 只读模板，包含创建 Docker 容器的指令 |
| **容器 (Container)** | 镜像的运行实例，相互隔离，保证安全 |
| **仓库 (Repository)** | 集中存放镜像的地方，分为公有和私有 |

---

## 二、Docker 安装

### CentOS 7 安装 Docker

```bash
# 安装 Docker
yum install -y docker

# 启动 Docker 服务
systemctl start docker

# 设置开机自启动
systemctl enable docker

# 验证安装
docker version
```

### 配置国内镜像加速

```bash
# 创建配置目录
mkdir -p /etc/docker

# 配置镜像加速
cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

# 重启 Docker 服务
systemctl daemon-reload
systemctl restart docker
```

---

## 三、Docker 常用命令

### 镜像命令

```bash
# 查看本地镜像
docker images

# 搜索镜像
docker search <镜像名>

# 拉取镜像
docker pull <镜像名>[:tag]

# 删除镜像
docker rmi <镜像ID>

# 构建镜像
docker build -t <镜像名:tag> .

# 导出镜像
docker save -o <文件名>.tar <镜像名:tag>

# 导入镜像
docker load -i <文件名>.tar
```

### 容器命令

```bash
# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a

# 创建并启动容器
docker run [OPTIONS] <镜像名> [COMMAND]

# 常用 run 参数
-d          # 后台运行
-p          # 端口映射 hostPort:containerPort
-v          # 挂载卷 hostPath:containerPath
--name      # 指定容器名称
--network   # 指定网络
-e          # 设置环境变量
--restart   # 重启策略 always/on-failure

# 启动已停止的容器
docker start <容器ID>

# 停止容器
docker stop <容器ID>

# 重启容器
docker restart <容器ID>

# 删除容器
docker rm <容器ID>

# 强制删除运行中的容器
docker rm -f <容器ID>

# 进入容器
docker exec -it <容器ID> /bin/bash

# 查看容器日志
docker logs <容器ID>

# 查看容器详细信息
docker inspect <容器ID>
```

---

## 四、Docker 网络管理

### 网络模式

| 模式 | 说明 |
|------|------|
| **bridge** | 默认模式，容器通过虚拟网桥连接 |
| **host** | 容器使用宿主机网络 |
| **none** | 容器没有网络接口 |
| **container** | 与指定容器共享网络命名空间 |

### 网络命令

```bash
# 查看网络列表
docker network ls

# 创建网络
docker network create <网络名>

# 删除网络
docker network rm <网络名>

# 查看网络详情
docker network inspect <网络名>

# 连接容器到网络
docker network connect <网络名> <容器名>

# 断开容器与网络的连接
docker network disconnect <网络名> <容器名>
```

---

## 五、Docker 数据管理

### 数据卷

```bash
# 创建数据卷
docker volume create <卷名>

# 查看数据卷列表
docker volume ls

# 查看数据卷详情
docker volume inspect <卷名>

# 删除数据卷
docker volume rm <卷名>

# 挂载数据卷到容器
docker run -v <卷名>:<容器路径> <镜像名>
```

### 挂载宿主机目录

```bash
# 挂载宿主机目录到容器
docker run -v /宿主机路径:/容器路径 <镜像名>

# 只读挂载
docker run -v /宿主机路径:/容器路径:ro <镜像名>
```

---

## 六、Dockerfile

### 常用指令

```dockerfile
# 基础镜像
FROM <镜像名>:<tag>

# 维护者信息
MAINTAINER <name>

# 运行命令
RUN <命令>

# 复制文件
COPY <源路径> <目标路径>

# 添加文件（支持URL和解压）
ADD <源路径> <目标路径>

# 设置工作目录
WORKDIR <路径>

# 设置环境变量
ENV <key>=<value>

# 暴露端口
EXPOSE <端口>

# 容器启动时执行的命令
CMD ["命令", "参数"]

# 入口点
ENTRYPOINT ["命令", "参数"]
```

### 示例 Dockerfile

```dockerfile
FROM openjdk:11-jdk

WORKDIR /app

COPY target/myapp.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## 七、Docker Compose

### 安装 Docker Compose

```bash
# 下载
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 添加执行权限
chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### docker-compose.yml 示例

```yaml
version: '3.8'

services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    networks:
      - app-network

  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=prod
    depends_on:
      - db
    networks:
      - app-network

  db:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root123
      MYSQL_DATABASE: mydb
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  db-data:
```

### Docker Compose 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs

# 重启服务
docker-compose restart

# 构建镜像
docker-compose build
```

---

## 八、常见问题解决

### 1. Docker 服务无法启动

```bash
# 检查 Docker 服务状态
systemctl status docker

# 启动 Docker 服务
systemctl start docker

# 设置开机自启动
systemctl enable docker
```

### 2. 容器无法访问外网

检查 Docker 网络配置和宿主机网络设置。

### 3. 镜像拉取失败

配置国内镜像加速器。

### 4. 磁盘空间不足

```bash
# 清理未使用的镜像
docker image prune -a

# 清理未使用的容器
docker container prune

# 清理未使用的数据卷
docker volume prune

# 一键清理
docker system prune -a
```

---

## 九、最佳实践

1. **镜像优化**
   - 使用多阶段构建减小镜像体积
   - 使用 `.dockerignore` 排除不需要的文件
   - 合并 RUN 指令减少层数

2. **安全实践**
   - 不以 root 用户运行容器
   - 使用最小化基础镜像
   - 定期扫描镜像漏洞

3. **资源限制**
   ```bash
   docker run --memory="512m" --cpus="1.0" <镜像名>
   ```

4. **日志管理**
   - 配置日志驱动限制日志大小
   - 集中收集容器日志