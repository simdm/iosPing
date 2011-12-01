//
//  MBPing.m
//  iosPing
//
//  Created by demeng on 11-11-9.
//  Copyright (c) 2011年 HOLDiPhone. All rights reserved.
//

#import "MBPing.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/time.h>

@implementation MBPing
@synthesize last_rtt, ipAdress;

struct ICMPHeader {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    // data...
    int64_t     sentTime;
};

#define ICMP_TYPE_ECHO_REPLY 0
#define ICMP_TYPE_ECHO_REQUEST 8

/* This is the standard BSD checksum code, modified to use modern types. */
static uint16_t in_cksum(const void *buffer, size_t bufferLen)
{
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);     /* add hi 16 to low 16 */
    sum += (sum >> 16);                     /* add carry */
    answer = ~sum;                          /* truncate to 16 bits */
    
    return answer;
}

int setSocketNonBlocking(int fd) {
    int flags;
    
    /* Set the socket nonblocking.
     * Note that fcntl(2) for F_GETFL and F_SETFL can't be
     * interrupted by a signal. */
    if ((flags = fcntl(fd, F_GETFL)) == -1) return -1;
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) == -1) return -1;
    return 0;
}

/* Return the UNIX time in microseconds */
int64_t ustime(void) {
    struct timeval tv;
    long long ust;
    
    gettimeofday(&tv, NULL);
    ust = ((int64_t)tv.tv_sec)*1000000;
    ust += tv.tv_usec;
    return ust;
}

- (void) sendPingwithId: (int) identifier andSeq: (int) seq {
    if (icmp_socket != -1) close(icmp_socket);
    
    int s = icmp_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    struct sockaddr_in sa;
    struct ICMPHeader icmp;
    
    if (s == -1) return;
    inet_aton([ipAdress UTF8String], &sa.sin_addr);
    setSocketNonBlocking(s);
    
    /* Note that we create always a new socket, with a different identifier
     * and sequence number. This is to avoid to read old replies to our ICMP
     * request, and to be sure that even in the case the user changes
     * connection, routing, interfaces, everything will continue to work. */
    icmp.type = ICMP_TYPE_ECHO_REQUEST;
    icmp.code = 0;
    icmp.checksum = 0;
    icmp.identifier = identifier;
    icmp.sequenceNumber = seq;
    icmp.sentTime = ustime();   
    icmp.checksum = in_cksum(&icmp,sizeof(icmp));
    
    sendto(s,&icmp,sizeof(icmp),0,(struct sockaddr*)&sa,sizeof(sa));
}

- (void) receivePing {
    unsigned char packet[1024*16];
    struct ICMPHeader *reply;
    int s = icmp_socket;
    ssize_t nread = read(s,packet,sizeof(packet));
    int icmpoff;
    
    if (nread <= 0) return;
//    NSLog(@"Received ICMP %d bytes\n", (int)nread);
    
    icmpoff = (packet[0]&0x0f)*4;
//    NSLog(@"ICMP offset: %d\n", icmpoff);
    
    /* Don't process malformed packets. */
    if (nread < (icmpoff + (signed)sizeof(struct ICMPHeader))) return;
    reply = (struct ICMPHeader*) (packet+icmpoff);
    
    /* Make sure that identifier and sequence match */
    if (reply->identifier != icmp_id ||
        reply->sequenceNumber != icmp_seq)
    {
        return;
    }
    
//    NSLog(@"OK received an ICMP packet that matches!\n");
    if (reply->sentTime > last_received_time) {
        last_rtt = (int)(ustime()-reply->sentTime)/1000;
        last_received_time = reply->sentTime;
        [timer invalidate];
        pageStillLoading = NO;
    }
}

- (void)startPing
{
    icmp_socket = -1;
    last_received_time = 0;
    last_rtt = 30000;
    icmp_id = random()&0xffff;
    icmp_seq = random()&0xffff;
    clicks = -1;
    
    pageStillLoading = YES;
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerHandler) userInfo:nil repeats:YES];
    while (pageStillLoading) 
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:nil];
}

- (void) timerHandler
{
    clicks++;
    if (clicks == 20) {
        [timer invalidate];
        pageStillLoading = NO;
        return;
    }
    if ((clicks % 10) == 0) {
        [self sendPingwithId:icmp_id andSeq: icmp_seq];
    }
    [self receivePing];
}
- (void)dealloc
{
    [ipAdress release];
    ipAdress = nil;
    timer = nil;
}

+(NSArray*)insertSortWithArray:(NSArray *)aData
{
    NSMutableArray *data = [[[NSMutableArray alloc]initWithArray:aData]autorelease];
    for (int i = 1; i < [data count]; i++) 
    {
        Server *tmp = [data objectAtIndex:i];
        int j = i-1;
        while (j != -1 && ((Server*)[data objectAtIndex:j]).speed > tmp.speed) 
        {
            [data replaceObjectAtIndex:j+1 withObject:[data objectAtIndex:j]];
            j--;
        }
        [data replaceObjectAtIndex:j+1 withObject:tmp];
    }
    return data;
}

+(Server*)start
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"servers" ofType:@"plist"];
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSArray *array = [dict objectForKey:@"servers"];
    
    NSMutableArray *serverArray = [[NSMutableArray alloc] initWithCapacity:[array count]];
    for (NSDictionary *element in array) 
    {
        MBPing *ping = [[MBPing alloc] init];
        ping.ipAdress = [element objectForKey:@"host"];
        [ping startPing];
        
        Server *server = [[Server alloc] init];
        server.name = [element objectForKey:@"name"];
        server.host = [element objectForKey:@"host"];
        server.speed = ping.last_rtt;
        [serverArray addObject:server];
        
        [server release];
        [ping release];
    }
    
    NSArray *bestArray = [self insertSortWithArray:serverArray];
    for (Server *element in bestArray) 
    {
        NSLog(@"name = [%@] , speed = [%dms]", element.name, element.speed);
    }
    NSLog(@"*********************************************");
    return [bestArray objectAtIndex:0];
}

@end
