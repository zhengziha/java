#!/bin/bash

# 解决Nacos数据库权限问题

# 1. 先停止nacos服务
echo "=== 停止Nacos服务 ==="
if [ -f /opt/nacos/bin/shutdown.sh ]; then
    /opt/nacos/bin/shutdown.sh
    sleep 5
fi

# 2. 尝试重置root密码或直接授权
echo ""
echo "=== 尝试使用socket连接授权 ==="
/usr/local/mysql/bin/mysql -S /tmp/mysql.sock -u root -p << 'EOF'
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
GRANT ALL ON nacos_config.* TO 'nacos'@'%';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'nacos'@'%';
EOF

echo ""
echo "=== 测试nacos用户连接 ==="
/usr/local/mysql/bin/mysql -S /tmp/mysql.sock -u nacos -pnacos -e "USE nacos_config; SHOW TABLES;"

echo ""
echo "=== 完成 ==="