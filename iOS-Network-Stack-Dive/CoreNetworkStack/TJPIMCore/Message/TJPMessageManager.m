//
//  TJPMessageManager.m
//  iOS-Network-Stack-Dive
//
//  Created by 唐佳鹏 on 2025/6/23.
//

#import "TJPMessageManager.h"
#import "TJPMessageStateMachine.h"
#import "TJPMessageContext.h"
#import "TJPNetworkDefine.h"
#import "TJPErrorUtil.h"

static const NSTimeInterval kDefaultRetryInterval = 10;


@interface TJPMessageManager ()

// 会话ID
@property (nonatomic, copy, readwrite) NSString *sessionId;

@property (nonatomic, strong, readwrite) dispatch_queue_t messageQueue;

// 消息存储：messageId -> TJPMessageContext
@property (nonatomic, strong) NSMutableDictionary<NSString *, TJPMessageContext *> *messages;

// 状态机映射：messageId -> TJPMessageStateMachine
@property (nonatomic, strong) NSMutableDictionary<NSString *, TJPMessageStateMachine *> *stateMachines;

// 序列号映射：sequence -> messageId
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSString *> *sequenceToMessageId;


@end
@implementation TJPMessageManager

#pragma mark - Life Cycle
- (instancetype)initWithSessionId:(NSString *)sessionId {
    if (self = [super init]) {
        _sessionId = [sessionId copy];
        
        _messages = [NSMutableDictionary dictionary];
        _sequenceToMessageId = [NSMutableDictionary dictionary];
        _stateMachines = [NSMutableDictionary dictionary];
        
        // 创建专用队列
        NSString *queueName = [NSString stringWithFormat:@"com.tjp.messageManager.%@", sessionId];
        _messageQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        
        TJPLOG_INFO(@"[TJPMessageManager] 初始化完成，会话ID: %@", sessionId);
    }

    return self;
}

- (void)dealloc {
    TJPLOG_INFO(@"[TJPMessageManager] 开始释放，会话ID: %@", self.sessionId);
    
    TJPLOG_INFO(@"[TJPMessageManager] 释放完成");
}

#pragma mark - Public Method
- (NSString *)sendMessage:(NSData *)data messageType:(TJPMessageType)messageType completion:(void (^)(NSString *messageId, NSError *error))completion {
    return [self sendMessage:data messageType:messageType encryptType:TJPEncryptTypeCRC32 compressType:TJPCompressTypeNone completion:completion];
}

- (NSString *)sendMessage:(NSData *)data messageType:(TJPMessageType)messageType encryptType:(TJPEncryptType)encryptType compressType:(TJPCompressType)compressType completion:(void (^)(NSString *messageId, NSError *error))completion {
    __block NSString *messageId = nil;
    __block NSError *validationError = nil;
    
    dispatch_sync(self.messageQueue, ^{
        // 参数校验 原Session逻辑
        if (!data) {
            TJPLOG_ERROR(@"[TJPMessageManager] 发送数据为空");
            validationError = [TJPErrorUtil errorWithCode:TJPErrorMessageIsEmpty description:@"消息数据为空" userInfo:@{}];
            return;
        }
        
        if (data.length > TJPMAX_BODY_SIZE) {
            TJPLOG_ERROR(@"[TJPMessageManager] 数据大小超过限制: %lu > %d", (unsigned long)data.length, TJPMAX_BODY_SIZE);
            validationError = [TJPErrorUtil errorWithCode:TJPErrorMessageTooLarge description:@"消息体长度超过限制" userInfo:@{@"length": @(data.length), @"maxSize": @(TJPMAX_BODY_SIZE)}];
            return;
        }
        
        // 创建消息上下文 序列号稍后由会话分配
        TJPMessageContext *context = [TJPMessageContext contextWithData:data seq:0 messageType:messageType encryptType:TJPEncryptTypeCRC32 compressType:TJPCompressTypeNone sessionId:self.sessionId];
        messageId = context.messageId;
        
        // 消息状态机管理消息状态
        TJPMessageStateMachine *stateMachine = [[TJPMessageStateMachine alloc] initWithMessageId:messageId];
        
        // 设置状态变化回调
        __weak typeof(self) weakSelf = self;
        stateMachine.stateChangeCallback = ^(TJPMessageContext * _Nonnull context, TJPMessageState oldState, TJPMessageState newState) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (strongSelf && strongSelf.delegate) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 状态转换回调
                    [strongSelf.delegate messageManager:strongSelf message:context didChangeState:newState fromState:oldState];
                });
                
                // 统一处理状态转换时的逻辑
                [strongSelf handleStateTransitionEffects:context newState:newState oldState:oldState];
            }
        };
        
        // 存储消息和状态机
        [self storeMessage:context withStateMachine:stateMachine];
        
        // 状态转换:创建 -> 发送
        [stateMachine transitionToState:TJPMessageStateSending context:context];
        
        // 实际的发送逻辑
        [self performActualSendForMessage:context];
    });
    
    if (validationError) {
        if (completion) {
            completion(@"", validationError);
        }
        return @"";
    }
    
    // 成功回调
    if (completion) {
        completion(messageId, validationError);
    }
    return messageId;
}

- (TJPMessageContext *)messageWithId:(NSString *)messageId {
    __block TJPMessageContext *message = nil;
    dispatch_sync(self.messageQueue, ^{
        message = self.messages[messageId];
    });
    return message;
}

- (void)updateMessage:(NSString *)messageId toState:(TJPMessageState)newState {
    dispatch_async(self.messageQueue, ^{
        TJPMessageContext *message = self.messages[messageId];
        TJPMessageStateMachine *stateMachine = self.stateMachines[messageId];
        
        if (message && stateMachine) {
            [stateMachine transitionToState:newState context:message];
        }
    });
}


- (NSArray<TJPMessageContext *> *)allMessages {
    __block NSArray<TJPMessageContext *> *result = nil;
    dispatch_sync(self.messageQueue, ^{
        result = [self.messages.allValues copy];
    });
    return result;
}



#pragma mark - Private Methods
- (void)handleStateTransitionEffects:(TJPMessageContext *)message newState:(TJPMessageState)newState oldState:(TJPMessageState)oldState {
    // 专注于状态管理相关的作用，不处理重传逻辑
    dispatch_async(self.messageQueue, ^{
        switch (newState) {
            case TJPMessageStateSending:
                // 触发willSend回调
                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:willSendMessage:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate messageManager:self willSendMessage:message];
                    });
                }
                break;
                
            case TJPMessageStateSent:
                // 触发didSend回调
                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:didSendMessage:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate messageManager:self didSendMessage:message];
                    });
                }
                break;
                
            case TJPMessageStateRetrying:
                // 重试中状态
                TJPLOG_INFO(@"[TJPMessageManager] 消息 %@ 进入重试状态，第 %ld 次重试", message.messageId, (long)message.retryCount);
                
                // 可以添加重试回调（如果需要）
//                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:willRetryMessage:attemptCount:)]) {
//                    // [self.delegate messageManager:self willRetryMessage:message attemptCount:message.retryCount];
//                }
                break;
                
            case TJPMessageStateFailed:
                // 触发失败回调
                TJPLOG_ERROR(@"[TJPMessageManager] 消息 %@ 发送失败: %@", message.messageId, message.lastError.localizedDescription);
                

                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:didFailToSendMessage:error:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate messageManager:self didFailToSendMessage:message error:message.lastError];
                    });
                }
                break;
            case TJPMessageStateDelivered:
                // 已送达状态（如果支持送达回执）
                TJPLOG_INFO(@"[TJPMessageManager] 消息 %@ 已送达", message.messageId);
                
//                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:messageDidDeliver:)]) {
//                    [self.delegate messageManager:self messageDidDeliver:message];
//                }
                break;
            case TJPMessageStateCancelled:
                // 已取消状态
                TJPLOG_INFO(@"[TJPMessageManager] 消息 %@ 已取消", message.messageId);
                
//                if (self.delegate && [self.delegate respondsToSelector:@selector(messageManager:messageDidCancel:)]) {
//                    [self.delegate messageManager:self messageDidCancel:message];
//                }
                break;
                
            default:
                break;
        }
    });
}
- (void)storeMessage:(TJPMessageContext *)message withStateMachine:(TJPMessageStateMachine *)stateMachine {
    // 存储消息
    self.messages[message.messageId] = message;
    
    // 存储状态机
    self.stateMachines[message.messageId] = stateMachine;
    
    // 序列号映射
    if (message.sequence > 0) {
        self.sequenceToMessageId[@(message.sequence)] = message.messageId;
    }
}

- (void)performActualSendForMessage:(TJPMessageContext *)message {
    if (self.networkDelegate && [self.networkDelegate respondsToSelector:@selector(messageManager:needsSendMessage:)]) {
        [self.networkDelegate messageManager:self needsSendMessage:message];
    }
}




@end
