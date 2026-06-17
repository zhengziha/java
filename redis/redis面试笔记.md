## 概念：一个基于内存存储的缓存数据库

## 用作：
缓存
token
排行榜
布隆过滤
分布式锁

zset：有序集合，支持计数排序，排行榜
bitmap：二进制数组，布隆过滤
GEO：地图信息存储(key,GeoCoordinate(double,double))，底层zset

## lua脚本
把client的多个操作合并成一个lua脚本，支持任意api操作
redis.call('指令',key,val,key,val......)
redis可以缓存lua脚本 script load 脚本 //缓存脚本,并返回sha1的摘要 evalsha 摘要 //执行摘要对应的lua脚本

## redis的批量操作
- mset key1 val1 key2 val2 ...
- pipline操作：RedisPipeline.plSet(keys,values);
- lua脚本，注意：版本兼容，集群模式key的路由

mulit事务：若事务，只检查命令的正确性，执行过程报错不回滚

## 集群的缺点

## redis扩容 
使用渐进式rehash 双hash表,把rehash操作分散到每个请求里面处理

## 数据倾斜 
大量热点key存在同一个redis