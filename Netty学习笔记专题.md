# Netty 学习笔记专题

> 本笔记涵盖了 Netty 框架的核心概念、重点 API 说明、实战案例和最佳实践

## 目录
- [一、Netty 概述](#一netty-概述)
- [二、核心组件](#二核心组件)
- [三、重点 API 详解](#三重点-api-详解)
- [四、实战案例](#四实战案例)
- [五、高级特性](#五高级特性)
- [六、性能优化](#六性能优化)
- [七、常见问题](#七常见问题)

---

## 一、Netty 概述

### 1.1 什么是 Netty

Netty 是一个异步的、基于事件驱动的网络应用框架，用于快速开发可维护、高性能的网络服务器和客户端。

### 1.2 为什么选择 Netty

- **高性能**：比 Java 原生 NIO 更好的性能和更低的资源消耗
- **易用性**：提供了简洁易用的 API，屏蔽了 NIO 的复杂性
- **稳定性**：经过众多大型项目验证，如 Dubbo、RocketMQ、Elasticsearch
- **功能丰富**：支持多种协议和编解码器

### 1.3 Netty vs 原生 NIO

| 特性 | Java NIO | Netty |
|------|----------|-------|
| API 复杂度 | 复杂 | 简单 |
| 线程模型 | 需要手动实现 | 内置完善的线程模型 |
| 编解码 | 需要手动实现 | 内置多种编解码器 |
| 心跳检测 | 需要手动实现 | 内置 IdleStateHandler |
| 零拷贝 | 支持 | 支持并优化 |

---

## 二、核心组件

### 2.1 核心组件关系图

```
┌─────────────────────────────────────────────────────────────┐
│                         Netty 架构                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐        ┌──────────────┐                   │
│  │   Bootstrap  │───────▶│   EventLoop  │                   │
│  │  (启动引导类)  │        │  (事件循环)   │                   │
│  └──────────────┘        └──────┬───────┘                   │
│                                  │                            │
│                                  ▼                            │
│  ┌──────────────┐        ┌──────────────┐                   │
│  │   Channel    │◀───────│  ChannelPipe │                   │
│  │   (网络通道)   │        │  (处理器管道)  │                   │
│  └──────┬───────┘        └──────┬───────┘                   │
│         │                       │                            │
│         ▼                       ▼                            │
│  ┌──────────────┐        ┌──────────────┐                   │
│  │  ByteBuf     │        │  ChannelHand │                   │
│  │  (字节容器)   │        │  (业务处理器)  │                   │
│  └──────────────┘        └──────────────┘                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Bootstrap (启动引导类)

#### 2.2.1 Bootstrap vs ServerBootstrap

```java
// Bootstrap - 客户端启动引导类
Bootstrap bootstrap = new Bootstrap();
bootstrap.group(eventLoopGroup)  // 客户端只需要一个 EventLoopGroup
         .channel(NioSocketChannel.class)  // 客户端使用 SocketChannel
         .handler(new ClientInitializer());

// ServerBootstrap - 服务端启动引导类
ServerBootstrap serverBootstrap = new ServerBootstrap();
serverBootstrap.group(bossGroup, workerGroup)  // 服务端需要两个 EventLoopGroup
              .channel(NioServerSocketChannel.class)  // 服务端使用 ServerSocketChannel
              .childHandler(new ServerInitializer());  // childHandler 处理客户端连接
```

**区别说明**：
- **Bootstrap**：用于客户端或无连接服务
- **ServerBootstrap**：用于服务端，可以处理多个连接的客户端
- **group()**：Bootstrap 一个参数，ServerBootstrap 两个参数（boss 负责连接，worker 负责 IO）
- **handler() vs childHandler()**：handler() 用于主线程，childHandler() 用于处理客户端连接

### 2.3 EventLoop (事件循环)

#### 2.3.1 EventLoopGroup 创建

```java
// 推荐方式：根据 CPU 核心数创建
EventLoopGroup bossGroup = new NioEventLoopGroup(1);  // 通常只需要 1 个线程处理连接
EventLoopGroup workerGroup = new NioEventLoopGroup(); // 默认 CPU 核心数 * 2

// 自定义线程数
EventLoopGroup customGroup = new NioEventLoopGroup(4);

// 使用 ThreadFactory 自定义线程
EventLoopGroup group = new NioEventLoopGroup(4, new ThreadFactoryBuilder()
    .setNameFormat("netty-worker-%d")
    .build());
```

#### 2.3.2 EventLoop 工作原理

```java
// EventLoop 内部机制（伪代码）
class EventLoop {
    private final Executor executor;
    private final Queue<Runnable> taskQueue;
    
    public void run() {
        while (true) {
            // 1. 处理 IO 事件
            int readyChannels = selector.select();
            if (readyChannels > 0) {
                processSelectedKeys();
            }
            
            // 2. 处理异步任务
            processTasks();
        }
    }
    
    private void processSelectedKeys() {
        Set<SelectionKey> selectedKeys = selector.selectedKeys();
        for (SelectionKey key : selectedKeys) {
            if (key.isAcceptable()) {
                // 处理连接接受
            } else if (key.isReadable()) {
                // 处理读事件
            } else if (key.isWritable()) {
                // 处理写事件
            }
        }
    }
}
```

### 2.4 Channel (网络通道)

#### 2.4.1 Channel 类型

```java
// 服务端 Channel 类型
NioServerSocketChannel  // 基于 NIO 的服务端通道
OioServerSocketChannel  // 基于 OIO 的服务端通道（阻塞）

// 客户端 Channel 类型
NioSocketChannel       // 基于 NIO 的客户端通道
OioSocketChannel       // 基于 OIO 的客户端通道（阻塞）

// 本地通信 Channel
NioDatagramChannel     // UDP 数据报通道
LocalServerChannel     // 本地服务端通道
LocalChannel           // 本地客户端通道
```

#### 2.4.2 Channel 核心 API

```java
// Channel 核心 API 说明
Channel channel = ...;

// === 生命周期相关 ===
ChannelFuture closeFuture = channel.close();              // 关闭通道
ChannelFuture closeFuture = channel.closeFuture();        // 获取关闭的 Future
ChannelFuture disconnectFuture = channel.disconnect();    // 断开连接

// === IO 操作相关 ===
ChannelFuture writeFuture = channel.write(message);        // 写入数据（会放入缓冲区）
Channel flush = channel.flush();                           // 刷新缓冲区
ChannelFuture writeAndFlush = channel.writeAndFlush(msg);  // 写入并刷新（推荐）

// === 地址信息 ===
SocketAddress localAddress = channel.localAddress();       // 本地地址
SocketAddress remoteAddress = channel.remoteAddress();    // 远程地址

// === 配置相关 ===
ChannelConfig config = channel.config();                   // 获取配置
config.setOption(ChannelOption.SO_KEEPALIVE, true);        // 设置配置项
config.setConnectTimeoutMillis(5000);                       // 设置连接超时

// === 状态查询 ===
boolean isOpen = channel.isOpen();                         // 是否打开
boolean isRegistered = channel.isRegistered();             // 是否已注册
boolean isActive = channel.isActive();                     // 是否活跃（已连接）
```

### 2.5 ChannelPipeline (处理器管道)

#### 2.5.1 Pipeline 工作流程

```java
// 数据在 Pipeline 中的流动
/*
入站数据（Inbound）：
客户端数据 → HeadContext → ChannelInboundHandler1 → ChannelInboundHandler2 → TailContext

出站数据（Outbound）：
服务端数据 → HeadContext → ChannelOutboundHandler1 → ChannelOutboundHandler2 → TailContext → 客户端
*/
```

#### 2.5.2 Pipeline 操作 API

```java
ChannelPipeline pipeline = channel.pipeline();

// === 添加处理器 ===
// addLast：添加到链表末尾（推荐）
pipeline.addLast("decoder", new StringDecoder());
pipeline.addLast("encoder", new StringEncoder());
pipeline.addLast("handler", new MyBusinessHandler());

// addFirst：添加到链表开头
pipeline.addFirst("logging", new LoggingHandler());

// addBefore：在指定处理器之前添加
pipeline.addBefore("decoder", "ssl", new SslHandler());

// addAfter：在指定处理器之后添加
pipeline.addAfter("decoder", "decompressor", new HttpContentDecompressor());

// === 替换和删除处理器 ===
pipeline.replace("handler", "newHandler", new NewBusinessHandler());
pipeline.remove("decoder");
pipeline.remove(MyBusinessHandler.class);

// === 查找处理器 ===
ChannelHandler handler = pipeline.get("handler");
MyHandler myHandler = pipeline.get(MyHandler.class);
Map<String, ChannelHandler> contextMap = pipeline.toMap();
```

---

## 三、重点 API 详解

### 3.1 ByteBuf (字节容器)

#### 3.1.1 ByteBuf vs ByteBuffer

| 特性 | Java NIO ByteBuffer | Netty ByteBuf |
|------|---------------------|---------------|
| 读写模式切换 | 需要 flip() | 自动管理读写索引 |
| 容量扩展 | 不支持 | 支持动态扩容 |
| 引用计数 | 无 | 支持引用计数，更好的内存管理 |
| 零拷贝 | 不支持 | 支持 CompositeByteBuf |
| 性能 | 一般 | 高性能 |

#### 3.1.2 ByteBuf 核心 API

```java
// === ByteBuf 创建 ===
// 推荐使用 ByteBufAllocator 创建
ByteBuf buffer = channel.alloc().buffer();  // 推荐方式
ByteBuf buffer = ByteBufAllocator.DEFAULT.buffer();  // 全局分配器

// 直接缓冲区（堆外内存，零拷贝）
ByteBuf directBuffer = channel.alloc().directBuffer();

// 堆缓冲区（堆内内存）
ByteBuf heapBuffer = channel.alloc().heapBuffer();

// 指定初始容量的缓冲区
ByteBuf buffer = channel.alloc().buffer(1024);  // 初始容量 1024
ByteBuf buffer = channel.alloc().buffer(1024, 65536);  // 初始 1024，最大 65536

// === ByteBuf 索引说明 ===
/*
+-------------------+------------------+------------------+
| discardable bytes |  readable bytes  |  writable bytes  |
|    (已读字节)      |    (可读字节)     |    (可写字节)     |
+-------------------+------------------+------------------+
|                   |                  |                  |
0      readerIndex  |          writerIndex              capacity
*/

// === 读写操作 ===
buffer.writeBytes("Hello Netty".getBytes());  // 写入字节数组
buffer.writeInt(12345);                        // 写入整数
buffer.writeLong(67890L);                      // 写入长整数

// 读取数据
while (buffer.isReadable()) {  // 检查是否可读
    byte b = buffer.readByte();  // 读取一个字节
    System.out.println((char) b);
}

// === 索引操作 ===
int readerIndex = buffer.readerIndex();        // 获取读索引
buffer.readerIndex(0);                         // 设置读索引（重置）

int writerIndex = buffer.writerIndex();        // 获取写索引
buffer.writerIndex(0);                         // 设置写索引

int readableBytes = buffer.readableBytes();    // 可读字节数
int writableBytes = buffer.writableBytes();    // 可写字节数
int capacity = buffer.capacity();              // 容量
int maxCapacity = buffer.maxCapacity();        // 最大容量

// === 标记和重置 ===
buffer.markReaderIndex();                      // 标记读索引
buffer.resetReaderIndex();                     // 重置到标记位置

buffer.markWriterIndex();                      // 标记写索引
buffer.resetWriterIndex();                     // 重置到标记位置

// === 引用计数和释放 ===
buffer.retain();                               // 增加引用计数
buffer.release();                              // 减少引用计数
buffer.release();                              // 引用计数为 0 时释放内存

// 确保释放的工具方法
ReferenceCountUtil.release(buffer);            // 安全释放
ReferenceCountUtil.releaseLater(buffer, channel);  // 在事件循环中延迟释放

// === 其他常用操作 ===
buffer.clear();                                // 清空缓冲区（重置索引）
buffer.skipBytes(4);                           // 跳过指定字节
buffer.slice();                                // 创建切片（共享底层内存）
buffer.duplicate();                           // 创建副本（共享底层内存）
buffer.copy();                                 // 创建深拷贝（不共享内存）
```

#### 3.1.3 ByteBuf 池化

```java
// === 使用池化技术提高性能 ===
// 池化的 ByteBuf 可以重复使用，减少 GC 压力

// 启用池化（默认启用）
System.setProperty("io.netty.allocator.type", "pooled");
// 或禁用池化
System.setProperty("io.netty.allocator.type", "unpooled");

// 检查是否使用池化
boolean isPooled = buffer.isDirect();  // 检查是否为直接缓冲区

// === 使用 ByteBufHolder ===
// ByteBufHolder 是一个持有 ByteBuf 的对象，可以自动管理 ByteBuf 的生命周期
ByteBufHolder holder = new DefaultByteBufHolder(buffer);
ByteBuf content = holder.content();
holder.copy();
holder.duplicate();
holder.release();  // 释放持有的 ByteBuf
```

### 3.2 ChannelHandler (处理器)

#### 3.2.1 ChannelHandler 类型

```java
// === ChannelInboundHandler（入站处理器）===
// 处理从客户端到服务端的数据
public class MyInboundHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelRegistered(ChannelHandlerContext ctx) throws Exception {
        // 当 Channel 注册到 EventLoop 时调用
        System.out.println("Channel 注册");
        super.channelRegistered(ctx);
    }
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // 当 Channel 活跃（连接建立）时调用
        System.out.println("连接建立：" + ctx.channel().remoteAddress());
        super.channelActive(ctx);
    }
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // 当从 Channel 读取数据时调用
        System.out.println("读取数据：" + msg);
        super.channelRead(ctx, msg);
    }
    
    @Override
    public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
        // 当当前读操作完成时调用
        ctx.flush();  // 刷新缓冲区，发送数据
        super.channelReadComplete(ctx);
    }
    
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        // 当 Channel 不活跃（连接断开）时调用
        System.out.println("连接断开");
        super.channelInactive(ctx);
    }
    
    @Override
    public void channelUnregistered(ChannelHandlerContext ctx) throws Exception {
        // 当 Channel 从 EventLoop 注销时调用
        System.out.println("Channel 注销");
        super.channelUnregistered(ctx);
    }
    
    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        // 当用户自定义事件触发时调用
        if (evt instanceof IdleStateEvent) {
            IdleStateEvent idleEvent = (IdleStateEvent) evt;
            if (idleEvent.state() == IdleState.READER_IDLE) {
                System.out.println("读空闲超时");
                ctx.close();
            }
        }
        super.userEventTriggered(ctx, evt);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        // 当异常发生时调用
        cause.printStackTrace();
        ctx.close();  // 关闭连接
    }
}

// === ChannelOutboundHandler（出站处理器）===
// 处理从服务端到客户端的数据
public class MyOutboundHandler extends ChannelOutboundHandlerAdapter {
    
    @Override
    public void bind(ChannelHandlerContext ctx, SocketAddress localAddress, ChannelPromise promise) throws Exception {
        // 当绑定本地地址时调用
        System.out.println("绑定地址：" + localAddress);
        super.bind(ctx, localAddress, promise);
    }
    
    @Override
    public void connect(ChannelHandlerContext ctx, SocketAddress remoteAddress, SocketAddress localAddress, ChannelPromise promise) throws Exception {
        // 当连接远程地址时调用
        System.out.println("连接远程：" + remoteAddress);
        super.connect(ctx, remoteAddress, localAddress, promise);
    }
    
    @Override
    public void disconnect(ChannelHandlerContext ctx, ChannelPromise promise) throws Exception {
        // 当断开连接时调用
        System.out.println("断开连接");
        super.disconnect(ctx, promise);
    }
    
    @Override
    public void close(ChannelHandlerContext ctx, ChannelPromise promise) throws Exception {
        // 当关闭 Channel 时调用
        System.out.println("关闭 Channel");
        super.close(ctx, promise);
    }
    
    @Override
    public void deregister(ChannelHandlerContext ctx, ChannelPromise promise) throws Exception {
        // 当从 EventLoop 注销时调用
        System.out.println("注销 Channel");
        super.deregister(ctx, promise);
    }
    
    @Override
    public void read(ChannelHandlerContext ctx) throws Exception {
        // 当请求读取数据时调用
        System.out.println("请求读取数据");
        super.read(ctx);
    }
    
    @Override
    public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
        // 当写入数据时调用
        System.out.println("写入数据：" + msg);
        super.write(ctx, msg, promise);
    }
    
    @Override
    public void flush(ChannelHandlerContext ctx) throws Exception {
        // 当刷新缓冲区时调用
        System.out.println("刷新缓冲区");
        super.flush(ctx);
    }
}

// === ChannelDuplexHandler（双向处理器）===
// 同时处理入站和出站数据
public class MyDuplexHandler extends ChannelDuplexHandler {
    // 可以同时实现入站和出站的处理方法
}
```

#### 3.2.2 ChannelHandlerContext 上下文

```java
// ChannelHandlerContext 是 ChannelHandler 和 Pipeline 之间的桥梁
public class ContextExampleHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // === 获取相关信息 ===
        Channel channel = ctx.channel();              // 获取 Channel
        ChannelPipeline pipeline = ctx.pipeline();    // 获取 Pipeline
        ByteBufAllocator allocator = ctx.alloc();    // 获取 ByteBuf 分配器
        EventExecutor executor = ctx.executor();      // 获取 EventExecutor
        
        // === 状态检查 ===
        boolean isRemoved = ctx.isRemoved();          // 是否已移除
        boolean isActive = ctx.channel().isActive();  // Channel 是否活跃
        
        // === 发送数据 ===
        ctx.write(msg);                                // 写入数据
        ctx.writeAndFlush(msg);                        // 写入并刷新数据
        
        // === Channel 操作 ===
        ctx.channel().close();                         // 关闭 Channel
        ctx.channel().flush();                         // 刷新缓冲区
        ctx.channel().read();                          // 请求读取数据
        
        // === Pipeline 操作 ===
        ctx.fireChannelRead(msg);                      // 触发下一个处理器的 channelRead
        ctx.fireExceptionCaught(cause);                // 触发异常处理
        
        // === 执行器操作 ===
        ctx.executor().execute(() -> {
            // 在 EventLoop 中执行异步任务
            System.out.println("异步任务执行");
        });
        
        // === ChannelPromise 使用 ===
        ChannelPromise promise = ctx.newPromise();     // 创建新的 Promise
        ctx.write(msg, promise);                        // 写入数据并添加监听器
        
        promise.addListener(future -> {
            if (future.isSuccess()) {
                System.out.println("写入成功");
            } else {
                System.out.println("写入失败：" + future.cause());
            }
        });
    }
}
```

### 3.3 ChannelFuture (异步结果)

#### 3.3.1 ChannelFuture API

```java
// ChannelFuture 表示一个异步的 I/O 操作结果
ChannelFuture future = channel.writeAndFlush(message);

// === 基本操作 ===
boolean isSuccess = future.isSuccess();              // 操作是否成功
boolean isCancelled = future.isCancelled();          // 操作是否取消
boolean isDone = future.isDone();                   // 操作是否完成
Throwable cause = future.cause();                   // 获取失败原因
Channel channel = future.channel();                  // 获取关联的 Channel

// === 同步等待结果 ===
try {
    future.sync();  // 同步等待操作完成，如果失败会抛出异常
    System.out.println("操作成功");
} catch (Exception e) {
    System.out.println("操作失败：" + e.getMessage());
}

// await() 不会抛出异常
if (future.await(5, TimeUnit.SECONDS)) {  // 最多等待 5 秒
    if (future.isSuccess()) {
        System.out.println("操作成功");
    } else {
        System.out.println("操作失败：" + future.cause());
    }
} else {
    System.out.println("操作超时");
}

// === 异步监听 ===
future.addListener(new ChannelFutureListener() {
    @Override
    public void operationComplete(ChannelFuture future) {
        if (future.isSuccess()) {
            System.out.println("写入成功");
        } else {
            System.out.println("写入失败：" + future.cause());
            future.channel().close();  // 关闭 Channel
        }
    }
});

// Lambda 表达式写法
future.addListener(f -> {
    if (f.isSuccess()) {
        System.out.println("操作成功");
    } else {
        System.out.println("操作失败：" + f.cause());
    }
});

// === ChannelPromise ===
// ChannelPromise 是可写的 ChannelFuture
ChannelPromise promise = channel.newPromise();
promise.setSuccess();                    // 设置成功
promise.setFailure(new Exception());    // 设置失败
promise.trySuccess();                   // 尝试设置成功
promise.tryFailure(new Exception());    // 尝试设置失败

// 监听 Promise
promise.addListener(future -> {
    if (future.isSuccess()) {
        System.out.println("操作成功");
    }
});
```

#### 3.3.2 常用 ChannelFutureListener

```java
// === 内置监听器 ===
// 关闭连接监听器
future.addListener(ChannelFutureListener.CLOSE);

// 关闭失败监听器
future.addListener(ChannelFutureListener.CLOSE_ON_FAILURE);

// === 自定义监听器 ===
ChannelFutureListener writeListener = new ChannelFutureListener() {
    @Override
    public void operationComplete(ChannelFuture future) {
        if (future.isSuccess()) {
            System.out.println("数据写入成功");
            // 继续发送下一条消息
            future.channel().writeAndFlush(nextMessage);
        } else {
            System.out.println("数据写入失败：" + future.cause());
            future.channel().close();
        }
    }
};

future.addListener(writeListener);

// === 组合多个监听器 ===
ChannelFutureListener listener1 = f -> System.out.println("监听器 1");
ChannelFutureListener listener2 = f -> System.out.println("监听器 2");

future.addListener(listener1).addListener(listener2);
```

---

## 四、实战案例

### 4.1 Echo 服务器（最简单的案例）

#### 4.1.1 服务端代码

```java
public class EchoServer {
    private final int port;

    public EchoServer(int port) {
        this.port = port;
    }

    public void start() throws Exception {
        // 1. 创建 EventLoopGroup
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);  // 接受连接
        EventLoopGroup workerGroup = new NioEventLoopGroup();  // 处理 I/O
        
        try {
            // 2. 创建 ServerBootstrap
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)  // 使用 NIO ServerSocketChannel
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast(new EchoServerHandler());
                 }
             });
            
            // 3. 绑定端口并启动服务器
            ChannelFuture f = b.bind(port).sync();
            System.out.println("Echo 服务器已启动，端口：" + port);
            
            // 4. 等待服务器 socket 关闭
            f.channel().closeFuture().sync();
        } finally {
            // 5. 关闭 EventLoopGroup
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new EchoServer(8080).start();
    }
}

@ChannelHandler.Sharable  // 标记为可共享，多个 Channel 可以共享同一个 Handler
public class EchoServerHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // 直接将接收到的消息写回客户端（Echo）
        ctx.writeAndFlush(msg);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();  // 发生异常时关闭连接
    }
}
```

#### 4.1.2 客户端代码

```java
public class EchoClient {
    private final String host;
    private final int port;

    public EchoClient(String host, int port) {
        this.host = host;
        this.port = port;
    }

    public void start() throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();
        
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
             .channel(NioSocketChannel.class)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast(new EchoClientHandler());
                 }
             });
            
            // 连接到服务器
            ChannelFuture f = b.connect(host, port).sync();
            System.out.println("已连接到服务器：" + host + ":" + port);
            
            // 等待连接关闭
            f.channel().closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new EchoClient("localhost", 8080).start();
    }
}

public class EchoClientHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // 连接建立后发送消息
        ctx.writeAndFlush("Hello, Netty Server!");
    }
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        // 接收服务器的响应
        System.out.println("收到服务器响应：" + msg);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 4.2 HTTP 服务器

#### 4.2.1 完整的 HTTP 服务器

```java
public class HttpServer {
    private final int port;

    public HttpServer(int port) {
        this.port = port;
    }

    public void start() throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // HTTP 解码器：将字节流解码为 HTTP 请求对象
                     // maxInitialLineLength: 最大初始行长度（默认 4096）
                     // maxHeaderSize: 最大 header 大小（默认 8192）
                     // maxChunkSize: 最大 chunk 大小（默认 8192）
                     p.addLast("decoder", new HttpRequestDecoder());
                     
                     // HTTP 编码器：将 HTTP 响应对象编码为字节流
                     p.addLast("encoder", new HttpResponseEncoder());
                     
                     // HTTP 压缩：支持 gzip 压缩
                     p.addLast("compressor", new HttpContentCompressor());
                     
                     // HTTP 聚合：将 HttpContent 聚合成完整的 FullHttpRequest
                     p.addLast("aggregator", new HttpObjectAggregator(1048576));  // 1MB
                     
                     // 自定义处理器
                     p.addLast("handler", new HttpServerHandler());
                 }
             })
             .option(ChannelOption.SO_BACKLOG, 128)  // 连接队列大小
             .childOption(ChannelOption.SO_KEEPALIVE, true);  // 保持连接
            
            ChannelFuture f = b.bind(port).sync();
            System.out.println("HTTP 服务器已启动，端口：" + port);
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new HttpServer(8080).start();
    }
}

@ChannelHandler.Sharable
public class HttpServerHandler extends SimpleChannelInboundHandler<FullHttpRequest> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpRequest request) throws Exception {
        // 获取请求信息
        HttpMethod method = request.method();
        String uri = request.uri();
        HttpHeaders headers = request.headers();
        
        System.out.println("收到请求：" + method + " " + uri);
        
        // 处理不同请求
        if (uri.equals("/")) {
            sendWelcome(ctx);
        } else if (uri.equals("/api/status")) {
            sendStatus(ctx);
        } else {
            sendNotFound(ctx);
        }
    }
    
    private void sendWelcome(ChannelHandlerContext ctx) {
        String html = "<html><body><h1>Welcome to Netty HTTP Server!</h1></body></html>";
        FullHttpResponse response = new DefaultFullHttpResponse(
            HTTP_1_1, 
            OK, 
            Unpooled.copiedBuffer(html, CharsetUtil.UTF_8)
        );
        response.headers().set(CONTENT_TYPE, "text/html; charset=UTF-8");
        ctx.writeAndFlush(response);
    }
    
    private void sendStatus(ChannelHandlerContext ctx) {
        String json = "{\"status\":\"running\",\"server\":\"Netty\"}";
        FullHttpResponse response = new DefaultFullHttpResponse(
            HTTP_1_1, 
            OK, 
            Unpooled.copiedBuffer(json, CharsetUtil.UTF_8)
        );
        response.headers().set(CONTENT_TYPE, "application/json; charset=UTF-8");
        ctx.writeAndFlush(response);
    }
    
    private void sendNotFound(ChannelHandlerContext ctx) {
        FullHttpResponse response = new DefaultFullHttpResponse(
            HTTP_1_1, 
            NOT_FOUND
        );
        ctx.writeAndFlush(response);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

#### 4.2.2 HTTP 客户端

```java
public class HttpClient {
    public static void main(String[] args) throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();
        
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
             .channel(NioSocketChannel.class)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // HTTP 编解码器
                     p.addLast("codec", new HttpClientCodec());
                     
                     // HTTP 压缩
                     p.addLast("decompressor", new HttpContentDecompressor());
                     
                     // HTTP 聚合
                     p.addLast("aggregator", new HttpObjectAggregator(1048576));
                     
                     // 自定义处理器
                     p.addLast("handler", new HttpClientHandler());
                 }
             });
            
            ChannelFuture f = b.connect("localhost", 8080).sync();
            
            // 发送 GET 请求
            HttpRequest request = new DefaultFullHttpRequest(
                HTTP_1_1, 
                HttpMethod.GET, 
                "/"
            );
            request.headers().set(HttpHeaderNames.HOST, "localhost");
            request.headers().set(HttpHeaderNames.CONNECTION, HttpHeaderValues.CLOSE);
            request.headers().set(HttpHeaderNames.ACCEPT_ENCODING, HttpHeaderValues.GZIP);
            
            f.channel().writeAndFlush(request);
            
            f.channel().closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }
}

public class HttpClientHandler extends SimpleChannelInboundHandler<FullHttpResponse> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpResponse response) throws Exception {
        System.out.println("状态码：" + response.status());
        System.out.println("内容类型：" + response.headers().get(HttpHeaderNames.CONTENT_TYPE));
        
        String content = response.content().toString(CharsetUtil.UTF_8);
        System.out.println("响应内容：" + content);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 4.3 WebSocket 服务器

#### 4.3.1 WebSocket 服务器实现

```java
public class WebSocketServer {
    private final int port;

    public WebSocketServer(int port) {
        this.port = port;
    }

    public void start() throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // HTTP 编解码器（WebSocket 握手需要 HTTP）
                     p.addLast("codec", new HttpServerCodec());
                     
                     // HTTP 聚合器（将多个 HttpContent 聚合成 FullHttpRequest）
                     p.addLast("aggregator", new HttpObjectAggregator(65536));
                     
                     // WebSocket 升级处理器（处理 HTTP 升级到 WebSocket 的握手）
                     p.addLast("upgrade", new WebSocketServerProtocolHandler("/ws"));
                     
                     // 自定义 WebSocket 处理器
                     p.addLast("handler", new WebSocketServerHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            System.out.println("WebSocket 服务器已启动，端口：" + port);
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new WebSocketServer(8080).start();
    }
}

@ChannelHandler.Sharable
public class WebSocketServerHandler extends SimpleChannelInboundHandler<WebSocketFrame> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, WebSocketFrame frame) throws Exception {
        // 判断帧类型
        if (frame instanceof TextWebSocketFrame) {
            // 处理文本消息
            String request = ((TextWebSocketFrame) frame).text();
            System.out.println("收到消息：" + request);
            
            // 回复消息
            ctx.channel().writeAndFlush(new TextWebSocketFrame("服务器回复：" + request));
            
        } else if (frame instanceof PingWebSocketFrame) {
            // 处理 Ping 帧
            ctx.channel().writeAndFlush(new PongWebSocketFrame(frame.content().retain()));
            
        } else if (frame instanceof CloseWebSocketFrame) {
            // 处理关闭帧
            System.out.println("客户端请求关闭连接");
            ctx.channel().writeAndFlush(frame.retainedDuplicate()).addListener(ChannelFutureListener.CLOSE);
        }
    }
    
    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof WebSocketHandshakeCompletionEvent) {
            System.out.println("WebSocket 握手完成");
        }
        super.userEventTriggered(ctx, evt);
    }
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("客户端连接：" + ctx.channel().remoteAddress());
        super.channelActive(ctx);
    }
    
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("客户端断开：" + ctx.channel().remoteAddress());
        super.channelInactive(ctx);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

#### 4.3.2 WebSocket 客户端

```java
public class WebSocketClient {
    public static void main(String[] args) throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();
        
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
             .channel(NioSocketChannel.class)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // HTTP 编解码器
                     p.addLast("codec", new HttpClientCodec());
                     
                     // HTTP 聚合器
                     p.addLast("aggregator", new HttpObjectAggregator(65536));
                     
                     // WebSocket 客户端握手处理器
                     p.addLast("upgrade", new WebSocketClientProtocolHandler(
                         new URI("ws://localhost:8080/ws"),
                         WebSocketVersion.V13,
                         null,  // 自定义子协议
                         true,  // 允许扩展
                         false,  // 不执行相对路径验证
                         8192  // 最大帧大小
                     ));
                     
                     // 自定义 WebSocket 处理器
                     p.addLast("handler", new WebSocketClientHandler());
                 }
             });
            
            ChannelFuture f = b.connect("localhost", 8080).sync();
            System.out.println("已连接到 WebSocket 服务器");
            
            f.channel().closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }
}

public class WebSocketClientHandler extends SimpleChannelInboundHandler<WebSocketFrame> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, WebSocketFrame frame) throws Exception {
        if (frame instanceof TextWebSocketFrame) {
            String response = ((TextWebSocketFrame) frame).text();
            System.out.println("收到服务器消息：" + response);
        } else if (frame instanceof PongWebSocketFrame) {
            System.out.println("收到 Pong 响应");
        } else if (frame instanceof CloseWebSocketFrame) {
            System.out.println("服务器请求关闭连接");
            ctx.close();
        }
    }
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("连接建立");
        
        // 发送测试消息
        ctx.channel().writeAndFlush(new TextWebSocketFrame("Hello WebSocket!"));
        
        super.channelActive(ctx);
    }
    
    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof WebSocketHandshakeCompletionEvent) {
            System.out.println("WebSocket 握手完成");
        }
        super.userEventTriggered(ctx, evt);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 4.4 自定义协议处理器

#### 4.4.1 协议定义

```java
// 假设我们有一个简单的自定义协议：
// +--------+--------+--------+--------+--------+--------+--------+--------+
// | 魔数 (4) | 版本 (1) | 类型 (1) | 长度 (4) |    数据 (N)     | 校验和 (2) |
// +--------+--------+--------+--------+--------+--------+--------+--------+

public class CustomProtocol {
    public static final int MAGIC_NUMBER = 0x12345678;  // 魔数
    public static final byte VERSION = 1;                // 版本号
    
    // 消息类型
    public static final byte TYPE_REQUEST = 1;
    public static final byte TYPE_RESPONSE = 2;
    
    // 协议头长度
    public static final int HEADER_LENGTH = 12;
}
```

#### 4.4.2 编解码器

```java
// === 解码器 ===
public class CustomMessageDecoder extends ByteToMessageDecoder {
    
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        // 1. 检查是否有足够的数据读取头部
        if (in.readableBytes() < CustomProtocol.HEADER_LENGTH) {
            return;  // 数据不足，等待更多数据
        }
        
        // 2. 标记读指针位置
        in.markReaderIndex();
        
        // 3. 读取协议头
        int magicNumber = in.readInt();
        if (magicNumber != CustomProtocol.MAGIC_NUMBER) {
            throw new IllegalArgumentException("无效的魔数：" + magicNumber);
        }
        
        byte version = in.readByte();
        if (version != CustomProtocol.VERSION) {
            throw new IllegalArgumentException("不支持的版本：" + version);
        }
        
        byte type = in.readByte();
        int length = in.readInt();
        
        // 4. 检查是否有足够的数据读取消息体
        if (in.readableBytes() < length) {
            in.resetReaderIndex();  // 重置读指针
            return;  // 数据不足，等待更多数据
        }
        
        // 5. 读取消息体
        byte[] data = new byte[length];
        in.readBytes(data);
        
        // 6. 读取校验和
        short checksum = in.readShort();
        
        // 7. 验证校验和
        if (checksum != calculateChecksum(data)) {
            throw new IllegalArgumentException("校验和验证失败");
        }
        
        // 8. 创建消息对象并添加到输出列表
        CustomMessage message = new CustomMessage(type, data);
        out.add(message);
    }
    
    private short calculateChecksum(byte[] data) {
        int sum = 0;
        for (byte b : data) {
            sum += b;
        }
        return (short) (sum & 0xFFFF);
    }
}

// === 编码器 ===
public class CustomMessageEncoder extends MessageToByteEncoder<CustomMessage> {
    
    @Override
    protected void encode(ChannelHandlerContext ctx, CustomMessage msg, ByteBuf out) throws Exception {
        // 1. 写入魔数
        out.writeInt(CustomProtocol.MAGIC_NUMBER);
        
        // 2. 写入版本号
        out.writeByte(CustomProtocol.VERSION);
        
        // 3. 写入消息类型
        out.writeByte(msg.getType());
        
        // 4. 写入数据长度
        byte[] data = msg.getData();
        out.writeInt(data.length);
        
        // 5. 写入数据
        out.writeBytes(data);
        
        // 6. 计算并写入校验和
        short checksum = calculateChecksum(data);
        out.writeShort(checksum);
    }
    
    private short calculateChecksum(byte[] data) {
        int sum = 0;
        for (byte b : data) {
            sum += b;
        }
        return (short) (sum & 0xFFFF);
    }
}

// === 消息对象 ===
public class CustomMessage {
    private byte type;
    private byte[] data;
    
    public CustomMessage(byte type, byte[] data) {
        this.type = type;
        this.data = data;
    }
    
    public byte getType() {
        return type;
    }
    
    public byte[] getData() {
        return data;
    }
    
    public String getDataAsString() {
        return new String(data, CharsetUtil.UTF_8);
    }
}
```

#### 4.4.3 使用示例

```java
// === 服务器端 ===
public class CustomProtocolServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast("decoder", new CustomMessageDecoder());
                     p.addLast("encoder", new CustomMessageEncoder());
                     p.addLast("handler", new CustomProtocolServerHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

public class CustomProtocolServerHandler extends SimpleChannelInboundHandler<CustomMessage> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, CustomMessage msg) throws Exception {
        System.out.println("收到消息：" + msg.getDataAsString());
        
        // 回复消息
        CustomMessage response = new CustomMessage(
            CustomProtocol.TYPE_RESPONSE, 
            "服务器已收到消息".getBytes(CharsetUtil.UTF_8)
        );
        ctx.writeAndFlush(response);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}

// === 客户端 ===
public class CustomProtocolClient {
    public void start(String host, int port) throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();
        
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
             .channel(NioSocketChannel.class)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast("decoder", new CustomMessageDecoder());
                     p.addLast("encoder", new CustomMessageEncoder());
                     p.addLast("handler", new CustomProtocolClientHandler());
                 }
             });
            
            ChannelFuture f = b.connect(host, port).sync();
            f.channel().closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }
}

public class CustomProtocolClientHandler extends SimpleChannelInboundHandler<CustomMessage> {
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // 连接建立后发送消息
        CustomMessage message = new CustomMessage(
            CustomProtocol.TYPE_REQUEST, 
            "Hello from Client".getBytes(CharsetUtil.UTF_8)
        );
        ctx.writeAndFlush(message);
    }
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, CustomMessage msg) throws Exception {
        System.out.println("收到服务器回复：" + msg.getDataAsString());
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

---

## 五、高级特性

### 5.1 心跳检测

#### 5.1.1 IdleStateHandler 使用

```java
public class HeartbeatServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // 添加空闲状态处理器
                     // readerIdleTime：读空闲时间（秒）
                     // writerIdleTime：写空闲时间（秒）
                     // allIdleTime：读写空闲时间（秒）
                     // 单位：秒
                     p.addLast("idleStateHandler", new IdleStateHandler(30, 0, 0));
                     
                     // 添加心跳处理器
                     p.addLast("heartbeatHandler", new HeartbeatHandler());
                     
                     // 添加业务处理器
                     p.addLast("businessHandler", new BusinessHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

public class HeartbeatHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void userEventTriggered(ChannelHandlerContext ctx, Object evt) throws Exception {
        if (evt instanceof IdleStateEvent) {
            IdleStateEvent event = (IdleStateEvent) evt;
            
            if (event.state() == IdleState.READER_IDLE) {
                // 读空闲超时，客户端可能已经断开
                System.out.println("读空闲超时，关闭连接：" + ctx.channel().remoteAddress());
                ctx.close();
                
            } else if (event.state() == IdleState.WRITER_IDLE) {
                // 写空闲超时，发送心跳包
                System.out.println("写空闲超时，发送心跳包");
                ctx.writeAndFlush("HEARTBEAT");
                
            } else if (event.state() == IdleState.ALL_IDLE) {
                // 读写空闲超时
                System.out.println("读写空闲超时，关闭连接");
                ctx.close();
            }
        }
        
        super.userEventTriggered(ctx, evt);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 5.2 SSL/TLS 加密

#### 5.2.1 SSL 服务器

```java
public class SslServer {
    private final int port;
    private final SslContext sslContext;

    public SslServer(int port, String certChainFile, String keyFile) throws SSLException {
        this.port = port;
        // 初始化 SSL 上下文
        this.sslContext = SslContextBuilder.forServer(new File(certChainFile), new File(keyFile))
                                          .build();
    }

    public void start() throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // 添加 SSL 处理器
                     SslHandler sslHandler = sslContext.newHandler(ch.alloc());
                     p.addLast("ssl", sslHandler);
                     
                     // 添加业务处理器
                     p.addLast("handler", new SslServerHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            System.out.println("SSL 服务器已启动，端口：" + port);
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }

    public static void main(String[] args) throws Exception {
        new SslServer(8443, "server.crt", "server.key").start();
    }
}

public class SslServerHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        System.out.println("SSL 连接建立：" + ctx.channel().remoteAddress());
        super.channelActive(ctx);
    }
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        ByteBuf buf = (ByteBuf) msg;
        System.out.println("收到加密消息：" + buf.toString(CharsetUtil.UTF_8));
        ctx.writeAndFlush(buf);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

#### 5.2.2 SSL 客户端

```java
public class SslClient {
    public static void main(String[] args) throws Exception {
        EventLoopGroup group = new NioEventLoopGroup();
        
        // 信任所有证书（仅用于测试环境）
        SslContext sslContext = SslContextBuilder.forClient()
                                                 .trustManager(InsecureTrustManagerFactory.INSTANCE)
                                                 .build();
        
        try {
            Bootstrap b = new Bootstrap();
            b.group(group)
             .channel(NioSocketChannel.class)
             .handler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // 添加 SSL 处理器
                     p.addLast("ssl", sslContext.newHandler(ch.alloc(), "localhost", 8443));
                     
                     // 添加业务处理器
                     p.addLast("handler", new SslClientHandler());
                 }
             });
            
            ChannelFuture f = b.connect("localhost", 8443).sync();
            System.out.println("已连接到 SSL 服务器");
            f.channel().closeFuture().sync();
        } finally {
            group.shutdownGracefully();
        }
    }
}

public class SslClientHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // 发送加密消息
        ctx.writeAndFlush(Unpooled.copiedBuffer("Hello SSL Server", CharsetUtil.UTF_8));
    }
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        ByteBuf buf = (ByteBuf) msg;
        System.out.println("收到服务器响应：" + buf.toString(CharsetUtil.UTF_8));
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 5.3 数据压缩

#### 5.3.1 压缩处理器

```java
public class CompressionServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // 添加 HTTP 编解码器
                     p.addLast("codec", new HttpServerCodec());
                     
                     // 添加 HTTP 聚合器
                     p.addLast("aggregator", new HttpObjectAggregator(65536));
                     
                     // 添加压缩处理器（出站压缩）
                     // 支持 gzip 和 deflate
                     p.addLast("compressor", new HttpContentCompressor());
                     
                     // 添加解压处理器（入站解压）
                     p.addLast("decompressor", new HttpContentDecompressor());
                     
                     // 添加业务处理器
                     p.addLast("handler", new CompressionServerHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

public class CompressionServerHandler extends SimpleChannelInboundHandler<FullHttpRequest> {
    
    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpRequest request) throws Exception {
        // 获取请求内容
        String content = request.content().toString(CharsetUtil.UTF_8);
        System.out.println("收到请求：" + content);
        
        // 创建响应
        String responseContent = "Hello, this is a compressed response!";
        FullHttpResponse response = new DefaultFullHttpResponse(
            HTTP_1_1,
            OK,
            Unpooled.copiedBuffer(responseContent, CharsetUtil.UTF_8)
        );
        
        // 设置压缩相关的响应头
        response.headers().set(HttpHeaderNames.CONTENT_TYPE, "text/plain; charset=UTF-8");
        response.headers().set(HttpHeaderNames.CONTENT_ENCODING, HttpHeaderValues.GZIP);
        
        ctx.writeAndFlush(response);
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 5.4 零拷贝文件传输

#### 5.4.1 FileRegion 使用

```java
public class FileTransferServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     p.addLast("handler", new FileTransferHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

public class FileTransferHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (msg instanceof String) {
            String request = (String) msg;
            if (request.equals("SEND_FILE")) {
                // 使用 FileRegion 进行零拷贝文件传输
                File file = new File("large_file.dat");
                RandomAccessFile raf = new RandomAccessFile(file, "r");
                FileRegion region = new DefaultFileRegion(raf.getChannel(), 0, file.length());
                
                ctx.writeAndFlush(region).addListener(future -> {
                    if (future.isSuccess()) {
                        System.out.println("文件传输完成");
                    } else {
                        System.out.println("文件传输失败：" + future.cause());
                    }
                    raf.close();  // 关闭文件
                });
            }
        }
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

---

## 六、性能优化

### 6.1 线程模型优化

#### 6.1.1 EventLoopGroup 参数优化

```java
// === 根据 CPU 核心数优化 ===
int availableProcessors = Runtime.getRuntime().availableProcessors();

// Boss Group：通常只需要 1 个线程
EventLoopGroup bossGroup = new NioEventLoopGroup(1);

// Worker Group：建议设置为 CPU 核心数 * 2
EventLoopGroup workerGroup = new NioEventLoopGroup(availableProcessors * 2);

// === 业务耗时操作优化 ===
// 如果 Handler 中有耗时操作，建议使用单独的业务线程池
EventExecutorGroup businessGroup = new DefaultEventExecutorGroup(16);

// 在 Pipeline 中使用业务线程池
pipeline.addLast(businessGroup, "handler", new BusinessHandler());

// === 自定义线程工厂 ===
ThreadFactory threadFactory = new ThreadFactoryBuilder()
    .setNameFormat("netty-worker-%d")
    .setDaemon(false)  // 非守护线程
    .setPriority(Thread.NORM_PRIORITY)
    .setUncaughtExceptionHandler((thread, throwable) -> {
        System.err.println("线程异常：" + thread.getName());
        throwable.printStackTrace();
    })
    .build();

EventLoopGroup workerGroup = new NioEventLoopGroup(
    availableProcessors * 2, 
    threadFactory
);
```

### 6.2 内存优化

#### 6.2.1 ByteBuf 内存管理

```java
// === 使用合适的 ByteBuf 类型 ===
// 对于大文件传输，使用直接缓冲区（避免内存拷贝）
ByteBuf directBuffer = channel.alloc().directBuffer();

// 对于小数据，使用堆缓冲区（分配和释放更快）
ByteBuf heapBuffer = channel.alloc().heapBuffer();

// === 控制缓冲区大小 ===
// 根据实际业务需求设置初始容量
ByteBuf buffer = channel.alloc().buffer(1024);  // 初始容量 1KB

// 设置最大容量限制
ByteBuf buffer = channel.alloc().buffer(1024, 65536);  // 最大 64KB

// === 及时释放 ByteBuf ===
try {
    ByteBuf buffer = channel.alloc().buffer();
    // 使用 buffer
} finally {
    ReferenceCountUtil.release(buffer);  // 确保释放
}

// === 使用 ByteBufHolder ===
ByteBufHolder holder = new DefaultByteBufHolder(buffer);
// holder 会在释放时自动释放内部的 ByteBuf
holder.release();
```

### 6.3 网络参数优化

#### 6.3.1 ChannelOption 配置

```java
ServerBootstrap b = new ServerBootstrap();
b.group(bossGroup, workerGroup)
 .channel(NioServerSocketChannel.class)
 // === 服务端 Channel 配置 ===
 .option(ChannelOption.SO_BACKLOG, 1024)  // 连接队列大小
 .option(ChannelOption.SO_REUSEADDR, true)  // 允许地址重用
 
 // === 子 Channel 配置 ===
 .childOption(ChannelOption.SO_KEEPALIVE, true)  // 保持连接
 .childOption(ChannelOption.TCP_NODELAY, true)  // 禁用 Nagle 算法
 .childOption(ChannelOption.SO_LINGER, 0)  // 立即关闭连接
 .childOption(ChannelOption.SO_RCVBUF, 32 * 1024)  // 接收缓冲区大小 32KB
 .childOption(ChannelOption.SO_SNDBUF, 32 * 1024)  // 发送缓冲区大小 32KB
 .childOption(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5000)  // 连接超时 5秒
 .childHandler(new ServerInitializer());

// === 高吞吐量配置 ===
.childOption(ChannelOption.SO_SNDBUF, 128 * 1024)  // 增大发送缓冲区
.childOption(ChannelOption.SO_RCVBUF, 128 * 1024)  // 增大接收缓冲区
.childOption(ChannelOption.WRITE_BUFFER_HIGH_WATER_MARK, 32 * 1024)  // 写缓冲区高水位
.childOption(ChannelOption.WRITE_BUFFER_LOW_WATER_MARK, 8 * 1024);   // 写缓冲区低水位
```

### 6.4 编解码优化

#### 6.4.1 使用堆外内存

```java
// === 使用堆外内存减少拷贝 ===
public class ZeroCopyEncoder extends MessageToByteEncoder<byte[]> {
    
    @Override
    protected void encode(ChannelHandlerContext ctx, byte[] data, ByteBuf out) throws Exception {
        // 直接写入堆外内存，避免中间缓冲区
        out.writeBytes(data);
    }
}

// === 使用 CompositeByteBuf ===
public class CompositeEncoder extends MessageToByteEncoder<List<byte[]>> {
    
    @Override
    protected void encode(ChannelHandlerContext ctx, List<byte[]> dataList, ByteBuf out) throws Exception {
        // 使用 CompositeByteBuf 组合多个 ByteBuf，避免内存拷贝
        CompositeByteBuf compositeBuf = Unpooled.compositeBuffer();
        
        for (byte[] data : dataList) {
            ByteBuf buffer = Unpooled.wrappedBuffer(data);
            compositeBuf.addComponent(true, buffer);
        }
        
        out.writeBytes(compositeBuf);
    }
}
```

---

## 七、常见问题

### 7.1 内存泄漏

#### 7.1.1 ByteBuf 泄漏检测

```java
// === 启用内存泄漏检测 ===
// 在 JVM 参数中添加：
// -Dio.netty.leakDetection.level=paranoid

// 级别：
// simple：检测 1% 的 ByteBuf（默认）
// advanced：检测所有 ByteBuf，显示创建位置
// paranoid：检测所有 ByteBuf，并报告所有访问路径

// === 使用 ResourceLeakDetector ===
// 自定义泄漏检测
ResourceLeakDetector<ByteBuf> leakDetector = new ResourceLeakDetector<>(
    ByteBuf.class, 
    ResourceLeakDetector.Level.PARANOID
);

ByteBuf buffer = Unpooled.buffer();
ResourceLeakTracker<ByteBuf> tracker = leakDetector.track(buffer);

// 使用完成后关闭 tracker
tracker.close(buffer);
```

#### 7.1.2 常见泄漏场景

```java
// === 场景1：未释放 ByteBuf ===
// ❌ 错误写法
ByteBuf buffer = channel.alloc().buffer();
buffer.writeBytes(data);
// 忘记释放 buffer

// ✅ 正确写法
ByteBuf buffer = channel.alloc().buffer();
try {
    buffer.writeBytes(data);
    // 使用 buffer
} finally {
    ReferenceCountUtil.release(buffer);
}

// === 场景2：Handler 中未释放 msg ===
// ❌ 错误写法
@Override
public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
    ByteBuf buf = (ByteBuf) msg;
    System.out.println(buf.toString());
    // 忘记释放 msg
}

// ✅ 正确写法
@Override
public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
    try {
        ByteBuf buf = (ByteBuf) msg;
        System.out.println(buf.toString());
    } finally {
        ReferenceCountUtil.release(msg);
    }
}

// === 场景3：SimpleChannelInboundHandler 自动释放 ===
// ✅ 推荐写法
@Override
protected void channelRead0(ChannelHandlerContext ctx, String msg) throws Exception {
    // SimpleChannelInboundHandler 会自动释放 msg
    System.out.println(msg);
}

// === 场景4：ChannelFutureListener 中泄漏 ===
// ❌ 错误写法
ctx.writeAndFlush(buffer).addListener(future -> {
    if (!future.isSuccess()) {
        System.out.println("发送失败");
    }
    // buffer 在失败时可能没有被释放
});

// ✅ 正确写法
ctx.writeAndFlush(buffer).addListener(future -> {
    if (!future.isSuccess()) {
        System.out.println("发送失败");
        ReferenceCountUtil.release(buffer);
    }
});
```

### 7.2 粘包拆包问题

#### 7.2.1 问题说明

```java
/*
粘包问题：
客户端发送两条消息：
  "Hello"
  "World"
服务端可能收到：
  "HelloWorld"（两条消息粘在一起）

拆包问题：
客户端发送一条消息：
  "Hello World, this is a long message"
服务端可能收到：
  "Hello Wo"
  "rld, this is a long message"（一条消息被拆成多条）
*/
```

#### 7.2.2 解决方案

```java
// === 方案1：固定长度帧解码器 ===
// 每个消息固定 10 个字节
pipeline.addLast("fixedLengthFrameDecoder", new FixedLengthFrameDecoder(10));

// === 方案2：行分隔符解码器 ===
// 使用换行符作为消息分隔符
pipeline.addLast("lineBasedFrameDecoder", new LineBasedFrameDecoder(8192));

// === 方案3：分隔符解码器 ===
// 使用自定义分隔符
ByteBuf delimiter = Unpooled.copiedBuffer("\t".getBytes());
pipeline.addLast("delimiterFrameDecoder", new DelimiterBasedFrameDecoder(8192, delimiter));

// === 方案4：长度域解码器 ===
// 消息格式：长度(4字节) + 数据
// maxFrameLength: 最大帧长度
// lengthFieldOffset: 长度字段偏移量
// lengthFieldLength: 长度字段字节数
// lengthAdjustment: 长度调整值
// initialBytesToStrip: 跳过的字节数
pipeline.addLast("lengthFieldBasedDecoder", new LengthFieldBasedFrameDecoder(
    65535,      // maxFrameLength
    0,          // lengthFieldOffset
    4,          // lengthFieldLength
    0,          // lengthAdjustment
    4           // initialBytesToStrip
));

// === 方案5：自定义协议解码器 ===
public class CustomProtocolDecoder extends ByteToMessageDecoder {
    
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) throws Exception {
        // 等待至少有 4 字节（长度字段）
        if (in.readableBytes() < 4) {
            return;
        }
        
        in.markReaderIndex();  // 标记读指针
        
        int length = in.readInt();  // 读取长度
        
        // 检查是否有足够的数据
        if (in.readableBytes() < length) {
            in.resetReaderIndex();  // 重置读指针
            return;  // 等待更多数据
        }
        
        // 读取数据
        byte[] data = new byte[length];
        in.readBytes(data);
        
        // 创建消息对象
        CustomMessage message = new CustomMessage(data);
        out.add(message);
    }
}
```

### 7.3 连接超时处理

#### 7.3.1 连接超时配置

```java
// === 方式1：通过 ChannelOption 配置 ===
Bootstrap b = new Bootstrap();
b.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5000);  // 5秒超时

// === 方式2：使用 ReadTimeoutHandler ===
pipeline.addLast("readTimeoutHandler", new ReadTimeoutHandler(30, TimeUnit.SECONDS));

// === 方式3：使用 WriteTimeoutHandler ===
pipeline.addLast("writeTimeoutHandler", new WriteTimeoutHandler(30, TimeUnit.SECONDS));

// === 方式4：自定义超时处理 ===
public class ConnectTimeoutHandler extends ChannelInboundHandlerAdapter {
    
    private final long timeoutMillis;
    private ScheduledFuture<?> timeoutFuture;
    
    public ConnectTimeoutHandler(long timeoutMillis) {
        this.timeoutMillis = timeoutMillis;
    }
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        // 设置超时任务
        timeoutFuture = ctx.executor().schedule(() -> {
            if (ctx.channel().isActive()) {
                System.out.println("连接超时，关闭连接");
                ctx.close();
            }
        }, timeoutMillis, TimeUnit.MILLISECONDS);
        
        super.channelActive(ctx);
    }
    
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        // 取消超时任务
        if (timeoutFuture != null) {
            timeoutFuture.cancel(false);
        }
        super.channelInactive(ctx);
    }
}
```

### 7.4 大文件传输

#### 7.4.1 ChunkedWriteHandler 使用

```java
public class LargeFileServer {
    public void start(int port) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup(1);
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        
        try {
            ServerBootstrap b = new ServerBootstrap();
            b.group(bossGroup, workerGroup)
             .channel(NioServerSocketChannel.class)
             .childHandler(new ChannelInitializer<SocketChannel>() {
                 @Override
                 protected void initChannel(SocketChannel ch) throws Exception {
                     ChannelPipeline p = ch.pipeline();
                     
                     // 添加分块写入处理器（支持大文件传输）
                     p.addLast("chunkedWriteHandler", new ChunkedWriteHandler());
                     
                     // 添加业务处理器
                     p.addLast("handler", new LargeFileHandler());
                 }
             });
            
            ChannelFuture f = b.bind(port).sync();
            f.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}

public class LargeFileHandler extends ChannelInboundHandlerAdapter {
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        if (msg instanceof String && ((String) msg).equals("SEND_LARGE_FILE")) {
            // 使用 ChunkedWriteHandler 发送大文件
            File file = new File("large_file.dat");
            RandomAccessFile raf = new RandomAccessFile(file, "r");
            
            // 使用 ChunkedFile 进行分块传输
            ChunkedFile chunkedFile = new ChunkedFile(raf, 8192);  // 每块 8KB
            
            ctx.writeAndFlush(chunkedFile).addListener(future -> {
                if (future.isSuccess()) {
                    System.out.println("大文件传输完成");
                } else {
                    System.out.println("大文件传输失败：" + future.cause());
                }
                raf.close();
            });
        }
    }
    
    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
        cause.printStackTrace();
        ctx.close();
    }
}
```

### 7.5 性能监控

#### 7.5.1 监控指标

```java
public class NettyMetricsHandler extends ChannelDuplexHandler {
    
    // 记录连接时间
    private long connectTime;
    
    // 记录接收字节数
    private final AtomicLong receivedBytes = new AtomicLong(0);
    
    // 记录发送字节数
    private final AtomicLong sentBytes = new AtomicLong(0);
    
    // 记录接收消息数
    private final AtomicLong receivedMessages = new AtomicLong(0);
    
    // 记录发送消息数
    private final AtomicLong sentMessages = new AtomicLong(0);
    
    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        connectTime = System.currentTimeMillis();
        System.out.println("连接建立：" + ctx.channel().remoteAddress());
        super.channelActive(ctx);
    }
    
    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        long duration = System.currentTimeMillis() - connectTime;
        System.out.println("连接断开：" + ctx.channel().remoteAddress());
        System.out.println("连接时长：" + duration + "ms");
        System.out.println("接收字节：" + receivedBytes.get());
        System.out.println("发送字节：" + sentBytes.get());
        System.out.println("接收消息：" + receivedMessages.get());
        System.out.println("发送消息：" + sentMessages.get());
        super.channelInactive(ctx);
    }
    
    @Override
    public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
        receivedMessages.incrementAndGet();
        
        if (msg instanceof ByteBuf) {
            ByteBuf buf = (ByteBuf) msg;
            receivedBytes.addAndGet(buf.readableBytes());
        }
        
        super.channelRead(ctx, msg);
    }
    
    @Override
    public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
        sentMessages.incrementAndGet();
        
        if (msg instanceof ByteBuf) {
            ByteBuf buf = (ByteBuf) msg;
            sentBytes.addAndGet(buf.readableBytes());
        }
        
        super.write(ctx, msg, promise);
    }
}
```

---

## 总结

### 学习路线

1. **基础阶段**：理解 EventLoop 模型、Channel、Pipeline 等核心概念
2. **实践阶段**：从简单的 Echo 服务器开始，逐步实现 HTTP、WebSocket 等协议
3. **进阶阶段**：掌握自定义协议、编解码器、性能优化等高级特性
4. **实战阶段**：结合实际项目需求，应用到生产环境中

### 重点回顾

- **ByteBuf**：理解读写索引、引用计数、内存管理
- **ChannelHandler**：区分入站和出站处理器，正确传递事件
- **Pipeline**：理解处理器的添加顺序和数据流向
- **EventLoop**：理解线程模型和异步执行机制
- **编解码器**：掌握粘包拆包问题的解决方案
- **内存管理**：正确释放 ByteBuf，避免内存泄漏

### 推荐资源

- **官方文档**：[Netty 官方文档](https://netty.io/wiki/user-guide.html)
- **源码阅读**：推荐阅读 Netty 源码，理解底层实现
- **实战项目**：Dubbo、RocketMQ、Elasticsearch 等开源项目的 Netty 使用

---

**创建时间**：2025-01-23  
**标签**：`#netty` `#网络编程` `#java` `#高性能`  
**相关笔记**：[[Java-IO模型-NIO与AIO详解.md]] | [[IO优化-零拷贝-MMAP-DMA详解.md]]