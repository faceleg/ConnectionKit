//
//  KTHost.h
//  Marvel
//
//  Created by Greg Hulands on 5/06/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTHost : NSObject 
{
	CFHostRef		myHost;
	NSTimeInterval	myTimeoutValue;
	NSTimer			*myTimeoutTimer;
	BOOL			hasResolved;
	BOOL			isResolving;
	NSLock			*myLock;
}

+ (id)currentHost;
+ (id)hostWithName:(NSString *)name;
+ (id)hostWithAddress:(NSString *)address;

- (id)initWithName:(NSString *)name;
- (id)initWithAddress:(NSString *)address;

- (void)setTimeout:(NSTimeInterval)to;
- (NSTimeInterval)timeout;

- (NSString *)address;
- (NSArray *)addresses;

- (NSString *)name;
- (NSArray *)names;

- (BOOL)isEqualToHost:(KTHost *)host;

@end
