# VIPER 架构设计思路文档

## 目录
1. [简介](#简介)
2. [VIPER 架构概述](#VIPER-架构概述)
3. [各个模块的职责](#各个模块的职责)
   - [View](#View)
   - [Interactor](#Interactor)
   - [Presenter](#Presenter)
   - [Entity](#Entity)
   - [Router](#Router)
4. [模块间通信](#模块间通信)
5. [方法和命名规范](#方法和命名规范)
6. [日志记录与性能优化](#日志记录与性能优化)
7. [错误处理与用户提示](#错误处理与用户提示)
8. [总结](#总结)

## 简介

VIPER（View, Interactor, Presenter, Entity, Router）是一种常见的架构模式，旨在将应用程序的不同职责分离，以提高可维护性、可扩展性和可测试性。它通过将逻辑划分到不同的模块中，减少模块之间的耦合，保证每个模块的单一职责。

在本设计中，我们遵循 VIPER 架构模式，主要包括以下几个模块：
- **View**：负责显示 UI 并接收用户输入。
- **Interactor**：处理业务逻辑，与数据源交互。
- **Presenter**：处理视图与交互器之间的协调，准备和格式化数据以供视图显示。
- **Entity**：表示业务数据模型。
- **Router**：负责页面导航和路由控制。

## VIPER 架构概述

VIPER 架构是一种分层架构设计模式，它将应用的不同职责分配给不同的模块，每个模块之间通过明确的协议进行通信。VIPER 各模块的职责划分如下：

### View
- **职责**：展示 UI 并处理用户输入，直接与 Presenter 进行交互。
- **操作**：
  - 向 Presenter 请求数据更新。
  - 显示或隐藏加载状态。
  - 显示错误信息。

### Interactor
- **职责**：处理业务逻辑，管理数据操作，如从服务器获取数据、数据验证等。
- **操作**：
  - 从网络或本地存储中获取数据。
  - 执行与业务相关的操作。
  - 将结果传递给 Presenter。

### Presenter
- **职责**：协调 View 和 Interactor，处理业务逻辑与数据格式化，将数据准备好以便 View 展示。
- **操作**：
  - 从 Interactor 获取数据。
  - 格式化数据或处理逻辑。
  - 更新 View 的 UI。

### Entity
- **职责**：代表数据模型或对象结构，通常是从服务器或数据库中获取的数据。
- **操作**：
  - 持有业务数据。
  - 供 Presenter 或 Interactor 使用。

### Router
- **职责**：管理页面导航，负责视图之间的切换与数据传递。
- **操作**：
  - 根据用户的操作进行页面跳转。
  - 处理页面之间的参数传递。

## 各个模块的职责

### View
- **TJPViperBaseTableViewController**：作为 View，负责显示表格视图并响应用户的下拉刷新和上拉加载请求。
- **职责**：
  - 向 Presenter 请求数据。
  - 更新 UI 状态，如显示加载指示器、错误提示等。

### Interactor
- **TJPViperBaseInteractorImpl**：作为 Interactor，负责与数据源交互（如网络请求、数据库操作）。
- **职责**：
  - 执行数据请求操作。
  - 提供数据更新信号。
  - 实现具体的业务逻辑。

### Presenter
- **TJPViperBasePresenterImpl**：作为 Presenter，协调 View 和 Interactor，处理数据请求和业务逻辑。
- **职责**：
  - 请求 Interactor 获取数据。
  - 格式化数据并将其传递给 View。
  - 订阅 Interactor 中的信号并更新 View。

### Router
- **TJPViperBaseRouterImpl**：作为 Router，负责页面的导航和路由管理。
- **职责**：
  - 根据指定的跳转类型（如 Push、Present、Modal）进行页面跳转。
  - 处理页面间的数据传递。

## 模块间通信

- **View 与 Presenter**：View 通过协议调用 Presenter 中的方法来请求数据，并接收 Presenter 提供的数据更新。
- **Presenter 与 Interactor**：Presenter 请求 Interactor 获取数据，Interactor 将数据返回给 Presenter。
- **Interactor 与 Router**：Interactor 触发数据更新信号，Presenter 和 Router 可以通过订阅信号来响应页面跳转操作。

## 方法和命名规范

- **命名规范**：方法名应遵循清晰、简洁且描述性强的原则，采用驼峰命名法。例如：
  - `fetchDataForPageWithCompletion`：表示获取某一页的数据。
  - `handleDataFetchSuccess`：表示处理数据获取成功的逻辑。
  - `handleDataFetchError`：表示处理数据获取失败的错误逻辑。
- **回调机制**：使用回调闭包（如成功和失败回调）来处理异步操作的结果。

### 示例方法：
```objc
- (void)fetchDataForPageWithCompletion:(NSInteger)page 
                                success:(nonnull void (^)(NSArray * _Nullable data, NSInteger totalPage))success 
                                failure:(nonnull void (^)(NSError * _Nullable error))failure;

