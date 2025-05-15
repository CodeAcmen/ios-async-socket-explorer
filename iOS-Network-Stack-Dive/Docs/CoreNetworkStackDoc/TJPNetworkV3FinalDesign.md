# 中心管理 + 会话自治架构设计文档

## 1. 架构概述

基于 **中心协调 + 会话自治** 的设计理念，旨在实现高并发网络连接场景下的灵活管理和资源优化。核心思想如下：

- **中心管理**：由全局协调器（`TJPNetworkCoordinator`）统一管理网络状态、会话生命周期和公共资源。
- **会话自治**：每个会话（`TJPConcreteSession`）独立管理自身的连接、消息收发和状态逻辑。
- **事件驱动**：通过状态机（`TJPStateMachine`）实现状态转换与业务逻辑的解耦，提升代码可维护性。
- **串行化控制**：通过分级串行队列保证线程安全

### 1.1分层架构模型
```objc
// 三级架构总体设计
NetworkCoordinator(管理层)
  └─ ConcreteSession(会话层)
       └─ GCDAsyncSocket(传输层)
// 细分设计
TJPIMClient (门面模式，屏蔽底层实现细节)
├── TJPNetworkCoordinator (多会话管理)
│   ├── TJPConcreteSession (会话自制模型)
│   │   ├── TJPConnectionManager (连接管理)
│   │   ├── TJPDynamicHeartbeat (动态心跳)
│   │   ├── TJPMessageParser (消息解析)
│   │   ├── TJPMessageBuilder (消息组装)
│   │   ├── TJPSequenceManager (序列号管理)


```
### 1.2状态机驱动设计
```objc
// 状态转换矩阵示例
StateMachineTransitionMatrix:
  Disconnected → Connecting : ConnectEvent
  Connecting → Connected    : ConnectSuccessEvent
  Connected → Disconnecting : DisconnectEvent
```
### 1.3模块化设计
- 独立的心跳管理器(TJPDynamicHeartbeat)
- 可插拔的协议解析器(TJPMessageParser)
- 可配置的重连策略(TJPReconnectPolicy)

### 1.4明确组件责任界限
- Coordinator: 全局单例，用于管理、会话创建，网络状态监控和全局事件分发，不直接处理TCP连接细节
- Session: 负责单个TCP连接的生命周期管理、数据收发，维护连接状态
- HeartbeatManager: 仅负责心跳管理，向Session报告心跳状态，不直接控制连接
- StateMachine: 仅负责状态管理和转换验证，不执行业务逻辑
- ReconnectPolicy：只负责重连逻辑、计算重连时间，不直接操作TCP连接

### 1.5队列设计
- 并发队列：并行处理任务，如多个会话的数据解析（但解析器本身要是线程安全），网络状态变更的通知分发
- 串行队列：按顺序执行任务，如单TCP的生命周期管理、心跳管理、状态管理、共享资源操作

## 2. 核心组件

### 2.1 TJPNetworkCoordinator（全局协调器）

- **职责**：
  - 管理所有会话的创建和销毁。
  - 监控全局网络状态，如：可达性、带宽
  - 分配共享资源，如：线程池、解析队列

- **关键特性**：
  - 串行队列管理会话池
  - 独立监控和解析队列

### 2.2 TJPConcreteSession（会话实例）

- **职责**：
  - 管理单个连接的完整生命周期（连接、断开、重连）
  - TJPMessageParser统一处理消息的发送、接收和解析
  - TJPDynamicHeartbeat动态维护心跳机制

- **关键特性**：
  - 独立的状态机（`TJPStateMachine`）管理会话状态
  - 支持自定义重连策略（`TJPReconnectPolicy`）

### 2.3 TJPStateMachine（状态机）

- **职责**：
  - 定义合法的状态转换规则（如 `Disconnected → Connecting`）
  - 通过事件（`Event`）驱动状态变更
  - 触发状态变更时的副作用（如通知代理、刷新消息队列）

- **关键特性**：
  - 轻量级实现，无第三方依赖。
  - 支持动态添加状态和事件。

## 3. 架构图

```
+---------------------+  
| TJPNetworkCoordinator |  
+---------------------+  
| - Session Pool      |  
| - Network Monitor   |  
| - Global Queues     |  
+----------+----------+  
           |  
           | manages  
           v  
+---------------------+  
| TJPConcreteSession   |  
+---------------------+  
| - State Machine     |  
| - Socket Instance    |  
| - Message Queue     |  
+---------------------+  
           |  
           | uses  
           v  
+---------------------+  
| TJPStateMachine      |  
+---------------------+  
| - State Transitions |  
| - Event Handlers    |  
+---------------------+  



+---------------------+       +-----------------------+
| TJPDynamicHeartbeat |       |   TJPNetworkCondition |
|---------------------|       |-----------------------|
| - heartbeatQueue    |<>---->| - rttWindow[10]       |
| - networkCondition  |       | - lossWindow[10]      |
+---------------------+       +-----------------------+
         | 更新RTT/丢包率                ^
         |------------------------------|
         
         v                              |
+---------------------+       +-----------------------+
|   TCP/UDP Session   |       |    Adjustment Logic   |
|---------------------|       |-----------------------|
| - sendData()        |       | - 加权平均计算          |
| - disconnect()      |       | - 梯度调整策略          |
+---------------------+       +-----------------------+


```


## 4. 核心流程

### 4.1 连接管理流程

1. **用户（User）** 发起会话创建请求，传递所需配置给 **全局协调器（Coordinator）**。
2. **全局协调器（Coordinator）** 接收到请求后，初始化 **会话实例（Session）** 并传递配置。
3. **会话实例（Session）** 初始化状态机（`StateMachine`）。
4. 用户调用 `connectToHost:port` 方法，**会话实例（Session）** 接收连接请求并触发 **状态机（StateMachine）**。
5. **状态机（StateMachine）** 向 **会话实例（Session）** 发送 **连接请求（Connect 事件）**，并将状态更改为 `Connecting`。
6. **会话实例（Session）** 向目标主机发起连接请求（通过 **Socket**）。
7. **Socket** 连接成功后，返回连接成功的消息。
8. **会话实例（Session）** 接收到连接成功消息后，向 **状态机（StateMachine）** 发送 **连接成功事件（ConnectSuccess）**，并将状态更改为 `Connected`。
9. **会话实例（Session）** 向 **全局协调器（Coordinator）** 通知状态已变更为 `Connected`。

### 4.2 消息收发流程

1. **用户（User）** 向 **会话实例（Session）** 发送数据。
2. **会话实例（Session）** 构建协议包（包含头部和 CRC32 校验）。
3. **会话实例（Session）** 将数据发送给 **Socket**。
4. **Socket** 收到数据并返回响应数据。
5. **会话实例（Session）** 使用 **消息解析器（MessageParser）** 解析响应数据。
6. **消息解析器（MessageParser）** 将数据解析为 `ParsedPacket` 并返回给 **会话实例（Session）**。
7. **会话实例（Session）** 根据消息类型触发事件（例如：`ACK` 确认）。
8. **状态机（StateMachine）** 处理事件并反馈给 **会话实例（Session）**。
9. **会话实例（Session）** 将处理结果回调给 **用户（User）**。



## 5. 优势总结

### 5.1 中心管理的优势

- **资源优化**：通过共享线程池和解析队列，降低内存开销，提升资源利用率。
- **统一监控**：实现全局网络状态与会话健康度的集中监控，提供实时反馈。
- **扩展性强**：支持动态扩展和添加新的会话类型，如 HTTP、WebSocket 等协议，提升系统的灵活性和可扩展性。

### 5.2 会话自治的优势

- **隔离性**：每个会话独立管理，不同会话间故障隔离，确保单一会话的故障不会影响其他连接。
- **灵活性**：每个会话可以独立配置其策略，如心跳间隔、超时时间等，适应不同的应用场景。
- **易测试**：会话的逻辑与状态独立，能够单独进行单元测试，确保系统的可测试性与可靠性。

### 5.3 状态机的优势

- **清晰的状态转换**：通过规则明确定义合法的状态路径，确保系统运行的规范性与一致性。
- **解耦业务逻辑**：事件驱动设计有效避免了传统的 `if-else` 嵌套，增强了代码的可读性和维护性。
- **可维护性**：系统状态变更时会产生日志或调试信息，方便开发人员跟踪和排查问题。


---

## 6. 为什么使用 zlib 进行压缩？

- **减少网络带宽占用**：数据压缩后，传输数据的大小大幅减少，节省带宽，提高数据传输效率。
- **提高传输速度**：压缩后的数据更小，传输所需的时间更短，降低了网络延迟，提升了传输速度。
- **广泛支持**：zlib 是一个高效、广泛使用的压缩库，支持几乎所有主流平台，兼容性强。

---

## 7. 核心技术细节

### 无锁设计

- 串行队列替代锁和屏障，保证`Session` 内部的线程安全，避免数据竞争。


### 灵活扩展

- 通过 `Configuration` 配置字典支持会话参数的动态配置，方便根据不同需求调整会话行为。

### 性能隔离

- 将操作队列与协议解析队列分离，避免阻塞操作，确保 Socket 操作的高效性和实时性。

### 智能重连

- 集成指数退避算法，并结合网络状态动态调整重连策略，确保在不稳定的网络环境下，系统能够自适应并恢复连接。

---

## 8. 可扩展组件（后期实现）

以下组件可根据需求进一步扩展：

- **加密模块**：在协议层加入 AES 加密，提升通信安全性。
- **流量统计**：在 `Coordinator` 中集成流量监控模块，跟踪和记录网络流量数据。
- **优先级队列**：实现带优先级的消息发送队列，保证高优先级消息的优先传输。
- **协议压缩**：在 `MessageParser` 中集成 zlib 压缩功能，减少数据传输量。

---

