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
    NSLog(@"[DEBUG] registerLogWithConfig - Start");
    //获取目标类
    Class cls = config.targetClass;
    SEL originSEL = config.targetSelector;
    NSLog(@"[DEBUG] targetClass: %@, targetSelector: %@", cls, NSStringFromSelector(originSEL));
    if (!cls || !originSEL) return;
    
    //获取原始方法
    Method originMethod = class_getInstanceMethod(cls, originSEL);
    if (!originMethod) return;
    
    //避免出现并发问题
    os_unfair_lock_lock(&aspect_lock);
    NSString *clsKey = NSStringFromClass(cls);
    NSString *selKey = NSStringFromSelector(originSEL);
    
    //避免重复交换
    if ([_originIMPMap[clsKey] objectForKey:selKey]) {
        NSLog(@"[DEBUG] Already hooked: %@ %@", clsKey, selKey);
        os_unfair_lock_unlock(&aspect_lock);
        return;
    };
    
    //获取原始方法实现并保存
    IMP originIMP = method_getImplementation(originMethod);
    NSValue *impValue = [NSValue valueWithPointer:originIMP];
    
    NSLog(@"[DEBUG] Original IMP captured for %@ %@", clsKey, selKey);
    
    //动态生成新的方法实现   核心点!
    IMP newIMP = imp_implementationWithBlock(^(id self, ...) {
        NSLog(@"[DEBUG] Swizzled IMP called for %@ %@", clsKey, selKey);
        //构造日志模型
        TJPLogModel *logModel = [TJPLogModel new];
        logModel.clsName = clsKey;
        logModel.methodName = selKey;
        
        //方法执行前的切点
        if (trigger & TJPLogTriggerBeforeMethod) {
            NSLog(@"[DEBUG] Triggering BEFORE hook");
            handler(logModel);
        }
        
        //获取原始方法签名
        NSMethodSignature *originSig = [self methodSignatureForSelector:originSEL];
        
        /*
         NSInvocation的作用:  触发这次封装好的方法调用  如[person eat]
         */
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:originSig];
        [invocation setTarget:self];
        [invocation setSelector:originSEL];
        
        
        //处理可变参数  参考Aspect实现
        va_list args;
        va_start(args, self);
        [TJPAspectCore aspect_setInvocation:invocation withArgs:args];
        va_end(args);
        
        //使用CACurrentMediaTime为了不受系统时间影响
        NSTimeInterval start = CACurrentMediaTime();
        //存储返回值
        void *returnValue = NULL;
        
        //调用原始方法
        @try {
            /*此处不可以使用 [invocation invoke];
             因为先替换了原方法实现 newIMP -> originIMP
             此时动态生成新的方法实现newIMP方法中, [invocation invoke]会再次调用newIMP,
             newIMP <-> newIMP  会无限死循环
             */
            
            // 调用原始方法实现（使用 originIMP），确保不会递归调用新 IMP
            ((void(*)(id, SEL))originIMP)(self, originSEL);
            
            // 获取返回值（兼容不同类型）
            if (originSig.methodReturnLength) {
                void *buffer = malloc(originSig.methodReturnLength);
                [invocation getReturnValue:buffer];
                returnValue = buffer;
            }
            
        } @catch (NSException *exception) {
            NSLog(@"[ERROR] Exception during method execution: %@", exception);
            //方法异常切点
            logModel.exception = exception;
            if (trigger & TJPLogTriggerOnException) {
                handler(logModel);
            }
            @throw;
        } @finally {
            // 触发点：调用后
            if (trigger & TJPLogTriggerAfterMethod) {
                NSLog(@"[DEBUG] Triggering AFTER hook - Execution Time: %f", logModel.executeTime);
                logModel.executeTime = CACurrentMediaTime() - start;
                handler(logModel);
            }
        }
        //处理返回结果  只有当有返回值的时候才返回
        if (originSig.methodReturnLength) {
            return *(__unsafe_unretained id *)returnValue;
        }
        // 如果返回类型是 void，不返回任何值
    });
    
    NSLog(@"[DEBUG] Replacing method implementation for %@ %@", clsKey, selKey);
    //方法替换
    class_replaceMethod(cls, originSEL, newIMP, method_getTypeEncoding(originMethod));
    
    // 存储原始IMP
    NSMutableDictionary *selDict = _originIMPMap[clsKey] ?: [NSMutableDictionary new];
    [selDict setObject:impValue forKey:selKey];
    [_originIMPMap setObject:selDict forKey:clsKey];
    
    os_unfair_lock_unlock(&aspect_lock);
    NSLog(@"[DEBUG] registerLogWithConfig - End");
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
        }
    }];
    
    [_originIMPMap removeObjectForKey:clsKey];
    os_unfair_lock_unlock(&aspect_lock);
}

+ (void)aspect_setInvocation:(NSInvocation *)invocation withArgs:(va_list)args {
    NSUInteger numberOfArgs = invocation.methodSignature.numberOfArguments;
    
    // Skip self and _cmd
    for (NSUInteger i = 2; i < numberOfArgs; i++) {
        const char *argType = [invocation.methodSignature getArgumentTypeAtIndex:i];
        
        // Handle basic types
        if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
            id value = va_arg(args, id);
            [invocation setArgument:&value atIndex:i];
        }
        else if (strcmp(argType, @encode(int)) == 0) {
            int val = va_arg(args, int);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(unsigned int)) == 0) {
            unsigned int val = va_arg(args, unsigned int);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(short)) == 0) {
            int val = va_arg(args, int);  // 'short' is promoted to 'int'
            short shortVal = (short)val;
            [invocation setArgument:&shortVal atIndex:i];
        }
        else if (strcmp(argType, @encode(unsigned short)) == 0) {
            int val = va_arg(args, int);  // 'unsigned short' is promoted to 'int'
            unsigned short uShortVal = (unsigned short)val;
            [invocation setArgument:&uShortVal atIndex:i];
        }
        else if (strcmp(argType, @encode(long)) == 0) {
            long val = va_arg(args, long);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(unsigned long)) == 0) {
            unsigned long val = va_arg(args, unsigned long);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(long long)) == 0) {
            long long val = va_arg(args, long long);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(unsigned long long)) == 0) {
            unsigned long long val = va_arg(args, unsigned long long);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(float)) == 0) {
            float val = va_arg(args, double);  // 'float' is promoted to 'double'
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(double)) == 0) {
            double val = va_arg(args, double);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(char)) == 0) {
            int val = va_arg(args, int);  // 'char' is promoted to 'int'
            char charVal = (char)val;
            [invocation setArgument:&charVal atIndex:i];
        }
        else if (strcmp(argType, @encode(unsigned char)) == 0) {
            unsigned int val = va_arg(args, unsigned int);  // 'unsigned char' is promoted to 'unsigned int'
            unsigned char uCharVal = (unsigned char)val;
            [invocation setArgument:&uCharVal atIndex:i];
        }
        else if (strcmp(argType, @encode(BOOL)) == 0) {
            int val = va_arg(args, int);  // 'BOOL' is promoted to 'int'
            BOOL boolVal = (BOOL)val;
            [invocation setArgument:&boolVal atIndex:i];
        }
        else if (strcmp(argType, @encode(SEL)) == 0) {
            SEL val = va_arg(args, SEL);
            [invocation setArgument:&val atIndex:i];
        }
        else if (strcmp(argType, @encode(void *)) == 0) {
            void *ptr = va_arg(args, void *);
            [invocation setArgument:&ptr atIndex:i];
        }
        else {
            // Handle struct types (need extension)
            NSCAssert(NO, @"Unsupported argument type: %s", argType);
        }
    }
}


@end


