//
//  DWEventBus.m
//  DWEventBus
//
//  Created by Wicky on 2018/10/22.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "DWEventBus.h"
#import <objc/runtime.h>

@interface DWEvent ()

@property (nonatomic ,strong) id target;

@end

@implementation DWEvent

#pragma mark --- interface method ---
-(void)setEventHandledBy:(id)flag {
    if (self.eventHandledCallback) {
        self.eventHandledCallback(flag);
    }
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _subType = -1;
    }
    return self;
}

@end

@interface DWEventBus ()

@property (nonatomic ,strong) NSMutableDictionary * subscribersMap;

@property (nonatomic ,strong) dispatch_semaphore_t sema;

@property (nonatomic ,copy) NSString * uid;

@end

///实际保存事件的实例
@interface DWEventEntity : NSObject

@property (nonatomic ,copy) void(^eventHandler)(__kindof DWEvent * event);

@property (nonatomic ,strong) dispatch_queue_t queue;

-(void)receiveEvent:(__kindof DWEvent *)event;

@end

@implementation DWEventEntity

#pragma mark --- interface method ---
-(void)receiveEvent:(__kindof DWEvent *)event {
    if (self.eventHandler) {
        if (self.queue) {
            dispatch_async(self.queue, ^{
                self.eventHandler(event);
            });
        } else {
            self.eventHandler(event);
        }
    }
}

@end

///bus管理subscriber的proxy
@interface DWEventProxy : NSProxy

@property (nonatomic ,weak) id target;

+(instancetype)proxyWithTarget:(id)target;

@end

@implementation DWEventProxy

+(instancetype)proxyWithTarget:(id)target {
    DWEventProxy * p = [DWEventProxy alloc];
    p.target = target;
    return p;
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

- (BOOL)isEqual:(id)object {
    return [_target isEqual:object];
}

- (NSUInteger)hash {
    return [_target hash];
}

- (Class)superclass {
    return [_target superclass];
}

- (Class)class {
    return [_target class];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_target isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_target isMemberOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [_target conformsToProtocol:aProtocol];
}

- (BOOL)isProxy {
    return YES;
}

- (NSString *)description {
    return [_target description];
}

- (NSString *)debugDescription {
    return [_target debugDescription];
}

@end

///对象管理所有时间的中间订阅者
@interface DWEventSubscriber : NSObject

@property (nonatomic ,strong) DWEventProxy * proxy;

@property (nonatomic ,strong) NSMutableDictionary * eventsMap;

@property (nonatomic ,strong) DWEventBus * bus;

@property (nonatomic ,strong) dispatch_semaphore_t sema;

+(instancetype)subscriberWithTaget:(id)target bus:(DWEventBus *)bus;

-(void)receiveEvent:(__kindof DWEvent *)event;

@end

@implementation DWEventSubscriber

#pragma mark --- interface method ---
///非线程安全，应由外界保证线程安全
+(instancetype)subscriberWithTaget:(id)target bus:(DWEventBus *)bus {
    DWEventSubscriber * sub = objc_getAssociatedObject(target, [bus.uid UTF8String]);
    if (!sub) {
        sub = [DWEventSubscriber new];
        sub.bus = bus;
        sub.proxy = [DWEventProxy proxyWithTarget:sub];
        objc_setAssociatedObject(target, [bus.uid UTF8String], sub, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return sub;
}

-(void)receiveEvent:(__kindof DWEvent *)event {
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    NSDictionary * subType = [self.eventsMap valueForKey:event.eventName];
    NSSet * entitys = [subType valueForKey:@(event.subType).stringValue];
    [entitys enumerateObjectsUsingBlock:^(DWEventEntity * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj receiveEvent:event];
    }];
    dispatch_semaphore_signal(self.sema);
}

#pragma mark --- tool method ---
-(void)disposeHanlder {
    [self.eventsMap enumerateKeysAndObjectsUsingBlock:^(NSString * key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableSet * subs = [self.bus.subscribersMap valueForKey:key];
        [subs removeObject:self.proxy];
    }];
}

#pragma mark --- override ---

-(void)dealloc {
    [self disposeHanlder];
}

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)eventsMap {
    if (!_eventsMap) {
        _eventsMap = [NSMutableDictionary dictionary];
    }
    return _eventsMap;
}

-(dispatch_semaphore_t)sema {
    if (!_sema) {
        _sema = dispatch_semaphore_create(1);
    }
    return _sema;
}

@end

@interface DWEventMaker ()

@property (nonatomic ,strong) id _target;

@property (nonatomic ,copy) NSString * _eventName;

@property (nonatomic ,assign) NSInteger _subType;

@property (nonatomic ,strong) dispatch_queue_t _queue;

@property (nonatomic ,strong) NSMutableSet * events;

@end

@implementation DWEventMaker

#pragma mark --- tool method ---
-(void)reset {
    self._target = nil;
    self._eventName = nil;
    self._subType = -1;
    self._queue = NULL;
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        self._subType = -1;
    }
    return self;
}

#pragma mark --- setter/getter ---
-(DWEventMaker *(^)(id))Target {
    return ^DWEventMaker *(id target) {
        self._target = target;
        return self;
    };
}

-(DWEventMaker *(^)(NSString *))EventName {
    return ^DWEventMaker *(NSString * eventName) {
        self._eventName = eventName;
        return self;
    };
}

-(DWEventMaker *(^)(NSInteger))SubType {
    return ^DWEventMaker *(NSInteger subType) {
        self._subType = subType;
        return self;
    };
}

-(void (^)(void))Build {
    return ^(void){
        ///无效事件
        if (!self._target || !self._eventName.length) {
            [self reset];
            return ;
        }
        ///不合法的subType（未指定为-1，代表强类型，合法，指定为正数代表强类型+弱类型，合法，指定为非-1的负数不合法）
        if (self._subType != -1 && self._subType < 0) {
            [self reset];
            return;
        }
        DWEvent * e = [DWEvent new];
        e.target = self._target;
        e.eventName = self._eventName;
        e.subType = self._subType;
        e.queue = self._queue;
        [self.events addObject:e];
        [self reset];
    };
}

-(NSMutableSet *)events {
    if (!_events) {
        _events = [NSMutableSet set];
    }
    return _events;
}

@end

@implementation DWEventMaker (AutoBuildWithSelf)

-(void (^)(void))dw_Build {
    NSLog(@"Will never get here");
    return nil;
}

@end

static DWEventBus * defaultBus = nil;
@implementation DWEventBus

#pragma mark --- interface method ---

+(instancetype)defaultEventBus {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultBus = [[DWEventBus alloc] init];
    });
    return defaultBus;
}

-(void)subscribe:(void (^)(DWEventMaker *))makeEvent On:(void (^)(__kindof DWEvent *))handleEvent {
    ///没有事件或者没有回调均不作处理
    if (!makeEvent || !handleEvent) {
        return;
    }
    DWEventMaker * maker = [DWEventMaker new];
    makeEvent(maker);
    ///如果没有有效事件不作处理
    if (!maker.events.count) {
        return;
    }
    
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    [maker.events enumerateObjectsUsingBlock:^(DWEvent * obj, BOOL * _Nonnull stop) {
        ///事件合法，开始注册
        DWEventSubscriber * sub = nil;
        
        ///取出观察者
        sub = [DWEventSubscriber subscriberWithTaget:obj.target bus:self];
        
        /*
         在Bus上注册,结构是
                        /eventName - []
         subscribersMap -eventName - []
                        \eventName - []
         */
        NSMutableSet * eventSet = self.subscribersMap[obj.eventName];
        if (!eventSet) {
            eventSet = [NSMutableSet set];
            [self.subscribersMap setValue:eventSet forKey:obj.eventName];
        }
        [eventSet addObject:sub.proxy];
        
        /*
         在subcriber上注册
                                     /subType - []
                     /eventName - {} -subType - []
                    /                \subType - []
                   /
                  /                  /subType - []
         eventsMap----eventName - {} -subType - []
                  \                  \subType - []
                   \
                    \                /subType - []
                     \eventName - {} -subType - []
                                     \subType - []
         */
        ///取出一级map
        NSMutableDictionary * subTypeMD = [sub.eventsMap valueForKey:obj.eventName];
        if (!subTypeMD) {
            subTypeMD = [NSMutableDictionary dictionary];
            [sub.eventsMap setValue:subTypeMD forKey:obj.eventName];
        }
        ///取出二级set
        NSMutableSet * entitys = [subTypeMD valueForKey:@(obj.subType).stringValue];
        if (!entitys) {
            entitys = [NSMutableSet set];
            [subTypeMD setValue:entitys forKey:@(obj.subType).stringValue];
        }
        ///添加观察者
        DWEventEntity * entity = [DWEventEntity new];
        entity.eventHandler = handleEvent;
        entity.queue = obj.queue;
        [entitys addObject:entity];
    }];
    dispatch_semaphore_signal(self.sema);
}

-(void)dispatch:(DWEvent *)event {
    ///没有事件类型不做操作
    if (!event.eventName.length) {
        return;
    }
    ///副类型不合法，不做操作
    if (event.subType < 0 && event.subType != -1) {
        return;
    }
    ///派发事件
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    NSSet <DWEventSubscriber *>* subs = [self.subscribersMap valueForKey:event.eventName];
    [subs enumerateObjectsUsingBlock:^(DWEventSubscriber * _Nonnull obj, BOOL * _Nonnull stop) {
        if (event.queue) {
            dispatch_async(event.queue, ^{
                [obj receiveEvent:event];
            });
        } else {
            [obj receiveEvent:event];
        }
    }];
    dispatch_semaphore_signal(self.sema);
}

-(void)removeSubscriber:(void (^)(DWEventMaker *))makeEvent {
    ///没有生成s事件则不做操作
    if (!makeEvent) {
        return;
    }
    DWEventMaker * maker = [DWEventMaker new];
    makeEvent(maker);
    ///事件没有target或eventName则不作处理
    if (!maker._target || !maker._eventName.length) {
        return;
    }
    
    ///取出订阅者
    DWEventSubscriber * sub = nil;
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    sub = [DWEventSubscriber subscriberWithTaget:maker._target bus:self];
    if (!sub) {
        dispatch_semaphore_signal(self.sema);
        return;
    }
    ///如果是-1则代表未指定subType，则移除全部
    if (maker._subType == -1) {
        ///subcriber中移除所有实例
        [sub.eventsMap removeObjectForKey:maker._eventName];
        ///bus中移除对应sub
        [self.subscribersMap[maker._eventName] removeObject:sub.proxy.target];
        dispatch_semaphore_signal(self.sema);
        return;
    } else if (maker._subType >= 0) {
        NSMutableDictionary * subType = sub.eventsMap[maker._eventName];
        ///移除subTyper中的实例
        if (subType) {
            [subType removeObjectForKey:@(maker._subType).stringValue];
        }
        ///如果移除后没有弱类型了则移除bus中的sub
        if (!subType.allKeys.count) {
            [self.subscribersMap[maker._eventName] removeObject:sub.proxy];
        }
        dispatch_semaphore_signal(self.sema);
        return;
    } else {
        dispatch_semaphore_signal(self.sema);
    }
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _sema = dispatch_semaphore_create(1);
        _uid = [NSString stringWithFormat:@"%p",self];
    }
    return self;
}

#pragma mark --- singleton ---
+(instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultBus = [super allocWithZone:zone];
    });
    return defaultBus;
}

-(id)copyWithZone:(struct _NSZone *)zone {
    return self;
}

-(id)mutableCopyWithZone:(struct _NSZone *)zone {
    return self;
}

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)subscribersMap {
    if (!_subscribersMap) {
        _subscribersMap = [NSMutableDictionary dictionary];
    }
    return _subscribersMap;
}

@end
