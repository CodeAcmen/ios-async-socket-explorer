
# TJPNetworkManagerV2：高性能、线程安全的单 TCP 通信模块

> 经过实际生产环境验证的，为 iOS/macOS 打造的 GCD 异步、单 TCP 管理器，支持心跳、重连、ACK、重发机制，使用串行队列实现高性能线程安全，适用于小型项目以及中型项目早期。
> 注意:不适用于现代大型项目

---

## 模块特点

- **线程安全、无锁实现：** 所有共享状态通过 `dispatch_queue_t` 串行调度，避免加锁与死锁风险；
- **稳定可靠的通信机制：**
  - 心跳机制（Dispatch Timer）；
  - 重连机制（指数退避 + 抖动）；
  - ACK + 消息重发；
- **强模块化设计：** 支持协议扩展、消息处理解耦；
- **适用于：** 游戏、物联网、IM、轻量服务通信等场景。

---

## 已实现的能力（Features）

| 类型             | 能力描述 |
|------------------|----------|
| **连接管理**     | 支持单连接的建立与断开，支持 TLS 可选配置 |
| **消息解析机制** | 使用串行队列 `_networkQueue` 实现无锁串行解析，避免竞态 |
| **自定义协议结构** | 包含 `magic` 魔数校验、消息类型、序列号、数据长度、CRC 校验 |
| **ACK 回执机制** | 发送数据后会保存待确认消息，收到 ACK 后移除，支持自动重发 |
| **心跳机制**     | 使用 `dispatch_source` 定时器发送心跳，支持对端响应、超时断线 |
| **断线重连机制** | 支持指数退避 + 随机抖动的重连策略，避免惊群问题 |
| **完整单元测试** | 提供 `TJPMockTCPServer` 实现模拟服务端，支持心跳/ACK 单测 |
| **测试注入接口** | 例如 `onSocketWrite` / `onMessageParsed` 等 hook，便于行为验证 |
| **错误处理模块** | 支持协议错误、数据校验失败等异常处理与日志抛出 |

---


## 核心架构

GCDAsyncSocket
     ↓
TJPNetworkManagerV2
    ├── connect / disconnect
    ├── sendData / resendPacket
    ├── parseBuffer（串行解析）
    ├── heartbeatTimer（定时心跳）
    └── pendingMessages（ACK机制）



---

## 线程安全实现策略

| 共享资源          | 并发问题                 | 解决方式                                                     |
|-------------------|--------------------------|--------------------------------------------------------------|
| `parseBuffer`     | 多线程读写、替换、截取   | 封装为 GCD 串行队列 `_networkQueue` 内方法，如 `appendToParseBuffer:` |
| `pendingMessages` | 多线程添加/移除          | 同样使用 `_networkQueue` 串行访问                            |
| `_isParsingHeader`| 状态切换竞争             | 封装为 `setIsParsingHeaderSafe:` 和 `isParsingHeaderSafe`     |
| `socket`          | 多线程收发数据           | 委托 GCDAsyncSocket 自动调度，委托队列设为 `_networkQueue`    |
| 心跳 + 重连        | 计时器和网络状态变化并发 | dispatch_source + Reachability 回调 block 同步调度           |

---



