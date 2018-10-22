//
//  DWEventBus.h
//  DWEventBus
//
//  Created by Wicky on 2018/10/22.
//  Copyright © 2018年 Wicky. All rights reserved.
//

/**
 DWEventBus
 
 支持强弱类型、指定队列、组合事件的事件总线。
 
 DWEventBus提供强弱类型支持，可以指定事件发送的队列和接收事件后回调的队列。
 同时当接收到事件后，你也可以通知发送方接收方已处理完毕。
 你也可以指定多个事件联合作为一个回调触发的条件，也可指定订阅多个不同的事件而触发同一个回调。
 此外，当订阅者销毁时，可以自动移除订阅关系。
 
 version 1.0.0
 提供强弱类型支持、提供队列支持、提供联合事件和批量事件支持、提供销毁时自动移除订阅支持
 */

#import <Foundation/Foundation.h>
@interface DWEvent : NSObject

///事件名称
@property (nonatomic ,copy) NSString * eventName;

///副类型，默认值为-1，则为未指定副类型（一般应为枚举，除非指定为-1，其他情况请保证不小于0）
@property (nonatomic ,assign) NSInteger subType;

///发送事件指定的队列，若不指定，则以 -dispath: 调用线程作为发送线程
@property (nonatomic ,strong) dispatch_queue_t queue;

///事件携带的参数
@property (nonatomic ,strong) id userInfo;

///事件被处理的回调，-(void)setEventHandledBy:调用一次则回调被调用一次。
///可用于信号接收端调用方法后，通知到发送端事件已处理完成
@property (nonatomic ,copy) void(^eventHandledCallback)(id flag);

///设置event被处理了。通常在事件订阅回调中调用，以告诉发送者自身事件已经处理完毕，可以不调用。
-(void)setEventHandledBy:(id)flag;

///校验当前event是否是合法的事件
-(BOOL)valid;

@end

///快捷宏，直接以当前self作为target进行build
#define dw_Build() Target(self).Build()

///链式配置event的工厂
@interface DWEventMaker : NSObject

///指定订阅者，指定后当订阅者释放后会自动移除该订阅者的所有订阅，多次调用以最后一次为准，必须参数
@property (nonatomic ,strong ,readonly) DWEventMaker * (^Target)(id target);

///指定订阅的事件名称，多次调用以最后一次为准，必须参数
@property (nonatomic ,strong ,readonly) DWEventMaker *(^EventName)(NSString * eventName);

///指定订阅的副类型，多次调用以最后一次为准，非必须参数
@property (nonatomic ,strong ,readonly) DWEventMaker *(^SubType)(NSInteger subType);

///指定收到订阅事件后回调的队列，若不指定则在发送队列上回调，多次调用以最后一次为准，非必须参数
@property (nonatomic ,strong ,readonly) DWEventMaker *(^Queue)(dispatch_queue_t queue);

///联合事件，在一次build中若包含联合事件将忽略本条语句的EventName和SubType。一次build中联合事件可多次调用，则所有事件均将作为条件。当且仅当所有事件至少发送一次后才会视为满足条件进而触发回调，并在回调后重置条件，等待下一次满足条件
@property (nonatomic ,strong ,readonly) DWEventMaker *(^UniteEvent)(__kindof DWEvent * event);

///将本条语句封装成一个事件进行订阅。应在每条语句的最后一句调用，不可多次调用，必须参数
@property (nonatomic ,strong ,readonly) void(^Build)(void);

@end

@interface DWEventMaker (AutoBuildWithSelf)

///为扩展提示命名的空方法，实际上会优先采用宏进行替换
-(void(^)(void))dw_Build;

@end

///事件总线
@interface DWEventBus : NSObject

///默认总线单例
+(instancetype)defaultEventBus;

///订阅一个事件
-(void)subscribe:(void(^)(DWEventMaker * maker))makeEvent On:(void(^)(__kindof DWEvent * event))handleEvent;

///发送一个事件
-(void)dispatch:(DWEvent *)event;

///移除一个事件订阅
-(void)removeSubscriber:(void(^)(DWEventMaker * maker))makeEvent;

@end


