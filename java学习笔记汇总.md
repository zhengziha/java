# Java 学习笔记汇总

> 格式说明：每个知识点含 **说明**（快速理解）和 **面试要点**（高频考点，便于背诵）

---

## java基础

### JDK、JRE、JVM
- **说明**：JDK = 开发工具包（含 JRE + 编译器 javac 等）；JRE = 运行环境（JVM + 核心类库）；JVM = 虚拟机，负责字节码执行、内存管理、GC
- **面试要点**：
  - 三者包含关系：JDK ⊃ JRE ⊃ JVM
  - 跨平台靠 JVM：一次编译，到处运行（字节码 + 不同 OS 的 JVM 实现）
  - JDK 8 后 Oracle 收费策略变化，OpenJDK 成为主流

### 字符串常量池
- **说明**：JDK 1.7 起常量池从方法区（永久代）移到堆中；`String s = "abc"` 直接入池；`new String("abc")` 在堆中创建对象，可能引用池中 `"abc"`
- **面试要点**：
  - `String a = "ab"; String b = "a" + "b";` → `a == b` 为 true（编译期常量折叠）
  - `String c = new String("ab");` → `a == c` 为 false（堆 vs 池）
  - `intern()` 作用：将堆中字符串引用放入常量池并返回池引用
  - 拼接：`+` 在循环中效率低，用 `StringBuilder`

### 对象池化
- **说明**：复用已创建对象减少 GC 压力，如 Integer 缓存 -128~127、String 常量池、数据库连接池
- **面试要点**：
  - `Integer.valueOf(127) == Integer.valueOf(127)` → true；128 则 false
  - 池化适用：创建成本高、使用频繁、状态可重置的对象

### == 与 equals
- **说明**：`==` 比较引用地址（基本类型比较值）；`equals` 默认同 `==`，String/包装类重写后比较内容
- **面试要点**：
  - 重写 `equals` 必须同时重写 `hashCode`（HashMap 等依赖）
  - `equals` 满足：自反、对称、传递、一致、非空
  - 比较 String 用 `equals`，不要用 `==`

### hashCode
- **说明**：对象哈希值，用于 HashMap 等散列结构定位桶位置；相同对象 hashCode 必须相同，不同对象可能相同（哈希冲突）
- **面试要点**：
  - 重写规则：equals 相等 → hashCode 必相等；hashCode 相等 ≠ equals 相等
  - HashMap 先比 hashCode 定位桶，再 equals 比 key

### final、finally、finalize
- **说明**：`final` 修饰类不可继承、方法不可重写、变量不可改；`finally` 异常处理中必执行块（除非 JVM 退出）；`finalize` 对象 GC 前回调，已废弃（JDK 9 标记 deprecated）
- **面试要点**：
  - `final` 变量赋值时机：声明时、代码块、构造器（三者选一）
  - `finally` 中 return 会覆盖 try/catch 的 return
  - 不要用 `finalize` 做资源释放，用 try-with-resources

### 反射
- **说明**：运行时动态获取类信息、创建对象、调用方法；核心类：Class、Method、Field、Constructor
- **面试要点**：
  - 获取 Class：`类名.class`、`对象.getClass()`、`Class.forName()`
  - 破坏封装：`setAccessible(true)` 访问 private
  - 缺点：性能低、破坏封装；框架（Spring、MyBatis）大量使用

### 集合
- **说明**：Collection（List/Set/Queue）和 Map 两大体系；ArrayList 数组、LinkedList 双向链表、HashSet 基于 HashMap
- **面试要点**：
  - List 有序可重复，Set 无序不重复，Map 键值对
  - ArrayList 扩容 1.5 倍；LinkedList 增删快查慢
  - HashMap 线程不安全，ConcurrentHashMap 线程安全

### HashMap & ConcurrentHashMap
- **说明**：HashMap 数组+链表+红黑树（链表长度≥8 且数组≥64 转红黑树）；ConcurrentHashMap JDK7 分段锁，JDK8 CAS+synchronized 锁桶头节点
- **面试要点**：
  - **put 流程**：算 hash → 定位桶 → 无冲突直接放 → 有冲突拉链表/树 → 超阈值扩容 2 倍
  - 初始容量 16，负载因子 0.75，容量始终 2 的幂（便于位运算取模）
  - 线程不安全场景：多线程 put 可能死循环（JDK7）或数据丢失
  - ConcurrentHashMap 不允许 null key/value（二义性：无法区分「不存在」和「值为 null」）
  - size 统计：JDK8 用 baseCount + CounterCell 数组求和

### 4 种引用类型
- **说明**：强引用（默认，GC 不回收）、软引用（内存不足才回收，适合缓存）、弱引用（下次 GC 必回收，ThreadLocal key）、虚引用（跟踪 GC，PhantomReference）
- **面试要点**：
  - 软引用 → SoftReference，适合做图片/网页缓存
  - 弱引用 → WeakReference，ThreadLocal 内存泄漏根源
  - 虚引用必须配合 ReferenceQueue 使用

---

## 多线程

### 线程与进程概念
- **说明**：进程是资源分配最小单位（独立内存空间）；线程是 CPU 调度最小单位，共享进程内存
- **面试要点**：
  - 一个进程可含多个线程，线程切换开销小于进程
  - 线程共享堆和方法区，各自拥有栈和程序计数器

### 线程的常用方法
- **说明**：`start()` 启动新线程；`run()` 线程体；`sleep()` 不释放锁；`wait()` 释放锁并等待；`notify()/notifyAll()` 唤醒；`join()` 等待线程结束；`yield()` 让出 CPU
- **面试要点**：
  - `start()` vs `run()`：start 创建新线程，run 只是普通方法调用
  - `sleep()` 不释放锁，`wait()` 必须在 synchronized 中且释放锁
  - `notifyAll()` 唤醒所有等待线程，notify 随机唤醒一个

### 线程的生命周期
- **说明**：NEW → RUNNABLE → BLOCKED（等锁）/ WAITING（wait/join）/ TIMED_WAITING（sleep）→ TERMINATED
- **面试要点**：
  - RUNNABLE 包含 Running 和 Ready（就绪）
  - BLOCKED 等 synchronized 锁；WAITING 等 notify

### Synchronized 和 ReentrantLock
- **说明**：synchronized JVM 层面，自动加解锁，不可中断；ReentrantLock JDK API，可中断、可公平、可多个 Condition
- **面试要点**：
  - synchronized 锁升级：无锁 → 偏向锁 → 轻量级锁 → 重量级锁
  - ReentrantLock 需手动 lock/unlock，必须在 finally 中 unlock
  - 选 synchronized：简单场景；选 ReentrantLock：需要公平锁、可中断、多条件队列

### 线程的安全划分
- **不可变对象**（String、Integer 等）：状态不可变，天然线程安全
- **绝对线程安全**（CopyOnWriteArrayList/Set）：所有操作都线程安全
- **相对线程安全**（Vector）：单个操作安全，复合操作需额外同步
- **非安全**（ArrayList、LinkedList、HashMap）：多线程需外部同步
- **面试要点**：Vector 的 `if(!contains) add()` 仍不安全，需 synchronized 包裹

### 线程安全三特性
- **原子性**：操作不可分割，要么全做要么不做 → synchronized、Lock、Atomic 类
- **可见性**：一个线程修改对其他线程可见 → volatile、synchronized、final
- **有序性**：禁止指令重排 → volatile（禁止特定重排）、happens-before 规则
- **面试要点**：
  - as-if-serial：单线程内重排不影响结果
  - happens-before 8 条规则：程序次序、锁、volatile、线程 start/join 等

### 常用线程池
- **说明**：Executors 提供 FixedThreadPool、CachedThreadPool、SingleThreadExecutor、ScheduledThreadPool；生产推荐 ThreadPoolExecutor 自定义
- **面试要点**：
  - 不用 Executors 创建：Fixed/Cached 队列或线程数无界，可能 OOM
  - IO 密集型：线程数 ≈ CPU 核数 × 2；CPU 密集型 ≈ CPU 核数 + 1

### 线程池 7 个参数
- **说明**：corePoolSize、maximumPoolSize、keepAliveTime、unit、workQueue、threadFactory、handler
- **面试要点**：
  - 执行顺序：核心线程 → 队列 → 非核心线程 → 拒绝策略
  - 队列选型：ArrayBlockingQueue 有界、LinkedBlockingQueue 可无界、SynchronousQueue 不存元素

### 线程池工作原理
- **说明**：提交任务 → 核心未满则创建核心线程 → 已满则入队 → 队列满则创建非核心线程 → 达最大则拒绝
- **面试要点**：能口述完整流程；核心线程默认不回收（allowCoreThreadTimeOut 可改）

### 线程池拒绝策略
- **AbortPolicy**：抛 RejectedExecutionException（默认）
- **CallerRunsPolicy**：调用者线程执行，起到降级/背压作用
- **DiscardOldestPolicy**：丢弃队列最老任务，再提交新任务
- **DiscardPolicy**：静默丢弃
- **面试要点**：CallerRunsPolicy 适合不允许丢任务的场景；AbortPolicy 配合监控告警

### ThreadLocal
- **说明**：每个线程独立副本，底层 ThreadLocalMap 以 ThreadLocal 为 key（弱引用），value 存在 Entry 中
- **面试要点**：
  - 内存泄漏：key 被 GC 但 value 仍被 Thread 强引用 → 用完必须 `remove()`
  - 原理：Thread 持有 ThreadLocalMap，get/set 操作当前线程的 Map
  - InheritableThreadLocal：子线程可继承父线程值（创建子线程时复制）
  - 应用场景：用户信息上下文、SimpleDateFormat 线程安全、数据库连接

### CopyOnWrite 原理
- **说明**：写时复制，写操作加锁并复制新数组，读无锁；适合读多写少
- **面试要点**：
  - 缺点：写开销大、数据短暂不一致
  - 迭代器弱一致性，不会抛 ConcurrentModificationException

### ConcurrentHashMap 读写与红黑树
- **说明**：读无锁（volatile 保证可见）；写 CAS 或 synchronized 锁桶头节点；链表≥8 转红黑树，≤6 退化为链表
- **面试要点**：
  - 为何不用 null：get 返回 null 无法区分「不存在」和「值为 null」
  - size 统计用 LongAdder 思想（CounterCell 分散热点）

### 死锁的检测和定位
- **说明**：两个以上线程互相等待对方持有的锁；条件：互斥、占有且等待、不可抢占、循环等待
- **面试要点**：
  - 排查：`jstack <pid>` 看 "Found one Java-level deadlock"
  - 预防：固定加锁顺序、tryLock 超时、银行家算法
  - 压测指标：吞吐量、响应时间 P99、CPU、内存、GC

---

## 并发编程

### Java 内存可见性
- **说明**：每个 CPU 有独立缓存，线程修改变量可能只更新本地缓存，其他线程不可见
- **面试要点**：
  - 缓存行伪共享：不同变量在同一缓存行，一个核修改导致其他核缓存失效 → @Contended、padding 解决
  - 多核 CPU 缓存不共享，需内存屏障/volatile 保证可见性

### JMM（Java 内存模型）
- **说明**：定义主内存与工作内存交互规则，屏蔽硬件差异，保证并发语义
- **面试要点**：
  - **volatile**：保证可见性 + 禁止指令重排，不保证原子性（i++ 不安全）
  - **CAS**：Compare And Swap，CPU 原子指令，ABA 问题用版本号解决（AtomicStampedReference）
  - happens-before 是 JMM 对开发者的保证，volatile 写 happens-before 后续读

### 锁的分类
- **可重入/不可重入**：同一线程能否重复获取同一把锁（synchronized、ReentrantLock 可重入）
- **乐观/悲观**：乐观 CAS 无冲突直接改，悲观先加锁（synchronized）
- **公平/非公平**：公平按申请顺序，非公平可插队（ReentrantLock 默认非公平，吞吐更高）
- **互斥/共享**：互斥锁独占，共享锁多读（ReadWriteLock 读锁共享、写锁互斥）

### CAS 与 Java 锁底层实现
- **说明**：synchronized 锁升级（偏向→轻量→重量）；AQS 抽象队列同步器是 ReentrantLock/CountDownLatch 基础
- **面试要点**：
  - 轻量级锁：CAS 自旋，适合锁竞争少
  - AQS：state + CLH 双向队列，模板方法模式

### ConcurrentHashMap 为何 key/value 不能为 null
- **说明**：`get(key)` 返回 null 时，无法区分 key 不存在还是 value 为 null，ConcurrentHashMap 不允许这种二义性
- **面试要点**：HashMap 允许一个 null key 和多个 null value

### hash 冲突 4 种解决方式
- **链地址法**：拉链表（HashMap 默认）
- **开放地址法**：线性探测、二次探测
- **再哈希法**：多个 hash 函数
- **公共溢出区**：溢出区存冲突元素
- **面试要点**：HashMap 链地址 + 红黑树优化长链表

### FutureTask
- **说明**：RunnableFuture 实现，包装 Callable，get() 阻塞获取结果，可取消
- **面试要点**：state 状态机 NEW → COMPLETING → NORMAL/EXCEPTIONAL；run() 执行 Callable.call()

### CompletableFuture
- **说明**：JDK8 异步编程，支持链式组合（thenApply/thenCompose）、多任务聚合（allOf/anyOf）
- **面试要点**：
  - `supplyAsync` 有返回值，`runAsync` 无返回值
  - 异常处理：`exceptionally`、`handle`
  - 对比 Future：可组合、可回调，不阻塞 get

### 怎么唤醒阻塞的线程
- **说明**：sleep → 时间到自动醒；wait → notify/notifyAll；park → unpark；join → 目标线程结束；IO 阻塞 → IO 就绪
- **面试要点**：interrupt() 可中断 sleep/wait，抛 InterruptedException

### 阻塞队列
| 队列 | 特点 | 场景 |
|------|------|------|
| ArrayBlockingQueue | 有界数组 | 固定容量生产者消费者 |
| LinkedBlockingQueue | 可选有界链表 | 常用，吞吐高 |
| PriorityBlockingQueue | 优先级堆 | 定时任务 |
| DelayQueue | 延迟到期才能取 | 定时消息 |
| SynchronousQueue | 不存元素，直接交接 | CachedThreadPool |

- **面试要点**：SynchronousQueue 每个 put 必须等待 take，适合高吞吐直接传递场景

### JUC 工具类
- **CountDownLatch**：一次性倒计时，await 等 count 归零（主线程等多线程完成）
- **CyclicBarrier**：可重用屏障，多线程互相等待到齐（分批计算）
- **Semaphore**：信号量，控制并发数（连接池、限流）
- **面试要点**：
  - CountDownLatch 不可重置，CyclicBarrier 可 reset
  - Semaphore 三个线程轮流打印：acquire(1) + release(1) 控制顺序

---

## IO

### 输入流、输出流
- **说明**：InputStream/Reader 读，OutputStream/Writer 写；字节流处理二进制，字符流处理文本（含编码转换）
- **面试要点**：字节流 InputStream/OutputStream；字符流 Reader/Writer；缓冲流 BufferedXxx 提升性能

### 同步/异步 vs 阻塞/非阻塞
- **说明**：同步/异步看**调用方是否等待结果**；阻塞/非阻塞看**线程是否挂起等待**
- **面试要点**：
  - BIO：同步阻塞（一个连接一个线程）
  - NIO：同步非阻塞（Selector 多路复用，一个线程管多连接）
  - AIO：异步非阻塞（回调通知，Linux 下实际用 epoll 模拟）
  - 四者正交：同步阻塞、同步非阻塞、异步阻塞、异步非阻塞

### BIO / NIO / AIO
| 模型 | 特点 | 场景 |
|------|------|------|
| BIO | 一连接一线程，阻塞 IO | 连接数少 |
| NIO | Buffer+Channel+Selector，多路复用 | 高并发（Netty） |
| AIO | 异步回调 | 大文件、连接数多（实际少用） |

- **面试要点**：NIO 核心：Channel 双向、Buffer 缓冲区、Selector 监听多个 Channel 事件

### 设计模式（IO 相关）
- **装饰者**：BufferedInputStream 包装 FileInputStream 加缓冲
- **适配器**：InputStreamReader 字节流→字符流
- **观察者**：NIO 事件监听
- **工厂**：各种 Stream 的工厂方法

---

## 网络

### OSI 七层
- **说明**：应用层→表示层→会话层→传输层（TCP/UDP）→网络层（IP）→链路层→物理层
- **面试要点**：实际常用 TCP/IP 四层：应用层、传输层、网络层、链路层

### Socket
- **说明**：网络通信端点抽象，TCP 用 Socket/ServerSocket，UDP 用 DatagramSocket
- **面试要点**：Socket = IP + 端口，是全双工通信

### TCP
- **说明**：面向连接、可靠、有序、流量控制（滑动窗口）、拥塞控制
- **面试要点**：
  - **三次握手**：SYN → SYN+ACK → ACK（确认双方收发能力）
  - **四次挥手**：FIN → ACK → FIN → ACK（全双工需分别关闭）
  - **为什么握手 3 次挥手 4 次**：握手可合并 SYN+ACK；关闭需等数据发完
  - TIME_WAIT 2MSL：防旧包干扰新连接
  - 滑动窗口：接收方告知可接收量，防止发送过快

### UDP
- **说明**：无连接、不可靠、无序、速度快，适合视频、DNS、游戏
- **面试要点**：TCP 可靠慢，UDP 快但不保证送达；选 UDP 场景：实时性 > 可靠性

### DNS 域名解析
- **说明**：域名 → IP 的映射，递归查询（客户端→本地 DNS→根→顶级→权威）
- **面试要点**：浏览器缓存 → 系统 hosts → 本地 DNS → 递归查询

### Java NIO 实现
- **Buffer**：堆内存/直接内存，flip() 切换读写模式，clear() 重置
- **Channel**：双向，FileChannel、SocketChannel；FileChannel.transferTo() 零拷贝
- **Selector**：多路复用，select/poll/epoll；监听 OP_ACCEPT/READ/WRITE/CONNECT
- **面试要点**：DirectBuffer 减少一次拷贝但分配慢，需手动释放防泄漏

### Netty
- **性能优化**：
  - 零拷贝：CompositeByteBuf 组合、DirectBuffer、transferTo/sendfile
  - 内存池化：PooledByteBufAllocator 复用 ByteBuf
  - Reactor 模型：Boss 处理 Accept，Worker 处理 Read/Write
  - 锁优化：细粒度锁、LongAdder、ThreadLocal、CountDownLatch 替代 wait/notify
- **潜在问题**：
  - 空轮询 Bug：JDK epoll 空轮询导致 CPU 100% → Netty 限次后 rebuild Selector
  - DirectBuffer 泄漏：必须 release()，用 leak detector 检测
- **面试要点**：Netty 基于 NIO，异步事件驱动，Pipeline 责任链处理入站/出站

### HTTP / HTTPS
- **说明**：HTTP 无状态请求响应；HTTPS = HTTP + TLS（加密 + 证书认证）
- **面试要点**：
  - HTTP/1.1 长连接；HTTP/2 多路复用；HTTP/3 基于 QUIC(UDP)
  - HTTPS 握手：非对称加密交换对称密钥 → 对称加密传输
  - 状态码：200 成功、301/302 重定向、400 客户端错、401 未认证、403 无权限、404 不存在、500 服务端错

### RPC（gRPC / Dubbo）
- **说明**：远程过程调用，像调本地方法一样调远程服务
- **面试要点**：
  - gRPC：HTTP/2 + Protobuf，跨语言，流式
  - Dubbo：Java 生态，Nacos 注册，支持多种协议（Dubbo/Triple/gRPC）

---

## JVM

### Class 文件结构
- **说明**：魔数 CAFEBABE → 版本号 → 常量池 → 访问标志 → 类/父类/接口索引 → 字段 → 方法 → 属性
- **面试要点**：用 jclasslib 查看；常量池存字面量和符号引用

### 双亲委派机制
- **说明**：类加载：Bootstrap → Extension → Application → 自定义；子加载器先委派父加载器，父无法加载才自己加载
- **面试要点**：
  - 作用：保证核心类不被篡改（如自定义 java.lang.String 无效）
  - 破坏场景：Tomcat 隔离 Web 应用、SPI（线程上下文类加载器）、OSGi
  - 字节码加密：自定义 ClassLoader 解密后 defineClass

### JVM 运行时数据区
- **说明**：
  - 线程共享：堆（对象实例）、方法区/元空间（类信息、常量、静态变量）
  - 线程私有：虚拟机栈（方法帧、局部变量）、本地方法栈、程序计数器
- **面试要点**：
  - JDK8 方法区用元空间（本地内存），替代永久代
  - 栈溢出 StackOverflowError（递归过深）；堆溢出 OutOfMemoryError

### JVM OOM 类型
| 区域 | 异常 | 原因 |
|------|------|------|
| 堆 | Java heap space | 对象太多/泄漏 |
| 栈 | StackOverflowError | 递归/栈帧过大 |
| 方法区/元空间 | Metaspace OOM | 类加载过多 |
| 直接内存 | Direct buffer memory | NIO 未释放 |
| 程序计数器 | 不会 OOM | — |

### 对象创建过程
- **说明**：类加载检查 → 分配内存（指针碰撞/空闲列表）→ 初始化零值 → 设置对象头 → `<init>` 构造
- **面试要点**：
  - 并发分配：CAS 或 TLAB（Thread Local Allocation Buffer，线程私有分配缓冲）
  - 栈上分配：逃逸分析 + 标量替换，未逃逸对象可能在栈上分配

### 垃圾判断与回收
- **可达性分析**（Java 采用）：从 GC Roots 不可达则可回收
  - GC Roots：栈中引用、静态变量、常量、JNI 引用、Synchronized 持有的对象
- **引用计数**（Python 等）：循环引用无法回收，Java 不用
- **三色标记**：白（未访问）灰（访问中）黑（已完成）；漏标问题 → 增量更新（CMS）或 SATB（G1）
- **STW**：Stop-The-World，GC 时暂停所有用户线程
- **安全点**：可中断位置（方法调用、循环跳转）；安全区：线程处于 Sleep/Blocked 时的区域
- **面试要点**：空间满触发 GC；finalize 已废弃

### 分代收集理论
- **说明**：弱分代假说：大多数对象朝生夕灭；强分代假说：熬过多次 GC 的对象难消亡
- **新生代**：Eden + 2 Survivor，复制算法，Minor GC 频繁
- **老年代**：标记-清除/整理，Major/Full GC 慢
- **面试要点**：对象优先 Eden 分配 → Minor GC 存活进 Survivor → 年龄达阈值进老年代

### 垃圾回收算法
- **复制**：分两块，存活复制到另一块，适合新生代（Eden+Survivor）
- **标记-清除**：标记存活，清除未标记，产生碎片
- **标记-整理**：标记后移动存活对象，消除碎片，适合老年代
- **面试要点**：没有完美算法，分代组合使用

### 常用垃圾回收器
| 回收器 | 特点 | 场景 |
|--------|------|------|
| Serial | 单线程 STW | 客户端 |
| ParNew | Serial 多线程版 | 配合 CMS |
| Parallel Scavenge | 吞吐量优先 | 后台计算 |
| CMS | 并发标记清除，低延迟，有碎片 | 已废弃 |
| G1 | 分区 Region，可预测停顿，JDK9 默认 | 通用 |
| ZGC | 超低延迟（<10ms），染色指针 | 大堆低延迟 |

- **面试要点**：PS+PO（Parallel Scavenge + Parallel Old）吞吐量；G1 Mixed GC；ZGC 颜色指针标记对象状态

### 线上问题排查
- **CPU 100%**：`top -Hp pid` 找线程 → `jstack pid` 看栈 → 定位热点方法/死循环
- **内存溢出**：`-XX:+HeapDumpOnOutOfMemoryError` → MAT 分析大对象/泄漏
- **死锁**：`jstack` 搜 deadlock
- **面试要点**：常用工具 jps、jstat、jmap、jstack、MAT、Arthas

---

## Tomcat

### Servlet 生命周期
- **说明**：init() 初始化 → service() 处理请求 → destroy() 销毁；由容器管理生命周期
- **面试要点**：service() 根据 HTTP 方法分发到 doGet/doPost 等

### Tomcat 架构
- **Server** → **Service**（Connector + Engine）→ **Host** → **Context** → **Wrapper**（Servlet）
- **Connector**：接收请求（HTTP/AJP），解析协议
- **Engine**：Servlet 引擎，处理请求管道
- **面试要点**：一个 Service 可有多个 Connector 共用一个 Engine；请求链 Valve 管道处理

---

## MySQL

### 事务 ACID
- **A 原子性**：undo log 回滚
- **C 一致性**：业务+数据库约束共同保证
- **I 隔离性**：MVCC + 锁
- **D 持久性**：redo log
- **面试要点**：ACID 靠 undo/redo/MVCC/锁 实现，一致性是最终目标

### InnoDB 存储结构
- **逻辑**：表空间 → 段 → 区(1MB,64页) → 页(16KB，最小 IO 单元)
- **物理**：8.0 取消 .frm，表结构存数据字典（InnoDB 数据字典）
- **面试要点**：一行记录可能跨页（溢出页）；页内按行存储

### InnoDB vs MyISAM
| 对比 | InnoDB | MyISAM |
|------|--------|--------|
| 事务 | 支持 | 不支持 |
| 锁 | 行锁 | 表锁 |
| 索引 | 聚簇索引 | 非聚簇 |
| 崩溃恢复 | 支持 | 不支持 |
| 面试 | InnoDB 默认引擎，MyISAM 已淘汰 | |

### 索引（B+ 树）
- **聚簇索引**：叶子存完整行数据，InnoDB 主键即聚簇索引
- **二级索引**：叶子存主键值，查非索引列需**回表**
- **覆盖索引**：查询列全在索引中，无需回表（Extra: Using index）
- **最左前缀**：联合索引 (a,b,c) 可匹配 a、ab、abc，不能跳过 a 直接用 b
- **三星索引**：① 扫描范围小 ② 排序与查询一致 ③ 覆盖索引不回表
- **面试要点**：
  - 为什么 B+ 树不用 B 树：B+ 树叶子链表便于范围查询，非叶子只存 key 更矮
  - Hash 索引：等值快，不支持范围/排序；Memory 引擎支持

### 锁
- **当前读**（加锁读）：SELECT ... FOR UPDATE / LOCK IN SHARE MODE、UPDATE、DELETE
- **快照读**（普通读）：MVCC 读历史版本，不加锁
- **S 锁**（共享）：可读不可写；**X 锁**（排他）：不可读不可写
- **意向锁**（IS/IX）：表级，快速判断是否有行锁冲突
- **行锁类型**：Record Lock（记录锁）、Gap Lock（间隙锁，防幻读）、Next-Key Lock（Record+Gap）
- **面试要点**：
  - 无索引条件 → 锁全表（表锁）
  - RR 级别 Next-Key Lock 防幻读；RC 只用 Record Lock
  - 死锁：InnoDB 自动检测，回滚代价小的事务

### Explain 执行计划
- **关键列**：type（访问类型，const>ref>range>index>ALL）、key（实际索引）、rows（扫描行数）、Extra（Using index/Using filesort/Using temporary）
- **面试要点**：type=ALL 全表扫描需优化；Extra 出现 filesort/temporary 需关注

### 高性能索引规则
- 不在索引列做函数/运算/类型转换
- 联合索引遵循最左前缀，范围条件放最后
- 尽量覆盖索引；慎用 `!=`、`<>`、`OR`（OR 两侧都有索引才走索引）
- `IS NULL` 可走索引；`IS NOT NULL` 通常不走
- `LIKE 'abc%'` 可走索引，`'%abc'` 不行
- 字符串列不加引号会隐式转换导致索引失效
- 主键自增顺序插入减少页分裂
- **面试要点**：口诀「最左前缀、覆盖索引、避免函数、范围放后」

### Buffer Pool
- **说明**：InnoDB 内存缓存，缓存数据页和索引页；LRU 改进版（Young:Old = 5:3）
- **面试要点**：新页插入 Old 区头部，淘汰 Old 尾部；多实例 Buffer Pool 减少锁竞争

### Change Buffer
- **说明**：二级索引变更时，若目标页不在 Buffer Pool，先缓存在 Change Buffer，下次读取时 merge
- **面试要点**：仅适用于非唯一二级索引；唯一索引需立即读页校验唯一性

### Double Write Buffer
- **说明**：页写入时先写 double write 区域（顺序写），再写数据文件；崩溃时从 double write 恢复
- **面试要点**：解决部分页写入（partial page write）问题

### Redo Log
- **说明**：InnoDB 物理日志，记录页的修改；WAL 先写日志再写盘；环形文件，write pos 和 checkpoint
- **面试要点**：
  - redo log 保证持久性（崩溃恢复）；binlog 保证主从复制
  - 两阶段提交：redo prepare → binlog → redo commit

### Undo Log
- **说明**：逻辑日志，记录反向操作；用于回滚和 MVCC 多版本
- **隐藏列**：DB_TRX_ID（事务 ID）、DB_ROLL_PTR（回滚指针）、DB_ROW_ID（隐式主键）

### MVCC
- **说明**：多版本并发控制，快照读不加锁；通过 undo log 链 + Read View 判断可见性
- **Read View 四属性**：creator_trx_id、trx_ids（活跃事务）、min_trx_id、max_trx_id
- **可见性规则**：trx_id < min → 可见；trx_id ≥ max 或在 trx_ids 中 → 不可见；否则可见
- **面试要点**：
  - RC 每次读生成新 Read View；RR 首次读生成，之后复用（解决不可重复读）
  - 幻读：RR + 当前读用 Next-Key Lock 防；快照读靠 MVCC

### Binlog
- **说明**：Server 层逻辑日志，所有引擎通用；三种格式：STATEMENT、ROW、MIXED
- **面试要点**：主从复制、数据恢复靠 binlog；ROW 格式记录行变更，更安全

### 事务隔离级别
| 级别 | 脏读 | 不可重复读 | 幻读 |
|------|------|-----------|------|
| 读未提交 | ✗ | ✗ | ✗ |
| 读已提交 | ✓ | ✗ | ✗ |
| 可重复读（默认） | ✓ | ✓ | 快照读✓/当前读✗ |
| 串行化 | ✓ | ✓ | ✓ |

- **面试要点**：MySQL 默认可重复读；Oracle 默认读已提交

### 主从同步
- **流程**：Master 写 binlog → Slave IO 线程拉取 → relay log → SQL 线程重放
- **延迟优化**：并行复制、避免大事务、半同步复制、从库硬件升级
- **面试要点**：异步复制有延迟；半同步等至少一个从库 ACK

---

## Redis

### 应用场景
- **缓存穿透**：查不存在的数据，绕过缓存直击 DB → 布隆过滤器 / 缓存空值
- **缓存击穿**：热点 key 过期瞬间大量请求 → 互斥锁 / 逻辑过期（不设 TTL，异步更新）
- **缓存雪崩**：大量 key 同时过期或 Redis 宕机 → 过期时间加随机值 / 集群高可用
- **排行榜/计数器**：ZSet / INCR
- **共享 Session**：集中存储用户会话
- **分布式锁**：SET NX EX + Lua 脚本释放 + Redisson 看门狗续期
- **分布式 ID**：INCR / 雪花算法
- **布隆过滤器**：BitMap 实现，判断元素可能存在/一定不存在
- **GEO**：地理位置，GEORADIUS 附近的人
- **面试要点**：穿透 vs 击穿 vs 雪崩 三者区别要能一句话说清

### 数据一致性
- **建议**：先更新 DB，再删缓存（Cache Aside）
- **延迟双删**：删缓存 → 更新 DB → 延迟再删缓存（防脏读）
- **面试要点**：先删后写可能脏读；先写后删可能短暂不一致，最终一致

### 持久化
- **RDB**：快照，fork 子进程写盘；恢复快但可能丢最后一次快照后的数据
- **AOF**：追加写命令，everysec 最多丢 1 秒；AOF 重写压缩体积
- **混合持久化**（4.0+）：RDB 全量 + AOF 增量，重启最快
- **面试要点**：重启加载：AOF 优先 → RDB → 旧版 AOF

### 事务
- **说明**：MULTI → 命令入队 → EXEC 执行；不支持回滚，错误命令入队前发现
- **面试要点**：弱一致性，非 ACID；WATCH 实现 CAS 乐观锁

### 5 大数据类型底层
| 类型 | 底层 | 要点 |
|------|------|------|
| String | SDS | O(1) 取长度，二进制安全，预分配 |
| List | quicklist（双向链表+压缩列表） | 3.2+ 快速列表 |
| Hash | ziplist / hashtable | 元素少且短用 ziplist |
| Set | intset / hashtable | 整数集合用 intset |
| ZSet | ziplist / skiplist+dict | 跳表 O(logN) 范围查询 |

- **面试要点**：SDS 比 C 字符串多 len/free 字段；跳表多层索引类似 B+ 树

### 主从 & 哨兵
- **主从复制**：全量（RDB 快照）→ 部分（复制偏移量 + 复制缓冲区，默认 1MB）
- **哨兵**：3 个定时任务（10s info / 2s 订阅 / 1s ping）；主观下线 → 客观下线（quorum 过半）→ Raft 选 Leader → 故障转移
- **故障转移选主**：过滤不健康 → slave-priority → 复制偏移量最大 → runid 最小
- **脑裂**：网络分区导致多主；min-slaves-to-write 限制
- **面试要点**：异步复制有丢数据风险；哨兵至少 3 节点防脑裂

### 集群模式
- **说明**：16384 槽位，CRC16(key) % 16384 定位；Gossip 协议交换状态
- **面试要点**：一致性 Hash 减少扩容迁移；MOVED/ASK 重定向

### 线程模型
- **6.0 前**：单线程（命令串行，避免锁）
- **6.0+**：多 IO 线程（读写网络），命令仍单线程（默认 io-threads-do-reads 关闭）
- **面试要点**：单线程也快的原因：纯内存、IO 多路复用、无锁、高效数据结构

### 内存淘汰策略
- **noeviction**：不淘汰，写满报错
- **volatile-xxx**：只淘汰设了过期时间的 key（lru/ttl/random/lfu）
- **allkeys-xxx**：所有 key（lru/random/lfu）
- **近似 LRU**：随机采样 5 个，淘汰最久未访问
- **LFU**：按访问频率，24bit 中 16bit 时间 + 8bit 计数（对数编码）
- **面试要点**：生产常用 allkeys-lru 或 volatile-lru；LFU 4.0+ 适合热点明显场景

### 过期策略
- **定期删除**：每秒 10 次，随机取 20 个 key 检查过期
- **惰性删除**：访问时发现过期才删
- **lazyfree**：大 key 删除放后台线程，主线程只标记
- **面试要点**：过期 key 不会立即删除，占内存直到被访问或定期扫描

---

## MQ

### 应用场景
- **异步解耦**：下单后 MQ 通知库存/积分/短信，主流程不阻塞
- **削峰填谷**：秒杀流量写入 MQ，消费者按能力消费
- **分布式事务**：半事务消息（RocketMQ）/ 本地消息表
- **缓存同步**：Canal 监听 binlog → MQ → 更新 Redis
- **面试要点**：MQ 引入后需考虑：消息丢失、重复、顺序、积压

### 延迟消息
- **RabbitMQ**：TTL + 死信队列（DLX）
- **Kafka**：不支持原生延迟
- **RocketMQ**：18 个延迟等级（1s ~ 2h）
- **面试要点**：延迟消息本质是先存后不立即投递

### 消息有序性
- **全局有序**：单分区/单队列，吞吐低
- **局部有序**：同一业务 key 路由到同一分区（如 orderId hash）
- **面试要点**：前提：生产有序 + 单消费者 + 单分区

### 优化技术
- **零拷贝**：sendfile，数据不经过用户态
- **MMAP**：内存映射文件，减少 read/write 拷贝
- **DMA**：直接内存访问，CPU 不参与数据拷贝
- **面试要点**：Kafka 高性能 = 顺序写盘 + 零拷贝 + 批量 + 分区并行

### 分布式事务
- **RocketMQ 半事务**：发 half 消息 → 执行本地事务 → commit/rollback → 未决则回查
- **最终一致性**：允许短暂不一致，最终达到一致
- **面试要点**：强一致用 2PC/XA；高吞吐用最终一致 + 补偿

### 重复消费
- **说明**：网络重试、Rebalance 等导致重复，消费端必须幂等
- **方案**：唯一索引 / 状态机 / Redis SETNX / 版本号乐观锁
- **面试要点**：幂等 key = 业务唯一标识（如 orderId + 操作类型）

### Kafka 要点
- **消费策略**：earliest（从头）/ latest（最新）/ none（无 offset 报错）
- **Ack**：0 不等待 / 1 Leader 确认 / all 所有 ISR 确认（最可靠）
- **幂等性**：PID + Sequence Number，需 retries=true + acks=all
- **事务**：transactional.id 唯一，跨分区原子写
- **架构**：Topic → Partition → Leader/Follower（ISR 同步副本集）
- **Rebalance**：消费者组变化时重新分配分区
- **面试要点**：
  - Kafka 不区分主从，Partition 有 Leader 负责读写
  - 消费者 offset 存 __consumer_offsets 或外部（Kafka 0.9+ 内置）
  - 丢消息：producer acks=0 / broker 异步刷盘 / consumer 自动提交后崩溃

### RocketMQ 要点
- **vs Kafka**：Topic 逻辑分散在多个 Broker 的 Queue；Kafka Partition 全量复制
- **消费模式**：集群（负载均衡）/ 广播（每个消费者都收到）
- **高可用**：同步/异步刷盘 + 主从同步 + Dledger 自动选主
- **零丢失**：同步发送 + 同步刷盘 + 同步复制 + 手动 ACK
- **面试要点**：
  - NameServer 轻量注册中心（无选举）
  - 死信队列：重试 16 次后进入 DLQ
  - 事务消息：Half Message → 本地事务 → Commit/Rollback → 回查

  - MyBatis
    - jdbc
    - 源码理解
      - 映射器解析
      - sql语句执行
      - 对象映射
      - SqlSessionFactory
        - 创建SqlSession对象，是MyBatis的核心组件之一
        - 线程安全的，单例模式
      - SqlSession
        - SqlSession的生命周期
          - SqlSession的生命周期是从它的创建到关闭。SqlSession的创建可以通过SqlSessionFactory来创建，一般情况下，我们在需要访问数据库的时候，就会创建一个SqlSession对象。当SqlSession对象不再使用时，应该将其关闭
        - SqlSession的作用
          - SqlSession封装了对数据库的操作，包括数据的插入、更新、删除和查询等操作。通过SqlSession可以执行Mapper中定义的方法，并将执行结果返回给应用程序。SqlSession还提供了事务管理的支持
        - SqlSession的管理
          - 在MyBatis中，SqlSession的管理是由SqlSessionFactory来管理的。SqlSessionFactory可以通过配置文件或者Java代码来创建，每个应用程序通常只需要一个SqlSessionFactory实例，用于创建SqlSession对象。在应用程序中，SqlSession的管理一般由Spring框架或者自己手动管理
        - 线程不安全
          - SqlSession不是线程安全的，每个SqlSession实例都应该被单独使用，不能被多个线程共享。在多线程环境下，如果多个线程共用一个SqlSession对象，则可能会出现数据混乱的情况，因此需要保证每个线程都有自己的SqlSession实例
      - Executor
        - Executor的实现类
          - SimpleExecutor
            - SimpleExecutor是最简单的Executor实现，每次执行SQL语句都会创建一个新的Statement对象
          - ReuseExecutor
            - ReuseExecutor会尝试重用Statement对象，避免多次创建Statement对象，提高执行效率
          - BatchExecutor
            - BatchExecutor则是批量执行SQL语句的Executor实现
        - Executor的执行流程
          - 根据传入的MappedStatement对象创建StatementHandler对象。
          - 判断是否开启了二级缓存，如果开启了，则先从二级缓存中获取执行结果。
          - 判断是否需要刷新缓存，如果需要，则清空缓存。
          - 执行SQL语句，并将执行结果保存到缓存中。
          - 如果开启了二级缓存，则将执行结果保存到二级缓存中。
        - Executor的线程安全性
          - Executor是线程安全的，多个线程可以共用同一个Executor实例。在多线程环境下，Executor会使用线程池来管理多个线程的执行，避免线程竞争和线程创建销毁的开销
      - Configuration
        - 加载配置文件
          - 在MyBatis的配置文件中，可以配置数据源、映射文件、插件、类型别名等信息。Configuration通过XMLConfigBuilder类来加载配置文件，并将解析后的配置信息保存到Configuration对象中
        - 创建SqlSessionFactory
          - Configuration类也负责创建SqlSessionFactory。它会通过build方法创建SqlSessionFactory对象，并将该对象缓存起来，以便后续使用。在创建SqlSessionFactory对象时，会将Configuration对象作为参数传入，以便SqlSessionFactory可以获取MyBatis的配置信息和映射信息
        - 管理映射信息
          - MyBatis中的映射文件通常包含SQL语句和实体类之间的映射关系。Configuration会读取映射文件，将其中的SQL语句解析成MappedStatement对象，并将其保存到mappedStatements集合中。mappedStatements集合中保存了所有映射文件中定义的SQL语句，以及它们对应的MappedStatement对象
        - 管理缓存
          - Configuration还负责管理MyBatis的缓存。它会读取配置文件中的缓存配置信息，并创建对应的缓存对象，缓存对象被保存在caches集合中。在执行SQL语句时，如果该语句对应的MappedStatement对象中配置了缓存，则会从caches集合中获取缓存对象，并使用缓存对象来提高查询效率
    - 占位符$和#
      - $是字符串替换，拼接到sql中
      - #可以防止sql注入
    - 插件机制
      - 拦截器式设计
      - 动态代理
    - 一、二级缓存
      - 内存缓存
      - 一级缓存：sqlSession
      - 二级缓存：Mapper
    - 三级缓存
      - 自定义缓存
      - 插件
    - 日志
      - 使用适配器模式，兼容各种日志实现Log4j、Logback、JDK Logging
    - 设计模式
      - 构造者模式
        - SqlSessionFactoryBuilder
        - XMLConfigBuilder
      - 模板方法模式
        - XMLConfigBuilder
      - 工厂模式
        - SqlSessionFactory
      - 装饰器模式
        - 缓存模块，Excuter执行器
      - 适配器模式
        - 日志模块
      - 代理模式
        - mapper接口的实现，代理jdbc原生的类实现日志输出，插件

  - Spring系列
    - spring
      - IOC
      - DI
      - 包含的重点模块
        - aop
        - beans
        - core
        - orm
        - web
        - webmvc
      - refresh方法
        - prepareRefresh
          - 刷新准备
        - obtainFreshBeanFactory
          - 获得全新bean工厂
        - prepareBeanFactory
          - 对工厂填充属性
        - postProcessBeanFactory
          - 子类覆盖方法做额外的处理
        - invokeBeanFactoryPostProcessors
          - 执行BeanFactoryPostProcessor以及子接口BeanDefinitionRegistryPostProcessor的方法
        - registerBeanPostProcessors
          - 注册bean处理器，只注册，调用是getBean方法
        - initMessageSource
          - 初始化message源，不用语言的消息体，国际化处理
        - initApplicationEventMulticaster
          - 初始化事件监听多路广播器
        - onRefresh
          - 留给子类实现
        - registerListeners
          - 在所有注册bean里面找listener bean，注册到广播器中
        - finishBeanFactoryInitialization
          - 初始化剩下的单实例（非懒加载）
        - finishRefresh
          - 完成刷新过程，通知生命周期处理器lifecycleProcessor，同时发出ContextRefreshEvent通知别人
        - 如果发生异常：执行destoryBeans销毁之前创建的单例Bean，cancelRefresh重置active标志
        - finally
          - 重置公共缓存
      - Bean的生命周期
        - 创建
          - BeanFactoryPostProcesser#postProcessBeanFactory()
          - InstantiationAwareBeanPostProcessorAdapter#postProcessBeforeInstantiation()
          - 构造器实例化bean
          - InstantiationAwareBeanPostProcessAdapter#postProcessAfterInstantiation()
          - InstantiationAwareBeanPostProcessAdapter#postPropertyValues()
          - 注入Bean属性
          - XXXAware的方法
            - BeanNameAware#setBeanName()
            - BeanFacoryAware#setBeanFactory()
          - BeanPostProcessor#postProcessBeforeInitialization()
          - init-method
          - @PostConstruct
          - InitializingBean#afterPropertiesSet()
          - BeanPostProcessor#postProcessAfterInitialization()
        - 销毁
          - DisposabledBean#destory()
          - destory-method
          - @PreDestory
      - AOP
        - 通知
          - 前置通知
          - 后置通知
          - 环绕通知
          - 异常通知
        - 切入点
        - 切面
        - 增强
        - 织入
        - jdk动态代理
          - 接口
          - 字节码生成
        - cglib代理
      - 事务
        - 事务的传播属性7个
          - require
            - 支持当前事务，若当前没有事务，则新建一个事务
          - supports
            - 支持当前事务，若当前没有事务，则以非事务方式运行
          - mandatory（强制的）
            - 支持当前事务，若当前没有事务，则抛出异常 IllegalTransactionStateException
          - requires_new
            - 新建事务，若当前存在事务，则将当前事务挂起
          - not_supported
            - 以非事务方式运行操作，若当前存在事务，则将当前事务挂起
          - never
            - 以非事务方式运行，若当前存在事务，则抛出异常 IllegalTransactionStateException
          - nested
            - 若当前存在事务，则在嵌套事务内执行；若没有事务，则行为等同于 PROPAGATION_REQUIRED
        - 事务的隔离级别
          - 默认
          - 读未提交
          - 读已提交
          - 可重复读
          - 串行
      - 源码问题
        - 循环依赖
          - 3级缓存
    - spring MVC
      - 九大内置组件
        - handlerMapping
        - handlerAdapter
        - handlerExceptionResolver
        - viewResolver
        - requestToViewNameTranslator
        - localeResolver
        - themeResolver
        - MultipartResolver
        - FlashMapManager
      - doDispatch方法流程
        - 请求处理核心环节
          - 1、请求开始
          - 2、判断是否是文件上传：是-》MultipartResolver
          - 3、根据request查找handler（HandlerMapping）
          - 4、根据handler查找handlerAdapter（HandlerAdapter）
          - 5、处理last_modified
          - 6、执行interceptor的preHandler方法
          - 7、HandlerAdapter处理请求（HandlerAdapter）
          - 8、是否需要异步：是-》teturn
          - 9、当view为空时设置默认试图（RequestToViewNameTranslator）
          - 10、执行interceptor的postHandler方法
        - 11、是否发生异常：是-》将异常绑定到dispatchException（HandlerExceptionResolver）
        - 视图处理过程
          - 12、设置view
          - 13、页面的渲染处理（localeResolver，themeResolver，viewResolver）
          - 14、是否发生异常：是-》执行intercept的afterCompletion方法
          - 15、finally释放资源
    - spring boot
      - 自动配置原理
        - @EnableAutoConfiguration
        - @Import注解
          - 原理：注入标识的对象到spring容器
          - 注解的三种使用方式
            -  1。实现ImportSelector 接口
            - 2。实现 ImportBeanDefinitionRegistrar接口
            - 3。没有实现任何接口
        - DeferredImportSelector
          - 作用：延迟注入。目的是降低注入的复杂度。实现条件注解中要求的各种先后循序
      - SPI机制
        - META-INF/spring.factories文件
    - spring，spring boot所有扩展点
      - BeanFactoryPostProcessor
        - void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException;
        - 子接口BeanDefinitionRegistryPostProcessor
          - void postProcessBeanDefinitionRegistry(BeanDefinitionRegistry registry) throws BeansException;
      - BeanPostProcessor
        - 子接口InstantiationAwareBeanPostProcessor
        - 子接口SmartInstantiationAwareBeanPostProcessor
        - MergedBeanDefinitionPostProcessor
      - ApplicationListener
      - xxxxAware
      - InitializingBean/DisposableBean
      - FactoryBean
      - SmartInitializingSingleton
      - @PostConstruct
      - @PreDestory
      - CommandLineRunner
      - ApplicationRunner
      - SpringApplicationRunListener＆ApplicationContextInitializer
    - SpringSecurity
    - 配置文件的加载
      - ConfigFileApplicationListener
      - 加载顺序：./config、./、classpath：/config、classpath：/
    - 设计模式
      - 工厂模式
      - 单例模式
      - 观察者模式
      - 代理模式
      - 模板方法模式
      - 适配器模式

  - 微服务
    - 注册中心
      - Nacos
        - 客户端
          - 客户端启动时，创建每5秒一次请求的定时器作为心跳检测
          - 然后将自己服务的信息通过http协议instanc接口注册到服务端
          - 客户端再拉取一次完整服务端中的注册列表信息后，然后将此操作放入到一个每10秒一次请求的定时任务中用来更新注册服务列表
        - 服务端
          - 服务端接收到客户端的注册请求后，将请求分成修改和删除类型，放入阻塞队列，然后启动一个线程死循环处理这个阻塞队列，这样写与写的线程也不会有并发操作。修改时使用CopyOnWrite方式，通过创建一个一样的注册表的map，然后修改完成后，替换这个map，达到修改不阻塞读的效果。
          - 服务端也会启动一个每5秒一次的定时器，遍历所有的客户端实例，判断实例的最后心跳时间，如果大于15秒则改为不健康状态，如果大于30秒则剔除该实例。
      - zookeeper
        - 角色
          - leader
          - follower
          - observer
        - 初始化leader选举
          - 投自己一票，内容（SID：myid，ZXID：事务id）
          - 先比较比较zxid取大的，再比较sid取大的
          - 投票超过半数，则通过
        - 运行期间leader选举
          - 投自己一票，然后发送给集群其它节点
          - 接下来跟初始化选举相同
      - Eurak
    - 配置中心
      - nacos
        - 动态刷新
          - 1.4版本长轮询
          - @RefreshScope
            - 自定义的scope，区别于单例和原型
          - 监听RefreshEvent
        - 配置加载顺序
          - #作用：顺序,从上覆盖到下
          - #${application.name}-${profile}.${file- extension}   msb-edu-prod.yaml
          - #${application.name}.${file-extension}   nacos-config.yaml
          - #${application.name}   nacos-config
          - #extensionConfigs  扩展配置
          - #sharedConfigs  共享配置
        - Distro协议
          - - Nacos 每个节点是平等的都可以处理写请求，同时把新数据同步到其他节点。
          - - 在写请求时，每个节点只负责部分数据，其他请求通过DistroFilter转发至责任节点‌，定时发送自己负责数据的校验值到其他节点来保持数据一致性。
          - - 每个节点直接处理读请求，及时从本地发出响应。
    - 网关
      - gateway
        - WebFlux + Netty + Reactor 响应式的 API 网关
        - 路由
        - 断言
        - 过滤器
          - pre小的先执行
          - post小的后执行
      - zuul
    - 负载均衡
      - 客户端负载均衡
      - 服务端负载均衡
      - resttemplate
        - 拦截器ClientHttpRequestInterceptor
      - 服务器提供：服务注册列表
      - ribbon
        - java配置优先于属性配置（建议用属性配置）
      - loadbalance
        - 基于webflux
      - 策略
        - 轮询
        - 随机
        - 响应时间权重
        - 按分区权重
    - 容错
      - 思路
        - 隔离
        - 超时
        - 限流
        - 熔断
        - 降级
      - 流控降级
        - sentinel
          - 信号量
        - hystrix
          - 信号量/线程池隔离
      - 限流算法
        - 固定窗口
        - 滑动窗口
        - 令牌桶
        - 漏桶
    - RPC
      - http
        - feign
        - openFeign
      - scoket/netty
        - dubbo
        - gRPC
    - 分布式理论
      - CAP定理
        - Consistency（一致性）
        -  Availability（可用性）
        - Partition tolerance（分区容错性）
      - BASE理论
        - Basically Available（基本可用）
        - Soft state（软状态）
          - 指允许系统中的数据存在中间状态，并认为该中间状态的存在不会影响系统的整体可用性，即允许系统在不同节点的数据副本之间进行数据同步的过程存在延时
        - Eventually consistent（最终一致性）
    - 分布式事务
      - 跨库，分库分表，跨进程
      - 2PC：两阶段提交协议
        - 两阶段
          - pre commint（执行事务不提交）
          - do commit（提交/回滚）
        - 缺点
          - 单点故障：协调者出错
          - 阻塞资源：占用数据库连接
          - 数据不一致：二阶段出错，数据不一致
        - XA规范
          - AP：应用程序
          - TM：事务管理器（协调者）
          - RM：资源管理器
      - 3PC：三阶段提交
        - can commit（校验准备）
        - pre commint
        - do commit
      - Seata
        - 支持模式
          - AT模式:提供无侵入自动补偿的事务模式
            - 通过解析jdbc，生成并保存事务的回滚语句并根据全局事务id关联，执行事务直接提交释放资源，然后如果事务协调者最后执行提交，就不用处理，如果是回滚，就根据全局事务id找到之前生成的回滚记录，进行回滚操作
          - XA模式:支持已实现XA接口的数据库的XA模式
            - 优势
              - 接入简单，无侵入性
              - 支持主流数据库
              - 支持多种语言
            - 缺点
              - 有阻塞，性能低
          - TCC模式:TCC则可以理解为在应用层面的 2PC，是需要我们编写业务逻辑来实现。
            - TCC 是一种侵入式的分布式事务解决方案，以上三个操作都需要业务系统自行实现，对业务系统有着非常大的入侵性，设计相对复杂，但优点是 TCC 完全不依赖数据库，能够实现跨数据库、跨应用资源管理，对这些不同数据访问通过侵入式的编码方式实现一个原子操作，更好地解决了在各种复杂业务场景下的分布式事务问题
          - SAGA模式:为长事务提供有效的解决方案
        - 术语
          - TC (Transaction Coordinator) - 事务协调者- 独立部署的Server 服务端
          - TM (Transaction Manager) - 事务管理器-嵌入到应用的Client 客户端
          - RM (Resource Manager) - 资源管理器-嵌入到应用的Client 客户端
        - 事务执行流程
          - 1.TM 请求 TC 开启一个全局事务。TC 会生成一个 XID 作为该全局事务的编号。XID，会在微服务的调用链路中传播，保证将多个微服务的子事务关联在一起。
          - 2.RM 请求 TC 将本地事务注册为全局事务的分支事务，通过全局事务的 XID 进行关联。
          - 3.TM 请求 TC 告诉 XID 对应的全局事务是进行提交还是回滚。
          - 4.TC 驱动 RM 们将 XID 对应的自己的本地事务进行提交还是回滚。
        - 源码分析
          - GlobalTransactionScanner
            - wrapperIfNecessary创建代理类
            - afterPropertiesSet初始化TM和RM（Netty）
          - AT模式
            - 一阶段
              -  1.解析 SQL：得到 SQL 的类型（UPDATE），表（product），条件（where name = 'TXC'）等相关的信息。
              - 2. 查询前镜像（改变之前的数据）：根据解析得到的条件信息，生成查询语句，定位数据。
              - 3. 执行业务 SQL：更新这条数据。
              - 4. 查询后镜像（改变后的数据）：根据前镜像的结果，通过 **主键** 定位数据。
              - 5. 插入回滚日志：把前后镜像数据以及业务 SQL 相关的信息组成一条回滚日志记录，插入到 `UNDO_LOG` 表中。
              - 6. 提交前，向 TC 注册分支：申请 **全局锁** 。
              - 7. 本地事务提交：业务数据的更新和前面步骤中生成的 UNDO LOG 一并提交。
              - 8. 将本地事务提交的结果上报给 TC
            - 二阶段-回滚
              - 1. 收到 TC 的分支回滚请求，开启一个本地事务，执行如下操作。
              - 2. 通过 XID 和 Branch ID 查找到相应的 UNDO LOG 记录。
              - 3. 根据 UNDO LOG 中的前镜像和业务 SQL 的相关信息生成并执行回滚的语句：
              - 4. 提交本地事务。并把本地事务的执行结果（即分支事务回滚的结果）上报给 TC。
            - 二阶段-提交
              - 1. 收到 TC 的分支提交请求，把请求放入一个异步任务的队列中，马上返回提交成功的结果给 TC。
              - 2. 异步任务阶段的分支提交请求将异步和批量地删除相应 UNDO LOG 记录。
      - TCC：try-confirm-cancel
        - try
        - confirm：直接提交
        - cancel：回滚操作
      - 事件表解决方案
        - 定时器+事件表+消息通知
      - 最大努力通知方案
        - 支付回调
    - 日志收集
      - elk
    - 监控
    - 一致性
      - Gossip（流行病协议）：redis集群
      - distro最终一致性协议：Nacos注册中心的AP协议
      - raft一致性算法：CP协议，redis实现哨兵领导者选举
        - 新增和修改数据时，主节点的数据只要同步到从节点超过半数，则这次数据的操作算成功
      - ZAB一致性协议：zookeeper Atomic Broadcast协议
    - 分布式ID
      - uuid
      - 数据库自增id
      - 数据库多主模式
      - 号段模式
      - snowflake雪花算法
      - 百度UIDGenerator
        - 双ringBuffer
        - Snowflake算法
      - 美团Leaf
        - leaf-segment号段模式
        - snowflake雪花算法
      - 滴滴TinyId
        - leaf-segment升级而来
        - 数据库多主节点模式
        - tinyid-client客户端
        - 只支持号段一种模式

  - 23种设计模式
    - 创建型
      - 工厂
        - 工厂方法
          - BeanFactory
          - SqlSessionFactory
          - TreadFactory
        - 抽象工厂
      - 单例
      - 构造者
      - 原型
    - 结构型
      - 代理
      - 桥接
      - 装饰器
      - 适配器
      - 不常用
        - 门面
        - 组合
        - 享元
    - 行为型
      - 观察者
      - 模板方法
      - 策略
      - 迭代器
      - 状态
      - 不常用
        - 访问者
        - 备忘录
        - 命令
        - 解释器
        - 中介

  - 架构设计

  - 技术才是王道，沉浸下来学习技术
