//
//  MBPing.h
//  iosPing
//
//  Created by demeng on 11-11-9.
//  Copyright (c) 2011年 HOLDiPhone. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Server.h"

@interface MBPing : NSObject {
    uint16_t icmp_id;
    uint16_t icmp_seq;
    int64_t last_received_time;
    int icmp_socket;
    int connection_state;
    NSTimer *timer;
    long clicks;
    
    int last_rtt;
    NSString *ipAdress;
    BOOL pageStillLoading;
}

@property(nonatomic, assign)int last_rtt;
@property(nonatomic, retain)NSString *ipAdress;

int setSocketNonBlocking(int fd);
int64_t ustime(void);
-(void)startPing;
-(void)timerHandler;
+(NSArray*)insertSortWithArray:(NSArray *)aData;
+(Server*)start;

@end
