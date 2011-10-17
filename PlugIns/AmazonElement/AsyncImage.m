//
//  AsyncImage.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/9/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AsyncImage.h"

@interface AsyncImage ( Private )

- (void)setDimensions:(NSSize)aDimensions;
- (void)setImage:(NSImage *)anImage;

@end

@implementation AsyncImage

- (id)initWithURL:(NSURL *)aURL
{
	if ((self = [super initWithURL:aURL]) != nil)
	{
		[self setCachePolicy:NSURLRequestReturnCacheDataElseLoad];		// allow cache to be used.  Very nice for images not to have to reload redundant images!
	}
	return self;
}

- (void)dealloc
{
	[self setImage:nil];
	[super dealloc];
}

-(NSError *)processLoadedData
{
	NSError *result = nil;

	NSImage *image = [[[NSImage alloc] initWithData: [self data]] autorelease];
	[self setImage:image];

	if (nil == image)
	{
		result = [NSError errorWithDomain: @"AsyncImageError" code:0 userInfo: nil];
	}
	return result;
}

#pragma mark -
#pragma mark Accessors

- (NSImage *)image
{
    return myImage;
}

- (void)setImage:(NSImage *)anImage
{
    [anImage retain];
    [myImage release];
    myImage = anImage;
}

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ Image: %p",
		[super description], myImage];
}

@end