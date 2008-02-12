//
//  KTWebPageThumbnailer.m
//  Marvel
//
//  Created by Greg Hulands on 24/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "KTWebPageThumbnailer.h"

enum { CHECK_QUEUE, HAS_SYNC };

NSString *KTThumbnailerURLKey = @"url";
//NSString *KTThumbnailer

static KTWebPageThumbnailer *_sharedThumbnailer = nil;

@implementation KTWebPageThumbnailer

+ (id)sharedThumbnailer
{
	if (!_sharedThumbnailer)
		_sharedThumbnailer = [[KTWebPageThumbnailer alloc] init];
	return _sharedThumbnailer;
}

- (id)init
{
	if (self = [super init]) {
		
		
		myLock = [[NSLock alloc] init];
		myPort = [[NSPort port] retain];
		[myPort setDelegate:self];
		
		[NSThread prepareForInterThreadMessages];
		
		[NSThread detachNewThreadSelector:@selector(runAsyncThumbnailerThread:) toTarget:self withObject:nil];
	}
	return self;
}

- (void)dealloc
{
	
}

#pragma mark -
#pragma mark Threading for Async

- (void)runAsyncThumbnailerThread:(id)notUsed
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	myWorkerThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	
	[[NSRunLoop currentRunLoop] addPort:myPort forMode:(NSString *)kCFRunLoopCommonModes];
	[[NSRunLoop currentRunLoop] run];
	
	[pool release];
}

- (void)sendPortMessage:(int)aMessage
{
	if (nil != myPort)
	{
		NSPortMessage *message
		= [[NSPortMessage alloc] initWithSendPort:myPort
									  receivePort:myPort components:nil];
		[message setMsgid:aMessage];
		
		@try {
			BOOL sent = [message sendBeforeDate:[NSDate dateWithTimeIntervalSinceNow:15.0]];
			if (!sent)
			{
				NSLog(@"KTWebPageThumbnailer couldn't send message %d", aMessage);
			}
		} @catch (NSException *ex) {
			NSLog(@"%@", ex);
		} @finally {
			[message release];
		} 
	}
}

- (void)handlePortMessage:(NSPortMessage *)portMessage
{
	int message = [portMessage msgid];
	
	switch (message) {
		
	}
}

- (NSImage *)thumbnailForURL:(NSURL *)url size:(NSSize)size
{
	[self sendPortMessage:HAS_SYNC];
}

- (void)fetchThumbnailForURL:(NSURL *)url notifyTarget:(id)target size:(NSSize)size
{
	NSMutableDictionary *rec = [NSMutableDictionary dictionary];
	[rec setObject:url forKey:KTThumbnailerURLKey];
	
	[myLock lock];
	[myJobQueue addObject:rec];
	[myLock unlock];
	[self sendPortMessage:CHECK_QUEUE];
}


@end
