# iOS-Network-Stack-Dive（逐步完善ing）

## 项目描述
#### **生产级网络通信架构实践**
基于 **CocoaAsyncSocket** 实现的底层网络通信系统，来源于即时通讯领域实际工作经验（**已脱敏**）。展示了从**小型项目单 TCP 架构**，逐步演进为适用于中大型项目**多路复用架构**的过程，包含协议设计、架构解耦、高并发优化等核心实践。
> **个人利用非工作时间整理，持续更新中...** 🚀


## 核心价值
- **即学即用**：整体系统经过生产环境验证，对应小、中、大型项目有不同的设计方案。（亿级流量暂无实际经验）
- **深度解耦**：企业级架构设计，模块可插拔
- **性能保障**：支持万级并发，内置线程安全模型

## 核心功能
**按需使用**，快速定位需求

| 需求分类 | 将会实现的功能 | 常用场景 |
| -------------|----------------------- | --------------------|
| 网通通信核心 | TCP连接管理、心跳保活、断线重连、TLS安全传输 | 即时通讯IM、IoT设备管理 |
| 协议设计 | 自定义二进制协议（魔数+CRC32+TLV结构）、Protobuf兼容、数据压缩 | 高吞吐、低延迟场景 |
|高并发优化 | 多路复用连接池（支持10k+并发）、GCD多读单写模型、零拷贝传输优化 | 实时数据同步、高并发消息推送 |
| 现代企业级架构 | VIPER分层架构+注入式解耦框架（Typhoon）实现的聊天UI界面、IM防腐层设计 | 大型项目长期维护 |
| 可靠传输 | ACK/NACK 确认机制、超时重传、自适应动态心跳 | 弱网环境、可靠级传输 |



## 网络架构演进
| 阶段                    | 方案                 | 适用场景               | 关键特性                   |
| ---------------------- | ------------------- | ---------------------- | ------------------------ |
| TJPConcurrentNetworkManager | 单 TCP 通道           | 小型项目/中型项目早期  | 心跳保活、断线重连、协议解析、线程安全 |
| TJPNetworkManagerFinal    | 中心管理+会话自治     | 中大型项目             | 多路复用连接池、状态机驱动、VIPER业务层、动态策略配置 |

## 项目进度与规划
### ✅ **已完成**

### **ConcurrentNetworkManager**
经过生产环境检测的**高性能、线程安全**的**单 TCP** 通信模块，注释友好，方便单元测试，适用于小型项目以及中型项目早期。关键特性如下：

- **连接管理**：支持单连接的建立与断开，支持 TLS。
- **粘包处理**：采用定长头部 + TLV 协议解析。
- **心跳保活**：15 秒间隔心跳，30 秒超时检测。
- **超时重试**：基于 ACK 确认 + 最大重试次数控制。
- **断线重连**：使用指数退避 + 随机抖动，避免惊群效应。
- **数据解析**：缓冲区管理 + 魔数校验 + CRC32 校验。
- **线程安全**：串行队列管理资源，防止竞争冲突。

### **NetworkManagerFinal**
**企业级多路复用架构**，已通过单元测试且覆盖率>90%，支撑日均50w+连接场景，具备以下关键特性：

##### 1. **中心协调器（TJPNetworkCoordinator）**
- **全局管理**：会话池、网络状态监控、资源分配。
- **动态扩容**：支持动态扩容，隔离故障会话。

##### 2. **会话自治模型（TJPConcreteSession）**
- **独立状态机**：管理连接状态流转。
- **内置动态心跳**：自适应重连策略。

##### 3. **协议栈优化**
- **二进制协议设计**：Header + CRC32 + Payload。
- **TLS 安全传输**：支持加密安全传输。

##### 快速接入 Objective-C
```Objective-C
// 1. 初始化配置
TJPNetworkConfig *config = [TJPNetworkConfig configWithMaxRetry:5 heartbeat:15];

// 2. 创建会话（中心协调器自动管理）
TJPConcreteSession *session = [[TJPNetworkCoordinator shared] createSessionWithConfiguration:config];

// 3. 连接服务器
[session connectToHost:@"example_host" port:8080];

// 4. 发送消息
NSData *messageData = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
[session sendData:messageData];
```

##### Swift
```Swift
// 1. 初始化配置
let config = NetworkConfig(maxRetry: 5, heartbeat: 15)

// 2. 创建会话
guard let session = NetworkCoordinator.shared.createSession(config: config) else { return }

// 3. 连接服务器
session.connect(toHost: "example_host", port: 8080)

// 4. 发送消息
let messageData = "Hello World".data(using: .utf8)
session.send(data: messageData)
```

### **企业级 VIPER 架构演示**
构建了一套**标准化的适用于中大型应用场景**的 VIPER 架构体系。架构充分遵循 **职责分离** 原则，通过模块划分提升可读性、可维护性与可测试性。整体设计高度解耦，利于团队协作与模块复用，并具备强适应性，能够灵活应对业务规模的快速增长与变化。
#### 核心亮点

- **完整链路演示 Demo**  
  已实现从 ViewController → Presenter → Interactor → 数据请求 → View 渲染 → Router 跳转 的闭环流程。

- **数据驱动视图组件**  
  封装了通用的 `TJPViperBaseTableView`，便于快速构建高性能的列表型 UI。

- **响应式编程集成**  
  基于 `ReactiveCocoa` 构建，使用信号流推动数据和事件流转，特别适用于 **数据驱动界面** 构建，提升了异步处理的简洁性。

- **模块化设计**  
  各层通过协议通信，结构清晰、扩展方便。通过接口方式解耦，**无缝集成注入式框架**，天然支持依赖注入和单元测试。

- **灵活的路由机制**  
  Router 层支持多种导航方式（Push、Present、Modal、自定义跳转），支持多场景复用。

---

如需更进一步对接状态管理框架、状态机、权限控制等高级功能，也可在现有架构基础上自然延展。


#### 已知问题
目前 AOP 切面日志存在问题，在监听多参数方法时会发生崩溃，已定位问题，接下来会修复


 **持续迭代ing，敬请关注！**

### 🚧**进行中**
- **IM防腐层整理、聊天界面整理、可靠UDP协议、消息可靠传输、多级ACK相应机制...**


## 使用方法

**螺旋式进阶学习**：  
项目采用 **螺旋式学习方式**，从Demo演示到生产级代码，从单体架构演进至多路复用设计。每个阶段都配有对应的 **Doc 设计思路**，注释友好，结合实际开发经验和理论知识，逐步掌握 **iOS 网络栈的核心技术**。

## 核心实现
Socket通信模块架构
```
+--------------------------+
|     Network Layer         |
| (CocoaAsyncSocket wrapper)|
+--------------------------+
           |
           v
+--------------------------+
|       SocketManager       |
| (Connection, Heartbeat)   |
+--------------------------+
           |
           v
+--------------------------+
|       Message Handler     |
| (Message Parsing, Packets)|
+--------------------------+
           |
           v
+--------------------------+
|      Protocol Layer       |
|  (Custom Protocol Logic)  |
+--------------------------+
```

### 完整TCP状态机实现

通过实现完整的TCP状态机，掌握TCP协议的核心机制：
- **三次握手**：在客户端与服务器之间建立可靠连接。
- **慢启动**：在网络连接初期，逐渐增加传输速率以避免拥塞。
- **快速重传**：在数据包丢失时，通过快速重传机制提高网络可靠性和数据传输效率。
- **ACK/NACK机制**：保证数据的可靠传输，客户端和服务器交换确认包。
- **超时重传机制**：数据包未收到确认时，执行超时重传，确保数据传输的可靠性。

### 多路复用连接池

实现连接池技术，能够在同一时刻管理多个并发连接，满足高并发需求：
- 支持 **10k+ 并发连接**。
- 提高连接的复用效率，减少连接的创建和销毁次数，降低资源消耗。

### 生产级VIPER架构

在iOS项目中，采用VIPER架构模式进行分层设计，提高系统的可维护性和扩展性：
- **分层架构**：将网络层、业务逻辑层和UI层解耦，提升代码可维护性。
- **Typhoon注入式框架**：使用Typhoon框架进行依赖注入，减少类之间的耦合，便于单元测试和功能扩展。
```
+-----------------+      +------------------+      +-----------------+
|                 |      |                  |      |                 |
|    View         | <--> |    Presenter     | <--> |   Interactor    |
| (UI Components) |      | (Coordinator)    |      | (Business Logic)|
|                 |      |                  |      |                 |
+-----------------+      +------------------+      +-----------------+
                             ^                        |
                             |                        |
                      +----------------+         +---------------------+
                      |   Entity       |         |     Router          |
                      |  (Data Models) |         | (Navigation Logic)  |
                      +----------------+         +---------------------+
```

### iOS中的AOP实践

实现面向切面编程（AOP）：
- 通过切面方式AOP，为网络请求和响应逻辑增加额外的功能，如日志记录、错误处理等。

## 技术栈

- **编程语言**：Objective-C
- **工具**：Xcode，Wireshark，Charles
- **网络协议**：TCP，UDP，HTTP，HTTPS
- **其他技术**：SSL/TLS，Socket编程，GCD，Protocol Buffers，VIPER架构，Typhoon框架，AOP

## 学习资源

### 推荐书籍与文档
- 《计算机网络：自顶向下方法》
- 《TCP/IP详解》
- iOS官方文档：Networking Frameworks

### 开源项目与工具
- [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) - 一个常用的iOS Socket编程库，用于处理TCP和UDP协议的网络编程。
- [Wireshark](https://www.wireshark.org/) - 网络协议分析工具，帮助开发者监控和分析网络通信数据，调试网络层问题。
- [Charles Proxy](https://www.charlesproxy.com/) - 网络请求调试工具，适用于捕获、分析和调试HTTP/HTTPS请求。
- [Typhoon](https://github.com/appsquickly/Typhoon) - 一个依赖注入框架，用于iOS项目中管理对象依赖，帮助解耦组件，提升代码可维护性、可测试性。通过Typhoon可以实现清晰的依赖关系管理，支持生产级应用中的架构设计。
- [Reachability](https://github.com/tonymillion/Reachability) - 非常常用的网络状态监听库，用来检测设备当前的网络连接状态。
- [libffi](https://github.com/libffi/libffi) - 一个用于实现外部函数接口（FFI，Foreign Function Interface）的开源库，它提供了一种在运行时调用外部函数的方式，特别是对于动态语言和静态编译语言之间的交互。
- [ReactiveObjC](https://github.com/ReactiveCocoa/ReactiveObjC) - 一个响应式编程库，用于简化异步事件流的处理和管理，广泛用于 iOS 和 macOS 开发中。
- [MJRefresh](https://github.com/CoderMJLee/MJRefresh) - 一个常用的下拉刷新与上拉加载更多的库，提供丰富的自定义选项，用于处理 UITableView 和 UICollectionView 的刷新功能。
- [DZNEmptyDataSet](https://github.com/dzenbot/DZNEmptyDataSet) - 一个简洁的空数据视图展示库，适用于 UITableView 和 UICollectionView，当数据为空时提供漂亮的占位视图。


### 在线资源
- [TCP/IP详解在线教程](http://www.tcpipguide.com/) - 一份详尽的TCP/IP协议教程，涵盖了从基础到高级的各个方面。
- [Apple iOS Network Programming Guide](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/NetworkingOverview/Introduction/Introduction.html) - 苹果官方的iOS网络编程指南，介绍了iOS中的网络编程技术和API。


## 项目结构

```
iOS-Network-Stack-Dive
# 项目结构构思（后续会根据实际情况调整）

iOS-Network-Stack-Dive/
├── Docs/                           # 文档
│   ├── Journey/                
│   │   ├── Phase1-TCP-UDP-Core.md 
│   │   ├── Phase2-Protocol-Design.md
│   │   └── Phase3-Arch-Integration.md
│   └── RFC/                       # 协议标准文档
│       ├── RFC793-TCP.pdf         
│       └── RFC768-UDP.pdf
├── Labs/                          
│   ├── NetworkFundamentals/       
│   │   ├── Lab1-Socket-API/       # Socket实践
│   │   └── Lab2-NSStream-Analysis/ # 流解析实验
│   └── AdvancedLabs/              
│       ├── CustomProtocol-Lab/    # 协议设计沙盒
│       └── WeakNetwork-Simulation/ # 弱网模拟测试
├── ArchitectureExtensions/       
│   ├── VIPER-Integration/         # 生产级VIPER架构
│   │   ├── NetworkService/        # 网络服务层
│   │   │   ├── ConnectionManager/ # 连接池管理
│   │   │   └── ProtocolAdapter/   # 协议适配器
│   │   └── DI Container/          # 依赖注入实现
│   └── AOP/                       
│       ├── NetworkMonitor/        # 网络监控切面
│       └── LoggingAspect/         # 日志追踪切面
├── CoreNetworkStack/              
│   ├── TransportLayer/            # 传输层实现
│   │   ├── TCP-State-Machine/     # TCP状态机实现
│   │   └── Reliable-UDP/          # 可靠UDP实现
│   └── ProtocolLayer/             
│       ├── BinaryProtocol/        # 自定义二进制协议
│       │   ├── Encoder-Decoder/   # 编解码器
│       │   └── CRC-Checker/       # 校验模块
│       └── Security/              
│           ├── KeyExchange/       # 密钥交换
│           └── PacketEncryption/  # 数据加密
├── Tools/                         
│   ├── NetworkDebugger/           # 网络调试工具集
│   │   ├── PacketSniffer/         # 抓包分析器
│   │   └── LatencySimulator/      # 延迟模拟器
│   └── CI-Scripts/                
│       ├── CoverageReport         # 覆盖率检测
│       └── MemoryChecker          # 内存检测
└── ProductionBridge/              
    ├── CaseStudy-WeChat.pcapng    # 协议抓包分析
    └── VIPER-Sample/              # 真实项目代码片段
        └── MessageModule/         # 消息模块实现
```

## 贡献
欢迎**任何开发者贡献代码、改进文档、提出意见和建议！！！**如果你有关于iOS网络栈的实践经验或心得，欢迎提交PR来丰富本项目。


## License
本项目遵循 **MIT 许可证**，详细信息请查看 [LICENSE](./LICENSE) 文件。


## 特别说明：
本项目不仅涵盖 **TCP/UDP 通信、协议解析、网络优化** 等底层技术，还涉及 **现代化架构设计、高并发处理、网络安全** 等企业级应用场景。  
通过 **螺旋式进阶学习**，你将逐步掌握 **iOS 网络通信的核心技术**，并能在 **生产环境** 中 **高效开发、优化即时通讯系统**。  
适合作为**iOS开发者**的网络层技术进阶指南。

### 如果觉得有帮助，请点击右上角Star支持！你的认可是我持续优化的最大动力！

## **注意事项**

### 1. **非商业用途**
本项目仅供个人学习、研究和交流使用，不得用于 **商业用途**。根据 **MIT 许可证**，您可以自由使用、修改、分发和出售本项目，但强烈建议您不要将其**直接**用于商业产品或服务中，如果您计划将项目用于商业用途，本项目作者不承担责任。

### 2. **版权声明**
本项目遵循 **MIT 许可证**。在分发本项目的修改版本或源代码时，请保留原始版权声明和许可证文件。  
所有相关的知识产权和版权归原作者所有，除非明确授予许可，否则不得将其用于任何不符合许可证条款的目的。

### 3. **数据隐私与安全**
本项目涉及网络通信和消息传输功能，请确保您的使用符合 **数据隐私法律和规定**，特别是当您处理个人敏感数据时。  
本项目不对任何因使用过程中涉及到的数据泄露、隐私侵犯或安全事件承担责任。

### 4. **使用风险**
本项目是一个开源学习工具，不保证其完整性和稳定性，因此在用于生产环境时，可能存在数据丢失、通信中断等风险。请确保在使用前进行充分测试，并自行承担使用本项目可能带来的风险。  

### 5. **禁止滥用**
本项目不得用于任何形式的 **恶意攻击**、**网络滥用**、**未经授权的数据访问** 等活动。  
项目使用者应遵守当地的法律和法规，确保使用本项目不会违反任何国家或地区的网络安全法律。





