//
//  AmazonOperation.h
//  Amazon Support
//
//  Created by Mike on 23/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	A standard RESTOperation, but with some knowledge of the data involved.
//	i.e. the operation to perform & roughly what XML will be returned (including errors).
//	Also provides a Queue which operations are placed into. This stops us breaking
//	Amazon's terms and conditions by sending a maximum of one request per second.
//	Not only is this for legal reasons, but if too many requests are sent at once, I have
//	seen the server simply ignore some of the later ones.


#import <Cocoa/Cocoa.h>
#import "RESTOperation.h"


@class AsyncObjectQueue;


@interface AmazonOperation : RESTOperation
{
	NSString *myResultListKey;
	NSString *myResultKey;
}

- (id)initWithOperation:(NSString *)operation
			 parameters:(NSDictionary *)parameters
		  resultListKey:(NSString *)aResultListKey
			  resultKey:(NSString *)aResultKey;

+ (NSString *)accessKeyID;
+ (void)setAccessKeyID:(NSString *)key;

+ (NSString *)secretKeyID;
+ (void)setHash:(NSString *)key;

+ (AsyncObjectQueue *)queue;

- (BOOL)requestIsValid;
- (NSError *)requestError;

// Abstract, subclass should override
- (BOOL)requestIsValidUncached;
- (NSError *)requestErrorUncached;
- (NSURL *)baseURL;

- (NSString *)resultListKey;
- (NSString *)resultKey;

@end

