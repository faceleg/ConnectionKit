//
//  AsyncImage.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/9/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	A subclass of AsyncObject that specifically loads an NSImage
//	rather than general data.


#import <Cocoa/Cocoa.h>
#import "AsyncObject.h"


@interface AsyncImage : AsyncObject
{
	NSImage			*myImage;
}

- (id)initWithURL:(NSURL *)aURL;

- (NSImage *)image;

@end
