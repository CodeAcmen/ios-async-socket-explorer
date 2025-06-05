# ios-async-socket-explorer (EN)

A production-ready TCP communication framework for iOS, designed for high-concurrency, weak network environments, and modular architecture in enterprise-level applications.

## ✨ Overview

`ios-async-socket-explorer` is an industrial-grade TCP socket framework built on CocoaAsyncSocket, abstracted from real-world enterprise IM systems.

- Supports **3000+ concurrent connections**, handling **100,000+ messages daily**
- Implements **TLV binary protocol**, **CRC32 checksum**, and **ACK-based reliability mechanism**
- Equipped with **RTT-adaptive heartbeat** and **exponential backoff reconnection**, optimized for complex weak network conditions
- Features **enterprise-level VIPER architecture**, with **unit test coverage over 85%**
- Provides **comprehensive monitoring metrics and full-link tracing** to ensure system observability

## 🔧 Why not just use WebSocket?

| Comparison | Advantage of CocoaAsyncSocket |
|------------|-------------------------------|
| Custom protocol support | Enables binary framing, versioning, compression |
| Fine-grained control | Better handling of sessions, retries, and heartbeats |
| Enterprise security | Supports TLS, keepalive, session isolation |
| Flexibility | Objective-C base, easy Swift integration |

## 🚀 Quick Start
**Objective-C Example**

```Objc
// 0. Add this in AppDelegate
[TJPMessageFactory load];

// 1. Initialize the client
TJPIMClient *client = [TJPIMClient shared];
// It's recommended to keep 'client' as a member variable to avoid premature release

// 2. Establish different session connections
[client connectToHost:@"media.example.com" port:8080 forType:TJPSessionTypeChat];
[client connectToHost:@"media.example.com" port:8081 forType:TJPSessionTypeMedia];

// 3. Create different types of messages
TJPTextMessage *textMsg = [[TJPTextMessage alloc] initWithText:@"Hello World!!!!!"];
// 4.1 Send message - specify session manually
[client sendMessage:textMsg throughType:TJPSessionTypeChat];

// 4.2 Send message - auto route
TJPMediaMessage *mediaMsg = [[TJPMediaMessage alloc] initWithMediaId:@"12345"];
[client sendMessageWithAutoRoute:mediaMsg]; // Automatically routed to media session
```

**Swift Example**

```Swift
// 0. Add this in AppDelegate
TJPMessageFactory.load()

// 1. Initialize the client
let client = TJPIMClient.shared
// It's recommended to keep 'client' as a property to avoid premature deallocation

// 2. Establish different session connections
client.connect(toHost: "media.example.com", port: 8080, for: .chat)
client.connect(toHost: "media.example.com", port: 8081, for: .media)

// 3. Create different types of messages
let textMsg = TJPTextMessage(text: "Hello World!!!!!")
// 4.1 Send message - specify session manually
client.sendMessage(textMsg, through: .chat)

// 4.2 Send message - auto route
let mediaMsg = TJPMediaMessage(mediaId: "12345")
client.sendMessageWithAutoRoute(mediaMsg) // Automatically routed to media session
```

## License & Disclaimer
This project is released under the **MIT License** and intended for personal study and research purposes only. Please be aware of the following before using:

1. You are free to modify and distribute the code, but it's **not recommended** to use it directly in production applications.
2. Ensure your usage **complies with relevant data privacy regulations**.
3. Given the complexity and variability of network environments, you should **fully test the framework before integrating it**.
4. The author **is not responsible** for any issues that may arise from the use of this project.

For full license details, see the [LICENSE](./LICENSE) file.

