# Server-Sent Events 技术专栏 - 深入理解与实战

## 一、SSE 基础原理

### 1.1 什么是 Server-Sent Events？

Server-Sent Events (SSE) 是一种基于 HTTP 的服务器推送技术，允许服务器向客户端单向发送事件流。它是 HTML5 规范的一部分，被设计为一种轻量级的实时通信解决方案。

**核心特点：**
- **单向通信**：仅支持服务器到客户端的数据推送
- **基于 HTTP**：使用标准 HTTP 协议，无需握手升级
- **自动重连**：浏览器原生支持断线重连机制
- **文本格式**：使用简单的文本格式传输数据
- **事件驱动**：支持事件类型和消息ID

### 1.2 SSE vs WebSocket vs HTTP 轮询

```
HTTP 轮询：
客户端 ──────请求──────> 服务器
客户端 <──────响应─────── 服务器
(连接关闭)
等待 2 秒...
客户端 ──────请求──────> 服务器
客户端 <──────响应─────── 服务器
(连接关闭)
等待 2 秒...

WebSocket：
客户端 <=====> 持续双向通信 <=====> 服务器
(连接保持)

SSE：
客户端 <======= 单向事件流 ======= 服务器
(连接保持，服务器持续推送)
```

**对比表格：**

| 特性 | HTTP 轮询 | WebSocket | SSE |
|------|----------|-----------|-----|
| 通信方向 | 单向 | 双向 | 单向 |
| 协议复杂度 | 低 | 高 | 低 |
| 浏览器支持 | 所有 | 现代浏览器 | 现代浏览器 |
| 自动重连 | 需手动实现 | 需手动实现 | 内置 |
| 数据格式 | 任意 | 二进制/文本 | 文本 |
| 服务器资源 | 高连接开销 | 中等连接开销 | 低连接开销 |

### 1.3 SSE 适用场景

**适合 SSE 的场景：**
- 实时新闻推送
- 股票价格更新
- 社交媒体动态
- 服务器状态监控
- 实时日志流
- 进度更新

**不适合 SSE 的场景：**
- 需要客户端向服务器频繁发送数据
- 二进制数据传输
- 低延迟要求的游戏应用
- 需要全双工通信的场景

## 二、SSE 协议详解

### 2.1 SSE 协议格式

SSE 使用简单的文本格式，每个事件由多个字段组成：

```
data: 这是一条消息
data: 这是第二条消息

event: customEvent
data: {"message": "自定义事件数据"}
id: 12345
retry: 3000

data: 多行数据
data: 可以通过多个
data: data 字段实现

: 这是一个注释，会被客户端忽略

```

### 2.2 SSE 字段说明

- **data**：事件的数据内容，多个 data 字段表示多行数据
- **event**：事件类型，默认为 "message"
- **id**：事件ID，用于断线重连时的恢复
- **retry**：重连间隔时间（毫秒），默认 3000ms
- **** (注释)**：以冒号开头的行被视为注释

### 2.3 SSE 响应格式要求

服务器必须设置正确的 HTTP 响应头：

```http
HTTP/1.1 200 OK
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
Access-Control-Allow-Origin: *

data: 欢迎连接到 SSE 服务

data: 第二条消息

```

**响应头说明：**
- `Content-Type: text/event-stream`：SSE 必需的 MIME 类型
- `Cache-Control: no-cache`：禁用缓存
- `Connection: keep-alive`：保持持久连接
- `Access-Control-Allow-Origin: *`：支持跨域请求

## 三、Java SSE 实现

### 3.1 基础 SSE Server 实现

```java
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import java.time.*;

public class SSEServer {

    private ServerSocket serverSocket;
    private ExecutorService executor = Executors.newCachedThreadPool();
    private Set<SSEConnection> connections = ConcurrentHashMap.newKeySet();

    public SSEServer(int port) throws IOException {
        this.serverSocket = new ServerSocket(port);
    }

    public void start() {
        System.out.println("SSE Server started on port " + serverSocket.getLocalPort());
        
        while (true) {
            try {
                Socket clientSocket = serverSocket.accept();
                executor.submit(() -> handleClient(clientSocket));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    private void handleClient(Socket clientSocket) {
        try {
            BufferedReader reader = new BufferedReader(
                new InputStreamReader(clientSocket.getInputStream()));
            OutputStream outputStream = clientSocket.getOutputStream();
            PrintWriter writer = new PrintWriter(outputStream, true);

            // 读取 HTTP 请求
            String requestLine = reader.readLine();
            if (requestLine == null || !requestLine.startsWith("GET")) {
                clientSocket.close();
                return;
            }

            // 读取所有头部
            Map<String, String> headers = new HashMap<>();
            String line;
            while ((line = reader.readLine()) != null && !line.isEmpty()) {
                int colonPos = line.indexOf(':');
                if (colonPos > 0) {
                    String key = line.substring(0, colonPos).trim();
                    String value = line.substring(colonPos + 1).trim();
                    headers.put(key, value);
                }
            }

            // 发送 SSE 响应头
            String sseHeaders = "HTTP/1.1 200 OK\r\n" +
                "Content-Type: text/event-stream\r\n" +
                "Cache-Control: no-cache\r\n" +
                "Connection: keep-alive\r\n" +
                "Access-Control-Allow-Origin: *\r\n\r\n";
            
            writer.print(sseHeaders);
            writer.flush();

            // 创建 SSE 连接
            SSEConnection connection = new SSEConnection(clientSocket, writer);
            connections.add(connection);
            
            // 发送连接成功消息
            connection.sendEvent("connected", "SSE 连接建立成功");
            
            System.out.println("SSE client connected: " + clientSocket.getRemoteSocketAddress());

            // 保持连接并监听客户端断开
            try {
                while (!clientSocket.isClosed()) {
                    if (reader.read() == -1) break;
                    Thread.sleep(100); // 检查连接状态
                }
            } catch (SocketException e) {
                // 客户端断开连接
            } finally {
                cleanup(connection);
            }

        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private void cleanup(SSEConnection connection) {
        try {
            connections.remove(connection);
            connection.close();
            System.out.println("SSE client disconnected");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void broadcast(String event, String data) {
        for (SSEConnection connection : connections) {
            connection.sendEvent(event, data);
        }
    }

    private class SSEConnection {
        private Socket socket;
        private PrintWriter writer;

        public SSEConnection(Socket socket, PrintWriter writer) {
            this.socket = socket;
            this.writer = writer;
        }

        public void sendEvent(String data) {
            sendEvent("message", data, null);
        }

        public void sendEvent(String event, String data) {
            sendEvent(event, data, null);
        }

        public void sendEvent(String event, String data, String eventId) {
            try {
                if (eventId != null) {
                    writer.println("id: " + eventId);
                }
                
                if (event != null && !event.equals("message")) {
                    writer.println("event: " + event);
                }
                
                // 处理多行数据
                String[] lines = data.split("\n");
                for (String line : lines) {
                    writer.println("data: " + line);
                }
                
                writer.println(); // 空行表示事件结束
                writer.flush();
                
            } catch (Exception e) {
                // 发送失败，连接可能已断开
                System.err.println("Failed to send event: " + e.getMessage());
            }
        }

        public void sendRetry(long retryTime) {
            writer.println("retry: " + retryTime);
            writer.println();
            writer.flush();
        }

        public void close() throws IOException {
            socket.close();
        }
    }

    public static void main(String[] args) throws IOException {
        SSEServer server = new SSEServer(8080);
        server.start();
    }
}
```

### 3.2 完整的 SSE Client 实现

```java
import java.io.*;
import java.net.*;
import java.util.*;

public class SSEClient {

    private URL serverUrl;
    private HttpURLConnection connection;
    private BufferedReader reader;
    private SSEEventListener eventListener;
    private volatile boolean running = false;
    private Thread receiveThread;
    private long lastEventId = 0;

    public interface SSEEventListener {
        void onMessage(String data);
        void onEvent(String event, String data);
        void onError(Exception e);
        void onOpen();
        void onClose();
    }

    public SSEClient(String serverUrl) throws MalformedURLException {
        this.serverUrl = new URL(serverUrl);
    }

    public void setEventListener(SSEEventListener listener) {
        this.eventListener = listener;
    }

    public void connect() throws IOException {
        connection = (HttpURLConnection) serverUrl.openConnection();
        connection.setRequestProperty("Accept", "text/event-stream");
        connection.setRequestProperty("Cache-Control", "no-cache");
        connection.setRequestProperty("Connection", "keep-alive");

        // 支持断点续传
        if (lastEventId > 0) {
            connection.setRequestProperty("Last-Event-ID", String.valueOf(lastEventId));
        }

        connection.setReadTimeout(0); // 无限等待
        connection.connect();

        if (connection.getResponseCode() != 200) {
            throw new IOException("Server returned HTTP " + connection.getResponseCode());
        }

        reader = new BufferedReader(new InputStreamReader(connection.getInputStream(), "UTF-8"));
        running = true;

        if (eventListener != null) {
            eventListener.onOpen();
        }

        // 启动接收线程
        receiveThread = new Thread(this::receiveLoop);
        receiveThread.start();
    }

    private void receiveLoop() {
        try {
            String line;
            StringBuilder dataBuffer = new StringBuilder();
            String currentEvent = "message";
            String currentEventId = null;

            while (running && (line = reader.readLine()) != null) {
                if (line.isEmpty()) {
                    // 空行表示事件结束
                    if (dataBuffer.length() > 0) {
                        dispatchEvent(currentEvent, dataBuffer.toString(), currentEventId);
                        dataBuffer = new StringBuilder();
                        currentEvent = "message";
                        currentEventId = null;
                    }
                } else if (line.startsWith(":")) {
                    // 注释行，忽略
                    continue;
                } else if (line.contains(":")) {
                    // 解析字段
                    int colonPos = line.indexOf(':');
                    String field = line.substring(0, colonPos).trim();
                    String value = line.substring(colonPos + 1).trim();

                    switch (field) {
                        case "data":
                            if (dataBuffer.length() > 0) {
                                dataBuffer.append("\n");
                            }
                            dataBuffer.append(value);
                            break;
                        case "event":
                            currentEvent = value;
                            break;
                        case "id":
                            currentEventId = value;
                            try {
                                lastEventId = Long.parseLong(value);
                            } catch (NumberFormatException e) {
                                // 忽略无效ID
                            }
                            break;
                        case "retry":
                            // 可以根据这个值调整重连间隔
                            break;
                    }
                }
            }

        } catch (SocketTimeoutException e) {
            // 超时，尝试重连
            handleReconnect();
        } catch (IOException e) {
            if (running) {
                if (eventListener != null) {
                    eventListener.onError(e);
                }
                handleReconnect();
            }
        } finally {
            close();
        }
    }

    private void dispatchEvent(String event, String data, String eventId) {
        if (eventListener != null) {
            if ("message".equals(event)) {
                eventListener.onMessage(data);
            } else {
                eventListener.onEvent(event, data);
            }
        }
    }

    private void handleReconnect() {
        if (!running) return;

        System.out.println("Connection lost, attempting to reconnect...");
        
        // 指数退避重连策略
        int retryCount = 0;
        long baseDelay = 1000; // 1秒基础延迟
        
        while (running && retryCount < 10) {
            try {
                long delay = (long) (baseDelay * Math.pow(2, retryCount));
                System.out.println("Reconnecting in " + (delay / 1000) + " seconds...");
                Thread.sleep(delay);
                
                connect();
                System.out.println("Reconnected successfully");
                return;
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            } catch (IOException e) {
                retryCount++;
                System.err.println("Reconnection failed, attempt " + retryCount);
            }
        }
        
        System.err.println("Max reconnection attempts reached");
    }

    public void close() {
        running = false;
        
        try {
            if (reader != null) {
                reader.close();
            }
            if (connection != null) {
                connection.disconnect();
            }
            if (receiveThread != null) {
                receiveThread.interrupt();
            }
            
            if (eventListener != null) {
                eventListener.onClose();
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        SSEClient client = new SSEClient("http://localhost:8080");
        
        client.setEventListener(new SSEEventListener() {
            @Override
            public void onMessage(String data) {
                System.out.println("收到消息: " + data);
            }

            @Override
            public void onEvent(String event, String data) {
                System.out.println("收到事件 [" + event + "]: " + data);
            }

            @Override
            public void onError(Exception e) {
                System.err.println("发生错误: " + e.getMessage());
            }

            @Override
            public void onOpen() {
                System.out.println("SSE 连接建立");
            }

            @Override
            public void onClose() {
                System.out.println("SSE 连接关闭");
            }
        });
        
        client.connect();
        
        // 保持运行
        Thread.sleep(60000);
        client.close();
    }
}
```

## 四、SSE 高级特性实现

### 4.1 事件类型系统

```java
public class SSEEventDispatcher {

    private Map<String, List<SSEEventHandler>> handlers = new ConcurrentHashMap<>();

    public interface SSEEventHandler {
        void handle(String data);
    }

    public void on(String eventType, SSEEventHandler handler) {
        handlers.computeIfAbsent(eventType, k -> new CopyOnWriteArrayList<>()).add(handler);
    }

    public void dispatch(String eventType, String data) {
        List<SSEEventHandler> eventHandlers = handlers.get(eventType);
        if (eventHandlers != null) {
            for (SSEEventHandler handler : eventHandlers) {
                try {
                    handler.handle(data);
                } catch (Exception e) {
                    System.err.println("Error handling event: " + e.getMessage());
                }
            }
        }
    }

    public void removeHandler(String eventType, SSEEventHandler handler) {
        List<SSEEventHandler> eventHandlers = handlers.get(eventType);
        if (eventHandlers != null) {
            eventHandlers.remove(handler);
        }
    }

    // 使用示例
    public static void main(String[] args) {
        SSEEventDispatcher dispatcher = new SSEEventDispatcher();

        // 注册不同类型的处理器
        dispatcher.on("news", data -> {
            System.out.println("收到新闻: " + data);
        });

        dispatcher.on("alert", data -> {
            System.out.println("收到警报: " + data);
        });

        dispatcher.on("status", data -> {
            System.out.println("状态更新: " + data);
        });

        // 分发事件
        dispatcher.dispatch("news", "Breaking: SSE技术发布");
        dispatcher.dispatch("alert", "服务器负载过高");
        dispatcher.dispatch("status", "CPU: 80%, Memory: 60%");
    }
}
```

### 4.2 JSON 数据序列化

```java
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public class SSEJsonUtils {

    private static final Gson gson = new GsonBuilder()
        .setDateFormat("yyyy-MM-dd HH:mm:ss")
        .create();

    public static String toJson(Object obj) {
        return gson.toJson(obj);
    }

    public static <T> T fromJson(String json, Class<T> classOfT) {
        return gson.fromJson(json, classOfT);
    }

    // SSE 事件数据包装器
    public static class SSEData<T> {
        private String type;
        private T data;
        private long timestamp;

        public SSEData(String type, T data) {
            this.type = type;
            this.data = data;
            this.timestamp = System.currentTimeMillis();
        }

        // Getters and setters
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public T getData() { return data; }
        public void setData(T data) { this.data = data; }
        public long getTimestamp() { return timestamp; }
        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    }

    // 使用示例
    public static void main(String[] args) {
        // 创建数据对象
        SSEData<String> eventData = new SSEData<>("user_login", "user123");
        
        // 转换为 JSON
        String json = toJson(eventData);
        System.out.println("JSON: " + json);
        
        // 解析 JSON
        SSEData<String> parsed = fromJson(json, SSEData.class);
        System.out.println("Type: " + parsed.getType());
        System.out.println("Data: " + parsed.getData());
    }
}
```

### 4.3 连接池管理

```java
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public class SSEConnectionPool {

    private final int maxConnections;
    private final AtomicInteger activeConnections = new AtomicInteger(0);
    private final Semaphore connectionSemaphore;
    private final ConcurrentMap<String, SSEConnection> connections = new ConcurrentHashMap<>();

    public SSEConnectionPool(int maxConnections) {
        this.maxConnections = maxConnections;
        this.connectionSemaphore = new Semaphore(maxConnections);
    }

    public SSEConnection acquireConnection(String connectionId) throws InterruptedException {
        connectionSemaphore.acquire();
        
        return connections.compute(connectionId, (id, existingConnection) -> {
            if (existingConnection != null && existingConnection.isActive()) {
                connectionSemaphore.release(); // 已有连接，释放信号量
                return existingConnection;
            }
            
            SSEConnection newConnection = new SSEConnection(id);
            activeConnections.incrementAndGet();
            return newConnection;
        });
    }

    public void releaseConnection(String connectionId) {
        SSEConnection connection = connections.get(connectionId);
        if (connection != null) {
            connection.close();
            connections.remove(connectionId);
            activeConnections.decrementAndGet();
            connectionSemaphore.release();
        }
    }

    public int getActiveConnectionCount() {
        return activeConnections.get();
    }

    public boolean isAvailable() {
        return connectionSemaphore.availablePermits() > 0;
    }

    private class SSEConnection {
        private String id;
        private long lastActivityTime;
        private volatile boolean active = true;

        public SSEConnection(String id) {
            this.id = id;
            this.lastActivityTime = System.currentTimeMillis();
        }

        public boolean isActive() {
            return active && (System.currentTimeMillis() - lastActivityTime) < 30000; // 30秒超时
        }

        public void updateActivity() {
            this.lastActivityTime = System.currentTimeMillis();
        }

        public void close() {
            active = false;
        }
    }
}
```

## 五、SSE 实战应用

### 5.1 实时股票价格推送

```java
import java.util.concurrent.*;
import java.util.*;

public class StockPricePusher {

    private SSEServer sseServer;
    private ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
    private Map<String, Stock> stocks = new ConcurrentHashMap<>();

    public StockPricePusher(int port) throws IOException {
        this.sseServer = new SSEServer(port);
        initializeStocks();
    }

    private void initializeStocks() {
        // 初始化一些股票数据
        stocks.put("AAPL", new Stock("AAPL", "Apple Inc.", 150.00));
        stocks.put("GOOGL", new Stock("GOOGL", "Alphabet Inc.", 2800.00));
        stocks.put("MSFT", new Stock("MSFT", "Microsoft Corp.", 300.00));
        stocks.put("AMZN", new Stock("AMZN", "Amazon.com", 3300.00));
    }

    public void start() {
        // 启动 SSE 服务器
        new Thread(() -> sseServer.start()).start();

        // 定时更新股票价格
        scheduler.scheduleAtFixedRate(this::updateStockPrices, 0, 1, TimeUnit.SECONDS);

        // 定时推送股票价格
        scheduler.scheduleAtFixedRate(this::pushStockPrices, 0, 2, TimeUnit.SECONDS);

        System.out.println("股票价格推送服务启动在端口 " + 8080);
    }

    private void updateStockPrices() {
        Random random = new Random();
        for (Stock stock : stocks.values()) {
            // 随机波动 ±2%
            double change = (random.nextDouble() - 0.5) * 0.04;
            double newPrice = stock.getPrice() * (1 + change);
            stock.setPrice(newPrice);
            stock.setChangePercent(change * 100);
        }
    }

    private void pushStockPrices() {
        for (Stock stock : stocks.values()) {
            String jsonData = SSEJsonUtils.toJson(stock);
            sseServer.broadcast("stock_update", jsonData);
        }
    }

    static class Stock {
        private String symbol;
        private String name;
        private double price;
        private double changePercent;

        public Stock(String symbol, String name, double price) {
            this.symbol = symbol;
            this.name = name;
            this.price = price;
        }

        // Getters and setters
        public String getSymbol() { return symbol; }
        public void setSymbol(String symbol) { this.symbol = symbol; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public double getPrice() { return price; }
        public void setPrice(double price) { this.price = price; }
        public double getChangePercent() { return changePercent; }
        public void setChangePercent(double changePercent) { this.changePercent = changePercent; }
    }

    public static void main(String[] args) throws IOException {
        StockPricePusher pusher = new StockPricePusher(8080);
        pusher.start();
    }
}
```

### 5.2 服务器监控实时推送

```java
import java.lang.management.*;
import java.util.concurrent.*;
import java.util.*;

public class ServerMonitorPusher {

    private SSEServer sseServer;
    private ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);

    public ServerMonitorPusher(int port) throws IOException {
        this.sseServer = new SSEServer(port);
    }

    public void start() {
        // 启动 SSE 服务器
        new Thread(() -> sseServer.start()).start();

        // 定时推送系统监控数据
        scheduler.scheduleAtFixedRate(this::pushSystemMetrics, 0, 5, TimeUnit.SECONDS);

        System.out.println("服务器监控推送服务启动在端口 " + 8080);
    }

    private void pushSystemMetrics() {
        SystemMetrics metrics = collectSystemMetrics();
        String jsonData = SSEJsonUtils.toJson(metrics);
        sseServer.broadcast("system_metrics", jsonData);
    }

    private SystemMetrics collectSystemMetrics() {
        SystemMetrics metrics = new SystemMetrics();
        
        // JVM 内存信息
        MemoryMXBean memoryMXBean = ManagementFactory.getMemoryMXBean();
        MemoryUsage heapMemory = memoryMXBean.getHeapMemoryUsage();
        metrics.setHeapUsed(heapMemory.getUsed() / 1024 / 1024); // MB
        metrics.setHeapMax(heapMemory.getMax() / 1024 / 1024);   // MB
        
        // CPU 使用率
        OperatingSystemMXBean osMXBean = ManagementFactory.getOperatingSystemMXBean();
        metrics.setCpuUsage(osMXBean.getSystemLoadAverage());
        
        // 线程信息
        ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();
        metrics.setThreadCount(threadMXBean.getThreadCount());
        
        // 运行时信息
        RuntimeMXBean runtimeMXBean = ManagementFactory.getRuntimeMXBean();
        metrics.setUptime(runtimeMXBean.getUptime() / 1000); // 秒
        
        // 时间戳
        metrics.setTimestamp(System.currentTimeMillis());
        
        return metrics;
    }

    static class SystemMetrics {
        private double heapUsed;      // MB
        private double heapMax;       // MB
        private double cpuUsage;      // 系统负载平均值
        private int threadCount;
        private long uptime;          // 秒
        private long timestamp;

        // Getters and setters
        public double getHeapUsed() { return heapUsed; }
        public void setHeapUsed(double heapUsed) { this.heapUsed = heapUsed; }
        public double getHeapMax() { return heapMax; }
        public void setHeapMax(double heapMax) { this.heapMax = heapMax; }
        public double getCpuUsage() { return cpuUsage; }
        public void setCpuUsage(double cpuUsage) { this.cpuUsage = cpuUsage; }
        public int getThreadCount() { return threadCount; }
        public void setThreadCount(int threadCount) { this.threadCount = threadCount; }
        public long getUptime() { return uptime; }
        public void setUptime(long uptime) { this.uptime = uptime; }
        public long getTimestamp() { return timestamp; }
        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    }

    public static void main(String[] args) throws IOException {
        ServerMonitorPusher pusher = new ServerMonitorPusher(8081);
        pusher.start();
    }
}
```

### 5.3 实时日志推送

```java
import java.io.*;
import java.util.concurrent.*;
import java.util.*;
import java.time.*;

public class LogStreamer {

    private SSEServer sseServer;
    private ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    private Queue<LogEntry> logBuffer = new ConcurrentLinkedQueue<>();
    private int maxBufferSize = 1000;

    public LogStreamer(int port) throws IOException {
        this.sseServer = new SSEServer(port);
    }

    public void start() {
        // 启动 SSE 服务器
        new Thread(() -> sseServer.start()).start();

        // 定时推送日志
        scheduler.scheduleAtFixedRate(this::pushLogs, 0, 1, TimeUnit.SECONDS);

        // 启动日志生成器（模拟应用日志）
        scheduler.scheduleAtFixedRate(this::generateSampleLogs, 0, 100, TimeUnit.MILLISECONDS);

        System.out.println("日志流推送服务启动在端口 " + 8082);
    }

    private void generateSampleLogs() {
        // 模拟生成不同级别的日志
        String[] levels = {"DEBUG", "INFO", "WARN", "ERROR"};
        String[] messages = {
            "用户登录成功",
            "数据库连接超时",
            "API 请求处理完成",
            "内存使用率过高",
            "缓存命中",
            "文件上传开始"
        };

        Random random = new Random();
        String level = levels[random.nextInt(levels.length)];
        String message = messages[random.nextInt(messages.length)];
        
        LogEntry entry = new LogEntry(level, message, LocalDateTime.now());
        addLog(entry);
    }

    public void addLog(LogEntry entry) {
        // 限制缓冲区大小
        if (logBuffer.size() >= maxBufferSize) {
            logBuffer.poll(); // 移除最老的日志
        }
        logBuffer.offer(entry);
    }

    private void pushLogs() {
        List<LogEntry> logsToPush = new ArrayList<>();
        
        while (!logBuffer.isEmpty() && logsToPush.size() < 100) {
            LogEntry entry = logBuffer.poll();
            logsToPush.add(entry);
        }

        if (!logsToPush.isEmpty()) {
            String jsonData = SSEJsonUtils.toJson(logsToPush);
            sseServer.broadcast("log_batch", jsonData);
        }
    }

    static class LogEntry {
        private String level;
        private String message;
        private LocalDateTime timestamp;

        public LogEntry(String level, String message, LocalDateTime timestamp) {
            this.level = level;
            this.message = message;
            this.timestamp = timestamp;
        }

        // Getters and setters
        public String getLevel() { return level; }
        public void setLevel(String level) { this.level = level; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
        public LocalDateTime getTimestamp() { return timestamp; }
        public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }
    }

    public static void main(String[] args) throws IOException {
        LogStreamer streamer = new LogStreamer(8082);
        streamer.start();
    }
}
```

## 六、SSE 性能优化

### 6.1 压缩传输

```java
import java.util.zip.*;
import java.io.*;

public class SSECompression {

    public static String compressData(String data) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        try (GZIPOutputStream gzipOutputStream = new GZIPOutputStream(byteArrayOutputStream)) {
            gzipOutputStream.write(data.getBytes("UTF-8"));
        }
        return Base64.getEncoder().encodeToString(byteArrayOutputStream.toByteArray());
    }

    public static String decompressData(String compressedData) throws IOException {
        byte[] compressedBytes = Base64.getDecoder().decode(compressedData);
        ByteArrayInputStream byteArrayInputStream = new ByteArrayInputStream(compressedBytes);
        
        try (GZIPInputStream gzipInputStream = new GZIPInputStream(byteArrayInputStream);
             ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
            
            byte[] buffer = new byte[1024];
            int len;
            while ((len = gzipInputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, len);
            }
            
            return outputStream.toString("UTF-8");
        }
    }

    // 使用压缩的 SSE 连接
    public static class CompressedSSEConnection {
        private SSEConnection connection;
        private boolean compressionEnabled;

        public CompressedSSEConnection(SSEConnection connection, boolean compressionEnabled) {
            this.connection = connection;
            this.compressionEnabled = compressionEnabled;
        }

        public void sendEvent(String event, String data) throws IOException {
            if (compressionEnabled) {
                String compressed = compressData(data);
                connection.sendEvent(event + "_compressed", compressed);
            } else {
                connection.sendEvent(event, data);
            }
        }
    }
}
```

### 6.2 批量消息优化

```java
import java.util.*;
import java.util.concurrent.*;

public class SSEBatchProcessor {

    private final int batchSize;
    private final long batchTimeout; // 毫秒
    private final List<String> messageBuffer = new ArrayList<>();
    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    private SSEConnection connection;

    public SSEBatchProcessor(SSEConnection connection, int batchSize, long batchTimeout) {
        this.connection = connection;
        this.batchSize = batchSize;
        this.batchTimeout = batchTimeout;
        startBatchProcessor();
    }

    public void addMessage(String message) {
        synchronized (messageBuffer) {
            messageBuffer.add(message);
            if (messageBuffer.size() >= batchSize) {
                flushBatch();
            }
        }
    }

    private void startBatchProcessor() {
        scheduler.scheduleAtFixedRate(() -> {
            synchronized (messageBuffer) {
                if (!messageBuffer.isEmpty()) {
                    flushBatch();
                }
            }
        }, batchTimeout, batchTimeout, TimeUnit.MILLISECONDS);
    }

    private void flushBatch() {
        if (messageBuffer.isEmpty()) return;

        List<String> batch = new ArrayList<>(messageBuffer);
        messageBuffer.clear();

        try {
            // 批量发送
            String batchData = SSEJsonUtils.toJson(batch);
            connection.sendEvent("batch", batchData);
        } catch (Exception e) {
            System.err.println("Failed to send batch: " + e.getMessage());
            // 失败时重新加入缓冲区
            messageBuffer.addAll(batch);
        }
    }

    public void shutdown() {
        scheduler.shutdown();
        try {
            if (!messageBuffer.isEmpty()) {
                flushBatch();
            }
        } catch (Exception e) {
            System.err.println("Error during shutdown: " + e.getMessage());
        }
    }
}
```

### 6.3 连接复用与负载均衡

```java
import java.util.*;
import java.util.concurrent.*;

public class SSELoadBalancer {

    private List<SSEServer> servers = new CopyOnWriteArrayList<>();
    private AtomicInteger currentIndex = new AtomicInteger(0);
    private ConcurrentMap<String, SSEServer> clientServerMapping = new ConcurrentHashMap<>();

    public void addServer(SSEServer server) {
        servers.add(server);
    }

    public SSEServer getNextServer(String clientId) {
        // 实现粘性会话 - 相同客户端总是连接到相同服务器
        SSEServer existingServer = clientServerMapping.get(clientId);
        if (existingServer != null && existingServer.isHealthy()) {
            return existingServer;
        }

        // 轮询选择服务器
        if (servers.isEmpty()) {
            throw new IllegalStateException("No available servers");
        }

        int index = currentIndex.getAndIncrement() % servers.size();
        SSEServer selectedServer = servers.get(index);
        
        if (selectedServer.isHealthy()) {
            clientServerMapping.put(clientId, selectedServer);
            return selectedServer;
        } else {
            // 服务器不健康，尝试下一个
            return getNextHealthyServer(index);
        }
    }

    private SSEServer getNextHealthyServer(int startIndex) {
        for (int i = 0; i < servers.size(); i++) {
            int index = (startIndex + i) % servers.size();
            SSEServer server = servers.get(index);
            if (server.isHealthy()) {
                return server;
            }
        }
        throw new IllegalStateException("No healthy servers available");
    }

    public void removeClient(String clientId) {
        clientServerMapping.remove(clientId);
    }

    // 扩展 SSEServer 类添加健康检查
    public static class SSEServer {
        private volatile boolean healthy = true;
        private long lastHealthCheck = System.currentTimeMillis();

        public boolean isHealthy() {
            // 简单的健康检查逻辑
            return healthy && 
                   (System.currentTimeMillis() - lastHealthCheck) < 60000; // 1分钟内检查过
        }

        public void setHealthy(boolean healthy) {
            this.healthy = healthy;
            this.lastHealthCheck = System.currentTimeMillis();
        }
    }
}
```

## 七、SSE 与 WebSocket 选择指南

### 7.1 技术对比矩阵

```java
public class RealTimeTechnologyComparison {

    public enum Technology {
        SSE, WEBSOCKET, HTTP_POLLING
    }

    public enum UseCase {
        STOCK_TICKER, CHAT_APP, LIVE_SCORES, DOCUMENT_EDITING, IOT_DEVICES
    }

    // 决策树
    public static Technology recommendTechnology(UseCase useCase, Requirements requirements) {
        
        // 如果需要双向通信
        if (requirements.needsBidirectionalCommunication()) {
            if (requirements.needsBinaryData()) {
                return Technology.WEBSOCKET;
            } else if (requirements.canUseSimpleProtocol()) {
                return Technology.WEBSOCKET;
            }
        }

        // 如果只需要服务器推送
        if (requirements.needsServerPushOnly()) {
            if (requirements.needsTextOnly()) {
                return Technology.SSE;
            } else if (requirements.needsAutomaticReconnection()) {
                return Technology.SSE;
            }
        }

        // 回退到 HTTP 轮询
        if (requirements.canToleratePolling()) {
            return Technology.HTTP_POLLING;
        }

        // 默认选择 WebSocket
        return Technology.WEBSOCKET;
    }

    static class Requirements {
        private boolean needsBidirectionalCommunication;
        private boolean needsServerPushOnly;
        private boolean needsBinaryData;
        private boolean needsTextOnly;
        private boolean needsAutomaticReconnection;
        private boolean canToleratePolling;
        private boolean canUseSimpleProtocol;

        // Getters and setters
        public boolean needsBidirectionalCommunication() { return needsBidirectionalCommunication; }
        public void setNeedsBidirectionalCommunication(boolean needsBidirectionalCommunication) { 
            this.needsBidirectionalCommunication = needsBidirectionalCommunication; 
        }
        public boolean needsServerPushOnly() { return needsServerPushOnly; }
        public void setNeedsServerPushOnly(boolean needsServerPushOnly) { 
            this.needsServerPushOnly = needsServerPushOnly; 
        }
        public boolean needsBinaryData() { return needsBinaryData; }
        public void setNeedsBinaryData(boolean needsBinaryData) { 
            this.needsBinaryData = needsBinaryData; 
        }
        public boolean needsTextOnly() { return needsTextOnly; }
        public void setNeedsTextOnly(boolean needsTextOnly) { 
            this.needsTextOnly = needsTextOnly; 
        }
        public boolean needsAutomaticReconnection() { return needsAutomaticReconnection; }
        public void setNeedsAutomaticReconnection(boolean needsAutomaticReconnection) { 
            this.needsAutomaticReconnection = needsAutomaticReconnection; 
        }
        public boolean canToleratePolling() { return canToleratePolling; }
        public void setCanToleratePolling(boolean canToleratePolling) { 
            this.canToleratePolling = canToleratePolling; 
        }
        public boolean canUseSimpleProtocol() { return canUseSimpleProtocol; }
        public void setCanUseSimpleProtocol(boolean canUseSimpleProtocol) { 
            this.canUseSimpleProtocol = canUseSimpleProtocol; 
        }
    }

    // 使用示例
    public static void main(String[] args) {
        // 股票价格推送场景
        Requirements stockRequirements = new Requirements();
        stockRequirements.setNeedsServerPushOnly(true);
        stockRequirements.setNeedsTextOnly(true);
        stockRequirements.setNeedsAutomaticReconnection(true);
        
        Technology recommended = recommendTechnology(UseCase.STOCK_TICKER, stockRequirements);
        System.out.println("推荐技术: " + recommended); // 应该输出 SSE

        // 聊天应用场景
        Requirements chatRequirements = new Requirements();
        chatRequirements.setNeedsBidirectionalCommunication(true);
        chatRequirements.setNeedsTextOnly(true);
        
        Technology chatRecommended = recommendTechnology(UseCase.CHAT_APP, chatRequirements);
        System.out.println("聊天应用推荐技术: " + chatRecommended); // 应该输出 WEBSOCKET
    }
}
```

## 八、SSE 最佳实践

### 8.1 连接生命周期管理

```java
public class SSEConnectionLifecycleManager {

    private final ConcurrentMap<String, SSEConnection> connections = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(2);
    private final long connectionTimeout; // 连接超时时间（毫秒）
    private final long heartbeatInterval; // 心跳间隔（毫秒）

    public SSEConnectionLifecycleManager(long connectionTimeout, long heartbeatInterval) {
        this.connectionTimeout = connectionTimeout;
        this.heartbeatInterval = heartbeatInterval;
        startConnectionMonitor();
        startHeartbeat();
    }

    public void addConnection(String connectionId, SSEConnection connection) {
        connections.put(connectionId, connection);
        sendWelcomeMessage(connection);
    }

    public void removeConnection(String connectionId) {
        SSEConnection connection = connections.remove(connectionId);
        if (connection != null) {
            connection.close();
        }
    }

    private void sendWelcomeMessage(SSEConnection connection) {
        try {
            connection.sendEvent("connected", "欢迎连接到 SSE 服务");
            connection.sendRetry(5000); // 设置重连间隔为 5 秒
        } catch (Exception e) {
            System.err.println("发送欢迎消息失败: " + e.getMessage());
        }
    }

    private void startConnectionMonitor() {
        scheduler.scheduleAtFixedRate(() -> {
            long currentTime = System.currentTimeMillis();
            Iterator<Map.Entry<String, SSEConnection>> iterator = connections.entrySet().iterator();
            
            while (iterator.hasNext()) {
                Map.Entry<String, SSEConnection> entry = iterator.next();
                SSEConnection connection = entry.getValue();
                
                // 检查连接是否超时
                if (currentTime - connection.getLastActivityTime() > connectionTimeout) {
                    System.out.println("连接超时，断开: " + entry.getKey());
                    iterator.remove();
                    connection.close();
                }
            }
        }, 30000, 30000, TimeUnit.MILLISECONDS); // 每 30 秒检查一次
    }

    private void startHeartbeat() {
        scheduler.scheduleAtFixedRate(() -> {
            for (SSEConnection connection : connections.values()) {
                try {
                    connection.sendEvent("heartbeat", String.valueOf(System.currentTimeMillis()));
                } catch (Exception e) {
                    System.err.println("心跳发送失败: " + e.getMessage());
                }
            }
        }, heartbeatInterval, heartbeatInterval, TimeUnit.MILLISECONDS);
    }

    public void shutdown() {
        scheduler.shutdown();
        for (SSEConnection connection : connections.values()) {
            connection.close();
        }
        connections.clear();
    }

    static class SSEConnection {
        private String connectionId;
        private long lastActivityTime;
        private java.net.Socket socket;
        private java.io.PrintWriter writer;

        public SSEConnection(String connectionId) {
            this.connectionId = connectionId;
            this.lastActivityTime = System.currentTimeMillis();
        }

        public void sendEvent(String event, String data) {
            // 实现发送逻辑
            this.lastActivityTime = System.currentTimeMillis();
        }

        public void sendRetry(long retryTime) {
            // 实现重连时间设置
        }

        public long getLastActivityTime() {
            return lastActivityTime;
        }

        public void close() {
            // 实现关闭逻辑
        }
    }

    public static void main(String[] args) throws InterruptedException {
        SSEConnectionLifecycleManager manager = 
            new SSEConnectionLifecycleManager(300000, 30000); // 5分钟超时，30秒心跳
        
        // 模拟运行
        Thread.sleep(60000);
        manager.shutdown();
    }
}
```

### 8.2 错误处理与监控

```java
import java.util.*;
import java.util.concurrent.*;

public class SSEErrorHandling {

    private final ConcurrentMap<String, ErrorStatistics> errorStats = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();

    public static class ErrorStatistics {
        private final AtomicInteger connectionErrors = new AtomicInteger(0);
        private final AtomicInteger sendErrors = new AtomicInteger(0);
        private final AtomicInteger parseErrors = new AtomicInteger(0);
        private volatile long lastErrorTime;

        public void recordConnectionError() {
            connectionErrors.incrementAndGet();
            updateLastErrorTime();
        }

        public void recordSendError() {
            sendErrors.incrementAndGet();
            updateLastErrorTime();
        }

        public void recordParseError() {
            parseErrors.incrementAndGet();
            updateLastErrorTime();
        }

        private void updateLastErrorTime() {
            this.lastErrorTime = System.currentTimeMillis();
        }

        public int getTotalErrors() {
            return connectionErrors.get() + sendErrors.get() + parseErrors.get();
        }

        public Map<String, Integer> getDetailedStats() {
            Map<String, Integer> stats = new HashMap<>();
            stats.put("connectionErrors", connectionErrors.get());
            stats.put("sendErrors", sendErrors.get());
            stats.put("parseErrors", parseErrors.get());
            return stats;
        }
    }

    public void recordError(String connectionId, String errorType) {
        ErrorStatistics stats = errorStats.computeIfAbsent(connectionId, k -> new ErrorStatistics());
        
        switch (errorType.toLowerCase()) {
            case "connection":
                stats.recordConnectionError();
                break;
            case "send":
                stats.recordSendError();
                break;
            case "parse":
                stats.recordParseError();
                break;
        }
    }

    public Map<String, Integer> getErrorStatistics(String connectionId) {
        ErrorStatistics stats = errorStats.get(connectionId);
        return stats != null ? stats.getDetailedStats() : Collections.emptyMap();
    }

    public void startErrorReporting() {
        scheduler.scheduleAtFixedRate(() -> {
            System.out.println("=== SSE 错误统计报告 ===");
            for (Map.Entry<String, ErrorStatistics> entry : errorStats.entrySet()) {
                String connectionId = entry.getKey();
                ErrorStatistics stats = entry.getValue();
                int totalErrors = stats.getTotalErrors();
                
                if (totalErrors > 0) {
                    System.out.printf("连接 %s: 总错误数 %d, 详细统计: %s%n",
                        connectionId, totalErrors, stats.getDetailedStats());
                }
            }
        }, 1, 1, TimeUnit.MINUTES);
    }

    public void shutdown() {
        scheduler.shutdown();
    }

    // 使用示例
    public static void main(String[] args) throws InterruptedException {
        SSEErrorHandling errorHandling = new SSEErrorHandling();
        errorHandling.startErrorReporting();

        // 模拟错误记录
        errorHandling.recordError("conn-001", "connection");
        errorHandling.recordError("conn-001", "send");
        errorHandling.recordError("conn-002", "parse");

        Thread.sleep(70000); // 等待报告生成
        errorHandling.shutdown();
    }
}
```

## 九、总结

通过本专栏的学习，我们深入了解了 Server-Sent Events 技术的核心原理和实际应用：

### 9.1 核心优势
- **简单易用**：基于 HTTP，无需复杂握手
- **自动重连**：浏览器原生支持断线重连
- **事件驱动**：支持不同类型的事件处理
- **单向推送**：非常适合服务器到客户端的数据推送场景

### 9.2 技术特点
- **文本格式**：简单的文本协议，易于调试
- **HTTP 兼容**：可以穿过代理和防火墙
- **浏览器支持**：现代浏览器原生支持
- **低延迟**：比 HTTP 轮询更高效

### 9.3 应用场景
SSE 特别适合以下场景：
- 实时数据推送（股票、新闻、天气）
- 服务器状态监控
- 实时日志流
- 进度更新通知

---

## 十、浏览器端 WebSocket 与 SSE 使用教程

### 10.1 浏览器端 SSE 使用（EventSource API）

SSE 在浏览器端使用原生 `EventSource` API，非常简单：

```javascript
// 创建 SSE 连接
const eventSource = new EventSource('/sse/events');

// 监听默认消息事件
eventSource.addEventListener('message', (event) => {
    console.log('收到消息:', event.data);
    
    // 解析 JSON 数据
    try {
        const data = JSON.parse(event.data);
        console.log('解析后的数据:', data);
    } catch (e) {
        console.log('非 JSON 数据');
    }
});

// 监听自定义事件
eventSource.addEventListener('stock_update', (event) => {
    console.log('股票更新:', event.data);
});

eventSource.addEventListener('heartbeat', (event) => {
    console.log('心跳:', event.data);
});

// 监听连接状态
eventSource.addEventListener('open', () => {
    console.log('SSE 连接已建立');
});

eventSource.addEventListener('error', (event) => {
    console.error('SSE 错误:', event);
    
    // 连接关闭时的处理
    if (eventSource.readyState === EventSource.CLOSED) {
        console.log('SSE 连接已关闭');
    }
});

// 手动关闭连接
// eventSource.close();
```

**EventSource 状态常量：**

```javascript
EventSource.CONNECTING;  // 0 - 正在连接
EventSource.OPEN;       // 1 - 连接已打开
EventSource.CLOSED;     // 2 - 连接已关闭
```

**设置请求头（需要使用 polyfill 或 XMLHttpRequest）：**

```javascript
// 标准 EventSource 不支持自定义请求头
// 如果需要认证等场景，可以使用 polyfill 或封装
class CustomEventSource {
    constructor(url, options = {}) {
        this.url = url;
        this.headers = options.headers || {};
        this.eventListeners = {};
        this.xhr = null;
        this.reconnectDelay = options.reconnectDelay || 3000;
        this.lastEventId = '';
    }
    
    addEventListener(eventName, callback) {
        if (!this.eventListeners[eventName]) {
            this.eventListeners[eventName] = [];
        }
        this.eventListeners[eventName].push(callback);
    }
    
    removeEventListener(eventName, callback) {
        if (this.eventListeners[eventName]) {
            this.eventListeners[eventName] = this.eventListeners[eventName]
                .filter(cb => cb !== callback);
        }
    }
    
    dispatchEvent(eventName, data) {
        const listeners = this.eventListeners[eventName];
        if (listeners) {
            listeners.forEach(callback => callback({ data }));
        }
    }
    
    connect() {
        this.xhr = new XMLHttpRequest();
        const url = this.url + (this.lastEventId ? `?lastEventId=${this.lastEventId}` : '');
        
        this.xhr.open('GET', url, true);
        
        // 设置自定义请求头
        for (const [key, value] of Object.entries(this.headers)) {
            this.xhr.setRequestHeader(key, value);
        }
        
        this.xhr.setRequestHeader('Accept', 'text/event-stream');
        this.xhr.setRequestHeader('Cache-Control', 'no-cache');
        
        let buffer = '';
        
        this.xhr.onprogress = () => {
            if (this.xhr.responseText) {
                const newData = this.xhr.responseText.substring(buffer.length);
                buffer = this.xhr.responseText;
                this.parseEvents(newData);
            }
        };
        
        this.xhr.onload = () => {
            console.log('连接正常关闭');
            this.scheduleReconnect();
        };
        
        this.xhr.onerror = () => {
            console.error('连接错误');
            this.scheduleReconnect();
        };
        
        this.xhr.send();
    }
    
    parseEvents(data) {
        const events = data.split('\n\n');
        
        for (const eventStr of events) {
            if (!eventStr.trim()) continue;
            
            const lines = eventStr.split('\n');
            let eventType = 'message';
            let eventData = '';
            let eventId = '';
            
            for (const line of lines) {
                if (line.startsWith('event:')) {
                    eventType = line.substring(6).trim();
                } else if (line.startsWith('data:')) {
                    eventData += line.substring(5).trim() + '\n';
                } else if (line.startsWith('id:')) {
                    eventId = line.substring(3).trim();
                }
            }
            
            if (eventId) {
                this.lastEventId = eventId;
            }
            
            if (eventData) {
                this.dispatchEvent(eventType, eventData.trim());
            }
        }
    }
    
    scheduleReconnect() {
        setTimeout(() => this.connect(), this.reconnectDelay);
    }
    
    close() {
        if (this.xhr) {
            this.xhr.abort();
            this.xhr = null;
        }
    }
}

// 使用自定义 SSE 客户端
const sse = new CustomEventSource('/sse/events', {
    headers: {
        'Authorization': 'Bearer token'
    },
    reconnectDelay: 5000
});

sse.addEventListener('message', (event) => {
    console.log('消息:', event.data);
});

sse.connect();
```

### 10.2 浏览器端 WebSocket 使用

WebSocket 在浏览器端使用原生 `WebSocket` API：

```javascript
// 创建 WebSocket 连接
// ws:// 或 wss://（加密）
const socket = new WebSocket('ws://localhost:8080/ws');

// 连接建立
socket.addEventListener('open', () => {
    console.log('WebSocket 连接已建立');
    
    // 发送消息
    socket.send(JSON.stringify({
        type: 'subscribe',
        channel: 'stock'
    }));
});

// 接收消息
socket.addEventListener('message', (event) => {
    console.log('收到消息:', event.data);
    
    // 解析 JSON
    try {
        const data = JSON.parse(event.data);
        console.log('解析后的数据:', data);
        
        // 根据消息类型处理
        switch (data.type) {
            case 'stock_update':
                handleStockUpdate(data.payload);
                break;
            case 'heartbeat':
                handleHeartbeat(data.payload);
                break;
            default:
                console.log('未知消息类型');
        }
    } catch (e) {
        console.log('非 JSON 消息');
    }
});

// 连接关闭
socket.addEventListener('close', (event) => {
    console.log('WebSocket 连接关闭', event.code, event.reason);
    
    // 尝试重连
    if (event.code !== 1000) {
        setTimeout(() => connectWebSocket(), 3000);
    }
});

// 错误处理
socket.addEventListener('error', (error) => {
    console.error('WebSocket 错误:', error);
});

// 发送二进制数据
const blob = new Blob(['binary data'], { type: 'application/octet-stream' });
socket.send(blob);

// 发送 ArrayBuffer
const buffer = new ArrayBuffer(8);
const view = new DataView(buffer);
view.setInt32(0, 42);
socket.send(buffer);

// 手动关闭连接
// socket.close(1000, '正常关闭');
```

**WebSocket 状态常量：**

```javascript
WebSocket.CONNECTING;  // 0 - 正在连接
WebSocket.OPEN;       // 1 - 连接已打开
WebSocket.CLOSING;    // 2 - 正在关闭
WebSocket.CLOSED;     // 3 - 连接已关闭
```

**关闭码说明：**

```javascript
1000: 正常关闭
1001: 端点正在离开（服务器关闭或浏览器导航离开页面）
1002: 端点协议错误
1003: 端点收到不支持的数据类型
1004: 保留（未使用）
1005: 无状态码（异常关闭）
1006: 异常关闭
1007: 消息格式错误
1008: 策略冲突
1009: 消息过大
1010: 客户端期望扩展，但服务器不支持
1011: 服务器内部错误
```

### 10.3 封装 WebSocket 客户端

```javascript
class WebSocketClient {
    constructor(url, options = {}) {
        this.url = url;
        this.reconnectDelay = options.reconnectDelay || 3000;
        this.maxReconnectAttempts = options.maxReconnectAttempts || 10;
        this.reconnectAttempts = 0;
        this.socket = null;
        this.eventListeners = {};
        this.heartbeatInterval = options.heartbeatInterval || 30000;
        this.heartbeatTimer = null;
    }
    
    connect() {
        this.socket = new WebSocket(this.url);
        
        this.socket.addEventListener('open', () => {
            console.log('WebSocket 连接已建立');
            this.reconnectAttempts = 0;
            this.startHeartbeat();
            this.dispatchEvent('open');
        });
        
        this.socket.addEventListener('message', (event) => {
            this.dispatchEvent('message', event.data);
        });
        
        this.socket.addEventListener('close', (event) => {
            console.log('WebSocket 连接关闭', event.code, event.reason);
            this.stopHeartbeat();
            this.dispatchEvent('close', { code: event.code, reason: event.reason });
            
            // 自动重连（排除正常关闭）
            if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                console.log(`第 ${this.reconnectAttempts} 次重连...`);
                setTimeout(() => this.connect(), this.reconnectDelay * this.reconnectAttempts);
            }
        });
        
        this.socket.addEventListener('error', (error) => {
            console.error('WebSocket 错误:', error);
            this.dispatchEvent('error', error);
        });
    }
    
    send(data) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            const payload = typeof data === 'string' ? data : JSON.stringify(data);
            this.socket.send(payload);
            return true;
        }
        console.error('WebSocket 未连接');
        return false;
    }
    
    sendBinary(data) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            this.socket.send(data);
            return true;
        }
        return false;
    }
    
    addEventListener(eventName, callback) {
        if (!this.eventListeners[eventName]) {
            this.eventListeners[eventName] = [];
        }
        this.eventListeners[eventName].push(callback);
    }
    
    removeEventListener(eventName, callback) {
        if (this.eventListeners[eventName]) {
            this.eventListeners[eventName] = this.eventListeners[eventName]
                .filter(cb => cb !== callback);
        }
    }
    
    dispatchEvent(eventName, data) {
        const listeners = this.eventListeners[eventName];
        if (listeners) {
            listeners.forEach(callback => callback(data));
        }
    }
    
    startHeartbeat() {
        this.stopHeartbeat();
        this.heartbeatTimer = setInterval(() => {
            this.send({ type: 'heartbeat', timestamp: Date.now() });
        }, this.heartbeatInterval);
    }
    
    stopHeartbeat() {
        if (this.heartbeatTimer) {
            clearInterval(this.heartbeatTimer);
            this.heartbeatTimer = null;
        }
    }
    
    close(code = 1000, reason = '正常关闭') {
        if (this.socket) {
            this.socket.close(code, reason);
            this.socket = null;
        }
        this.stopHeartbeat();
    }
    
    get readyState() {
        return this.socket ? this.socket.readyState : WebSocket.CLOSED;
    }
}

// 使用封装的 WebSocket 客户端
const wsClient = new WebSocketClient('ws://localhost:8080/ws', {
    reconnectDelay: 3000,
    maxReconnectAttempts: 10,
    heartbeatInterval: 30000
});

wsClient.addEventListener('open', () => {
    console.log('连接成功');
    wsClient.send({ type: 'subscribe', channel: 'news' });
});

wsClient.addEventListener('message', (data) => {
    console.log('收到消息:', data);
});

wsClient.addEventListener('close', (event) => {
    console.log('连接关闭:', event);
});

wsClient.addEventListener('error', (error) => {
    console.error('错误:', error);
});

// 启动连接
wsClient.connect();

// 发送消息
// wsClient.send({ type: 'chat', message: 'Hello' });

// 关闭连接
// wsClient.close();
```

### 10.4 SSE 与 WebSocket 浏览器 API 对比

| 特性 | SSE (EventSource) | WebSocket |
|------|-------------------|-----------|
| **API 复杂度** | 简单 | 中等 |
| **自动重连** | 内置支持 | 需手动实现 |
| **通信方向** | 单向（服务器→客户端） | 双向 |
| **数据格式** | 文本（text/event-stream） | 文本/二进制 |
| **请求头** | 有限制 | 无限制 |
| **认证支持** | 受限（需 polyfill） | 完整支持 |
| **代理穿透** | 好（HTTP） | 需配置 |
| **断线恢复** | 内置（last-event-id） | 需手动实现 |
| **心跳机制** | 需服务器发送 | 需手动实现 |

### 10.5 浏览器兼容性

**SSE 兼容性：**
- Chrome: 6+
- Firefox: 6+
- Safari: 5+
- Edge: 12+
- IE: 不支持（需 polyfill）

**WebSocket 兼容性：**
- Chrome: 4+
- Firefox: 4+
- Safari: 5+
- Edge: 12+
- IE: 10+

### 10.6 实际应用示例：实时股票推送

**HTML 页面：**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>实时股票行情</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .stock { border: 1px solid #ccc; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .stock-name { font-size: 1.2em; font-weight: bold; }
        .stock-price { font-size: 1.5em; margin: 10px 0; }
        .up { color: #e74c3c; }
        .down { color: #27ae60; }
        .status { margin-top: 20px; padding: 10px; border-radius: 4px; }
        .connected { background-color: #d4edda; color: #155724; }
        .disconnected { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <h1>实时股票行情</h1>
    
    <div id="status" class="status disconnected">
        连接状态：未连接
    </div>
    
    <div id="stock-list">
        <!-- 股票列表将动态生成 -->
    </div>

    <script>
        // 使用 SSE 获取实时股票数据
        const eventSource = new EventSource('/sse/stocks');
        const stockList = document.getElementById('stock-list');
        const statusDiv = document.getElementById('status');
        const stocks = {};

        // 更新状态显示
        function updateStatus(isConnected) {
            if (isConnected) {
                statusDiv.className = 'status connected';
                statusDiv.textContent = '连接状态：已连接';
            } else {
                statusDiv.className = 'status disconnected';
                statusDiv.textContent = '连接状态：未连接（自动重连中）';
            }
        }

        // 创建股票元素
        function createStockElement(stock) {
            const div = document.createElement('div');
            div.className = 'stock';
            div.id = `stock-${stock.code}`;
            div.innerHTML = `
                <div class="stock-name">${stock.name} (${stock.code})</div>
                <div class="stock-price ${stock.change >= 0 ? 'up' : 'down'}">
                    ¥${stock.price.toFixed(2)}
                </div>
                <div>涨跌：${stock.change >= 0 ? '+' : ''}${stock.change.toFixed(2)} 
                    (${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toFixed(2)}%)</div>
                <div>成交量：${stock.volume}</div>
            `;
            return div;
        }

        // 更新股票显示
        function updateStockDisplay(stock) {
            let element = document.getElementById(`stock-${stock.code}`);
            
            if (!element) {
                element = createStockElement(stock);
                stockList.appendChild(element);
            } else {
                // 更新价格
                const priceElement = element.querySelector('.stock-price');
                priceElement.textContent = `¥${stock.price.toFixed(2)}`;
                priceElement.className = `stock-price ${stock.change >= 0 ? 'up' : 'down'}`;
                
                // 更新涨跌
                const infoElements = element.querySelectorAll('div');
                infoElements[2].textContent = 
                    `涨跌：${stock.change >= 0 ? '+' : ''}${stock.change.toFixed(2)} 
                    (${stock.changePercent >= 0 ? '+' : ''}${stock.changePercent.toFixed(2)}%)`;
                infoElements[3].textContent = `成交量：${stock.volume}`;
            }
        }

        // 处理股票更新事件
        eventSource.addEventListener('stock_update', (event) => {
            try {
                const stock = JSON.parse(event.data);
                stocks[stock.code] = stock;
                updateStockDisplay(stock);
            } catch (e) {
                console.error('解析股票数据失败:', e);
            }
        });

        // 处理初始数据
        eventSource.addEventListener('initial_data', (event) => {
            try {
                const stockListData = JSON.parse(event.data);
                stockListData.forEach(stock => {
                    stocks[stock.code] = stock;
                    updateStockDisplay(stock);
                });
            } catch (e) {
                console.error('解析初始数据失败:', e);
            }
        });

        // 连接状态
        eventSource.addEventListener('open', () => {
            updateStatus(true);
        });

        eventSource.addEventListener('error', () => {
            updateStatus(false);
        });

        // 页面关闭时断开连接
        window.addEventListener('beforeunload', () => {
            eventSource.close();
        });
    </script>
</body>
</html>
```

### 10.7 实际应用示例：WebSocket 聊天室

**HTML 页面：**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>WebSocket 聊天室</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
        #messages { height: 400px; overflow-y: auto; border: 1px solid #ccc; padding: 10px; margin-bottom: 10px; }
        .message { margin: 5px 0; padding: 5px; border-radius: 4px; }
        .received { background-color: #f0f0f0; }
        .sent { background-color: #e3f2fd; text-align: right; }
        #input-area { display: flex; gap: 10px; }
        #message-input { flex: 1; padding: 10px; font-size: 16px; }
        #send-btn { padding: 10px 20px; font-size: 16px; }
        #status { margin-bottom: 10px; padding: 5px; border-radius: 4px; }
        .connected { background-color: #d4edda; color: #155724; }
        .disconnected { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <h1>WebSocket 聊天室</h1>
    
    <div id="status" class="status disconnected">
        连接状态：未连接
    </div>
    
    <div id="messages">
        <!-- 消息列表 -->
    </div>
    
    <div id="input-area">
        <input type="text" id="message-input" placeholder="输入消息..." />
        <button id="send-btn">发送</button>
    </div>

    <script>
        const socket = new WebSocket('ws://localhost:8080/chat');
        const messagesDiv = document.getElementById('messages');
        const messageInput = document.getElementById('message-input');
        const sendBtn = document.getElementById('send-btn');
        const statusDiv = document.getElementById('status');
        const username = prompt('请输入用户名：', '用户' + Math.floor(Math.random() * 1000));

        function updateStatus(isConnected) {
            if (isConnected) {
                statusDiv.className = 'status connected';
                statusDiv.textContent = '连接状态：已连接';
                sendBtn.disabled = false;
                messageInput.disabled = false;
            } else {
                statusDiv.className = 'status disconnected';
                statusDiv.textContent = '连接状态：未连接';
                sendBtn.disabled = true;
                messageInput.disabled = true;
            }
        }

        function addMessage(text, isSent = false) {
            const messageDiv = document.createElement('div');
            messageDiv.className = `message ${isSent ? 'sent' : 'received'}`;
            messageDiv.textContent = text;
            messagesDiv.appendChild(messageDiv);
            messagesDiv.scrollTop = messagesDiv.scrollHeight;
        }

        socket.addEventListener('open', () => {
            updateStatus(true);
            addMessage('已连接到聊天室');
            
            // 发送登录消息
            socket.send(JSON.stringify({
                type: 'login',
                username: username
            }));
        });

        socket.addEventListener('message', (event) => {
            try {
                const data = JSON.parse(event.data);
                
                switch (data.type) {
                    case 'message':
                        addMessage(`${data.username}: ${data.content}`);
                        break;
                    case 'system':
                        addMessage(`[系统] ${data.content}`);
                        break;
                    case 'login':
                        addMessage(`[系统] ${data.username} 加入了聊天室`);
                        break;
                    case 'logout':
                        addMessage(`[系统] ${data.username} 离开了聊天室`);
                        break;
                    default:
                        addMessage(`[未知] ${event.data}`);
                }
            } catch (e) {
                addMessage(`[原始] ${event.data}`);
            }
        });

        socket.addEventListener('close', () => {
            updateStatus(false);
            addMessage('连接已断开');
        });

        socket.addEventListener('error', (error) => {
            console.error('WebSocket 错误:', error);
            addMessage('连接出错');
        });

        function sendMessage() {
            const text = messageInput.value.trim();
            if (!text) return;

            socket.send(JSON.stringify({
                type: 'message',
                username: username,
                content: text
            }));

            addMessage(`我: ${text}`, true);
            messageInput.value = '';
        }

        sendBtn.addEventListener('click', sendMessage);
        messageInput.addEventListener('keypress', (event) => {
            if (event.key === 'Enter') {
                sendMessage();
            }
        });

        window.addEventListener('beforeunload', () => {
            socket.close(1000, '用户离开');
        });
    </script>
</body>
</html>
```