# MySQL 7 安装说明

## 环境信息

| 节点 | IP地址 | 账号 | 密码 |
|------|--------|------|------|
| node1 | 192.168.56.106 | root | root |
| node2 | 192.168.56.107 | root | root |
| node3 | 192.168.56.108 | root | root |

## 安装方法

### 方法一：手动执行（推荐）

1. 将 `install_mysql.sh` 复制到每个节点：

```bash
scp install_mysql.sh root@192.168.56.106:/root/
scp install_mysql.sh root@192.168.56.107:/root/
scp install_mysql.sh root@192.168.56.108:/root/
```

2. 登录每个节点执行安装：

```bash
# 登录 node1
ssh root@192.168.56.106
chmod +x /root/install_mysql.sh
/root/install_mysql.sh

# 登录 node2
ssh root@192.168.56.107
chmod +x /root/install_mysql.sh
/root/install_mysql.sh

# 登录 node3
ssh root@192.168.56.108
chmod +x /root/install_mysql.sh
/root/install_mysql.sh
```

### 方法二：PowerShell 自动执行（需要 sshpass）

在 Windows PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -File install_mysql.ps1
```

> **注意**：需要预先安装 sshpass 工具才能使用此方法。

## 安装完成后

MySQL 配置信息：
- 端口：3306
- 账号：root
- 密码：root
- 远程登录：已开启

## 验证安装

```bash
# 在任意节点上执行
mysql -uroot -proot -e "SELECT VERSION();"

# 从外部测试远程连接
mysql -h 192.168.56.106 -uroot -proot
```

## 文件清单

- `install_mysql.sh` - Linux 安装脚本
- `install_mysql.ps1` - Windows PowerShell 远程安装脚本
- `README.md` - 使用说明
