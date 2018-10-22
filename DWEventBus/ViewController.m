//
//  ViewController.m
//  DWEventBus
//
//  Created by Wicky on 2018/10/22.
//  Copyright © 2018年 Wicky. All rights reserved.
//

#import "ViewController.h"
#import "DWEventBus.h"
#import "A.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    [[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
        maker.EventName(@"Login").dw_Build();
        maker.EventName(@"Regist").Queue(dispatch_get_global_queue(0, 0)).dw_Build();
    } On:^(__kindof DWEvent *event) {
        NSLog(@"Finish Login %@",[NSThread currentThread]);
        [event setEventHandledBy:self];
    }];
    
    NSString * str1 = [NSString stringWithFormat:@"%@",@"1"];
    NSMutableSet * set = [NSMutableSet set];
    [set addObject:str1];
    NSString * str2 = [NSString stringWithFormat:@"%@",@"1"];
    [set removeObject:str2];
    NSLog(@"set = %@",set);
    
    DWEvent * e1 = [DWEvent new];
    e1.eventName = @"Login";
    DWEvent * e2 = [DWEvent new];
    e2.eventName = @"Regist";
    [[DWEventBus defaultEventBus] subscribe:^(DWEventMaker *maker) {
        maker.UniteEvent(e1).UniteEvent(e2).dw_Build();
    } On:^(__kindof DWEvent *event) {
        NSLog(@"Unite finish");
    }];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    static int i = 0;
    DWEvent * e = [DWEvent new];
    if (i == 0) {
        e.eventName = @"Regist";
    } else {
        e.eventName = @"Login";
    }
    
//    e.subType = 1;
//    e.eventHandledCallback = ^(id flag) {
//        NSLog(@"%@ 已经收到通知并完成操作",self);
//    };
//    [[DWEventBus defaultEventBus] dispatch:e];
    
    [[DWEventBus defaultEventBus] dispatch:e];
    i++;
}


@end
