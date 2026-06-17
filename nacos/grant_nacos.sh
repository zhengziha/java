#!/bin/bash
# 给nacos用户授权

echo "=== 给nacos用户授权 ==="
/usr/local/mysql/bin/mysql -S /tmp/mysql.sock -u root -p << EOF
GRANT ALL ON nacos_config.* TO 'nacos'@'%';
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user WHERE user='nacos';
EOF