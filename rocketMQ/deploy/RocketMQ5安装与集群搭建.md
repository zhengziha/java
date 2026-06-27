# RocketMQ5.x版本---单机安装+集群部署

# 服务器准备

服务器准备：4台linux服务器

**rocket_1**
192.168.110.185

**rocket_2**

192.168.110.186

**rocket_3**

192.168.110.187

**rocket_4**

192.168.110.188

## 1.1、单机启动和安装验证

安装文档：[https://rocketmq.apache.org/zh/docs/quickStart/01quickstart](https://rocketmq.apache.org/zh/docs/quickStart/01quickstart)

### 修改默认的RocketMQ的启动内存

Linux系统：  runbroker.sh  、runserver.sh

windows：   runbroker.bat、runserver.bat

修改 以上两个配置文件的 堆内存大小。

runserver.sh的

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/82817a3bc7294461b35b75a10f2986cc.png)

runbroker.sh

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/e8b7ff515e9544f49600691859058b70.png)

### 1、启动namesever服务

```
nohup sh bin/mqnamesrv > nameserver.log 2>&1  &
```

验证Name Server 是否启动成功

$ tail -f ~/logs/rocketmqlogs/namesrv.log

### 2、启动broker服务

```
 nohup sh bin/mqbroker -n localhost:9876 --enable-proxy  >broker.log 2>&1  &
```

```
tail -f ~/logs/rocketmqlogs/broker_default.log
```

### 3、启动dashboard

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/5f93c3b897d745cebbbdeaffe30638af.png)

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/77b8d72518a945699512d12a31d26ce1.png)

然后输入：http://192.168.110.185:8089/

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/dc60643224564bf8a1774f84f747f968.png)

## 1.2、多组节点（集群）单副本模式

NameServer不需要动

Broker启动脚本需要修改

```
### 在机器A，启动第一个Master，例如NameServer的IP为：192.168.110.185
$ nohup sh bin/mqbroker -n 192.168.110.185:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-noslave/broker-a.properties --enable-proxy  &
 
### 在机器B，启动第二个Master，例如NameServer的IP为：192.168.110.186
$ nohup sh bin/mqbroker -n 192.168.110.186:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-noslave/broker-b.properties --enable-proxy &

...
```

因为我这里是虚拟机启动linux，然后他们的内网地址都是一样的。

## 1.3、多节点（集群）多副本模式-异步复制

4台broker

在机器A，启动第一个Master，例如NameServer的IP为：192.168.110.185

最好对应的配置文件加上外网IP，

也就是在conf文件中，加入一个

brokerIP1=192.168.110.185

```
nohup sh bin/mqbroker -n 192.168.110.185:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-2s-async/broker-a.properties --enable-proxy &
```

在机器B，启动第二个Master，例如NameServer的IP为：192.168.110.185

也就是在conf文件中，加入一个

brokerIP1=192.168.110.186

```
nohup sh bin/mqbroker -n 192.168.110.185:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-2s-async/broker-b.properties --enable-proxy &
 
```

在机器C，启动第一个Slave，例如NameServer的IP为：192.168.110.185

也就是在conf文件中，加入一个

brokerIP1=192.168.110.187

```
nohup sh bin/mqbroker -n 192.168.110.185:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-2s-async/broker-a-s.properties --enable-proxy &
 
```

在机器D，启动第二个Slave，例如NameServer的IP为：192.168.110.185

也就是在conf文件中，加入一个

brokerIP1=192.168.110.188

```
nohup sh bin/mqbroker -n 192.168.110.185:9876 -c /home/rocketmq-all-5.3.0-bin-release/conf/2m-2s-async/broker-b-s.properties --enable-proxy &
```

# cluster模式

单节点的。没有集群的cluster模式。

1、nameserver

2、broker

3、proxy

```
nohup sh mqnamesrv &
```

```
nohup sh bin/mqbroker -n 192.168.110.185:9876 &
```

```
nohup sh bin/mqproxy -n 192.168.110.185:9876 >proxy.log 2>&1  &
```



* 在 Cluster 模式下，Broker 和 Proxy 分别部署，即在原有的集群基础上，额外再部署 Proxy 即可。
* proxy可以部署在一台，也可以分开部署。
* Proxy负责处理客户端协议适配、权限管理、消费管理等计算逻辑，而Broker则专注于数据存储

![image.png](https://fynotefile.oss-cn-zhangjiakou.aliyuncs.com/fynote/fyfile/5983/1722316265030/5ab618d7f2a74d168618d88b5c76ffa7.png)
