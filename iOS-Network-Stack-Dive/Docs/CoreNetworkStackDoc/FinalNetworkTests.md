各组件单元测试

TJPMessageContext
contextWithData:
验证 sendTime 是否为当前时间。
验证 retryCount 是否初始化为 0。
验证 sequence 是否正确设置。
buildRetryPacket
验证重试次数是否递增。
验证返回的数据包是否正确构建。


TJPDynamicHeartbeat
startMonitoringForSession:
验证定时器是否启动，心跳是否按预期发送。
测试心跳是否在正确的时间间隔内发送。
adjustIntervalWithNetworkCondition:
测试不同网络条件下，心跳频率是否调整正确。
heartbeatACKNowledgedForSequence:
验证 ACK 收到后，是否正确清除待确认心跳。
sendHeartbeat
验证心跳包是否正确构建并发送。
测试心跳超时后是否触发重试。


TJPNetworkCondition
conditionWithMetrics:
测试根据 NSURLSessionTaskMetrics 创建的条件是否正确计算 RTT 和丢包率。
calculatePacketLoss
验证丢包率计算是否符合预期。
qualityLevel
测试不同 RTT 和丢包率下的网络质量评估。
isCongested
测试不同丢包率和 RTT 下，网络是否被判断为拥塞。


TJPMessageParser
feedData:
测试数据是否正确添加到缓冲区。
hasCompletePacket
测试缓冲区是否能够正确判断是否有完整的数据包。
nextPacket
测试数据是否被正确解析成包，并触发正确的回调。
parseHeader
测试魔数校验和头部解析是否正确。
parseBody
测试消息体解析是否正确。


TJPReconnectPolicy
initWithMaxAttempst:baseDelay:qos:
验证重试策略的初始化是否正确。
attemptConnectionWithBlock:
测试连接重试逻辑，验证延迟计算和重试次数。
calculateDelay
测试延迟计算是否符合预期的指数退避和随机延迟策略。
notifyReachMaxAttempts
测试最大重试次数到达时，是否正确触发通知。


TJPConnectStateMachine
addTransitionFromState:toState:forEvent:
测试状态转换规则是否正确添加。
sendEvent:
测试事件触发后的状态转换。
onStateChange:
测试状态变化回调是否被正确触发。
无效状态转换
测试无效事件是否被正确处理并打印日志。


TJPNetworkUtil
buildPacketWithData:type:sequence:
测试数据包是否正确构建，验证协议头、CRC 校验等。
crc32ForData:
测试 CRC32 校验值是否正确。
compressData: 和 decompressData:
测试数据压缩和解压是否正确，验证压缩后的数据与原始数据是否一致。
base64EncodeData: 和 base64DecodeString:
测试 Base64 编解码是否正确。
deviceIPAddress:
测试设备 IP 地址获取是否正常。
isValidIPAddress:
测试 IP 地址的合法性验证是否正确。


TJPSequenceManager
nextSequence
测试序列号是否正确递增，确保循环逻辑正确。
resetSequence
测试序列号重置功能是否正常。
currentSequence
验证 currentSequence 是否返回最新的序列号。
线程安全
测试多线程环境下序列号生成的线程安全性。


TJPConcreteSession
connectToHost:port:
测试连接过程，验证是否能正确触发状态变化。
sendData:
测试消息发送和重试机制是否正常工作。
disconnectWithReason:
测试会话断开连接的过程。
socket:didConnectToHost:port:
测试连接成功后的处理。
socket:didReadData:withTag:
测试数据接收和解析过程。
processReceivedPacket:
验证不同类型的数据包（普通数据、心跳、ACK）是否正确处理。
flushPendingMessages
测试未确认消息的重传。
handleError:
测试错误处理和断开连接的逻辑。

TJPNetworkCoordinator
createSessionWithConfiguration:
测试会话的创建和添加到 sessionMap。
updateAllSessionsState:
验证所有会话状态的统一更新。
handleNetworkStateChange:
测试网络状态变化时，会话的处理逻辑。
triggerAutoReconnect
验证网络恢复时自动重连的功能。
session:didReceiveData:
测试接收到数据时，是否正确发布通知。
session:stateChanged:
验证会话状态变化时，是否正确移除断开连接的会话。

