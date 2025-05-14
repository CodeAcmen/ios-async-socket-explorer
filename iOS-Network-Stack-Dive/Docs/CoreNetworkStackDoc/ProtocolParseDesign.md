# 自定义协议完整流程设计

## 协议解析流程图

![流程图](./协议解析流程图.png)

## 缓冲区、协议头生命周期设计

### TCP协议的流式数据特性

由于 TCP 协议是流式数据传输，数据可能会被拆分成多个片段接收，可能是：
- 一个完整的消息
- 一个消息拆分成多个 TCP 包（**拆包**）
- 多个消息合并到一个 TCP 包中（**粘包**）

### 缓冲区的生命周期设计

考虑以下几个方面：

- **数据存储**：当接收到的数据不完整时，需存储数据，等待后续数据补全，确保可靠传输。
- **初始化与清空**：
  - 缓冲区在 `NetworkManager` 初始化时创建，并会一直存在，直到网络关闭。
  - 在处理完完整消息后，清空已处理部分。
  - 在魔数验证失败或解析错误时，应清空缓冲区，避免数据污染。
- **数据解析**：
  - 解析过程中，缓冲区存储的数据会被部分消耗。
  - 未解析的部分继续保留，等待后续数据到达。

### 协议头的生命周期设计

协议头的作用：描述消息的基本信息，如 **魔数、版本、消息类型、消息体积、CRC 校验**，用于指导消息体的解析。

设计考虑：

- **初始化与销毁**：
  - 在每个数据包开始解析时初始化。
  - 解析完成后销毁，因为每个数据包的协议头都是唯一的。
- **及时更新**：
  - 每次解析消息时，当前协议头都会被更新，始终代表当前正在解析的数据包。

### 总结

- **缓冲区**：设计为 **成员变量**，全程存在。
- **协议头**：设计为 **临时变量**，解析过程中动态更新。

---

## 解析数据时的方案设计

### 直接判断缓冲区大小 vs 解析标志位

**疑问**：既然协议头包含魔数和标准语义化控制版本，为什么解析过程中还需要使用标志位判断头部？

**核心原因**：TCP 的 **拆包问题**。

TCP 是流式传输，数据包的边界不固定。当缓冲区内容小于协议头时，可能出现以下情况：

- **拆包问题**：当前缓冲区数据可能是上个消息的最后部分。
- **数据污染**：收到的包是错误的，可能导致误解析。
- **边界问题**：如果缓冲区大小刚好等于消息头，可能会误识别为消息头。

**解决方案**：

- 使用 `BOOL` 类型的 **标志位** 指示解析阶段：
  - `YES`：当前缓冲区数据优先解析消息头。
  - `NO`：当前缓冲区数据优先解析消息体。

---
### 为什么优秀的协议都采用TLV？
TLV（Type-Length-Value）是一种广泛应用于通信协议和数据交换的编码格式，其核心由三个部分组成：

- Type（类型）：标识数据的种类或用途，如温度、湿度或其他业务参数。
- Length（长度）：明确后续 Value 字段的字节数，确保接收方能准确读取数据边界。
- Value（值）：存储实际数据内容，格式由 Type 和 Length 共同定义，可以是简单数值、字符串或嵌套的 TLV 结构。

#### **TLV 作用**
核心价值在于**自描述性**和**高扩展性**，错误处理和可靠性强。

```objc
// 示例：嵌套 TLV 结构（JSON 对比）
// 文本消息体
[
    {type:0x01, length:4, value:"Hello"},        // 文本内容
    {type:0x02, length:8, value:1715584000},     // 时间戳
    {type:0x03, length:N, value:[                // 嵌套附件列表
        {type:0x0A, length:M, value:"image.jpg"},
        {type:0x0B, length:K, value:"video.mp4"}
    ]}
]

```

IM领域业内常用设计：

- 即时消息传输：文本、表情采用基础TLV，图片/视频通过嵌套TLV携带元数据和分段内容
- 协议升级协商：通过特定命令类型交换双方支持的版本号，触发动态升降级
- 版本兼容：收到新版本服务器响应时，忽略未知TLV标签，若检测到旧客户端版本请求时，不返回新增Tag字段

### Body如何改造为 TLV 结构？

#### **TLV 条目定义**

每个 TLV 条目格式如下：

| Tag  | Length | Value |
| ---- | ------ | ----- |
| 2字节| 4字节    | N字节  |

要求：严格遵循 Tag(2) → Length(4) → Value(N) 的结构，且正确处理大端（网络）字节序

#### 协议头与 Body 的协作
- bodyLength 字段：正确表示 TLV 数据区的总长度，确保接收方完整读取。
- tlvEntries 属性：将解析后的 TLV 条目存储为字典（Tag → Value），便于业务逻辑访问。

| 特性 | 说明 |
| ------ | ------ |
| 动态扩展性 | 新增字段只需定义新 Tag，无需修改协议头或已有逻辑 |
| 兼容性 | 旧版本解析器可跳过未知 Tag（依赖 parseTLVFromData 的跳过逻辑） |
| 方便调试 | 通过 tlvEntries 可直观查看所有字段，便于日志记录和问题排查 |

### **关键实现细节**

1. **Mach-O Section 注册**
   利用 `__attribute__((section))` 将类名写入 Mach-O 文件的 `__DATA` 段，运行时通过 `dladdr` 和 `getsectiondata` 扫描所有注册的类
2. 引入 `TJPMessage` 协议，所有消息类型必须实现数据序列化和类型标记
3. 在现有 `TJPConcreteSession` 中增加 `sendMessage:` 方法，自动调用消息对象的 `tlvData` 方法
4. 新增 `TJPMessageSerializer` 处理公共字段的字节序转换、CRC 计算等底层细节

### **TLV 解析器 `TJPParsedPacket` 核心作用**

- **TLV 解包**：将二进制流按 TLV 格式拆解为 `Tag(2B) + Length(4B) + Value(NB)` 三元组
- **嵌套处理**：递归解析保留标签（如 `0xFFFF`），支持树形数据结构
- **字节序转换**：自动处理网络字节序 → 主机字节序（`ntohs/ntohl`）

### **序列化器 `TJPMessageSerializer` 核心作用**

- **TLV 打包**：将对象属性转换为 `Tag + Length + Value` 字节流
- 智能优化
  - 字符串自动 UTF-8 编码
  - 图片智能压缩（根据网络质量选择 JPEG/WebP）
  - 数值类型变长编码（Varint）

双模块协作流程：
```
发送端：
业务对象 → TJPMessageSerializer → TLV 二进制 → Socket 发送

接收端：
Socket 数据 → TJPParsedPacket → 结构化字典 → 业务对象映射
```

## 并发场景下的问题与解决方案

### 并发问题

多线程环境下，使用标志位或者多线程写操作可能会引发 **线程安全问题**，导致：
- 多个线程同时修改解析状态，出现状态错乱。
- 解析过程中被其他线程打断，无法正确完成解析。

### 解决方案

#### 1. 传统方案
- **加锁 (`lock`)**：能够解决问题，但会导致**锁竞争**，影响高并发性能。
- **信号量 (`semaphore`)**：可用于控制访问，但仍可能降低吞吐量。
- **串行队列 (`serial queue`)**：避免数据竞争，但会影响多个连接的并发能力。

#### 2. 企业级方案 —— **会话隔离模式**

**方案核心**：每个连接维护独立的状态 + 解析逻辑在独立的串行队列中执行。

- **每个连接维护自己的会话对象 (`Session`)**，包含：
  - **缓冲区 (`buffer`)**：存储数据。
  - **当前解析的协议头 (`TJPAdvancedHeader`)**。
  - **解析标志位 (`_isParsingHeader`)**。

- **解析操作在独立的串行队列 (`dispatch_queue_t`) 中执行**：
  - 避免多个线程同时修改解析状态，确保线程安全。
  - 解析过程不会影响其他会话，提高并发性能。
  
### Log完整流程分析

  1. 消息发送准备:
  
     ```
     [INFO] [TJPConcreteSession.m:242 -[TJPConcreteSession sendData:]_block_invoke] session 准备构造数据包
     ```
  
     - 客户端开始准备构造数据包，准备发送"Hello World!!!!!111112223333"消息
  
  2. 计算校验和:
  
     ```
     Calculated CRC32: 1789856453
     ```
  
     - 成功计算了消息体的CRC32校验值: 1789856453
  
  3. 安排重传计时器:
  
     ```
     [INFO] [TJPConcreteSession.m:693 -[TJPConcreteSession scheduleRetransmissionForSequence:]] 为消息 8 安排重传，间隔 3.0 秒，当前重试次数 0
     ```
  
     - 为序列号为8的消息安排了重传计时器，超时时间3秒，当前是第一次发送(重试次数0)
  
  4. 发送消息:
  
     ```
     [INFO] [TJPConcreteSession.m:281 -[TJPConcreteSession sendData:]_block_invoke] session 消息即将发出, 序列号: 8, 大小: 62字节
     ```
  
     - 消息即将发送，序列号8，总大小62字节(包括协议头和消息体)
  
  5. 服务端接收数据:
  
     ```
     [MOCK SERVER] 接收到客户端发送的数据
     [MOCK SERVER] 接收到的消息: 类型=0, 序列号=8, 时间戳=1747215938, 会话ID=4850, 加密类型=1, 压缩类型=1
     ```
  
     - 服务端成功接收到数据
     - 正确解析出消息类型(0=普通数据)、序列号(8)、时间戳、会话ID和加密/压缩类型
  
  6. 服务端验证校验和:
  
     ```
     Calculated CRC32: 1789856453
     [MOCK SERVER] 接收到的校验和: 1789856453, 计算的校验和: 1789856453
     ```
  
     - 服务端计算的CRC32校验值与接收到的校验值完全匹配，验证通过
  
  7. 服务端处理消息并发送ACK:
  
     ```
     [MOCK SERVER] 收到普通消息，序列号: 8
     [MOCK SERVER] 普通消息响应包字段：magic=0xDECAFBAD, msgType=2, sequence=8, timestamp=1747215938, sessionId=4850
     ```
  
     - 服务端识别为普通消息，序列号8
     - 发送ACK响应，消息类型为2(ACK)，保持相同的序列号、时间戳和会话ID
  
  8. 客户端接收ACK:
  
     ```
     [INFO] [TJPConcreteSession.m:456 -[TJPConcreteSession socket:didReadData:withTag:]_block_invoke] 读取到数据 缓冲区准备添加数据
     [INFO] [TJPConcreteSession.m:462 -[TJPConcreteSession socket:didReadData:withTag:]_block_invoke] 开始解析数据
     ```
  
     - 客户端接收到服务端的响应数据并开始解析
  
  9. 客户端解析ACK:
  
     ```
     [INFO] [TJPMessageParser.m:108 -[TJPMessageParser parseHeaderData]] 解析数据头部成功...魔数校验成功!
     [INFO] [TJPMessageParser.m:113 -[TJPMessageParser parseHeaderData]] 解析序列号:8 的头部成功
     [INFO] [TJPMessageParser.m:144 -[TJPMessageParser parseBodyData]] 解析序列号:8 的内容成功
     ```
  
     - 客户端成功解析ACK数据包的头部和内容
     - 验证魔数成功，确认序列号为8
  
  10. 客户端处理ACK:
  
      ```
      [INFO] [TJPConcreteSession.m:800 -[TJPConcreteSession handleACKForSequence:]] 接收到 ACK 数据包并进行处理
      [INFO] [TJPConcreteSession.m:831 -[TJPConcreteSession handleACKForSequence:]] 处理普通消息ACK，序列号: 8
      ```
  
      - 客户端识别并处理ACK数据包
      - 确认这是针对序列号8的普通消息的ACK
  
  11. 取消重传计时器:
  
      ```
      [INFO] [TJPConcreteSession.m:684 -[TJPConcreteSession scheduleRetransmissionForSequence:]_block_invoke] 取消消息 8 的重传计时器
      ```
  
      - 由于已收到序列号8的ACK确认，取消相应的重传计时器

  ### 流程评估

  整个流程完全符合预期，展示了一个健壮的消息发送-确认机制：

  1. ✅ **消息构建正确**：包含了所有必要字段，校验和计算无误
  2. ✅ **重传机制运作良好**：安排了重传计时器，并在接收到ACK后正确取消
  3. ✅ **服务端处理正确**：验证校验和，发送正确格式的ACK响应
  4. ✅ **客户端处理ACK正确**：识别并处理ACK，取消重传
  5. ✅ **所有时间戳、会话ID、序列号匹配**：确保消息追踪的一致性
  6. ✅ **日志信息完整详细**：包含了关键步骤的所有必要信息，便于调试和监控

### **总结**
- 最终会使用**会话隔离+中心管理**方案。支持统一重连策略，更细粒度的并发控制，减少内存占用;**标志位控制解析阶段，确保数据完整性,解析逻辑独立执行，提升系统吞吐量与响应速度。**

