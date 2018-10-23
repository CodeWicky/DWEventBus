# DWEventBus

## 描述
这是一个灵活的事件总线。

事件总线是对发布-订阅模式的一种实现。它是一种集中式事件处理机制，允许不同的组件之间进行彼此通信而又不需要相互依赖，达到一种解耦的目的。

借助DWEventBus，你可以轻松的实现这种模式。他是线程安全，随意指定消息发布或者订阅回调的执行队列、订阅方执行完毕的反馈、对联合事件的支持、强弱类型的支持以及链式语法都让你使用起来可以更加轻松愉快。


## Description
It's a flexible event bus.

The event bus is an implementation of the publish-subscribe pattern. It is a centralized event handling mechanism that allows different components to communicate with each other without needing to depend on each other for the purpose of decoupling.

Using DWEventBus,you can easily implement this pattern. It's thread safe ,and optionally specifying the execution queue for Posting messages or subscribing to callbacks, feedback after the subscriber's execution, support for united events, strong and weak types, and chain syntax, all these make it easier and more pleasant to use.

## 功能
- 发布-订阅模式
- 联合事件
- 指定发布和订阅回调所在队列
- 订阅方执行完毕的反馈

## Func
- Publish-subscribe pattern.
- United events
- Specifying the execution queue for Posting messages or subscribing to callbacks
- Feedback after the subscriber's execution

## 如何使用
首先，你应该将所需文件拖入工程中，或者你也可以用Cocoapods去集成他。

```
pod 'DWEventBus', '~> 1.0.0'
```

建立一个最简单的订阅关系：

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
    maker.EventName(@"Login").dw_Build();
} On:^(__kindof DWEvent *event, id subscribeTarget) {
   NSLog(@"收到事件了");
}];
 
[[DWEventBus defaultEventBus] publish:^(DWEventMaker *maker) {
   maker.EventName(@"Login").dw_Build();
}];
```

当然，你也可以指定消息发送的队列：

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
		maker.EventName(@"Login").Queue(dispatch_get_global_queue(0, 0)).dw_Build();
} On:^(__kindof DWEvent *event ,id target) {
        NSLog(@"Receive Login Event On Thread:%@",[NSThread currentThread]);
}];
```

如果需求是只有收到两个事件后才触发一个回调，你可以考虑使用联合事件：

```
DWEvent * e1 = [DWEvent new];
e1.eventName = @"Regist";
    
DWEvent * e2 = [DWEvent new];
e2.eventName = @"Login";
    
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
    maker.UniteEvent(e1).UniteEvent(e2).EventName(@"Test").dw_Build();
} On:^(__kindof DWEvent *event ,id target) {
    NSLog(@"事件接收完成，最后收到的是：%@",event.eventName);
}];
```

如果订阅方执行完成后想反馈给发布方，你也可以这样做：

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
    maker.EventName(@"Login").dw_Build();
} On:^(__kindof DWEvent *event, id subscribeTarget) {
    NSLog(@"已经收到Login事件");
    ///Do something
    NSLog(@"已经完成相关操作，通知发布方我已完成");
    [event setEventHandledBy:self];
}];
    
DWEvent * e = [DWEvent new];
e.eventName = @"Login";
e.eventHandledCallback = ^(id flag) {
    NSLog(@"%@已经完成了Login事件的相关处理",flag);
};
[[DWEventBus defaultEventBus] publishEvent:e];
```

如果你想学习更多用法，你可以到这个[Demo](https://github.com/CodeWicky/DWEventBus/tree/master/DEMO)里看看更详细的使用方法。

## Usage
Firstly,drag it into your project or use cocoapods.

```
pod 'DWEventBus', '~> 1.0.0'
```

Establish the simplest subscription relationship:

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
   maker.EventName(@"Login").dw_Build();
} On:^(__kindof DWEvent *event, id subscribeTarget) {
   NSLog(@"收到事件了");
}];
 
[[DWEventBus defaultEventBus] publish:^(DWEventMaker *maker) {
   maker.EventName(@"Login").dw_Build();
}];
```

Of course, you can also specify the queue where the message is sent:

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
		maker.EventName(@"Login").Queue(dispatch_get_global_queue(0, 0)).dw_Build();
} On:^(__kindof DWEvent *event ,id target) {
        NSLog(@"Receive Login Event On Thread:%@",[NSThread currentThread]);
}];
```

If the requirement is that a callback is triggered only after two events have been received, consider using united events:

```
DWEvent * e1 = [DWEvent new];
e1.eventName = @"Regist";
    
DWEvent * e2 = [DWEvent new];
e2.eventName = @"Login";
    
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
    maker.UniteEvent(e1).UniteEvent(e2).EventName(@"Test").dw_Build();
} On:^(__kindof DWEvent *event ,id target) {
    NSLog(@"事件接收完成，最后收到的是：%@",event.eventName);
}];
```

If the subscriber wants feedback to the publisher after execution, you can do like this:

```
[[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
    maker.EventName(@"Login").dw_Build();
} On:^(__kindof DWEvent *event, id subscribeTarget) {
    NSLog(@"已经收到Login事件");
    ///Do something
    NSLog(@"已经完成相关操作，通知发布方我已完成");
    [event setEventHandledBy:self];
}];
    
DWEvent * e = [DWEvent new];
e.eventName = @"Login";
e.eventHandledCallback = ^(id flag) {
    NSLog(@"%@已经完成了Login事件的相关处理",flag);
};
[[DWEventBus defaultEventBus] publishEvent:e];
```

如果你想学习更多用法，你可以到这个[Demo](https://github.com/CodeWicky/DWEventBus/tree/master/DEMO)里看看更详细的使用方法。

## 联系作者

你可以通过在[我的Github](https://github.com/CodeWicky/DWEventBus)上给我留言或者给我发送电子邮件 codeWicky@163.com 来给我提一些建议或者指出我的bug,我将不胜感激。

如果你喜欢这个小东西，记得给我一个star吧，么么哒~

## Contact With Me
You may issue me on [my Github](https://github.com/CodeWicky/DWEventBus) or send me a email at  codeWicky@163.com  to tell me some advices or the bug,I will be so appreciated.

If you like it please give me a star.

