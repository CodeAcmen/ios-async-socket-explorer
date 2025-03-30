# 切面日志系统设计

## 1. 背景与需求

切面日志（AOP日志），允许我们在方法执行的前后插入自定义逻辑（如日志记录、性能分析、异常捕捉等），而不需要修改方法本身的实现。

### 主要需求：
- 对**类方法、对象方法**执行的过程进行日志记录。
- 支持**无参、带参、不同返回值类型**的方法。
- 方法调用不应影响原有功能。
- 日志功能可配置，支持输出到控制台、文件或上传到服务器。

## 2. 方案设计概述

通过 **方法交换（Swizzling）** 和 **动态方法调用** 的方式实现 AOP 日志系统。

### 核心方案：
1. 使用 **Method Swizzling** 动态替换方法实现。
2. 使用 **NSInvocation** 捕获和传递方法参数。

核心思路：使用 **Method Swizzling** + **NSInvocation** 实现 AOP 切面，再去处理参数，返回值，替换新旧方法、

### 遇到的难点：
**hook任意方法时包含多种类型**：有无参数、基础类型/对象类型/结构体、有无返回值、不知道方法签名，运行时动态处理
### 解决方式：
1.block + 可变参数 (...) + va_list的形式，可以解决部分场景，比如无参方法可以成功hook，但可变参数在ARC下是不安全的，会崩溃。**不推荐**
2.使用 **`libffi`** 来实现更灵活的函数调用与参数处理。

### 原生 Objective-C 的局限
| 场景 | 能力 | 局限 |
|--------|-------|---------|
| Swizzling |基础支持 | 需要知道方法签名/IMP必须静态写死固定（block会不安全）|
| NSInvocation | 调用/设置参数 | 不能自动调用IMP，会走 hook 后的代码（导致无限递归、死循环）|
| va_list | 解析参数 | 使用block+...动态参数的方式在ARC下会出错（未定义行为） |
| forwardInvocation: | 动态消息转发 | 只能用于没实现的方法，已有方法还得交换 |
| C函数调用IMP | 性能快 | 参数类型必须写死，不能通用 |

### libffi的优势
| 能力 | 描述 |
|--------|-------|
| 动态生成调用桥 | 在运行时根据方法签名构建一个可以处理参数、返回值的桥 |
| 支持任意参数类型 | 基础类型、枚举、id等都可以动态识别和传入 |
| 安全调用原始IMP | 用 ffi_call 精准调用原始方法，防止无限递归 |
| 支持任意类型、任意方法 | 不用固定参数类型，或者block+动态参数 |
| 主流框架都在使用 | 成熟的 hook 解决方案 |

## 3. 切面日志系统设计

### 3.1 基本架构

1. **注册日志**：通过调用 `TJPLogManager` 中的 `registerLogWithConfig:` 方法来注册日志切面，指定要增强的目标类、目标方法及日志触发点（前置、后置、异常时等）。
   
2. **方法替换（Swizzling）**：使用 `class_replaceMethod` 将目标方法的原始实现替换为带有日志功能的新实现。新实现会在方法执行前后触发日志记录，并调用原方法。

3. **日志处理**：在新实现中，我们使用 `NSInvocation` 来触发原方法，并通过 `va_list` 来传递可变参数。通过 `handler` 回调来触发日志记录。

4. **日志输出**：日志输出可通过回调函数定制，支持输出到控制台、保存到文件或上传到服务器等。

### 3.2 核心代码流程

1. **注册日志切面**

```objc
+ (void)registerLogWithConfig:(TJPLogConfig)config trigger:(TJPLogTriggerPoint)trigger handler:(void (^)(TJPLogModel *log))handler {
    // 获取目标类和目标方法
    Class cls = config.targetClass;
    SEL originSEL = config.targetSelector;

    // 获取原始方法实现
    Method originMethod = class_getInstanceMethod(cls, originSEL);
    IMP originIMP = method_getImplementation(originMethod);

    // 创建新的实现方法（动态生成）
    IMP newIMP = imp_implementationWithBlock(^(id self, ...) {
        // 日志触发前
        TJPLogModel *logModel = [TJPLogModel new];
        logModel.clsName = NSStringFromClass(cls);
        logModel.methodName = NSStringFromSelector(originSEL);

        // 参数处理、日志触发
        // ...
        handler(logModel);  // 触发日志

        // 调用原始方法
        [self invokeOriginalIMP:originIMP withInvocation:invocation];

        // 日志触发后
        // ...
    });

    // 替换方法实现
    class_replaceMethod(cls, originSEL, newIMP, method_getTypeEncoding(originMethod));
}

```
## 参数和返回值处理

由于可变参数和不同返回值类型的问题，我们通过 `NSInvocation` 来处理参数，并且使用 `libffi` 动态调用原方法，避免直接使用 `va_list`。

```objc
void *raw = va_arg(args, void *);
id value = (__bridge id)(raw);

```
## 4. 为什么要引用 `libffi` 来解决这些问题？

### 4.1 `libffi` 的优势

- **动态生成函数调用桥（trampoline）**：
    - `libffi` 可以根据方法签名动态生成调用桥，这样我们就不需要手动解析每个参数类型，可以支持更复杂的参数类型（如结构体、对象等），并避免栈溢出问题。

- **自动处理各种参数类型**：
    - `libffi` 可以通过 `ffi_type` 自动处理各种类型的参数（包括 `id`、`SEL`、`CGRect` 等），而不需要我们手动解析和转换。

- **支持任意方法签名**：
    - `libffi` 允许我们在运行时动态生成函数签名，并执行原始方法。这样就不需要知道方法签名，能够真正实现“通用方法 hook”。

- **高效、安全**：
    - 使用 `libffi` 可以绕开递归问题，确保在不改变原有方法逻辑的基础上实现日志记录等功能，避免了递归调用导致的死循环问题。

---

### 4.2 使用 `libffi` 的方案

通过 `libffi`，我们可以在运行时根据目标方法的签名生成函数调用桥，然后调用原始 `IMP`。`ffi_call` 函数可以直接执行目标方法，避免了 `NSInvocation` 的递归调用问题。

**实现步骤**：

1. 使用 `NSMethodSignature` 获取方法签名。
2. 使用 `ffi_prep_cif` 来准备参数类型和方法签名。
3. 使用 `ffi_call` 执行原方法，并处理返回值。

## 5.总结
使用 **libffi**，能够构建一个更为健壮、通用和高效的切面日志系统，同时也解决了原有的 **NSInvocation + va_list** 模式中的问题
