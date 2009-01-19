//
//  KTParsedKeyPath.h
//  Marvel
//
//  Created by Mike on 22/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//
//	Represents a keypath that was parsed while building a page's HTML.
//	KTDocWebViewController maintains the hierarchy of these objects.


#import <Cocoa/Cocoa.h>


@interface KTParsedKeyPath : NSObject
{
	NSString	*myKeyPath;
	NSObject	*myObject;
}

- (id)initWithKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;

- (NSString *)keyPath;
- (NSObject	*)parsedObject;

@end
