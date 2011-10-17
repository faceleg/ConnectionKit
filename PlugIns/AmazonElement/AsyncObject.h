//
//  AsyncObject.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/9/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Simplifies use of an asynchronous NSURLConnection so that all NSData is automatically
//	stored and the delegate informed only once loading is complete or fails.


#import <Foundation/Foundation.h>
#import "CacheableObject.h"


@interface AsyncObject : CacheableObject
{
	id						myDelegate;
	NSMutableData			*myData;
	NSURL					*myRequestURL;
	NSURLRequestCachePolicy	myCachePolicy;

	BOOL					myDataIsLoading;
	BOOL					myDataHasLoaded;
	NSURLConnection			*myURLConnection;
}

+ (NSTimeInterval)timeout;
+ (void)setTimeout:(NSTimeInterval)aSeconds;

- (id)initWithURL:(NSURL *)aURL;

- (void)loadWithDelegate:(id)delegate;
- (void)load;
- (void)_load;	// internal load command
- (void)cancel;
- (void)unload;	// do this if you want to load again
- (BOOL)dataIsLoading;
- (BOOL)dataHasLoaded;

- (BOOL)delegateRespondsToSelector:(SEL)selector;
-(NSError *)processLoadedData;
- (void)raiseExceptionIfDataNotLoaded;		// Call this before invoking any ivar fetcher of loaded data

// Public Accessors

- (id)delegate;
- (void)setDelegate:(id)aDelegate;

- (NSData *)data;

- (NSURL *)requestURL;
- (void)setRequestURL:(NSURL *)aRequestURL;

- (NSURLRequestCachePolicy)cachePolicy;
- (void)setCachePolicy:(NSURLRequestCachePolicy)aCachePolicy;

@end


@interface NSObject ( AsyncObjectDelegate )
- (void)asyncObject:(id)aRequestedObject didFailWithError:(NSError *)error;
- (void)asyncObjectDidFinishLoading:(id)aRequestedObject;
@end
