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
        maker.EventName(@"Login").SubType(1).dw_Build();
        maker.EventName(@"Regist").SubType(1).dw_Build();
    } On:^(__kindof DWEvent *event) {
        NSLog(@"Finish Login");
        [event setEventHandledBy:self];
    }];
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    DWEvent * e = [DWEvent new];
    e.eventName = @"Regist";
//    e.subType = 1;
    e.eventHandledCallback = ^(id flag) {
        NSLog(@"%@ 已经收到通知并完成操作",self);
    };
    [[DWEventBus defaultEventBus] dispatch:e];
}


@end
