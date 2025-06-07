# ios-async-socket-explorer
> [English Version (简要英文版入口) → Click here](./README.en.md)

![GitHub stars](https://img.shields.io/github/stars/CodeAcmen/ios-async-socket-explorer?style=social)
![Platform](https://img.shields.io/badge/platform-iOS-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

> 企业级 iOS TCP 通信框架，专为高并发、弱网环境、模块化架构而设计。

## 🛠️ 技术栈

![Objective-C](https://img.shields.io/badge/Objective--C-orange?style=flat-square&logo=objective-c)
![TCP/IP](https://img.shields.io/badge/TCP%2FIP-blue?style=flat-square&logo=internetexplorer)
![CocoaAsyncSocket](https://img.shields.io/badge/CocoaAsyncSocket-lightgrey?style=flat-square)
![SSL/TLS](https://img.shields.io/badge/SSL%2FTLS-green?style=flat-square&logo=openssl)
![Typhoon](https://img.shields.io/badge/Typhoon-red?style=flat-square)
![GCD](https://img.shields.io/badge/GCD-purple?style=flat-square&logo=apple)

## 概述
`ios-async-socket-explorer` 是一套基于 CocoaAsyncSocket 封装的生产级通信框架，源自真实企业级 IM 项目实践，致力于提升 iOS 在弱网、高并发场景下的 TCP 通信稳定性、可维护性和扩展能力。

**主要特性:**
-  支持 **3000+并发连接**，**日均处理10w+消息**
-  实现 **TLV二进制协议 + CRC32校验 + ACK确认机制**
-  搭载 **RTT自适应心跳**、**指数退避重连**，支持复杂弱网环境
-  企业级 **VIPER分层架构设计**，单元测试覆盖率>85%
-  丰富的**监控指标和全链路追踪**，确保系统可观测性

> 已被用于 B2B IM 服务、物联网通信、弱网移动端场景评估

## 为什么选型 CocoaAsyncSocket？

尽管 iOS 生态已有多种通信方案（如 Starscream、NSURLSession WebSocket 等），但：

| 选型因素 | 原因 |
|----------|------|
| 高并发 + 底层控制 | CocoaAsyncSocket 支持底层 socket 原生封装，适合定制协议 |
| 企业部署场景 | 兼容 TLS、Socket KeepAlive、链路监控等安全与连接策略 |
| 可控性强 | 相比 WebSocket，更灵活地实现连接复用、消息确认、重传策略 |
| 跨项目适配 | Objective-C 封装 + Swift 调用，适配多技术栈客户端项目 |

---

## 🚀 快速开始
**Objective-C 接入示例**

```Objc
// 0. 在AppDelegate中添加
[TJPMessageFactory load];

// 1. 初始化客户端
TJPIMClient *client = [TJPIMClient shared];
//可以进行相关client设置 client最好为成员变量 防止提前释放问题

// 2. 建立不同类型的连接
[client connectToHost:@"media.example.com" port:8080 forType:TJPSessionTypeChat];
[client connectToHost:@"media.example.com" port:8081 forType:TJPSessionTypeMedia]

// 3. 创建不同类型消息
TJPTextMessage *textMsg = [[TJPTextMessage alloc] initWithText:@"Hello World!!!!!"];
// 4.1 发送消息 - 手动指定会话
[client sendMessage:textMsg throughType:TJPSessionTypeChat];

// 4.2 发送消息 - 自动路由
TJPMediaMessage *mediaMsg = [[TJPMediaMessage alloc] initWithMediaId:@"12345"];
[client sendMessageWithAutoRoute:mediaMsg]; // 自动路由到媒体会话
```

**Swift 接入示例**

```Swift
// 0. 在AppDelegate中添加
TJPMessageFactory.load

// 1. 初始化客户端
let client = TJPIMClient.shared
// 可以进行相关client设置 client最好为成员变量 防止提前释放问题

// 2. 建立不同类型的连接
client.connect(toHost: "media.example.com", port: 8080, for: .chat)
client.connect(toHost: "media.example.com", port: 8081, for: .media)

// 3. 创建不同类型消息
let textMsg = TJPTextMessage(text: "Hello World!!!!!")
// 4.1 发送消息 - 手动指定会话
client.sendMessage(textMsg, through: .chat)

// 4.2 发送消息 - 自动路由
let mediaMsg = TJPMediaMessage(mediaId: "12345")
client.sendMessageWithAutoRoute(mediaMsg) // 自动路由到媒体会话
```

## 核心功能
**按需使用**，快速定位需求

| 功能类别 | 核心特性 | 应用场景 |
| -------------|----------------------- | --------------------|
| **网络通信核心** | 内置心跳保活、断线重连、ACK确认机制 | 即时通讯、IoT设备管理 |
| **二进制协议设计** | 自定义TLV结构协议、CRC32校验、高效压缩 | 高吞吐、低延迟场景 |
| **高并发优化** | 多路复用连接池、GCD优化、零拷贝传输 | 实时数据同步 |
| **现代企业级架构** | VIPER分层架构、注入式解耦框架（Typhoon）、IM防腐层设计 | 大型项目长期维护 |
| **弱网优化** | ACK确认机制、指数退避重传、自适应动态心跳 | 移动网络环境通信 |

## 性能指标

- **高并发能力**: 支持峰值3000+并发连接，内存占用1.6GB (约320KB/连接)
- **消息吞吐量**: 单连接峰值8,000 pps (约6.4 Mbps)，基准测试环境（iPhone 14 Pro）
- **线程效率**: 多线程切换耗时占比 < 3%，GCD优化调度
- **弱网表现**: 30%丢包环境下消息可达率>92%，平均延迟<800ms
- **响应速度**: 网络恢复后连接重建平均耗时<2秒
- **资源占用**: 相比NSURLSession方案，内存占用减少35%，CPU使用降低28%
- **生产验证**: 日均处理10万+消息，真实服务于企业客户

## 🔥 技术亮点

<details>
<summary><b>查看技术实现细节</b></summary>

### 高性能单TCP通信模块
**ConcurrentNetworkManager** - 生产环境验证

- **连接管理**：TLS支持 + 单连接管理
- **协议解析**：定长头部 + TLV协议 + CRC32校验
- **健壮机制**：指数退避重连 + 心跳保活（15s间隔/30s超时）
- **线程安全**：串行队列资源管理
- **容错设计**：ACK确认重试 + 随机抖动防惊群

### 企业级多路复用架构
**NetworkManagerFinal** - 日均10w+消息实测验证
- **中心协调器**：动态扩容 + 故障隔离
- **会话自治模型**：独立状态机 + 自适应心跳
- **安全协议栈**：二进制协议设计 + TLS加密

### 完整TCP状态机实现
通过实现完整的TCP状态机，掌握TCP协议的核心机制：
- **三次握手**：建立可靠连接
- **慢启动**：避免网络拥塞
- **快速重传**：提高数据传输效率
- **ACK/NACK机制**：保证数据可靠传输
- **超时重传机制**：确保数据传输可靠性
</details>


## 通信架构设计
Socket通信模块架构
```
+---------------------------------------------------+
|                    应用层                          |
|  			     使用统一API管理网络通信 		                |
+---------------------------------------------------+
                        |
                        v
+---------------------------------------------------+
|                TJPIMClient                        |
|  (门面模式: 高级API + 内部适配器管理 + 代理分发)        |
+---------------------------------------------------+
                        |
              +---------+---------+
              |                   |
              v                   v
+-------------------------+    +-------------------------+
| TJPMessageParser        |    |   TJPConcreteSession   |
| (内容编解码与适配)         |    |   (底层连接管理)         |
+-------------------------+    +-------------------------+
                                          |
                                          v
                               +-------------------------+
                               |  TJPNetworkCoordinator  |
                               | (多会话协调与全局网络管理) |
                               +-------------------------+
                                          |
                                          v
                               +-------------------------+
                               |     GCDAsyncSocket      |
                               |    (底层套接字通信)       |
                               +-------------------------+
```
- **门面模式**: 统一API入口，简化调用
- **分层设计**: 连接管理与消息处理分离
- **状态机**: 完整实现TCP连接生命周期管理
- **内存安全**: 严格的资源生命周期管理，自动回收避免泄漏
- **并发控制**: 读写分离与串行队列设计，确保线程安全与数据一致性
- **自适应策略**: 基于当前网络质量动态调整传输参数和重试策略
- **开闭原则**: 基于协议设计的可插拔架构，支持业务定制与扩展

### TLV数据协议设计
二进制高效通信协议，支持协议平滑升级和嵌套结构：

<table>
  <tr>
    <th width="25%">Tag (2字节)</th>
    <th width="25%">Length (4字节)</th>
    <th width="50%">Value (N字节)</th>
  </tr>
  <tr>
    <td>业务标识<br><code>0x1001</code>=文本消息<br><code>0x1002</code>=图片消息</td>
    <td>Value部分长度<br>(不含T和L字段)</td>
    <td>原始数据或嵌套TLV<br>(保留Tag <code>0xFFFF</code>标记)</td>
  </tr>
</table>
**示例数据包**：
文本消息 "Hello" 的TLV编码：
[10 01] [00 00 00 05] [48 65 6C 6C 6F]
Tag     Length        Value("Hello")

- 采用**大端字节序**，兼容不同硬件平台
- 支持**协议版本协商**，实现向前兼容
- 内置**校验机制**，确保数据完整性
## 生产级VIPER架构

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
### VIPER架构在IM场景中的应用

基于VIPER架构的消息处理系统特别适合IM场景，提供:
- **消息状态管理**: 完整支持发送中、已发送、已读等状态流转
- **多渠道路由**: 支持文本、图片等不同消息类型的专用处理流程
- **UI渲染优化**: 分离数据处理与界面渲染，提升复杂聊天界面性能
- **测试友好**: 业务逻辑完全独立，单元测试覆盖率可达90%以上

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
│   │   ├── TCP链路流转图.jpg       
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
├── ArchitectureExtensions/       
│   ├── VIPER-Integration/         # 生产级VIPER架构
│   │   ├── NetworkService/        # 网络服务层
│   │   │   ├── ConnectionManager/ # 连接池管理
│   │   │   └── ProtocolAdapter/   # 协议适配器
│   │   └── DI Container/          # 依赖注入实现
│   └── AOP/                       
│   │   └── LoggingAspect/         # 日志追踪切面
│   └── NetworkMonitor/            # 网络监控
├── CoreNetworkStack/    
│   ├── V1_BasicFunction/          # 最初演示版本（演示TCP问题，并解决问题）
│   ├── V2_Concurrency/            # 多并发版本（单链接，此项目中更多用于演示作用）
│   ├── TJPIMCore/            		 # IM核心，多路复用通讯框架
│   └── TransportLayer/            # 传输层Mock
└── ProductionBridge/              
    └── VIPER-Sample/              # 真实项目代码片段
        └── MessageModule/         # 消息模块实现
```

## 版本历史
<details>
<summary><b>📋 版本历史</b></summary>

- **v1.0.0**：网络框架基础核心功能基本完成、生产级VIPER架构演示完成
- **v1.0.1**：修复了因libffi编译导致无法在模拟器运行的问题
- **v1.1.0**：新增全链路追踪、关键指标采集（网络质量/成功率/延迟）并添加演示Demo，引入序列号分区机制，整体逻辑优化
- **v1.2.0**：协议改造为TLV结构，支持协议无缝升级，整体逻辑重构，消息构造和解析逻辑发生本质变化，详见Doc
- **v1.2.1**：完善了消息错误机制，遵循单一职责拆分了数据包解析、组装，抽象了连接管理类，优化了握手交换协议版本信息逻辑
- **v1.3.0**：升级动态心跳机制，结合App状态+网络状态，使用更成熟稳定的方案动态调整心跳频率；埋点功能优化，提供更全面的埋点维度

</details>

## 后续迭代计划
- **运营商网络适配**: NAT超时处理、运营商防拦截
- **极端环境支持**: 智能降级策略、弱网优化、多级故障恢复
- **高性能传输**: 连接池优化、大文件传输、QoS流量控制
- **IM组件库**: 防腐层设计、聊天UI组件、VIPER架构示例

## 贡献
欢迎**任何开发者贡献代码、改进文档、提出意见和建议！** 如果你有关于iOS网络栈的实践经验或心得，欢迎提交PR来丰富本项目。


## License
本项目遵循 **MIT 许可证**，详细信息请查看 [LICENSE](./LICENSE) 文件。

如果这个项目对你有帮助，请点个 ⭐ Star 支持！

<details>
<summary><b>推荐学习资源</b></summary>

### 书籍与文档
- 《计算机网络：自顶向下方法》- 经典教程
- 《TCP/IP详解》- 协议深度解析
- [Apple iOS Network Programming Guide](https://developer.apple.com/documentation/foundation/networking)

### 工具与开源项目
- [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) - iOS Socket编程库
- [Wireshark](https://www.wireshark.org/) - 网络协议分析工具
- [Typhoon](https://github.com/appsquickly/Typhoon) - 依赖注入框架
</details>

## 许可与免责声明
本项目采用MIT许可证，供个人学习和研究使用。使用时请注意：

1. 允许修改和分发，但建议不要直接用于商业产品
2. 使用本项目时请确保符合数据隐私法规
3. 由于网络环境复杂多变，使用前请充分测试
4. 作者不对因使用本项目可能导致的任何问题负责

详情请查看[LICENSE](./LICENSE)文件。

## 社区透明度声明

近期我收到关于项目 Star 异常增长的反馈。经与 GitHub 官方核查确认，其中部分来自非自然增长渠道。

### 立场与行动
1. **问题回顾**  
   项目在早期曾尝试通过第三方服务进行曝光测试（现已永久终止）

2. **当前处理**  
   ✅ 已停止所有非自然推广行为  
   ✅ 已向 GitHub 报告异常 Star，并提交可疑样本，等待平台进一步处置  
   ✅ 项目保持完全透明，所有代码和提交记录均可审查

4. **未来承诺**  
   **专注技术价值**：依靠代码质量与架构创新赢得认可    
   **真实数据优先**：杜绝任何形式的数据操控  
   **开放治理**：将定期发布社区透明度报告（含增长分析）
   
### 特别致谢
感谢提出质疑的开发者！您的监督促使我更好地践行开源精神。任何疑问或建议，欢迎通过 issue 或 discussion 提出。

—— 项目维护者  
*更新于 2025.06.07*

