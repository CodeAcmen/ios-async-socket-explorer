//
//  TJPAspectCore.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/3/26.
//

#import "TJPAspectCore.h"
#import "TJPLogModel.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <os/lock.h>
//#import <ffi.h>



/*
 结构:
    {
        "ClassName1" : {
                    "method1": IMP_1,
                    "method2": IMP_2,
                },
        "ClassName2" : {
             "method1": IMP_1,
             "method2": IMPV_2,
         }
 
    }
 
 工作流程设计：

 1.获取目标类和方法。

 2.保存原始方法的实现。

 3.创建一个新的方法实现（newIMP），这个方法实现会包含你自定义的逻辑。

 4.替换目标类的原始方法实现为 newIMP。

 5.在 newIMP 中，调用原始方法并在方法执行的前后插入日志记录。

 */
static NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSValue *> *> *_originIMPMap;
static os_unfair_lock aspect_lock = OS_UNFAIR_LOCK_INIT;

@interface TJPAspectCore ()


@end

@implementation TJPAspectCore


+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _originIMPMap = [NSMutableDictionary dictionary];
    });
}

+ (void)registerLogWithConfig:(TJPLogConfig)config trigger:(TJPLogTriggerPoint)trigger handler:(void (^)(TJPLogModel * _Nonnull))handler {
//    NSLog(@"[DEBUG] 注册日志方法开始执行");
//    //获取目标类
//    Class cls = config.targetClass;
//    SEL originSEL = config.targetSelector;
//    if (!cls || !originSEL) return;
//    
//    //避免出现并发问题
//    os_unfair_lock_lock(&aspect_lock);
//    NSString *clsKey = NSStringFromClass(cls);
//    NSString *selKey = NSStringFromSelector(originSEL);
//    NSLog(@"[DEBUG] 原始类 %@ - 原始方法实现 %@", clsKey, selKey);
//    
//    //避免重复交换
//    if ([_originIMPMap[clsKey] objectForKey:selKey]) {
//        NSLog(@"[DEBUG] 已经存在钩子: %@ %@", clsKey, selKey);
//        os_unfair_lock_unlock(&aspect_lock);
//        return;
//    };
//    
//    //获取原始方法
//    Method originMethod = class_getInstanceMethod(cls, originSEL);
//    if (!originMethod) return;
//    
//    //获取原始方法实现
//    IMP originIMP = method_getImplementation(originMethod);
//    const char *typeEncoding = method_getTypeEncoding(originMethod);
//    
//    
//    //动态生成新的方法实现   核心点!
//    IMP newIMP = imp_implementationWithBlock(^(id self, SEL _cmd, ...) {
//        NSLog(@"[DEBUG] ========== Swizzled IMP 被调用: %@ %@ ==========", clsKey, selKey);
//        @autoreleasepool {
//            //构造日志模型
//            TJPLogModel *logModel = [TJPLogModel new];
//            logModel.clsName = clsKey;
//            logModel.methodName = selKey;
//            
//            //方法执行前的切点
//            if (trigger & TJPLogTriggerBeforeMethod) {
//                NSLog(@"[DEBUG]  触发 BEFORE 钩子");
//                handler(logModel);
//            }
//            
//            //动态调用原始IMP
//            void *returnValue = NULL;
//            //获取原始方法签名
//            NSMethodSignature *originSig = [self methodSignatureForSelector:originSEL];
//            NSLog(@"[DEBUG] 方法签名: %@", originSig);
//            NSUInteger numArgs = [originSig numberOfArguments];
//            
//            //使用libffi
//            ffi_cif cif;
//            ffi_type *returnType = [TJPAspectCore _ffiTypeForTypeEncoding:originSig.methodReturnType];
//            ffi_type **argTypes = malloc(numArgs * sizeof(ffi_type *));
//            void **argValues = malloc(numArgs * sizeof(void *));
//            
//            va_list args;
//            va_start(args, _cmd);
//            
//            // 提取参数类型和值
//            NSLog(@"[DEBUG] 调用 ffi_call: 准备参数");
//            for (NSUInteger i = 0; i < numArgs; i++) {
//                const char *type = [originSig getArgumentTypeAtIndex:i];
//                NSLog(@"[DEBUG] 参数 %lu 类型: %s", (unsigned long)i, type);
//
//                argTypes[i] = [TJPAspectCore _ffiTypeForTypeEncoding:type];
//                
//                if (i == 0) { // self
//                    argValues[i] = &self;
//                    NSLog(@"[DEBUG] 参数 self: %@", self);
//                } else if (i == 1) { // _cmd
//                    argValues[i] = (void *)&originSEL;
//                    NSLog(@"[DEBUG] 参数 _cmd: %@", NSStringFromSelector(originSEL));
//                } else { // 其他参数
//                    [TJPAspectCore _extractValue:&argValues[i] fromArgs:args type:type];
//                    NSLog(@"[DEBUG] 参数 %lu 值: %@", (unsigned long)i, argValues[i]);
//                }
//            }
//            va_end(args);
//            
//            // 准备ffi调用
//            ffi_status status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int) numArgs, returnType, argTypes);
//            NSLog(@"[DEBUG] ffi_prep_cif 状态: %d", status);
//
//            if (status != FFI_OK) {
//                NSLog(@"[ERROR] ffi_prep_cif 失败: %d", status);
//                os_unfair_lock_unlock(&aspect_lock);
//                return;
//            }
//            
//            // 分配返回值内存
//            if (originSig.methodReturnLength > 0) {
//                returnValue = malloc(originSig.methodReturnLength);
//            }
//            
//            //使用CACurrentMediaTime为了不受系统时间影响
//            NSTimeInterval start = CACurrentMediaTime();
//            
//            // 执行原始IMP
//            @try {
//                NSLog(@"[DEBUG]  准备调用原始 IMP: %p", originIMP);
//                
//                /*此处不可以使用 [invocation invoke];
//                 因为先替换了原方法实现 newIMP -> originIMP
//                 此时动态生成新的方法实现newIMP方法中, [invocation invoke]会再次调用newIMP,
//                 newIMP <-> newIMP  会无限死循环
//                 */
//                
//                // 调用原始方法实现（使用 originIMP），确保不会递归调用新方法实现
//                
//                NSLog(@"[DEBUG] 准备调用原始 IMP: %p", originIMP);
//                ffi_call(&cif, originIMP, returnValue, argValues);
//                NSLog(@"[DEBUG] 原始 IMP 调用完成, 返回值: %@", returnValue ? [NSValue valueWithPointer:returnValue] : @"无返回值");
//            } @catch (NSException *ex) {
//                NSLog(@"[ERROR]  调用原始方法时发生异常: %@", ex);
//                if (trigger & TJPLogTriggerOnException) {
//                    logModel.exception = ex;
//                    handler(logModel);
//                }
//                @throw;
//            } @finally {
//                // 触发切点：调用后
//                NSLog(@"[DEBUG]  触发 AFTER 钩子 - 耗时: %f", logModel.executeTime);
//                if (trigger & TJPLogTriggerAfterMethod) {
//                    logModel.executeTime = CACurrentMediaTime() - start;
//                    handler(logModel);
//                }
//                
//                // 处理返回值
//                if (returnValue) {
//                    [TJPAspectCore _processReturnValue:returnValue forSignature:originSig];
//                }
//                
//                // 释放内存
//                free(argTypes);
//                free(argValues);
//                if (returnValue) free(returnValue);
//            }
//        }
//    });
//
//    //替换方法实现
//    class_replaceMethod(cls, originSEL, newIMP, typeEncoding);
//
//    // 存储原始IMP
//    NSMutableDictionary *selDict = _originIMPMap[clsKey] ?: [NSMutableDictionary new];
//    [selDict setObject:[NSValue valueWithPointer:originIMP] forKey:selKey];
//    [_originIMPMap setObject:selDict forKey:clsKey];
//    
//    os_unfair_lock_unlock(&aspect_lock);
//    NSLog(@"[DEBUG] 注册日志方法执行结束 ---- ");
}

+ (void)removeLogForClass:(Class)cls {
    if (!cls) return;
    //防止并发问题
    os_unfair_lock_lock(&aspect_lock);
    //获取key
    NSString *clsKey = NSStringFromClass(cls);
    
    //取出对应的内层字典
    NSDictionary *selDict = _originIMPMap[clsKey];
    //遍历取出原方法和方法实现
    [selDict enumerateKeysAndObjectsUsingBlock:^(NSString *selKey, NSValue *impValue, BOOL * _Nonnull stop) {
        SEL originalSEL = NSSelectorFromString(selKey);
        IMP originalIMP = [impValue pointerValue];
        
        Method currentMethod = class_getInstanceMethod(cls, originalSEL);
        if (currentMethod) {
            //恢复
            method_setImplementation(currentMethod, originalIMP);
            NSLog(@"[DEBUG] removeLogForClass success class:%@", cls);
        }
    }];
    
    [_originIMPMap removeObjectForKey:clsKey];
    os_unfair_lock_unlock(&aspect_lock);
}

//#pragma mark - Private Helpers
//// 类型编码 -> ffi_type 映射
//+ (ffi_type *)_ffiTypeForTypeEncoding:(const char *)encoding {
//    switch (encoding[0]) {
//        case 'v': return &ffi_type_void;
//        case 'c': return &ffi_type_schar;
//        case 'i': return &ffi_type_sint;
//        case 's': return &ffi_type_sshort;
//        case 'l': return &ffi_type_slong;
//        case 'q': return &ffi_type_sint64;
//        case 'C': return &ffi_type_uchar;
//        case 'I': return &ffi_type_uint;
//        case 'S': return &ffi_type_ushort;
//        case 'L': return &ffi_type_ulong;
//        case 'Q': return &ffi_type_uint64;
//        case 'f': return &ffi_type_float;
//        case 'd': return &ffi_type_double;
//        case 'B': return &ffi_type_uint8;
//        case '@': return &ffi_type_pointer;
//        case '#': return &ffi_type_pointer;
//        case ':': return &ffi_type_pointer;
//        case '{': return [TJPAspectCore _ffiStructTypeForEncoding:encoding];
//        default:  return &ffi_type_void;
//    }
//}
//
//// 处理结构体（以CGRect为例）
//+ (ffi_type *)_ffiStructTypeForEncoding:(const char *)encoding {
//    if (strcmp(encoding, @encode(CGRect)) == 0) {
//        static ffi_type *rectType = NULL;
//        if (!rectType) {
//            rectType = malloc(sizeof(ffi_type));
//            rectType->type = FFI_TYPE_STRUCT;
//            rectType->elements = malloc(5 * sizeof(ffi_type *));
//            rectType->elements[0] = &ffi_type_float; // x
//            rectType->elements[1] = &ffi_type_float; // y
//            rectType->elements[2] = &ffi_type_float; // width
//            rectType->elements[3] = &ffi_type_float; // height
//            rectType->elements[4] = NULL;
//        }
//        return rectType;
//    }
//    return &ffi_type_void;
//}



// 处理返回值
+ (void)_processReturnValue:(void *)returnValue forSignature:(NSMethodSignature *)sig {
    const char *returnType = sig.methodReturnType;
    if (strcmp(returnType, @encode(id)) == 0) {
        id obj = (__bridge id)(*(void **)returnValue);
        NSLog(@"[RETURN] 对象: %@", obj);
    } else if (strcmp(returnType, @encode(int)) == 0) {
        int val = *(int *)returnValue;
        NSLog(@"[RETURN] 整数: %d", val);
    }
    // 扩展其他类型...
}

+ (void)_extractValue:(void **)valuePtr fromArgs:(va_list)args type:(const char *)type {
    NSLog(@"[DEBUG] va_list 地址: %p", args);
    NSLog(@"[DEBUG] 当前参数类型: %s", type);
    if (strcmp(type, @encode(id)) == 0) {
            // 处理对象类型（id）
            id obj = va_arg(args, id);
            if (obj) {
                NSLog(@"[DEBUG] 提取到对象参数: %@", obj);
            } else {
                NSLog(@"[ERROR] 提取到空对象参数");
            }
            *valuePtr = (__bridge void *)obj;
    }else if (strcmp(type, @encode(SEL)) == 0) {
        // 处理 SEL 类型
        SEL sel = va_arg(args, SEL);
        NSLog(@"[DEBUG] 提取到 SEL 参数: %@", NSStringFromSelector(sel));
        *valuePtr = (void *)sel; // 直接传递 SEL，无需转换字符串
    } else if (strcmp(type, @encode(int)) == 0) {
        // 处理 int 类型
        int val = va_arg(args, int);
        int *storage = malloc(sizeof(int));
        *storage = val;
        *valuePtr = storage;
        NSLog(@"[DEBUG] 提取到 int 参数: %d", val);
    } else if (strcmp(type, @encode(float)) == 0) {
        // 处理 float 类型（注意：va_arg 需用 double 提取）
        double temp = va_arg(args, double);
        float val = (float)temp;
        float *storage = malloc(sizeof(float));
        *storage = val;
        *valuePtr = storage;
        NSLog(@"[DEBUG] 提取到 float 参数: %f", val);
    } else if (strcmp(type, @encode(BOOL)) == 0) {
        // 处理 BOOL 类型（注意：BOOL 实际是 signed char）
        BOOL val = va_arg(args, int); // BOOL 被提升为 int
        BOOL *storage = malloc(sizeof(BOOL));
        *storage = val;
        *valuePtr = storage;
        NSLog(@"[DEBUG] 提取到 BOOL 参数: %d", val);
    } else if (strcmp(type, @encode(CGRect)) == 0) {
        // 处理结构体（如 CGRect）
        CGRect rect = va_arg(args, CGRect);
        CGRect *storage = malloc(sizeof(CGRect));
        *storage = rect;
        *valuePtr = storage;
        NSLog(@"[DEBUG] 提取到 CGRect 参数");
    } else {
        // 其他类型处理（可扩展）
        NSLog(@"[ERROR] 不支持的参数类型: %s", type);
        *valuePtr = NULL;
    }
}



@end
