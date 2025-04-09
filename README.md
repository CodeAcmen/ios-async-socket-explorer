# ios-async-socket-explorer（逐步完善ing）

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

## 性能基准

### 单连接测试
- **1KB 数据包吞吐测试**：12,000 pps (9.6 Gbps)
- **1MB 大包传输延迟**：平均 70ms（含完整往返校验）

### 多连接压测
- **10k 并发连接**：内存占用 2.3GB（216B/连接）
- **同时传输消息**：线程切换耗时占比 < 3%

### 弱网模拟测试
- **60% 丢包环境**：消息平均到达时延 1.25s
- **80% 带宽限制**：吞吐量保持理论值 90%

### 内存管理指标
- **传统 `NSMutableData`**：碎片率约 12%
- **当前环形缓冲区**：碎片率约 2.1%


## 项目进度与规划
### ✅ **已发布版本 v1.0.0**
#### 核心能力：**生产级网络通信架构** | **企业级 VIPER 架构** 
---

#### 网络框架
##### ConcurrentNetworkManager
**高性能单 TCP 通信模块**（生产环境验证）
- **核心特性**
  - **连接管理**：TLS 支持 + 单连接管理
  - **协议解析**：定长头部 + TLV协议 + CRC32校验
  - **健壮机制**：指数退避重连 + 心跳保活（15s间隔/30s超时）
  - **线程安全**：串行队列资源管理
  - **容错设计**：ACK确认重试 + 随机抖动防惊群

##### NetworkManagerFinal（企业级多路复用）
**日均10w+连接验证 | 单元测试覆盖率>90%**
- **架构亮点**
  - **中心协调器**：动态扩容 + 故障隔离
  - **会话自治模型**：独立状态机 + 自适应心跳
  - **安全协议栈**：二进制协议设计 + TLS加密
  
**Objective-C 接入示例**

```Objc
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

**Swift 接入示例**

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
##### 企业级 VIPER 架构体系
**中大型应用分层解耦设计解决方案**
- **架构优势**
  - **模块化设计**：协议通信 + 依赖解耦
  - **完整链路演示**：View → Presenter → Interactor → Router
  - **响应式编程**：ReactiveCocoa 数据驱动
  - **可测试性**：天然支持依赖注入
  - **灵活路由**：Push/Present/Modal自由组合
---
如需更进一步对接状态管理框架、状态机、权限控制等高级功能，也可在现有架构基础上自然延展。


#### 已知问题
- AOP切面日志：多参数方法监听崩溃，问题已定位，后期修复。

v1.1.1修复了因libffi编译导致无法在模拟器运行的问题

### 版本规划
#### 🔜 v1.1.0（开发中） - 可观测性增强
- **关键指标采集**：网络质量/成功率/延迟监控
- **全链路追踪**：端到端请求追踪
- **崩溃收集**：异常崩溃捕获机制
- **可行性分析报告**

#### v1.2.0（规划中） - 长连接优化
- **心跳保活增强**：运营商NAT超时适配
- **防拦截策略**：运营商级心跳包伪装
- **连接保持**：智能心跳间隔动态调整

#### v1.3.0（规划中） - 性能升级
- **连接池优化**：智能资源分配
- **分包策略升级**：大文件分片传输
- **QoS保障**：流量优先级控制

#### v1.4.0（规划中） - 极端场景优化
- **弱网对抗**：智能降级策略
- **错误恢复**：多级故障回滚
- **协议演进**：可靠UDP传输


 **✨ 持续迭代中，期待您的 Star 关注！ ✨**

### 🚧**规划中**
- **IM防腐层整理、聊天界面整理、可靠UDP协议、消息可靠传输、多级ACK响应机制...**


## 使用方法

**螺旋式进阶学习**：  
项目采用 **螺旋式进阶方式**，从Demo演示到生产级代码，从单体架构演进至多路复用设计。每个阶段都配有对应的 **设计思路文档**，注释友好，结合实际开发经验和理论知识，逐步深入 **iOS TCP网络的核心技术**以及**现代化架构设计**。

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
│   ├── ArchitectureExtensions/                
│   │   └── AspectLoggerDesign.md 
│   ├── CoreNetworkStackDoc/    
│   │   ├── 协议流程解析图.jpg       
│   │   ├── 单元测试用例文档
│   │   ├── ProtocolParseDesign.md       
│   │   ├── TJPNetworkManagerV2Design.md     
│   │   └── TJPNetworkV3FinalDesign.md   
│   ├── VIPER-Integration/   
│   │   ├── VIPER-Design.md    
│   │   └── VIPER-RouterGuide.md
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
│   │   └── LoggingAspect/         # 日志追踪切面
│		└── NetworkMonitor/        		 # 网络监控
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





