# WebSocket 技术专栏 - 深入理解与实战

## 一、WebSocket 基础原理

### 1.1 什么是 WebSocket？

WebSocket 是一种在单个 TCP 连接上进行全双工通信的协议。它于 2011 年被 IETF 标准化为 RFC 6455，设计目的是在 Web 浏览器和服务器之间提供实时、双向的数据传输能力。

**核心特点：**
- **全双工通信**：客户端和服务器可以同时发送数据
- **持久连接**：一旦建立连接，保持开放状态直到显式关闭
- **低开销**：相比 HTTP 轮询，减少了头部开销和连接建立次数
- **实时性**：服务器可以主动向客户端推送数据

### 1.2 WebSocket vs HTTP

```
HTTP 请求-响应模型：
客户端 ──────请求──────> 服务器
客户端 <──────响应─────── 服务器
(连接关闭)

HTTP 轮询模型：
客户端 ──────请求──────> 服务器
客户端 <──────响应─────── 服务器
(连接关闭)
客户端 ──────请求──────> 服务器
客户端 <──────响应─────── 服务器
(连接关闭)
... 重复

WebSocket 模型：
客户端 <=====> 握手 <=====> 服务器
客户端 <=====> 持续双向通信 <=====> 服务器
(连接保持)
```

### 1.3 WebSocket 握手过程

WebSocket 通过 HTTP Upgrade 机制建立连接：

```
客户端请求：
GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13

服务器响应：
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

握手成功后，连接从 HTTP 协议升级到 WebSocket 协议。

## 二、WebSocket 协议详解

### 2.1 WebSocket 帧格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+------+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-+-+-+------+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127    |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

**字段说明：**
- **FIN (1 bit)**：表示是否为最后一个分片
- **RSV1-3 (3 bits)**：保留位，用于扩展
- **Opcode (4 bits)**：操作码，定义帧类型
  - 0x0：继续帧
  - 0x1：文本帧
  - 0x2：二进制帧
  - 0x8：关闭帧
  - 0x9：Ping帧
  - 0xA：Pong帧
- **MASK (1 bit)**：是否使用掩码（客户端发送的帧必须为1）
- **Payload length (7 bits)**：负载数据长度
- **Masking key (32 bits)**：掩码密钥
- **Payload data**：实际数据

### 2.2 数据掩码机制

客户端发送的数据必须进行掩码处理：

```java
// 掩码算法
private static byte[] unmask(byte[] maskedData, byte[] maskKey) {
    byte[] unmaskedData = new byte[maskedData.length];
    for (int i = 0; i < maskedData.length; i++) {
        unmaskedData[i] = (byte) (maskedData[i] ^ maskKey[i % 4]);
    }
    return unmaskedData;
}
```

掩码目的是防止缓存污染攻击，确保恶意脚本无法通过 WebSocket 操纵代理服务器的缓存。

## 三、Java WebSocket 实现

### 3.1 基础 Server 实现

```java
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import java.security.*;

public class WebSocketServer {

    private ServerSocket serverSocket;
    private ExecutorService executor = Executors.newCachedThreadPool();
    private Set<WebSocketClient> clients = ConcurrentHashMap.newKeySet();

    public WebSocketServer(int port) throws IOException {
        this.serverSocket = new ServerSocket(port);
    }

    public void start() {
        System.out.println("WebSocket Server started on port " + serverSocket.getLocalPort());
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

            // 读取握手请求
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

            // 检查是否为 WebSocket 握手请求
            String upgrade = headers.get("Upgrade");
            String connection = headers.get("Connection");
            String webSocketKey = headers.get("Sec-WebSocket-Key");

            if ("websocket".equalsIgnoreCase(upgrade) &&
                "Upgrade".equalsIgnoreCase(connection) &&
                webSocketKey != null) {

                // 生成接受密钥
                String acceptKey = generateAcceptKey(webSocketKey);

                // 发送握手响应
                String response = "HTTP/1.1 101 Switching Protocols\r\n" +
                    "Upgrade: websocket\r\n" +
                    "Connection: Upgrade\r\n" +
                    "Sec-WebSocket-Accept: " + acceptKey + "\r\n\r\n";
                outputStream.write(response.getBytes());
                outputStream.flush();

                // 创建 WebSocket 客户端连接
                WebSocketClient client = new WebSocketClient(clientSocket, reader, outputStream);
                clients.add(client);
                client.start();

                System.out.println("WebSocket client connected: " + clientSocket.getRemoteSocketAddress());
            } else {
                clientSocket.close();
            }

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private String generateAcceptKey(String webSocketKey) throws NoSuchAlgorithmException {
        String magicString = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        String combined = webSocketKey + magicString;
        MessageDigest sha1 = MessageDigest.getInstance("SHA-1");
        byte[] hash = sha1.digest(combined.getBytes());
        return Base64.getEncoder().encodeToString(hash);
    }

    public void broadcast(String message) {
        for (WebSocketClient client : clients) {
            client.send(message);
        }
    }

    private class WebSocketClient {
        private Socket socket;
        private BufferedReader reader;
        private OutputStream outputStream;
        private Thread readThread;

        public WebSocketClient(Socket socket, BufferedReader reader, OutputStream outputStream) {
            this.socket = socket;
            this.reader = reader;
            this.outputStream = outputStream;
        }

        public void start() {
            readThread = new Thread(this::readLoop);
            readThread.start();
        }

        private void readLoop() {
            try {
                while (!socket.isClosed()) {
                    int data = reader.read();
                    if (data == -1) break;

                    // 简化的帧解析（只处理文本帧）
                    // 实际实现需要完整的帧解析
                    StringBuilder message = new StringBuilder();
                    // 这里应该是完整的 WebSocket 帧解析
                    // 为简化示例，省略详细实现

                    String receivedMessage = message.toString();
                    System.out.println("Received: " + receivedMessage);

                    // 回显消息
                    send(receivedMessage);
                }
            } catch (IOException e) {
                e.printStackTrace();
            } finally {
                cleanup();
            }
        }

        public void send(String message) {
            try {
                byte[] messageBytes = message.getBytes();
                byte[] frame = createFrame(messageBytes);
                outputStream.write(frame);
                outputStream.flush();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }

        private byte[] createFrame(byte[] messageBytes) {
            ByteArrayOutputStream frame = new ByteArrayOutputStream();

            // FIN + 文本帧 opcode
            frame.write(0x81);

            // 长度字段
            int length = messageBytes.length;
            if (length <= 125) {
                frame.write(length);
            } else if (length <= 65535) {
                frame.write(126);
                frame.write((length >> 8) & 0xFF);
                frame.write(length & 0xFF);
            } else {
                frame.write(127);
                // 长度为 64 位，这里简化处理
                for (int i = 56; i >= 0; i -= 8) {
                    frame.write((length >> i) & 0xFF);
                }
            }

            // 负载数据（服务器到客户端不需要掩码）
            frame.write(messageBytes);

            return frame.toByteArray();
        }

        private void cleanup() {
            try {
                clients.remove(this);
                socket.close();
                System.out.println("Client disconnected: " + socket.getRemoteSocketAddress());
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public static void main(String[] args) throws IOException {
        WebSocketServer server = new WebSocketServer(8080);
        server.start();
    }
}
```

### 3.2 基础 Client 实现

```java
import java.io.*;
import java.net.*;
import java.security.*;
import java.util.*;

public class WebSocketClient {

    private Socket socket;
    private BufferedReader reader;
    private OutputStream outputStream;
    private BufferedReader consoleReader;

    public WebSocketClient(String host, int port) throws IOException {
        this.socket = new Socket(host, port);
        this.reader = new BufferedReader(new InputStreamReader(socket.getInputStream()));
        this.outputStream = socket.getOutputStream();
        this.consoleReader = new BufferedReader(new InputStreamReader(System.in));
    }

    public void connect() throws IOException, NoSuchAlgorithmException {
        // 生成 WebSocket 密钥
        String webSocketKey = generateWebSocketKey();

        // 发送握手请求
        String handshake = "GET / HTTP/1.1\r\n" +
            "Host: " + socket.getInetAddress().getHostName() + ":" + socket.getPort() + "\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Key: " + webSocketKey + "\r\n" +
            "Sec-WebSocket-Version: 13\r\n\r\n";

        outputStream.write(handshake.getBytes());
        outputStream.flush();

        // 读取握手响应
        String line;
        boolean handshakeSuccess = false;
        while ((line = reader.readLine()) != null) {
            System.out.println(line);
            if (line.contains("101 Switching Protocols")) {
                handshakeSuccess = true;
            }
            if (line.isEmpty()) break;
        }

        if (!handshakeSuccess) {
            throw new IOException("WebSocket handshake failed");
        }

        System.out.println("WebSocket connected successfully!");

        // 启动消息接收线程
        Thread readThread = new Thread(this::receiveLoop);
        readThread.start();

        // 处理用户输入
        String userInput;
        while ((userInput = consoleReader.readLine()) != null) {
            send(userInput);
        }
    }

    private void receiveLoop() {
        try {
            while (!socket.isClosed()) {
                receiveMessage();
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void receiveMessage() throws IOException {
        // 读取第一个字节（FIN + Opcode）
        int firstByte = reader.read();
        if (firstByte == -1) return;

        boolean fin = (firstByte & 0x80) != 0;
        int opcode = firstByte & 0x0F;

        // 读取第二个字节（MASK + Payload length）
        int secondByte = reader.read();
        boolean masked = (secondByte & 0x80) != 0;
        int payloadLength = secondByte & 0x7F;

        // 处理扩展长度
        if (payloadLength == 126) {
            payloadLength = ((reader.read() & 0xFF) << 8) | (reader.read() & 0xFF);
        } else if (payloadLength == 127) {
            // 简化处理，实际应该读取 8 字节
            payloadLength = ((reader.read() & 0xFF) << 56) |
                          ((reader.read() & 0xFF) << 48) |
                          ((reader.read() & 0xFF) << 40) |
                          ((reader.read() & 0xFF) << 32) |
                          ((reader.read() & 0xFF) << 24) |
                          ((reader.read() & 0xFF) << 16) |
                          ((reader.read() & 0xFF) << 8) |
                          (reader.read() & 0xFF);
        }

        // 读取掩码密钥（如果存在）
        byte[] maskKey = null;
        if (masked) {
            maskKey = new byte[4];
            reader.read(maskKey);
        }

        // 读取负载数据
        byte[] payload = new byte[payloadLength];
        reader.read(payload);

        // 去掩码处理
        if (masked) {
            for (int i = 0; i < payload.length; i++) {
                payload[i] ^= maskKey[i % 4];
            }
        }

        // 处理不同类型的帧
        switch (opcode) {
            case 0x1: // 文本帧
                String message = new String(payload);
                System.out.println("Received: " + message);
                break;
            case 0x2: // 二进制帧
                System.out.println("Received binary data: " + payload.length + " bytes");
                break;
            case 0x8: // 关闭帧
                System.out.println("Server requested close");
                socket.close();
                break;
            case 0x9: // Ping 帧
                sendPong(payload);
                break;
            case 0xA: // Pong 帧
                System.out.println("Received pong");
                break;
        }
    }

    private void sendPong(byte[] pingData) throws IOException {
        ByteArrayOutputStream frame = new ByteArrayOutputStream();
        frame.write(0x8A); // Pong frame

        int length = pingData.length;
        if (length <= 125) {
            frame.write(length);
        } else if (length <= 65535) {
            frame.write(126);
            frame.write((length >> 8) & 0xFF);
            frame.write(length & 0xFF);
        }

        frame.write(pingData);
        outputStream.write(frame.toByteArray());
        outputStream.flush();
    }

    private void send(String message) throws IOException {
        byte[] messageBytes = message.getBytes();
        byte[] maskedData = maskData(messageBytes);

        ByteArrayOutputStream frame = new ByteArrayOutputStream();
        frame.write(0x81); // 文本帧 + FIN

        int length = maskedData.length - 4; // 减去掩码长度
        if (length <= 125) {
            frame.write(0x80 | length); // 设置 MASK 位
        } else if (length <= 65535) {
            frame.write(0x80 | 126);
            frame.write((length >> 8) & 0xFF);
            frame.write(length & 0xFF);
        }

        frame.write(maskedData);
        outputStream.write(frame.toByteArray());
        outputStream.flush();
    }

    private byte[] maskData(byte[] data) {
        byte[] masked = new byte[data.length + 4];
        byte[] maskKey = new byte[4];
        new Random().nextBytes(maskKey);

        System.arraycopy(maskKey, 0, masked, 0, 4);
        for (int i = 0; i < data.length; i++) {
            masked[i + 4] = (byte) (data[i] ^ maskKey[i % 4]);
        }

        return masked;
    }

    private String generateWebSocketKey() {
        byte[] randomBytes = new byte[16];
        new Random().nextBytes(randomBytes);
        return Base64.getEncoder().encodeToString(randomBytes);
    }

    public static void main(String[] args) throws IOException, NoSuchAlgorithmException {
        WebSocketClient client = new WebSocketClient("localhost", 8080);
        client.connect();
    }
}
```

## 四、完整帧解析实现

### 4.1 WebSocket 帧解析器

```java
public class WebSocketFrameParser {

    public static class WebSocketFrame {
        private boolean fin;
        private int opcode;
        private boolean masked;
        private byte[] payload;
        private byte[] maskKey;

        // getters and setters
        public boolean isFin() { return fin; }
        public int getOpcode() { return opcode; }
        public boolean isMasked() { return masked; }
        public byte[] getPayload() { return payload; }
        public byte[] getMaskKey() { return maskKey; }

        public String getTextPayload() {
            if (opcode == 0x1) { // 文本帧
                return new String(payload);
            }
            return null;
        }
    }

    public static WebSocketFrame parseFrame(InputStream inputStream) throws IOException {
        WebSocketFrame frame = new WebSocketFrame();

        // 读取第一个字节
        int firstByte = inputStream.read();
        if (firstByte == -1) return null;

        frame.fin = (firstByte & 0x80) != 0;
        frame.opcode = firstByte & 0x0F;

        // 读取第二个字节
        int secondByte = inputStream.read();
        if (secondByte == -1) return null;

        frame.masked = (secondByte & 0x80) != 0;
        int payloadLength = secondByte & 0x7F;

        // 处理扩展长度
        if (payloadLength == 126) {
            byte[] extendedLength = new byte[2];
            inputStream.read(extendedLength);
            payloadLength = ((extendedLength[0] & 0xFF) << 8) | (extendedLength[1] & 0xFF);
        } else if (payloadLength == 127) {
            byte[] extendedLength = new byte[8];
            inputStream.read(extendedLength);
            // 处理 64 位长度
            long longLength = 0;
            for (int i = 0; i < 8; i++) {
                longLength = (longLength << 8) | (extendedLength[i] & 0xFF);
            }
            payloadLength = (int) longLength;
        }

        // 读取掩码密钥
        if (frame.masked) {
            frame.maskKey = new byte[4];
            inputStream.read(frame.maskKey);
        }

        // 读取负载数据
        frame.payload = new byte[payloadLength];
        inputStream.read(frame.payload);

        // 去掩码
        if (frame.masked) {
            unmaskPayload(frame);
        }

        return frame;
    }

    private static void unmaskPayload(WebSocketFrame frame) {
        if (frame.maskKey == null) return;

        for (int i = 0; i < frame.payload.length; i++) {
            frame.payload[i] ^= frame.maskKey[i % 4];
        }
    }

    public static byte[] createFrame(byte[] payload, int opcode, boolean masked) {
        ByteArrayOutputStream frame = new ByteArrayOutputStream();

        // 第一个字节：FIN + Opcode
        int firstByte = 0x80 | opcode; // FIN=1
        frame.write(firstByte);

        // 计算长度
        int payloadLength = payload.length;
        int secondByte = masked ? 0x80 : 0x00;

        if (payloadLength <= 125) {
            frame.write(secondByte | payloadLength);
        } else if (payloadLength <= 65535) {
            frame.write(secondByte | 126);
            frame.write((payloadLength >> 8) & 0xFF);
            frame.write(payloadLength & 0xFF);
        } else {
            frame.write(secondByte | 127);
            // 写入 64 位长度
            for (int i = 56; i >= 0; i -= 8) {
                frame.write((payloadLength >> i) & 0xFF);
            }
        }

        // 如果需要掩码
        if (masked) {
            byte[] maskKey = new byte[4];
            new Random().nextBytes(maskKey);
            frame.write(maskKey);

            byte[] maskedPayload = new byte[payload.length];
            for (int i = 0; i < payload.length; i++) {
                maskedPayload[i] = (byte) (payload[i] ^ maskKey[i % 4]);
            }
            frame.write(maskedPayload);
        } else {
            frame.write(payload);
        }

        return frame.toByteArray();
    }
}
```

## 五、WebSocket 实战示例

### 5.1 聊天室应用

```java
public class ChatRoom {

    private Map<String, WebSocketConnection> users = new ConcurrentHashMap<>();
    private WebSocketServer server;

    public ChatRoom(int port) throws IOException {
        this.server = new WebSocketServer(port) {
            @Override
            protected void onMessage(WebSocketConnection connection, String message) {
                handleUserMessage(connection, message);
            }

            @Override
            protected void onConnect(WebSocketConnection connection) {
                handleUserConnect(connection);
            }

            @Override
            protected void onDisconnect(WebSocketConnection connection) {
                handleUserDisconnect(connection);
            }
        };
    }

    private void handleUserConnect(WebSocketConnection connection) {
        String userId = "User_" + connection.getId();
        users.put(userId, connection);

        // 广播用户加入消息
        broadcastUserAction("用户 " + userId + " 加入了聊天室");
    }

    private void handleUserDisconnect(WebSocketConnection connection) {
        String userId = "User_" + connection.getId();
        users.remove(userId);

        // 广播用户离开消息
        broadcastUserAction("用户 " + userId + " 离开了聊天室");
    }

    private void handleUserMessage(WebSocketConnection connection, String message) {
        String userId = "User_" + connection.getId();

        // 解析消息
        if (message.startsWith("/")) {
            handleCommand(connection, message);
        } else {
            // 广播普通消息
            broadcastMessage(userId, message);
        }
    }

    private void handleCommand(WebSocketConnection connection, String command) {
        if (command.startsWith("/users")) {
            // 发送用户列表
            String userList = String.join(", ", users.keySet());
            connection.send("在线用户: " + userList);
        } else if (command.startsWith("/quit")) {
            connection.close();
        }
    }

    private void broadcastMessage(String userId, String message) {
        String formattedMessage = userId + ": " + message;
        for (WebSocketConnection user : users.values()) {
            user.send(formattedMessage);
        }
    }

    private void broadcastUserAction(String action) {
        for (WebSocketConnection user : users.values()) {
            user.send(action);
        }
    }

    public void start() {
        new Thread(() -> server.start()).start();
        System.out.println("聊天室启动在端口 " + server.getPort());
    }

    public static void main(String[] args) throws IOException {
        ChatRoom chatRoom = new ChatRoom(8080);
        chatRoom.start();
    }
}
```

### 5.2 实时数据推送

```java
public class RealTimeDataPusher {

    private WebSocketServer server;
    private ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);

    public RealTimeDataPusher(int port) throws IOException {
        this.server = new WebSocketServer(port);
    }

    public void start() {
        // 启动 WebSocket 服务器
        new Thread(() -> server.start()).start();

        // 启动实时数据推送
        scheduler.scheduleAtFixedRate(this::pushMarketData, 0, 1, TimeUnit.SECONDS);
        System.out.println("实时数据推送服务启动在端口 " + server.getPort());
    }

    private void pushMarketData() {
        // 模拟市场数据
        MarketData data = generateMarketData();
        String jsonData = toJson(data);

        // 推送给所有连接的客户端
        server.broadcast(jsonData);
    }

    private MarketData generateMarketData() {
        MarketData data = new MarketData();
        data.setSymbol("BTC/USD");
        data.setPrice(generateRandomPrice());
        data.setVolume(generateRandomVolume());
        data.setTimestamp(System.currentTimeMillis());
        return data;
    }

    private double generateRandomPrice() {
        return 40000 + (Math.random() * 1000);
    }

    private double generateRandomVolume() {
        return Math.random() * 1000;
    }

    private String toJson(MarketData data) {
        return String.format("{\"symbol\":\"%s\",\"price\":%.2f,\"volume\":%.2f,\"timestamp\":%d}",
            data.getSymbol(), data.getPrice(), data.getVolume(), data.getTimestamp());
    }

    static class MarketData {
        private String symbol;
        private double price;
        private double volume;
        private long timestamp;

        // getters and setters
        public String getSymbol() { return symbol; }
        public void setSymbol(String symbol) { this.symbol = symbol; }
        public double getPrice() { return price; }
        public void setPrice(double price) { this.price = price; }
        public double getVolume() { return volume; }
        public void setVolume(double volume) { this.volume = volume; }
        public long getTimestamp() { return timestamp; }
        public void setTimestamp(long timestamp) { this.timestamp = timestamp; }
    }

    public static void main(String[] args) throws IOException {
        RealTimeDataPusher pusher = new RealTimeDataPusher(8081);
        pusher.start();
    }
}
```

## 六、WebSocket 优化与最佳实践

### 6.1 连接管理

```java
public class WebSocketConnectionManager {

    private ConcurrentMap<String, WebSocketConnection> connections = new ConcurrentHashMap<>();
    private ScheduledExecutorService healthChecker = Executors.newScheduledThreadPool(1);

    public void addConnection(String id, WebSocketConnection connection) {
        connections.put(id, connection);
        startHealthCheck(connection);
    }

    public void removeConnection(String id) {
        WebSocketConnection connection = connections.remove(id);
        if (connection != null) {
            connection.close();
        }
    }

    private void startHealthCheck(WebSocketConnection connection) {
        healthChecker.scheduleAtFixedRate(() -> {
            if (!connection.isOpen()) {
                removeConnection(connection.getId());
            } else {
                // 发送心跳检测
                connection.sendPing();
            }
        }, 30, 30, TimeUnit.SECONDS);
    }

    public void broadcast(String message) {
        connections.forEach((id, connection) -> {
            try {
                connection.send(message);
            } catch (Exception e) {
                removeConnection(id);
            }
        });
    }
}
```

### 6.2 消息队列缓冲

```java
public class WebSocketMessageBuffer {

    private BlockingQueue<String> messageQueue = new LinkedBlockingQueue<>();
    private WebSocketConnection connection;
    private ExecutorService sender = Executors.newSingleThreadExecutor();

    public WebSocketMessageBuffer(WebSocketConnection connection) {
        this.connection = connection;
        startSending();
    }

    public void enqueue(String message) {
        messageQueue.offer(message);
    }

    private void startSending() {
        sender.submit(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    String message = messageQueue.take();
                    connection.send(message);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } catch (Exception e) {
                    // 处理发送失败
                }
            }
        });
    }

    public void stop() {
        sender.shutdownNow();
    }
}
```

## 七、WebSocket 性能测试

```java
public class WebSocketPerformanceTest {

    public static void main(String[] args) throws Exception {
        // 启动测试服务器
        WebSocketServer server = new WebSocketServer(8080);
        new Thread(() -> server.start()).start();
        Thread.sleep(1000);

        // 吞吐量测试
        throughputTest();

        // 延迟测试
        latencyTest();

        // 并发连接测试
        concurrentConnectionTest();
    }

    private static void throughputTest() throws Exception {
        System.out.println("=== 吞吐量测试 ===");
        WebSocketClient client = new WebSocketClient("localhost", 8080);
        client.connect();

        long startTime = System.currentTimeMillis();
        int messageCount = 10000;

        for (int i = 0; i < messageCount; i++) {
            client.send("Test message " + i);
        }

        long endTime = System.currentTimeMillis();
        double throughput = messageCount / ((endTime - startTime) / 1000.0);

        System.out.printf("吞吐量: %.2f 消息/秒%n", throughput);
        client.close();
    }

    private static void latencyTest() throws Exception {
        System.out.println("=== 延迟测试 ===");
        WebSocketClient client = new WebSocketClient("localhost", 8080);
        client.connect();

        int testCount = 100;
        long totalLatency = 0;

        for (int i = 0; i < testCount; i++) {
            long startTime = System.nanoTime();
            client.send("Ping");
            // 等待响应...
            long endTime = System.nanoTime();
            totalLatency += (endTime - startTime);
        }

        double avgLatency = totalLatency / (double) testCount / 1_000_000;
        System.out.printf("平均延迟: %.2f ms%n", avgLatency);
        client.close();
    }

    private static void concurrentConnectionTest() throws Exception {
        System.out.println("=== 并发连接测试 ===");
        int connectionCount = 1000;
        CountDownLatch latch = new CountDownLatch(connectionCount);
        AtomicInteger successCount = new AtomicInteger(0);

        ExecutorService executor = Executors.newFixedThreadPool(50);

        for (int i = 0; i < connectionCount; i++) {
            executor.submit(() -> {
                try {
                    WebSocketClient client = new WebSocketClient("localhost", 8080);
                    client.connect();
                    successCount.incrementAndGet();
                } catch (Exception e) {
                    // 连接失败
                } finally {
                    latch.countDown();
                }
            });
        }

        latch.await(30, TimeUnit.SECONDS());
        executor.shutdown();

        System.out.printf("成功连接数: %d/%d%n", successCount.get(), connectionCount);
    }
}
```

## 八、常见问题与解决方案

### 8.1 连接断线重连

```java
public class WebSocketReconnectionHandler {

    private WebSocketClient client;
    private String host;
    private int port;
    private int maxRetries = 5;
    private long retryDelay = 5000; // 5秒

    public void connectWithRetry() {
        int retries = 0;
        while (retries < maxRetries) {
            try {
                client = new WebSocketClient(host, port);
                client.connect();
                System.out.println("连接成功");
                return;
            } catch (Exception e) {
                retries++;
                System.out.println("连接失败，重试 " + retries + "/" + maxRetries);

                if (retries < maxRetries) {
                    try {
                        Thread.sleep(retryDelay);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        return;
                    }
                }
            }
        }
        System.out.println("达到最大重试次数，连接失败");
    }

    public void onDisconnect() {
        System.out.println("连接断开，尝试重连...");
        connectWithRetry();
    }
}
```

### 8.2 消息压缩

```java
import java.util.zip.*;

public class WebSocketCompression {

    public static byte[] compress(byte[] data) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        DeflaterOutputStream dos = new DeflaterOutputStream(bos);
        dos.write(data);
        dos.close();
        return bos.toByteArray();
    }

    public static byte[] decompress(byte[] compressedData) throws IOException {
        ByteArrayInputStream bis = new ByteArrayInputStream(compressedData);
        InflaterInputStream iis = new InflaterInputStream(bis);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();

        byte[] buffer = new byte[1024];
        int len;
        while ((len = iis.read(buffer)) > 0) {
            bos.write(buffer, 0, len);
        }

        return bos.toByteArray();
    }
}
```

## 九、总结

WebSocket 通过以下方式实现了高效的实时通信：

1. **协议升级机制**：在 HTTP 基础上握手升级到 WebSocket 协议
2. **二进制帧协议**：高效的数据传输格式
3. **全双工通信**：支持客户端和服务器双向推送
4. **持久连接**：避免频繁建立连接的开销
5. **心跳机制**：保持连接活性，及时检测断线

通过本专栏的 Java 实现示例，你可以深入理解 WebSocket 的协议细节和实际应用场景。从基础的握手过程到帧解析，再到实际的应用开发，这些知识将帮助你构建高性能的实时应用系统。