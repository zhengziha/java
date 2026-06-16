# MySQL 7 安装脚本
# 用于在 CentOS 7 虚拟机上安装 MySQL 7

$nodes = @(
    @{ name = "node1"; ip = "192.168.56.106" },
    @{ name = "node2"; ip = "192.168.56.107" },
    @{ name = "node3"; ip = "192.168.56.108" }
)

$sshUser = "root"
$sshPass = "root"

foreach ($node in $nodes) {
    Write-Host "正在处理 $($node.name) ($($node.ip))..." -ForegroundColor Cyan
    
    # 创建远程执行的shell脚本
    $installScript = @"
#!/bin/bash
set -e

# 安装依赖
yum install -y wget libaio numactl

# 添加 MySQL 7 YUM 仓库
cat > /etc/yum.repos.d/mysql-community.repo << 'EOF'
[mysql70-community]
name=MySQL 7.0 Community Server
baseurl=http://repo.mysql.com/yum/mysql-7.0-community/el/7/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
EOF

# 导入 GPG key
wget -q -O /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql https://repo.mysql.com/RPM-GPG-KEY-mysql

# 安装 MySQL 7
yum install -y mysql-community-server-7.0.*

# 启动 MySQL 并设置开机启动
systemctl start mysqld
systemctl enable mysqld

# 获取初始密码
INIT_PASS=`grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}'`

# 设置密码策略为低强度（允许简单密码）
mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "SET GLOBAL validate_password_policy=LOW; SET GLOBAL validate_password_length=4;"

# 修改 root 密码为 root
mysql -uroot -p"$INIT_PASS" --connect-expired-password -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

# 允许远程登录
mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"

# 重启 MySQL 服务
systemctl restart mysqld

echo "MySQL 7 安装完成，端口 3306，账号 root，密码 root"
EOF

    # 将脚本写入临时文件
    $localScriptPath = "f:\m-knowledge\java\Mysql\install_$($node.name).sh"
    Set-Content -Path $localScriptPath -Value $installScript -Encoding UTF8

    # 使用 plink 或 ssh 执行远程脚本（需要确认虚拟机上已安装 SSH）
    Write-Host "正在通过 SSH 连接到 $($node.ip)..."
    
    # 使用 sshpass 和 ssh 执行（如果可用）
    try {
        # 尝试使用 ssh 命令直接执行
        $command = "sshpass -p '$sshPass' ssh -o StrictHostKeyChecking=no $sshUser@$($node.ip) 'bash -s' < ""$localScriptPath"""
        Invoke-Expression $command
    } catch {
        Write-Warning "SSH 执行失败，可能需要手动安装 sshpass 或使用其他方式"
        Write-Host "请手动将脚本复制到 $($node.name) 并执行："
        Write-Host "scp install_$($node.name).sh root@$($node.ip):/root/"
        Write-Host "ssh root@$($node.ip) 'chmod +x /root/install_$($node.name).sh && /root/install_$($node.name).sh'"
    }

    # 清理临时脚本文件
    Remove-Item -Path $localScriptPath -Force

    Write-Host "$($node.name) 处理完成" -ForegroundColor Green
    Write-Host "----------------------------------------"
}

Write-Host "所有节点安装完成！" -ForegroundColor Green
