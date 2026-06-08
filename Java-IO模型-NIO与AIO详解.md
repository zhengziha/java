# Java IO 模型：NIO 与 AIO 详解

> 独立专题笔记，汇总入口见 [java学习笔记汇总](./java学习笔记汇总.md)

---

## 一、背景：为什么需要 NIO / AIO？

传统 **BIO（Blocking IO）** 模型：

```
客户端连接 → 服务端为每个连接创建一个线程 → 线程阻塞在 read/write 上等待数据
```

连接数上千时，线程数爆炸、上下文切换频繁、内存占用高。  
NIO 和 AIO 的目标：**用更少的线程处理更多的连接**。

---

## 二、先搞清两个维度（面试必考）

| 维度 | 含义 | 判断方式 |
|------|------|----------|
| **阻塞 / 非阻塞** | 线程发起 IO 后，是否立刻挂起等待 | 看 **线程** 是否卡住 |
| **同步 / 异步** | 数据拷贝完成后，谁负责通知调用方 | 看 **结果通知** 由谁完成 |

两者正交，可组合成四种模型：

| 模型 | 说明 | Java 代表 |
|------|------|-----------|
| **同步阻塞** | 线程自己等数据就绪，并自己完成拷贝 | BIO、`InputStream.read()` |
| **同步非阻塞** | 线程轮询/多路复用等就绪，自己完成拷贝 | **NIO** + Selector |
| **异步阻塞** | 内核完成拷贝后通知，但线程仍阻塞等通知 | 较少见 |
| **异步非阻塞** | 内核完成拷贝后回调，线程不阻塞 | **AIO** + CompletionHandler |

**易混点**：
- NIO 的 `Selector.select()` 会让线程阻塞，但它是 **同步非阻塞**——因为数据就绪后，仍由应用线程自己 `read()` 拷贝数据
- AIO 的 `read()` 提交后立即返回，数据就绪 + 拷贝完成后由 **回调** 通知，才是 **异步非阻塞**

---

## 三、BIO 简要对比（Baseline）

```
ServerSocket.accept()  → 阻塞，直到有客户端连接
socket.getInputStream().read()  → 阻塞，直到有数据可读
```

| 特点 | 说明 |
|------|------|
| 模型 | 一连接一线程 |
| 优点 | 编程简单，逻辑直观 |
| 缺点 | 连接数多时线程开销大，C10K 问题 |
| 适用 | 连接数少、逻辑简单的场景 |

---

## 四、NIO（New IO / Non-blocking IO）

JDK 1.4 引入，核心包：`java.nio.*`

### 1. 三大核心组件

| 组件 | 作用 | 类比 |
|------|------|------|
| **Buffer** | 数据容器，读写都经过 Buffer | 货车 |
| **Channel** | 双向通道，连接 Buffer 与 IO 源/目标 | 管道 |
| **Selector** | 多路复用器，一个线程监听多个 Channel 事件 | 调度员 |

### 2. Buffer 要点

```java
ByteBuffer buffer = ByteBuffer.allocate(1024);       // 堆内存
ByteBuffer direct  = ByteBuffer.allocateDirect(1024); // 直接内存（堆外）

buffer.put(data);   // 写模式
buffer.flip();    // 切换为读模式：limit=position, position=0
buffer.get();     // 读
buffer.clear();   // 清空，切换回写模式
```

| 方法 | 作用 |
|------|------|
| `flip()` | 写 → 读 |
| `clear()` | 清空，写模式 |
| `compact()` | 未读数据移到开头，继续写 |
| `rewind()` | 重新读 |

- **堆内存 Buffer**：分配快，读写多一次拷贝（堆 ↔ 内核）
- **DirectBuffer**：堆外内存，减少拷贝，适合网络 IO；分配慢，需手动释放或 GC 回收

### 3. Channel 常见类型

| Channel | 用途 |
|---------|------|
| `FileChannel` | 文件读写，`transferTo()` 零拷贝 |
| `SocketChannel` | TCP 客户端 |
| `ServerSocketChannel` | TCP 服务端 |
| `DatagramChannel` | UDP |

Channel 是 **双向** 的（Stream 只能单向）。

### 4. Selector 多路复用

```java
Selector selector = Selector.open();
channel.configureBlocking(false);  // 必须非阻塞
channel.register(selector, SelectionKey.OP_READ);

while (true) {
    selector.select();  // 阻塞，直到有 Channel 就绪（可设超时）
    Set<SelectionKey> keys = selector.selectedKeys();
    for (SelectionKey key : keys) {
        if (key.isReadable()) {
            // 读数据
        }
        if (key.isAcceptable()) {
            // 接受连接
        }
    }
    keys.clear();
}
```

**监听事件**：
- `OP_ACCEPT`：新连接
- `OP_READ`：可读
- `OP_WRITE`：可写
- `OP_CONNECT`：连接完成

**底层实现**（OS 差异）：
- Linux：`epoll`（O(1)，高效）
- macOS/BSD：`kqueue`
- Windows：`select`（O(n)，有连接数上限）

JDK 的 Selector 在不同 OS 上自动选择实现（`EPollSelectorProvider` 等）。

### 5. NIO 服务端典型流程

```
1. ServerSocketChannel 设为非阻塞
2. 注册 OP_ACCEPT 到 Selector
3. loop:
     select() 等待事件
     → ACCEPT: 接受连接，新 SocketChannel 注册 OP_READ
     → READ:   读取数据，业务处理，必要时注册 OP_WRITE
     → WRITE:  写回响应
```

**一个线程（或少量线程）可管理成千上万个连接**。

### 6. NIO 优缺点

| 优点 | 缺点 |
|------|------|
| 单线程/少线程高并发 | 编程复杂（边界、半包粘包） |
| 基于事件驱动，资源占用低 | Buffer 需手动 flip/clear |
| Netty 等框架成熟 | 空轮询 Bug（epoll 早期 JDK 问题） |

---

## 五、AIO（Asynchronous IO / NIO.2）

JDK 7 引入（`java.nio.channels` 包下的异步 Channel），也叫 **NIO.2**。

### 1. 核心概念

| 组件 | 作用 |
|------|------|
| **AsynchronousChannel** | 异步 Channel 基类 |
| **AsynchronousServerSocketChannel** | 异步 TCP 服务端 |
| **AsynchronousSocketChannel** | 异步 TCP 客户端 |
| **CompletionHandler** | 异步完成回调 |
| **Future** | 也可用 Future 阻塞获取结果 |

### 2. 两种使用方式

**方式一：CompletionHandler 回调（真·异步）**

```java
AsynchronousServerSocketChannel server =
    AsynchronousServerSocketChannel.open().bind(new InetSocketAddress(8080));

server.accept(null, new CompletionHandler<AsynchronousSocketChannel, Void>() {
    @Override
    public void completed(AsynchronousSocketChannel channel, Void attachment) {
        server.accept(null, this);  // 继续接受下一个连接

        ByteBuffer buffer = ByteBuffer.allocate(1024);
        channel.read(buffer, buffer, new CompletionHandler<Integer, ByteBuffer>() {
            @Override
            public void completed(Integer result, ByteBuffer buf) {
                buf.flip();
                // 处理数据，再 write ...
            }
            @Override
            public void failed(Throwable exc, ByteBuffer buf) { /* 异常 */ }
        });
    }
    @Override
    public void failed(Throwable exc, Void attachment) { /* 异常 */ }
});
```

**方式二：Future 阻塞等待**

```java
Future<Integer> future = channel.read(buffer);
// 做其他事 ...
Integer bytesRead = future.get();  // 阻塞等结果
```

### 3. 底层线程模型

AIO 依赖 **AsynchronousChannelGroup**：
- 内部维护线程池
- IO 操作提交给 OS 或线程池
- 完成后回调 CompletionHandler

### 4. 重要坑：Linux 上 AIO 的真实实现

| OS | 底层实现 | 效果 |
|----|----------|------|
| **Windows** | IOCP（真正的异步 IO） | 性能好 |
| **Linux** | **JDK 用 epoll + 线程池模拟**，并非原生 libaio | 性能常不如 NIO + Netty |
| **macOS** | 类似模拟 | 实际很少用 |

> 面试常考：**Java AIO 在 Linux 上并不是真正的内核级异步 IO**，所以 Netty 等高性能框架仍选 NIO（epoll），而非 AIO。

### 5. AIO 优缺点

| 优点 | 缺点 |
|------|------|
| 回调模型，逻辑上「异步」 | Linux 下性能不占优 |
| 适合连接数极多、IO 操作长 | 回调嵌套（回调地狱） |
| Windows 上 IOCP 性能好 | 生态和资料远少于 NIO/Netty |

---

## 六、BIO / NIO / AIO 对比总表

| 对比项 | BIO | NIO | AIO |
|--------|-----|-----|-----|
| **IO 类型** | 流 Stream | 块 Buffer + Channel | 异步 Channel |
| **阻塞** | 阻塞 | 非阻塞（Channel）+ select 可阻塞 | 非阻塞 |
| **同步/异步** | 同步 | 同步 | 异步 |
| **线程模型** | 一连接一线程 | 少线程 + 多路复用 | 线程池 + 回调 |
| **编程难度** | 低 | 中 | 高 |
| **适用场景** | 连接少 | 高并发网络（Netty） | Windows IOCP；Linux 实际少用 |
| **Java API** | `java.io.*` | `java.nio.*` | `java.nio.channels`（AIO） |
| **代表框架** | Tomcat BIO（老） | Netty、Tomcat NIO | 几乎没有主流框架 |

---

## 七、与 Netty 的关系

```
Netty = NIO + 高性能封装
      = Reactor 模式 + 零拷贝 + 内存池 + 责任链 Pipeline
```

| 角色 | 职责 |
|------|------|
| **Boss EventLoop** | 处理 OP_ACCEPT |
| **Worker EventLoop** | 处理 OP_READ / OP_WRITE |

Netty **不用 AIO**，原因：Linux 下 AIO 无优势，NIO（epoll）更成熟。

---

## 八、选型建议

| 场景 | 推荐 |
|------|------|
| 连接少、内部系统 | BIO 够用 |
| 高并发 TCP（网关、RPC、Web） | **NIO + Netty** |
| 大文件异步读写（Windows） | 可考虑 AIO |
| Linux 生产环境 | **优先 NIO/Netty**，慎用 AIO |

---

## 九、面试简答模板

**NIO 是什么？三大组件？**
> NIO 是同步非阻塞 IO。核心是 Buffer 存数据、Channel 双向传输、Selector 多路复用一个线程监听多个 Channel 的 ACCEPT/READ/WRITE 事件，适合高并发。

**NIO 和 BIO 区别？**
> BIO 一连接一线程，线程阻塞在 read/write；NIO 用 Selector 多路复用，少量线程管大量连接，Channel 非阻塞，数据就绪后应用线程自己 read 拷贝。

**AIO 和 NIO 区别？**
> NIO 同步非阻塞：数据就绪后应用线程自己读；AIO 异步非阻塞：提交 IO 后立即返回，内核/线程池完成读写后通过 CompletionHandler 回调。但 Linux 下 Java AIO 用 epoll 模拟，性能不如 NIO+Netty。

**为什么 Netty 用 NIO 不用 AIO？**
> Linux 是服务器主流 OS，Java AIO 在 Linux 上并非真异步 IO，底层仍是 epoll+线程池；NIO 更成熟、可控，配合 Reactor 模型性能更好。

---

[← 返回 java学习笔记汇总](./java学习笔记汇总.md)
