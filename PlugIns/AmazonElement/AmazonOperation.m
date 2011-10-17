//
//  AmazonOperation.m
//  Amazon Support
//
//  Created by Mike on 23/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "AmazonOperation.h"

#import "AsyncObjectQueue.h"

#import "NSString+Amazon.h"
#import "NSXMLElement+Amazon.h"

@interface AmazonOperation ( private )

- (void)setResultListKey:(NSString *)aResultListKey;
- (void)setResultKey:(NSString *)aResultKey;

@end


@implementation AmazonOperation

#pragma mark -
#pragma mark Queue

+ (AsyncObjectQueue *)queue
{
	static AsyncObjectQueue *queue = nil;
	if (!queue) {
		queue = [[AsyncObjectQueue alloc] init];
	}
	
	return queue;
}

#pragma mark -
#pragma mark Init/Dealloc

- (id)initWithOperation:(NSString *)operation
			 parameters:(NSDictionary *)parameters
		  resultListKey:(NSString *)aResultListKey
			  resultKey:(NSString *)aResultKey;
{
	if ((self = [super initWithBaseURL:nil parameters:parameters]) != nil)
	{
		[[self params] setObject:operation forKey:@"Operation"];
		[self setResultListKey:aResultListKey];
		[self setResultKey:aResultKey];
		[[self params] setObject: [[self class] accessKeyID] forKey: @"AWSAccessKeyId"];
	}
	return self;
}

#pragma mark -
#pragma mark Loading

// Overridden to schedule the load
- (void)load
{
	[[AmazonOperation queue] addObjectToQueue: self];
}

// Overridden to also remove the operation from the queue
- (void)cancel
{
	[[AmazonOperation queue] removeObjectFromQueue: self];
	[super cancel];
}

// Abstract -- subclass should override
- (NSURL *)baseURL
{
	return nil;
}

#pragma mark -
#pragma mark Accessors


- (NSString *)resultListKey
{
    return myResultListKey; 
}

- (void)setResultListKey:(NSString *)aResultListKey
{
    [aResultListKey retain];
    [myResultListKey release];
    myResultListKey = aResultListKey;
}

- (NSString *)resultKey
{
    return myResultKey; 
}

- (void)setResultKey:(NSString *)aResultKey
{
    [aResultKey retain];
    [myResultKey release];
    myResultKey = aResultKey;
}


#pragma mark -
#pragma mark Post-Loading

- (NSError *)processLoadedData
{
	NSError *error = [super processLoadedData];
	if (nil == error)
	{
		error = [self requestError];
	}
	return error;
}

- (BOOL)requestIsValid { return [[self cachedValueForKey: @"requestIsValid"] boolValue]; }

// Abstract -- subclass should override
- (BOOL)requestIsValidUncached
{
	return YES;
}

- (NSError *)requestError { return [self cachedValueForKey: @"requestError"]; }

// Abstract -- subclass should override
- (NSError *)requestErrorUncached
{
	return nil;
}

#pragma mark -
#pragma mark Class Variables

+ (void)initialize
{
	[self setTimeout:5.0];	// try a smaller timeout
}

static NSString *_accessKeyID;
static NSString *_secretKeyID;

+ (NSString *)accessKeyID { return _accessKeyID; }

+ (void)setAccessKeyID:(NSString *)key
{
	if (key == _accessKeyID)
		return;

	[_accessKeyID release];
	_accessKeyID = [key retain];
}

+ (NSString *)secretKeyID { return _secretKeyID; }

+ (void)setHash:(NSString *)key
{
	if (key == _secretKeyID)
		return;
	
	[_secretKeyID release];
	_secretKeyID = [key retain];
}


@end
