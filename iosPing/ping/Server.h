//
//  Server.h
//  iosPing
//
//  Created by demeng on 11-11-9.
//  Copyright (c) 2011年 HOLDiPhone. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Server : NSObject {
    NSString *name;
    NSString *host;
    int speed;
}

@property(nonatomic, retain)NSString *name;
@property(nonatomic, retain)NSString *host;
@property(nonatomic, assign)int speed;

@end
