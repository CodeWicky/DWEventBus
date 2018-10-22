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

@property (nonatomic ,strong) NSMutableSet * uniteEvents;

@end

@implementation DWEvent

#pragma mark --- interface method ---
-(void)setEventHandledBy:(id)flag {
    if (self.eventHandledCallback) {
        self.eventHandledCallback(flag);
    }
}

-(BOOL)valid {
    return !self.target ? NO : [self validIgnoreTarget];
}

-(BOOL)validIgnoreTarget {
    return (!self.eventName.length) ? NO : ((self.subType < 0 && self.subType != -1) ? NO : YES);
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

@property (nonatomic ,strong) NSMutableSet * uniteEvents;

@property (nonatomic ,strong) NSMutableDictionary * conditions;

@property (nonatomic ,strong) dispatch_semaphore_t sema;

-(void)receiveEvent:(__kindof DWEvent *)event;

@end

@implementation DWEventEntity

#pragma mark --- interface method ---
-(void)receiveEvent:(__kindof DWEvent *)event {
    ///联合事件等待事件都接收到再处理，单独事件直接处理
    if (self.eventHandler) {
        if (self.uniteEvents.count) {
            dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
            NSString * key = keyForEvent(event);
            [self.conditions removeObjectForKey:key];
            if (self.conditions.allKeys.count == 0) {
                [self doEventHanlerWithEvent:event];
                [self configCondition];
            }
            dispatch_semaphore_signal(self.sema);
        } else {
            [self doEventHanlerWithEvent:event];
        }
    }
}

#pragma mark --- tool method ---
-(void)configCondition {
    [self.uniteEvents enumerateObjectsUsingBlock:^(DWEvent * obj, BOOL * _Nonnull stop) {
        @autoreleasepool {
            NSString * key = keyForEvent(obj);
            [self.conditions setValue:obj forKey:key];
        }
    }];
}

-(void)doEventHanlerWithEvent:(DWEvent *)event {
    if (self.queue) {
        dispatch_async(self.queue, ^{
            self.eventHandler(event);
        });
    } else {
        self.eventHandler(event);
    }
}

#pragma mark --- tool func ---
NS_INLINE NSString * keyForEvent(__kindof DWEvent * event) {
    return [NSString stringWithFormat:@"%@-%ld",event.eventName,event.subType];
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _sema = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark --- setter/getter ---
-(void)setUniteEvents:(NSMutableSet *)uniteEvents {
    _uniteEvents = uniteEvents;
    [self configCondition];
}

-(NSMutableDictionary *)conditions {
    if (!_conditions) {
        _conditions = [NSMutableDictionary dictionary];
    }
    return _conditions;
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

@property (nonatomic ,strong) NSMutableSet * _uniteEvents;

@property (nonatomic ,strong) NSMutableSet * events;

@end

@implementation DWEventMaker

#pragma mark --- tool method ---
-(void)reset {
    self._target = nil;
    self._eventName = nil;
    self._subType = -1;
    self._queue = NULL;
    self._uniteEvents = nil;
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

-(DWEventMaker *(^)(dispatch_queue_t))Queue {
    return ^DWEventMaker *(dispatch_queue_t queue) {
        self._queue = queue;
        return self;
    };
}

-(DWEventMaker *(^)(__kindof DWEvent *))UniteEvent {
    return ^DWEventMaker *(__kindof DWEvent * event) {
        if ([event validIgnoreTarget]) {
            [self._uniteEvents addObject:event];
        }
        return self;
    };
}

-(void (^)(void))Build {
    return ^(void){
        ///如果本次build存在组合事件则将忽略eventName和subType，直接使用组合事件
        if (self._uniteEvents.count) {
            if (!self._target) {
                [self reset];
                return ;
            }
            DWEvent * e = [DWEvent new];
            e.target = self._target;
            e.uniteEvents = self._uniteEvents;
            e.queue = self._queue;
            [self.events addObject:e];
            [self reset];
        } else {
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
        }
    };
}

-(NSMutableSet *)_uniteEvents {
    if (!__uniteEvents) {
        __uniteEvents = [NSMutableSet set];
    }
    return __uniteEvents;
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
    ///事件合法，开始注册
    /*
     在Bus上注册,结构是
                    /eventName - []
     subscribersMap -eventName - []
                    \eventName - []
     */
    /*
     在subcriber上注册
                                  /subType - []
                  /eventName - {} -subType - []
                 /                \subType - []
                /
               /                  /subType - []
     eventsMap ----eventName - {} -subType - []
               \                  \subType - []
                \
                 \                /subType - []
                  \eventName - {} -subType - []
                                  \subType - []
     */
    [maker.events enumerateObjectsUsingBlock:^(DWEvent * obj, BOOL * _Nonnull stop) {

        ///取出观察者
        DWEventSubscriber * sub = [DWEventSubscriber subscriberWithTaget:obj.target bus:self];
        ///创建实例
        DWEventEntity * entity = [DWEventEntity new];
        entity.eventHandler = handleEvent;
        entity.queue = obj.queue;
        ///联合事件
        if (obj.uniteEvents.count) {
            ///注册每一个事件
            entity.uniteEvents = obj.uniteEvents;
            [obj.uniteEvents enumerateObjectsUsingBlock:^(DWEvent * subObj, BOOL * _Nonnull stop) {
                ///将实例分别注册到每一个事件中
                [self registEvent:subObj onSubscriber:sub entity:entity];
            }];
            
        } else {
            ///注册
            [self registEvent:obj onSubscriber:sub entity:entity];
        }
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

#pragma mark --- tool method ---
-(void)registEvent:(__kindof DWEvent *)event onSubscriber:(DWEventSubscriber *)sub entity:(DWEventEntity *)entity {
    ///在bus上注册
    NSMutableSet * eventSet = self.subscribersMap[event.eventName];
    if (!eventSet) {
        eventSet = [NSMutableSet set];
        [self.subscribersMap setValue:eventSet forKey:event.eventName];
    }
    [eventSet addObject:sub.proxy];
    ///在subscriber上注册
    ///取出一级map
    NSMutableDictionary * subTypeMD = [sub.eventsMap valueForKey:event.eventName];
    if (!subTypeMD) {
        subTypeMD = [NSMutableDictionary dictionary];
        [sub.eventsMap setValue:subTypeMD forKey:event.eventName];
    }
    ///取出二级set
    NSMutableSet * entitys = [subTypeMD valueForKey:@(event.subType).stringValue];
    if (!entitys) {
        entitys = [NSMutableSet set];
        [subTypeMD setValue:entitys forKey:@(event.subType).stringValue];
    }
    
    ///添加观察者
    [entitys addObject:entity];
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
