//
//  KTImageLoader.m
//  Marvel
//
//  Created by Dan Wood on 1/29/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTImageLoader.h"
#import "NSBezierPath+KTExtensions.h"


@interface KTImageLoader ( Private )

- (NSURL *)URL;
- (void)setURL:(NSURL *)anURL;
- (NSMutableDictionary *)dictionary;
- (void)setDictionary:(NSMutableDictionary *)aDictionary;
- (NSSize)size;
- (void)setSize:(NSSize)aSize;
- (float)radius;
- (void)setRadius:(float)aRadius;

@end

@implementation KTImageLoader

- (id)initWithURL:(NSURL *)url size:(NSSize)aSize radius:(float)aRadius destination:(NSMutableDictionary *)aDictionary;
{
	if ((self = [super init]) != nil)
	{
		if (nil == url)
		{
			NSLog(@"KTImageLoader nil URL");
		}
		[self setURL:url];
 		[self setDictionary:aDictionary];
		[self setSize:aSize];
		[self setRadius:aRadius];

		NSURLRequest *theRequest
		=	[NSURLRequest requestWithURL:url
						   cachePolicy:NSURLRequestReturnCacheDataElseLoad	// prefer a cache
					   timeoutInterval:3.0];

		
		NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
		if (theConnection)
		{
			// Create the NSMutableData that will hold
			// the received data
			myConnectionData=[[NSMutableData alloc] init];
		} else {
			// inform the user that the download could not be made
			NSLog(@"unable to set up connection to get image %@", url);
		}
	}
	return self;
}

#pragma mark -
#pragma mark Loading

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

+ (NSImage *)finalizeImage:(NSImage *)anImage toSize:(NSSize)aSize radius:(float)aRadius
{
	[anImage setScalesWhenResized:YES];
	[anImage setSize:aSize];
	
	NSImage *destImage = anImage;	// default unless we do operations
	if (aRadius > 0.1)
	{
		NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundRectInRect:NSMakeRect(0,0,aSize.width, aSize.height) radius:aRadius];
		destImage = [[[NSImage alloc] initWithSize:aSize] autorelease];
		[destImage lockFocus];
		[roundedPath fill];
		[anImage compositeToPoint:NSZeroPoint operation:NSCompositeSourceIn];
		
		NSBezierPath *roundedPath2 = [NSBezierPath bezierPathWithRoundRectInRect:NSMakeRect(0.5,0.5,aSize.width-1, aSize.height-1) radius:aRadius];
		
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.10] set];
		[roundedPath2 stroke];
		[destImage unlockFocus];
	}
	return destImage;
}	
	
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	OBPRECONDITION(connection);

	NSImage *sourceImage = [[[NSImage alloc] initWithData:myConnectionData] autorelease];
	NSImage *destImage = [KTImageLoader finalizeImage:sourceImage toSize:mySize radius:myRadius];
	
	[myDictionary setObject:destImage forKey:@"originalIcon"];
	[myDictionary setObject:destImage forKey:@"icon"];

    // release the connection, and the data object
    [connection release];
    [myConnectionData release];
	myConnectionData = nil;
	
}

// Dan explains why connection, the passed in param, is released in these method:
// "Well, the connection needs to survive across runloops. One way would be to set
// it as an ivar, but in this case, it's retained before the connection starts, 
// and then when the connection is done (either failing or succeeding), it's released
// when it's no longer needed. I don't see a problem with that."

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
	OBPRECONDITION(connection);
	OBPRECONDITION(error);
    // release the connection, and the data object
    // inform the user
    NSLog(@"KTImageLoader Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[[[error userInfo] objectForKey:NSErrorFailingURLStringKey] description] condenseWhiteSpace]
	);
    [connection release];
    [myConnectionData release];
	myConnectionData = nil;
	
// leave placeholder icon in there.	[myDictionary removeObjectForKey:@"icon"];

}

#pragma mark -
#pragma mark Accessors


- (NSSize)size
{
    return mySize;
}

- (void)setSize:(NSSize)aSize
{
    mySize = aSize;
}

- (NSURL *)URL
{
    return myURL; 
}

- (void)setURL:(NSURL *)anURL
{
    [anURL retain];
    [myURL release];
    myURL = anURL;
}

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


- (float)radius
{
    return myRadius;
}

- (void)setRadius:(float)aRadius
{
    myRadius = aRadius;
}


@end
