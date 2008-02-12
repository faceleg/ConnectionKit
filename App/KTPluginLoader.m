//
//  KTPluginLoader.m
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPluginLoader.h"
#import "NSBezierPath+Karelia.h"
#import "NSError+Karelia.h"

@interface KTPluginLoader ( Private )

- (NSMutableDictionary *)dictionary;
- (void)setDictionary:(NSMutableDictionary *)aDictionary;

@end

@interface NSObject ( KTPluginLoaderDelegate )

- (void) loaderFinished:(KTPluginLoader *)aLoader error:(NSError *)anError;

@end

@implementation KTPluginLoader



- (void)dealloc
{
    [self setDictionary:nil];
	[self setConnection:nil];
    [self setConnectionData:nil];
    [super dealloc];
}

- (id)initWithDictionary:(NSMutableDictionary *)aDictionary delegate:(id)aDelegate;
{
	if ((self = [super init]) != nil)
	{
		myDelegate = aDelegate;
		[self setDictionary:aDictionary];

		NSURL *url = [aDictionary objectForKey:@"BundleURL"];
		NSLog(@"Opening up request for %@", url);
		if (!url)
		{
//			+ (id)errorWithDomain:(NSString *)anErrorDomain code:(int)anErrorCode localizedDescription:(NSString *)aLocalizedDescription;

			NSLog(@"nil URL from KTPluginLoader!");
			[myDelegate loaderFinished:self error:[NSError errorWithDomain:@"NSHTTPPropertyStatusCodeKey" code:0
													  localizedDescription:[NSString stringWithFormat:@"No URL was provided for loading %@", [aDictionary objectForKey:@"title"]]]];
			// finish immediately
		}
		else
		{
			NSURLRequest *theRequest
			=	[NSURLRequest requestWithURL:url
							   cachePolicy:NSURLRequestReturnCacheDataElseLoad	// prefer a cache
						   timeoutInterval:300.0];	// high timeout, in case of slow connection and multiple concurrent loads
			
			
			NSURLConnection *theConnection=[[[NSURLConnection alloc] initWithRequest:theRequest delegate:self] autorelease];
			if (theConnection)
			{
				// Create the NSMutableData that will hold
				// the received data
				myConnectionData=[[NSMutableData alloc] init];
			} else {
				// inform the user that the download could not be made
				NSLog(@"unable to set up connection to get image %@", url);
			}
			[self setConnection:theConnection];
		}
	}
	return self;
}

#pragma mark -
#pragma mark Cancelling

- (void) cancel
{
	[[self connection] cancel];
}

#pragma mark -
#pragma mark Loading callbacks

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	OBPRECONDITION(connection);
	OBPRECONDITION(response);
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
    [myConnectionData setLength:0];
	
	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode]; 
		if (statusCode >= 400)
		{
			[connection cancel];
			[self connection:connection didFailWithError:[NSError errorWithHTTPStatusCode:statusCode URL:[response URL]]];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	OBPRECONDITION(connection);
	OBPRECONDITION(data);
    // append the new data to the myConnectionData
    [myConnectionData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	OBPRECONDITION(connection);
	
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *destPath = [libraryPaths objectAtIndex:0];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	(void) [fm createDirectoryAtPath:destPath attributes:nil];
	
	destPath = [destPath stringByAppendingPathComponent:[NSApplication applicationName]];
	(void) [fm createDirectoryAtPath:destPath attributes:nil];
	
	
	// We want: (myConnectionData) | bunzip2 -c | tar xf -  .... destPath
	NSTask *task=[[[NSTask alloc] init] autorelease];
	[task setCurrentDirectoryPath:destPath];
	[task setLaunchPath: @"/bin/sh"];
    NSArray *arguments = [NSArray arrayWithObjects:
						  @"-c",
						  @"bunzip2 -c | tar xf -",
						  nil];
    [task setArguments: arguments];
	
	NSPipe *inPipe = [NSPipe pipe];
	NSFileHandle *inHandle = [inPipe fileHandleForWriting];
	[task setStandardInput:inPipe];
	[task launch];
	
	[inHandle writeData:myConnectionData];
	[inHandle closeFile];

	[task waitUntilExit];
	int result = [task terminationStatus];
	NSError *theErr = nil;
	if (result != 0)
	{
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSString stringWithFormat:
									NSLocalizedString(@"Unable to decompress data, code=%d",@"Description of an error"),
									result],NSLocalizedDescriptionKey,
								   [[myDictionary objectForKey:@"BundleURL"] absoluteString], NSErrorFailingURLStringKey,
								   nil];
		theErr = [NSError errorWithDomain:@"BZip2 Error" code:result userInfo:errorInfo];
		
	}
	
    // release the connection, and the data object
	[self setConnectionData:nil];
	[self setConnection:nil];
	
	[myDelegate loaderFinished:self error:theErr];

}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
	OBPRECONDITION(connection);
	OBPRECONDITION(error);
    // inform the user
    NSLog(@"KTPluginLoader Connection failed loading! Error - %@ %@",
          [error localizedDescription],
          [[[[error userInfo] objectForKey:NSErrorFailingURLStringKey] description] condenseWhiteSpace]
		  );
    // release the connection, and the data object
	[self setConnectionData:nil];
	[self setConnection:nil];
	
	[myDelegate loaderFinished:self error:error];
}

#pragma mark -
#pragma mark Accessors


- (NSMutableDictionary *)dictionary
{
    return myDictionary; 
}

- (void)setDictionary:(NSMutableDictionary *)aDictionary
{
    [aDictionary retain];
    [myDictionary release];
    myDictionary = aDictionary;
}


- (NSURLConnection *)connection
{
    return myConnection; 
}

- (void)setConnection:(NSURLConnection *)aConnection
{
    [aConnection retain];
    [myConnection release];
    myConnection = aConnection;
}

- (NSMutableData *)connectionData
{
    return myConnectionData; 
}

- (void)setConnectionData:(NSMutableData *)aConnectionData
{
    [aConnectionData retain];
    [myConnectionData release];
    myConnectionData = aConnectionData;
}


@end
