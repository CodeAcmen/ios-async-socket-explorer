# iOS-Network-Stack-Dive

## 项目描述
基于CocoaAsyncSocket实现的底层网络通信，项目为工作中企业级生产环境下的即时通讯系统（已脱敏）。涵盖：
网络通信核心：TCP连接、心跳处理、断线重连、协议设计、弱网优化思路、数据收发处理（消息粘包、拆包处理，分包、组包处理）
UI方面：文字信息，语音信息，图片信息，已读回执，消息状态机
业务架构：企业级生产环境下的VIPER架构、IM防腐层设计、模块可插拔可组件化
多线程：队列、连接池、数据一致性、多读单写模型

本项目是工作多年的经验总结，通过深入实践，你可以学到以下内容：

- **TCP/UDP协议底层原理**  
  掌握计算机网络中TCP/UDP协议的底层工作原理，理解其在iOS网络栈中的实现与应用。

- **自定义二进制协议设计**  
  学习如何根据业务需求设计高效且稳定的二进制协议，包括协议头部的设计、数据压缩与编码方式。

- **弱网优化与安全传输**  
  通过优化弱网络环境下的连接稳定性与传输效率，确保数据在不稳定网络条件下的可靠传输，同时加深对iOS网络传输安全的理解。

- **现代化架构设计**  
  通过实际项目中的VIPER架构，逐步掌握分层架构思想和复杂架构能力，提升代码可维护性、扩展性与可测试性。

## 学习方法

**螺旋式学习**：  
采用 **实践→理论→再实践** 的螺旋式学习，基于实践与理论结合的方式，逐步加深理解。通过实际经验和理论知识的结合，帮助更好地掌握iOS网络栈的核心技术。

### 第一阶段：实践入门  
**目标**：通过实际编写代码，掌握TCP和UDP的基础用法。
- 通过对iOS中的网络请求的处理，学习使用URLSession、Socket编程等常见技术。
- 实现基本的客户端和服务器端的通信，掌握网络请求的生命周期。

### 第二阶段：深入理论  
**目标**：通过阅读相关的计算机网络书籍和文档，深入理解TCP/UDP协议的工作原理、特性和差异。
- 深入研究TCP和UDP协议的工作流程，如三次握手、四次挥手、拥塞控制、滑动窗口等。
- 学习TCP与UDP的场景适用性以及如何在不同的业务需求下选择最合适的协议。
- 理解现代化网络架构中如何设计高可用、低延迟的协议传输。

### 第三阶段：优化与创新  
**目标**：通过对复杂网络环境下的实践，进行弱网优化、安全性设计及二进制协议设计的学习。
- 学习如何优化在不稳定网络环境下的TCP/UDP连接，例如重试机制、丢包恢复、延迟优化等。
- 探索自定义二进制协议的设计方案，确保高效的数据传输并减小带宽占用。
- 结合iOS的安全特性（如SSL/TLS协议），实现安全传输，确保数据传输的安全性与完整性。

### 第四阶段：架构设计与高级技术  
**目标**：掌握现代化架构设计和生产级应用的开发实践。
- **VIPER架构**：学习并实践VIPER架构，将网络栈与业务逻辑进行解耦，提升系统的可扩展性、可维护性以及单元测试覆盖率。
- **Typhoon依赖注入**：通过使用Typhoon框架进行依赖注入，使得代码更具模块化，提升可测试性和灵活性。
- **面向切面编程（AOP）**：通过AOP实践，在不破坏核心业务逻辑的前提下，为网络请求、数据处理等加入跨切面的关注点（如日志、错误处理等）。

### 第五阶段：高并发与可靠性设计  
**目标**：处理高并发连接和设计可靠性高的网络通信。
- **多路复用连接池**：实现连接池技术，支持10k+并发连接，优化资源利用率，避免过多的连接创建和销毁。
- **可靠UDP协议**：在UDP上实现ACK/NACK机制和超时重传功能，确保在无连接的协议下实现可靠数据传输。

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

### 实现可靠的UDP协议

基于UDP协议，通过实现以下功能，提供可靠的数据传输：
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
- 通过使用iOS中的装饰器模式或代理模式，为网络请求和响应逻辑增加额外的功能（如日志记录、错误处理等）。
- 采用切面编程的方式，对网络请求中的公共操作进行统一管理，减少代码重复。

## 技术栈

- **编程语言**：Objective-C
- **工具**：Xcode，Wireshark，Charles
- **网络协议**：TCP，UDP，HTTP，HTTPS
- **其他技术**：SSL/TLS，Socket编程，GCD，Protocol Buffers，JSON，VIPER架构，Typhoon框架，AOP

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

### 在线资源
- [TCP/IP详解在线教程](http://www.tcpipguide.com/) - 一份详尽的TCP/IP协议教程，涵盖了从基础到高级的各个方面。
- [Apple iOS Network Programming Guide](https://developer.apple.com/library/archive/documentation/Networking/Conceptual/NetworkingOverview/Introduction/Introduction.html) - 苹果官方的iOS网络编程指南，介绍了iOS中的网络编程技术和API。


## 项目结构

```
iOS-Network-Stack-Dive
# 项目结构设计（后续会慢慢调整）

```
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
│   │   ├── Lab1-Socket-API/       # BSD Socket实践
│   │   └── Lab2-NSStream-Analysis/ # 流解析实验
│   └── AdvancedLabs/              
│       ├── CustomProtocol-Lab/    # 协议设计沙盒
│       └── WeakNetwork-Simulation/ # 弱网模拟测试
├── ArchitectureExtensions/        # 生产级架构扩展
│   ├── VIPER-Integration/         # VIPER架构适配
│   │   ├── NetworkService/        # 网络服务层
│   │   │   ├── ConnectionManager/ # 连接池管理
│   │   │   └── ProtocolAdapter/   # 协议适配器
│   │   └── DI Container/          # 依赖注入实现
│   └── AOP/                       # 切面编程组件
│       ├── NetworkMonitor/        # 网络监控切面
│       └── LoggingAspect/         # 日志追踪切面
├── CoreNetworkStack/              # 核心网络栈实现
│   ├── TransportLayer/            # 传输层实现
│   │   ├── TCP-State-Machine/     # TCP状态机实现
│   │   └── Reliable-UDP/          # 可靠UDP实现
│   └── ProtocolLayer/             # 协议层实现
│       ├── BinaryProtocol/        # 自定义二进制协议
│       │   ├── Encoder-Decoder/   # 编解码器
│       │   └── CRC-Checker/       # 校验模块
│       └── Security/              # 安全层
│           ├── KeyExchange/       # 密钥交换
│           └── PacketEncryption/  # 数据加密
├── Tools/                         
│   ├── NetworkDebugger/           # 网络调试工具集
│   │   ├── PacketSniffer/         # 抓包分析器
│   │   └── LatencySimulator/      # 延迟模拟器
│   └── CI-Scripts/                # 持续集成脚本
│       ├── CoverageReport         # 覆盖率检测
│       └── MemoryChecker          # 内存检测
└── ProductionBridge/              # 生产衔接案例
    ├── CaseStudy-WeChat.pcapng    # 协议抓包分析
    └── VIPER-Sample/              # 真实项目代码片段
        └── MessageModule/         # 消息模块实现


```
## 贡献
欢迎任何开发者贡献代码、改进文档、提出意见和建议！如果你有关于iOS网络栈的实践经验或心得，欢迎提交PR来丰富本项目。

## License
本项目遵循 MIT 许可证，详细信息请参见 LICENSE 文件。



