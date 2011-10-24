//
//  AsyncObject.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/9/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AsyncObject.h"

@interface AsyncObject (Private)

// Private Acccessors
- (void)setData:(NSMutableData *)aData;
- (void)setDataIsLoading:(BOOL)flag;
- (void)setDataHasLoaded:(BOOL)flag;
- (NSURLConnection *)URLConnection;
- (void)setURLConnection:(NSURLConnection *)anURLConnection;

@end

@implementation AsyncObject

#pragma mark -
#pragma mark init/dealloc

- (id)init
{
	NSLog(@"Cannot initialize this way");
	[self release];
	return nil;
}

- (id)initWithURL:(NSURL *)aURL
{
	if ((self = [super init]) != nil)
	{
		[self setRequestURL:aURL];
		[self setCachePolicy:NSURLRequestReloadIgnoringCacheData];		// default
	}
	return self;
}

- (void)dealloc
{
	[[self URLConnection] cancel];
    [self setDelegate:nil];
    [self setData:nil];
    [self setRequestURL:nil];
    [self setURLConnection:nil];
    [super dealloc];
}

#pragma mark -
#pragma mark Loading

// May be overridden to queue up the load.  Assumes delegate set already.
- (void) load
{
	[self _load];
}

// Primitive Load method. Do not call directly.
- (void)_load
{
	if ([self dataIsLoading] || [self dataHasLoaded]) return;		// Ignore a second request to load data

	NSURL *requestURL = [self requestURL];	// note: subclass might have overridden this

#ifdef DEBUG
	NSLog(@"DEBUG ASyncObject loading: %@", [requestURL absoluteString]);
#endif	
	
	NSURLRequest *request = [[[NSURLRequest alloc] initWithURL:requestURL
												   cachePolicy:[self cachePolicy]
											   timeoutInterval:[AsyncObject timeout]] autorelease];

	// Begin the connection
	NSURLConnection *connection = [NSURLConnection connectionWithRequest: request delegate: self];
	[self setURLConnection: connection];
	[self setDataIsLoading: YES];
}

- (void)loadWithDelegate:(id)aDelegate
{
	[self setDelegate:aDelegate];
	[self load];
}

- (void)cancel
{
	[[self URLConnection] cancel];
	[self setDataIsLoading:NO];
}

- (void) unload
{
	[[self URLConnection] cancel];
    [self setData:nil];
    [self setURLConnection:nil];
	[self setDataIsLoading:NO];
	[self setDataHasLoaded:NO];
}

#pragma mark -
#pragma mark NSURLConnection Delegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// If it doesn't already exist, create a blank data set
	if (!myData)
	{
		[self setData:[NSMutableData data]];
	}
	// Append the new data to the existing
	[myData appendData: data];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
    [myData setLength:0];

	// Server error: simulate an error condition.
	if ([response respondsToSelector:@selector(statusCode)])
	{
		NSInteger statusCode = [((NSHTTPURLResponse *)response) statusCode];
		if (statusCode >= 400)
		{
			[connection cancel];

			NSDictionary *errorInfo
				= [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
					@"Server returned status code %d", statusCode]
											  forKey:NSLocalizedDescriptionKey];

			NSError *statusError = [NSError errorWithDomain:@"NSHTTPPropertyStatusCode" // was NSHTTPPropertyStatusCodeKey, now deprecated/gone
													   code:statusCode
												   userInfo:errorInfo];

			[self connection:connection didFailWithError:statusError];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self setDataIsLoading: NO];
	// Alert our delegate
	if ([self delegateRespondsToSelector: @selector(asyncObject:didFailWithError:)])
		[[self delegate] asyncObject: self didFailWithError: error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self setDataIsLoading: NO];	// This has to be done early to avoid confusing the delegate
	[self setDataHasLoaded: YES];

	NSError *error = nil;
	if (0 != [myData length])
	{
		// Try to convert the received data into XMLAlert our delegate as to the result
		error = [self processLoadedData];
	}
	else
	{
		error = [NSError errorWithDomain: @"AsyncObjectEmptyData" code:0 userInfo: nil];
	}

	// Alert our delegate as to the result
	if (error)
	{
		if ([self delegateRespondsToSelector: @selector(asyncObject:didFailWithError:)])
			[[self delegate] asyncObject: self didFailWithError: error];
	}
	else
	{
		[self setDataHasLoaded:YES];
		if ([self delegateRespondsToSelector: @selector(asyncObjectDidFinishLoading:)])
			[[self delegate] asyncObjectDidFinishLoading: self];
	}
}

#pragma mark -
#pragma mark Delegate

// Subclasses would override this to analyze what was loaded so callback can have error message
-(NSError *)processLoadedData
{
	return nil;
}

- (BOOL)delegateRespondsToSelector:(SEL)selector
{
	id delegate = [self delegate];
	BOOL responds = (delegate && [delegate respondsToSelector: selector]);

	return responds;
}

- (void) raiseExceptionIfDataNotLoaded		// Call this before invoking any ivar fetcher of loaded data
{
	if ([self dataIsLoading])
	{
		[NSException raise: @"AsyncObject Still Loading"
			format: @"Returned request data can not be accessed since the request is still loading"];
	}
	if (![self dataHasLoaded])
	{
		[NSException raise: @"AsyncObject Not Loaded"
					format: @"Returned request data can not be accessed since the request has not been loaded"];
	}
}

#pragma mark -
#pragma mark Timeout

static NSTimeInterval sTimeout;

+ (void)initialize
{
	[self setTimeout:10.0];
}

+ (NSTimeInterval)timeout
{
	return sTimeout;
}

+ (void)setTimeout:(NSTimeInterval)aSeconds
{
	sTimeout = aSeconds;
}

#pragma mark -
#pragma mark Accessors

- (id)delegate { return myDelegate; }

- (void)setDelegate:(id)aDelegate { myDelegate = aDelegate; }

- (NSData *)data
{
	[self raiseExceptionIfDataNotLoaded];
    return myData;
}

- (void)setData:(NSMutableData *)aData
{
    [aData retain];
    [myData release];
    myData = aData;
}

- (NSURL *)requestURL
{
    return myRequestURL;
}

- (void)setRequestURL:(NSURL *)aRequestURL
{
    [aRequestURL retain];
    [myRequestURL release];
    myRequestURL = aRequestURL;
}

- (NSURLRequestCachePolicy)cachePolicy
{
    return myCachePolicy;
}

- (void)setCachePolicy:(NSURLRequestCachePolicy)aCachePolicy
{
    myCachePolicy = aCachePolicy;
}

- (BOOL)dataIsLoading
{
    return myDataIsLoading;
}

- (void)setDataIsLoading:(BOOL)flag
{
    myDataIsLoading = flag;
}

- (BOOL)dataHasLoaded
{
    return myDataHasLoaded;
}

- (void)setDataHasLoaded:(BOOL)flag
{
    myDataHasLoaded = flag;
}

- (NSURLConnection *)URLConnection
{
    return myURLConnection;
}

- (void)setURLConnection:(NSURLConnection *)anURLConnection
{
    [anURLConnection retain];
    [myURLConnection release];
    myURLConnection = anURLConnection;
}

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ Connection:%p loading:%@ Data:%p",
		[super description], myURLConnection, (myDataIsLoading ? @"YES" : @"NO"), [myData description]];
}

@end
