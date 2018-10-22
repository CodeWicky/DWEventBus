//
//  DWEventBus.h
//  DWEventBus
//
//  Created by Wicky on 2018/10/22.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface DWEvent : NSObject

///事件名称
@property (nonatomic ,copy) NSString * eventName;

///副类型，默认值为-1，则为未指定副类型（一般应为枚举，除非指定为-1，其他情况请保证不小于0）
@property (nonatomic ,assign) NSInteger subType;

@property (nonatomic ,strong) dispatch_queue_t queue;

@property (nonatomic ,strong) id userInfo;

///事件被处理的回调，-(void)setEventHandledBy:调用一次则回调被调用一次。
///可用于信号接收端调用方法后，通知到发送端事件已处理完成
@property (nonatomic ,copy) void(^eventHandledCallback)(id flag);

-(void)setEventHandledBy:(id)flag;

-(BOOL)valid;

@end

#define dw_Build() Target(self).Build()
///链式配置event的工厂
@interface DWEventMaker : NSObject

@property (nonatomic ,strong ,readonly) DWEventMaker * (^Target)(id target);

@property (nonatomic ,strong ,readonly) DWEventMaker *(^EventName)(NSString * eventName);

@property (nonatomic ,strong ,readonly) DWEventMaker *(^SubType)(NSInteger subType);

@property (nonatomic ,strong ,readonly) DWEventMaker *(^Queue)(dispatch_queue_t queue);

@property (nonatomic ,strong ,readonly) DWEventMaker *(^UniteEvent)(__kindof DWEvent * event);

@property (nonatomic ,strong ,readonly) void(^Build)(void);

@end

@interface DWEventMaker (AutoBuildWithSelf)

-(void(^)(void))dw_Build;

@end

///事件总线
@interface DWEventBus : NSObject

+(instancetype)defaultEventBus;

-(void)subscribe:(void(^)(DWEventMaker * maker))makeEvent On:(void(^)(__kindof DWEvent * event))handleEvent;

-(void)dispatch:(DWEvent *)event;

-(void)removeSubscriber:(void(^)(DWEventMaker * maker))makeEvent;

@end


