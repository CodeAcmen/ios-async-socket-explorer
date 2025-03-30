# libffi-ios-latest
最新的 iOS libffi 库，与官方正式版本同步更新。The latest iOS libffi library, synced with official releases.

## 快速使用

使用 CocoaPods 安装 `libffi-ios-latest`：

在你的 `Podfile` 中添加以下内容：

```ruby
pod 'libffi-ios-latest'
```
然后，运行以下命令安装依赖：
```bash
pod install
```
## 导入库
在你的 **Objective-C** 项目中，使用以下方式导入：
```objc
#import <libffi-ios-latest/ffi.h>
```
在你的 **Swift** 项目中，使用以下方式导入：
```swift
import libffi_ios_latest
```

## 中文描述

本仓库提供了最新版本的 `libffi` iOS 版本，并与官方版本保持同步更新。该库包含支持 **x86_64** 和 **arm64** 架构的 **iOS 模拟器**，以及 **iOS 设备** 的 **arm64** 架构。

- **模拟器**：支持 **x86_64**（Intel Mac）和 **arm64**（Apple Silicon）架构。
- **设备**：支持 **arm64** 架构的 iOS 设备。
- **兼容性**：兼容 iOS 9.0 及以上版本。

该库会定期更新，以确保与官方 `libffi` 最新版本保持同步，方便开发者使用最新版本进行 iOS 开发。

## 已知问题与版本说明

- **本仓库V3.4.0版本-3.4.0-patch2** 版本存在问题。使用这些版本时，可能会遇到一些已知的构建问题和头文件未正确链接的问题。
- 如果使用**v3.4.0版本，请使用 `3.4.0-fix` 版本**。此版本已修复了 `patch1` 和 `patch2` 中的问题，确保正确集成 `libffi` 到 iOS 项目中。
- 如果你正在使用较旧版本（例如 `3.4.0-patch1` 或 `3.4.0-patch2`），强烈建议升级到 `3.4.0-fix` 或更高版本。
- 后续版本号将与官方正式版同步，修复bug版本将不带"v"，具体请留意说明

### 关于未来开发的建议

尽管 **libffi-iOS** 支持 **x86_64** 和 **arm64** 模拟器，但强烈建议未来的开发，尤其是针对 **iOS 12 及以上版本**，优先使用 **arm64 模拟器**，特别是对于使用 **Apple Silicon**（如 M1、M2）设备的开发者。自 **iOS 12** 版本以来，Apple 已将模拟器默认架构转向 **arm64**，因此为了兼容性和性能，建议开发者优先针对 **arm64 模拟器** 进行开发。



### English Description

This repository provides the latest version of the `libffi` iOS library, synchronized with the official releases. The library includes support for **x86_64** and **arm64** architectures for **iOS Simulators**, as well as **arm64** architecture for **iOS devices**.

- **Simulators**: Supports **x86_64** (Intel Macs) and **arm64** (Apple Silicon) architectures.
- **Devices**: Supports **arm64** architecture for iOS devices.
- **Compatibility**: Compatible with iOS 9.0 and later.

This library will be updated regularly to ensure it stays in sync with the official `libffi` releases, making it easy for developers to use the latest version in iOS development.

## Known Issues and Version Notes

- The **v3.4.0 version - 3.4.0-patch2** has issues. Using these versions may lead to known build problems and incorrect header linking.
- If you are using **v3.4.0**, please use the `3.4.0-fix` version. This version fixes the issues in `patch1` and `patch2`, ensuring proper integration of `libffi` into iOS projects.
- If you are using older versions (such as `3.4.0-patch1` or `3.4.0-patch2`), it is strongly recommended to upgrade to `3.4.0-fix` or higher.
- Future versions will align with the official release version, and bug-fix versions will not have the "v" prefix. Please pay attention to release notes for further details.

### Future Development Recommendations

Although **libffi-iOS** supports **x86_64** and **arm64** simulators, it is strongly recommended to prioritize **arm64 simulators** for future development, especially for **iOS 12 and later versions**, particularly for developers using **Apple Silicon** devices (such as M1 or M2). Since **iOS 12**, Apple has shifted the default architecture for simulators to **arm64**, so for better compatibility and performance, developers should prioritize **arm64 simulators** for development.

