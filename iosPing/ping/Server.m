//
//  Server.m
//  iosPing
//
//  Created by demeng on 11-11-9.
//  Copyright (c) 2011年 HOLDiPhone. All rights reserved.
//

#import "Server.h"

@implementation Server
@synthesize name, host, speed;

- (void)dealloc
{
    [name release];
    name = nil;
    [host release];
    host = nil;
}

@end
