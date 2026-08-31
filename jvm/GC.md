# JVM GC 知识体系

## 目录
- [一、GC基础概念](#一gc基础概念)
- [二、JVM垃圾收集器对比](#二jvm垃圾收集器对比)
- [三、并发标记与漏标问题](#三并发标记与漏标问题)
- [四、G1收集器的SATB机制](#四g1收集器的satb机制)
- [五、Go语言GC机制](#五go语言gc机制)
- [六、GC可视化工具](#六gc可视化工具)

---

## 一、GC基础概念

### 1.1 垃圾收集的基本算法
- **标记-清除算法**: 先标记存活对象，再清除未标记对象
- **三色标记法**: 将对象分为白色(未访问)、灰色(正在访问)、黑色(已访问)三类
- **分代收集**: 基于弱分代假说，将堆分为新生代和老年代

### 1.2 STW (Stop-The-World)
- **定义**: 垃圾回收过程中暂停应用线程的阶段
- **影响**: 直接影响应用延迟和响应时间
- **目标**: 现代GC的目标就是减少STW时间

---

## 二、JVM垃圾收集器对比

### 2.1 虚拟机架构对比

| 虚拟机 | 定位 | 适用场景 | 核心优势 |
|:---|:---|:---|:---|
| **HotSpot** | 通用场景标杆 | 长驻运行的大型应用 | 成熟稳定、生态完善、性能优化深入 |
| **GraalVM** | 高性能增强版 | 云原生、Serverless、微服务 | AOT编译、毫秒级启动、多语言支持 |
| **OpenJ9** | 低内存虚拟机 | 容器化、Serverless | 内存占用低、启动速度快 |

### 2.2 GraalVM vs 传统JDK

| 对比维度 | 传统JDK (HotSpot) | GraalVM |
|:---|:---|:---|
| **编译器** | C1 + C2 编译器 | Graal编译器(Java编写) |
| **编译模式** | 仅JIT | JIT + AOT双模式 |
| **启动速度** | 秒级冷启动 | AOT模式下毫秒级(提速100倍) |
| **内存占用** | 高(数百MB) | 低(降低40%~60%) |
| **多语言支持** | JVM系语言 | Java、Python、JS、Ruby等 |
| **打包产物** | JAR包 | 独立二进制可执行文件 |

---

## 三、并发标记与漏标问题

### 3.1 漏标的两个必要条件
同时满足以下两个条件才会发生漏标：

1. **黑找白**: 黑色对象新增指向白色对象的引用
2. **灰断白**: 灰色对象断开对白色对象的引用

**后果**: 白色对象因无引用指向而被误回收，导致程序崩溃

### 3.2 CMS的增量更新机制

#### 核心原理
- **写后屏障**: 当黑色对象新增指向白色对象的引用时，将黑色对象重标为灰色
- **局限性**: 只关注新增引用，不处理引用删除

#### CMS的STW阶段
| 阶段 | 是否STW | 作用 |
|:---|:---|:---|
| **初始标记** | ✅ 是 | 标记GC Roots直接引用的对象 |
| **并发标记** | ❌ 否 | 与用户线程并发，遍历对象图 |
| **重新标记** | ✅ 是 | 修正并发期间的引用变更 |
| **并发清除** | ❌ 否 | 清理未标记对象 |

#### CMS的缺陷
- 存在理论漏标风险
- 依赖重新标记阶段补救
- 在高并发复杂场景下可靠性不足

---

## 四、G1收集器的SATB机制

### 4.1 SATB核心原理
**SATB (Snapshot-At-The-Beginning)**: "冻结"并发标记开始时的对象存活视图

**破局思路**: 破坏"灰断白"条件，确保标记开始时的存活对象不被误回收

### 4.2 SATB实现机制

#### 写前屏障 (Pre-write Barrier)
```java
// 执行: obj.field = newValue
// 屏障逻辑:
if (oldValue != null && oldValue位于TAMS之前) {
    satb_mark_queue.add(oldValue);  // 记录旧引用
}
```

#### TAMS指针 (Top-At-Mark-Start)
- **定义**: 并发标记开始时，每个Region的顶部指针
- **作用**: 划分对象的处理策略

| 区域 | 对象特征 | GC处理方式 |
|:---|:---|:---|
| **TAMS之前** | 标记开始前已存在的对象 | 参与三色标记，受SATB保护 |
| **TAMS之后** | 标记开始后新分配的对象 | 默认存活(黑色)，本轮不回收 |

### 4.3 SATB执行流程

| 阶段 | 是否STW | SATB角色 |
|:---|:---|:---|
| **初始标记** | ✅ 是 | 确立快照时间点，设定TAMS指针 |
| **并发标记** | ❌ 否 | **SATB核心**: 写前屏障记录旧引用 |
| **最终标记** | ✅ 是 | 处理剩余SATB队列，确保无漏标 |
| **筛选回收** | ✅ 是 | SATB任务结束，执行复制清理 |

### 4.4 SATB vs CMS对比

| 特性 | CMS (增量更新) | G1 (SATB) |
|:---|:---|:---|
| **防御策略** | 破坏"黑找白" | 破坏"灰断白" |
| **屏障类型** | 写后屏障 | 写前屏障 |
| **记录内容** | 记录新引用 | 记录旧引用 |
| **漏标风险** | 存在理论风险 | **无**(理论保证) |
| **主要代价** | 重复扫描 | 产生浮动垃圾 |

### 4.5 浮动垃圾
**SATB的代价**: 产生浮动垃圾(实际上已不可达，但因快照机制被保留)

**处理**: 浮动垃圾会在下一轮GC中被正确识别并回收

---

## 五、Go语言GC机制

### 5.1 核心特点
- **非分代**: 不采用分代收集策略
- **并发式**: 三色标记清除，与业务代码并发执行
- **低延迟**: STW停顿可控制在微秒级

### 5.2 GC执行流程

| 阶段 | STW状态 | 说明 |
|:---|:---|:---|
| **Mark Setup** | 短暂STW | 开启写屏障(10~30微秒) |
| **并发标记** | ❌ 否 | GC占用25% CPU，业务协程协助 |
| **Mark Termination** | 短暂STW | 关闭写屏障，计算触发阈值 |
| **并发清理** | ❌ 否 | 业务申请内存时同步回收 |

### 5.3 GC触发时机
1. **内存分配触发**: 新分配内存达到上次GC存活对象大小的2倍
2. **定时触发**: 2分钟内未执行GC时强制触发
3. **手动触发**: 调用`runtime.GC()`强制执行

### 5.4 Go vs JVM GC对比

| 维度 | Go GC | JVM GC |
|:---|:---|:---|
| **分代策略** | 非分代 | 分代收集 |
| **STW时长** | 微秒级 | 毫秒级 |
| **内存优化** | 逃逸分析，栈上分配 | 分代回收 |
| **适用场景** | 低延迟服务 | 大型应用 |

---

## 六、GC可视化工具

### 6.1 动画演示站点
1. **标记清除算法动画**: [http://www.donghuasuanfa.com/platform/portal/mark-sweep](http://www.donghuasuanfa.com/platform/portal/mark-sweep)
2. **Go GC动态演示**: 支持三色标记清扫可视化

### 6.2 实用工具
1. **GCViewer**: [http://www.tagtraum.com/gcviewer.html](http://www.tagtraum.com/gcviewer.html) - GC日志可视化
2. **gcvis**: Go程序GC实时可视化工具

---

## 附录：SATB代码演示

```java
import java.util.ArrayList;
import java.util.List;

/**
 * 演示 G1 GC 中 SATB (Snapshot-At-The-Beginning) 机制的逻辑原理
 * 
 * 注意：这只是一个逻辑模拟。真实的 SATB 发生在 JVM native 层，
 * 当发生引用赋值时，JVM 会自动触发写前屏障 (Pre-write Barrier)。
 */
public class SatbDemo {
    
    // 模拟堆中的两个对象
    static class Node {
        String name;
        Node next;
        
        public Node(String name) {
            this.name = name;
        }
    }
    
    public static void main(String[] args) throws InterruptedException {
        System.out.println("=== 开始模拟 SATB 流程 ===");
        
        // 1. 初始状态：创建对象 A 和 B，A 引用 B
        Node nodeA = new Node("NodeA");
        Node nodeB = new Node("NodeB");
        nodeA.next = nodeB;
        
        System.out.println("1. 初始状态: NodeA -> NodeB");
        
        // 2. 模拟进入【并发标记阶段】
        System.out.println("2. GC 开始并发标记... (TAMS 指针设定)");
        
        // 3. 用户线程执行引用修改：断开 A 对 B 的引用，指向 C
        Node nodeC = new Node("NodeC");
        
        System.out.println("3. 用户线程执行: NodeA.next = NodeC");
        System.out.println("   >>> 触发 SATB 写前屏障 <<<");
        System.out.println("   >>> 屏障动作: 捕获旧引用 NodeB，将其加入 SATB 队列 <<<");
        
        // 执行实际的引用修改
        nodeA.next = nodeC;
        
        // 4. 模拟并发标记继续
        System.out.println("4. 并发标记继续... GC 线程处理 SATB 队列中的 NodeB");
        System.out.println("   >>> 结果: NodeB 被重新标记为存活，避免漏标 <<<");
        
        // 5. 最终标记阶段 (STW)
        System.out.println("5. 进入最终标记阶段 (Remark STW)...");
        System.out.println("   >>> 确保 SATB 队列中所有对象都被正确标记 <<<");
        
        System.out.println("\n=== 结论 ===");
        System.out.println("NodeB 虽然在业务逻辑中被断开了引用，但在本轮 GC 中仍被视为存活对象。");
        System.out.println("它将成为【浮动垃圾】，直到下一轮 GC 才会被真正回收。");
    }
}
```

---

## 参考资源
- [GraalVM官方文档](https://www.graalvm.org/docs/why-graal/)
- [GCViewer官方站点](http://www.tagtraum.com/gcviewer.html)
- [gcvis项目地址](https://gitcode.com/gh_mirrors/gc/gcvis)