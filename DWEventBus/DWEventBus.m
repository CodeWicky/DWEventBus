//
//  DWEventBus.m
//  DWEventBus
//
//  Created by Wicky on 2018/10/22.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "DWEventBus.h"
#import <objc/runtime.h>

///事件基类
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
    return (!self.eventName.length) ? NO : ((self.subType < 0 && self.subType != -1) ? NO : YES);
}

#pragma mark --- override ---
-(instancetype)init {
    if (self = [super init]) {
        _subType = -1;
    }
    return self;
}

#pragma mark --- setter/getter ---
-(void)setSubType:(NSInteger)subType {
    if (subType >= 0) {
        _subType = subType;
    }
}

@end

@interface DWEventBus ()

@property (nonatomic ,strong) NSMutableDictionary * subscribersMap;

@property (nonatomic ,strong) dispatch_semaphore_t sema;

@property (nonatomic ,copy) NSString * uid;

@end

///实际保存事件的实例
@interface DWEventEntity : NSObject

@property (nonatomic ,copy) void(^eventHandler)(__kindof DWEvent * event,id target);

@property (nonatomic ,strong) dispatch_queue_t queue;

@property (nonatomic ,strong) NSMutableSet * uniteEvents_;

@property (nonatomic ,strong) NSMutableSet * uniteEventKeys;

@property (nonatomic ,strong) NSMutableSet * conditions;

@property (nonatomic ,strong) dispatch_semaphore_t sema;

-(void)receiveEvent:(__kindof DWEvent *)event target:(id)target;

-(void)resetUniteCondition;

@end

@implementation DWEventEntity

#pragma mark --- interface method ---
-(void)receiveEvent:(__kindof DWEvent *)event target:(id)target {
    if (self.eventHandler) {
        ///联合事件等待事件都接收到再处理，单独事件直接处理
        if (self.uniteEventKeys.count) {
            ///每接受到一个事件则从条件中移除一个事件
            dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
            NSString * key = keyForEvent(event);
            [self.conditions removeObject:key];
            if (self.conditions.count == 0) {
                [self doEventHanlerWithEvent:event target:target];
                [self configCondition];
            }
            dispatch_semaphore_signal(self.sema);
        } else {
            [self doEventHanlerWithEvent:event target:target];
        }
    }
}

-(void)resetUniteCondition {
    [self.conditions removeAllObjects];
    [self configCondition];
}

#pragma mark --- tool method ---
-(void)configCondition {
    [self.conditions addObjectsFromArray:self.uniteEventKeys.allObjects];
}

-(void)doEventHanlerWithEvent:(DWEvent *)event target:(id)target {
    if (self.queue) {
        dispatch_async(self.queue, ^{
            self.eventHandler(event,target);
        });
    } else {
        self.eventHandler(event,target);
    }
}

#pragma mark --- tool func ---
NS_INLINE NSString * keyForEvent(__kindof DWEvent * event) {
    return [NSString stringWithFormat:@"%@|%ld",event.eventName,event.subType];
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
    [self.uniteEventKeys removeAllObjects];
    [uniteEvents enumerateObjectsUsingBlock:^(__kindof DWEvent * obj, BOOL * _Nonnull stop) {
        NSString * key = keyForEvent(obj);
        [self.uniteEventKeys addObject:key];
    }];
    [self resetUniteCondition];
}

-(NSMutableSet *)conditions {
    if (!_conditions) {
        _conditions = [NSMutableSet set];
    }
    return _conditions;
}

-(NSMutableSet *)uniteEventKeys {
    if (!_uniteEventKeys) {
        _uniteEventKeys = [NSMutableSet set];
    }
    return _uniteEventKeys;
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

///因为要在集合中在添加或移除，此处代理相等性返回自身的判断
- (BOOL)isEqual:(id)object {
    return [super isEqual:object];
}

///hash也是
- (NSUInteger)hash {
    return [super hash];
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

///对象管理所有事件的中间订阅者
@interface DWEventSubscriber : NSObject

@property (nonatomic ,weak) id target;

@property (nonatomic ,strong) DWEventProxy * proxy;

@property (nonatomic ,strong) NSMutableDictionary * eventsMap;

@property (nonatomic ,weak) DWEventBus * bus;

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
        sub.target = target;
        sub.bus = bus;
        sub.proxy = [DWEventProxy proxyWithTarget:sub];
        objc_setAssociatedObject(target, [bus.uid UTF8String], sub, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return sub;
}

///接收到事件以后分发给对应的entity
-(void)receiveEvent:(__kindof DWEvent *)event {
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    NSDictionary * subType = [self.eventsMap valueForKey:event.eventName];
    NSSet * entitys = [subType valueForKey:@(event.subType).stringValue];
    [entitys enumerateObjectsUsingBlock:^(DWEventEntity * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj receiveEvent:event target:self.target];
    }];
    dispatch_semaphore_signal(self.sema);
}

#pragma mark --- tool method ---

///移除bus中所有包含此sub的项
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

///事件工厂
@interface DWEventMaker ()

@property (nonatomic ,assign) BOOL buildIgnoreTarget;

@property (nonatomic ,strong) id _target;

@property (nonatomic ,copy) NSString * _eventName;

@property (nonatomic ,assign) NSInteger _subType;

@property (nonatomic ,strong) dispatch_queue_t _queue;

@property (nonatomic ,strong) NSMutableSet <__kindof DWEvent *>* _uniteEvents;

@property (nonatomic ,strong) NSMutableSet <__kindof DWEvent *>* events;

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
        __subType = -1;
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
        if (subType >= 0) {
            self._subType = subType;
        }
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
        if ([event valid]) {
            [self._uniteEvents addObject:event];
        }
        return self;
    };
}

-(void (^)(void))Build {
    return ^(void){
        ///如果本次build存在联合事件则将忽略eventName和subType，直接使用联合事件
        if (self._uniteEvents.count > 1) {
            if (!self.buildIgnoreTarget) {
                if (!self._target) {
                    [self reset];
                    return ;
                }
            }
            DWEvent * e = [DWEvent new];
            e.target = self._target;
            e.uniteEvents = self._uniteEvents;
            e.queue = self._queue;
            [self.events addObject:e];
            [self reset];
        } else if (self._uniteEvents.count == 1) {
            ///只有一个联合事件，降级为普通事件
            if (!self.buildIgnoreTarget) {
                if (!self._target) {
                    [self reset];
                    return;
                }
            }
            DWEvent * e = [DWEvent new];
            e.target = self._target;
            e.eventName = [self._uniteEvents anyObject].eventName;
            e.subType = [self._uniteEvents anyObject].subType;
            e.queue = self._queue;
            [self.events addObject:e];
            [self reset];
        } else {
            ///无效事件
            if (!self.buildIgnoreTarget) {
                if (!self._target) {
                    [self reset];
                    return;
                }
            }
            if (!self._eventName.length) {
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

-(NSMutableSet <__kindof DWEvent *>*)_uniteEvents {
    if (!__uniteEvents) {
        __uniteEvents = [NSMutableSet set];
    }
    return __uniteEvents;
}

-(NSMutableSet <__kindof DWEvent *>*)events {
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


@implementation DWEventBus

#pragma mark --- interface method ---

+(instancetype)defaultEventBus {
    static DWEventBus * defaultBus = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultBus = [[DWEventBus alloc] init];
    });
    return defaultBus;
}

-(void)subscribe:(void (^)(DWEventMaker *))makeEvent On:(void (^)(__kindof DWEvent * ,id))handleEvent {
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
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
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

-(void)subscribeEvent:(__kindof DWEvent *)event target:(id)target On:(void (^)(__kindof DWEvent *, id))handleEvent {
    if (!target || ![event valid]) {
        return;
    }
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    DWEventSubscriber * sub = [DWEventSubscriber subscriberWithTaget:target bus:self];
    DWEventEntity * entity = [DWEventEntity new];
    entity.eventHandler = handleEvent;
    entity.queue = event.queue;
    [self registEvent:event onSubscriber:sub entity:entity];
    dispatch_semaphore_signal(self.sema);
}

-(void)publish:(void (^)(DWEventMaker *))makeEvent {
    if (!makeEvent) {
        return;
    }
    DWEventMaker * maker = [DWEventMaker new];
    maker.buildIgnoreTarget = YES;
    makeEvent(maker);
    if (!maker.events.count) {
        return;
    }
    [maker.events enumerateObjectsUsingBlock:^(__kindof DWEvent * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.uniteEvents.count) {
            [obj.uniteEvents enumerateObjectsUsingBlock:^(__kindof DWEvent * subObj, BOOL * _Nonnull stop) {
                [self publishEvent:subObj];
            }];
        } else {
            [self publishEvent:obj];
        }
    }];
}

-(void)publishEvent:(DWEvent *)event {
    ///没有事件类型不做操作
    if (![event valid]) {
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

-(void)remove:(void (^)(DWEventMaker *))makeEvent {
    ///没有生成s事件则不做操作
    if (!makeEvent) {
        return;
    }
    DWEventMaker * maker = [DWEventMaker new];
    makeEvent(maker);
    ///如果没有有效事件不作处理
    if (!maker.events.count) {
        return;
    }
    
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    [maker.events enumerateObjectsUsingBlock:^(__kindof DWEvent * obj, BOOL * _Nonnull stop) {
        ///取出订阅者
        DWEventSubscriber * sub = [DWEventSubscriber subscriberWithTaget:obj.target bus:self];
        if (obj.uniteEvents.count) {
            [obj.uniteEvents enumerateObjectsUsingBlock:^(__kindof DWEvent * subObj, BOOL * _Nonnull stop) {
                ///取消注册每一个事件
                [self deregistEvent:subObj onSubscriber:sub];
            }];
        } else {
            ///取消注册
            [self deregistEvent:obj onSubscriber:sub];
        }
    }];
    dispatch_semaphore_signal(self.sema);
}

-(void)removeEvent:(__kindof DWEvent *)event target:(id)target {
    if (!target || ![event valid]) {
        return;
    }
    dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
    DWEventSubscriber * sub = [DWEventSubscriber subscriberWithTaget:target bus:self];
    [self deregistEvent:event onSubscriber:sub];
    dispatch_semaphore_signal(self.sema);
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

-(void)deregistEvent:(__kindof DWEvent *)event onSubscriber:(DWEventSubscriber *)sub {
    NSMutableDictionary * subTypeD = sub.eventsMap[event.eventName];
    
    ///获取二级所有实例（缺醒subType为-1）
    NSString * subKey = @(event.subType).stringValue;
    NSMutableSet * entitys = subTypeD[subKey];
    
    ///遍历即将移除的所有事件，检测其中的联合事件，若存在，移除联合事件在其他事件中的注册
    [entitys enumerateObjectsUsingBlock:^(DWEventEntity * obj, BOOL * _Nonnull stop) {
        ///存在即为联合事件
        if (obj.uniteEventKeys.count) {
            [obj.uniteEventKeys enumerateObjectsUsingBlock:^(NSString * uniteKey, BOOL * _Nonnull stop) {
                ///拆分为eventName和subType
                NSArray * keys = [uniteKey componentsSeparatedByString:@"|"];
                if (keys.count == 2) {
                    NSString * eventName = keys.firstObject;
                    NSString * subType = keys.lastObject;
                    ///找到联合事件在其他位置的订阅
                    ///是自身则不删除，避免遍历崩溃，之后做统一删除
                    NSMutableSet * tmpSet = sub.eventsMap[eventName][subType];
                    if (![tmpSet isEqual:entitys]) {
                        [tmpSet removeObject:obj];
                    }
                }
            }];
        }
    }];
    
    ///移除subType中的实例
    if (subTypeD) {
        [subTypeD removeObjectForKey:@(event.subType).stringValue];
    }
    ///如果移除后没有弱类型了则移除bus中的sub
    if (!subTypeD.allKeys.count) {
        [self.subscribersMap[event.eventName] removeObject:sub.proxy];
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

#pragma mark --- setter/getter ---
-(NSMutableDictionary *)subscribersMap {
    if (!_subscribersMap) {
        _subscribersMap = [NSMutableDictionary dictionary];
    }
    return _subscribersMap;
}

@end
