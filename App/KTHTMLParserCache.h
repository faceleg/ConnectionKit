//
//  KTHTMLParserCache.h
//  Marvel
//
//  Created by Mike on 11/09/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTHTMLParserCache : NSObject
{
	@private
	NSObject *myProxyObject;
	NSMutableDictionary *myCachedValues;
}

- (id)initWithProxyObject:(NSObject *)proxyObject;
- (NSObject *)proxyObject;

// KVC
- (id)valueForKey:(NSString *)key;
- (id)valueForKeyPath:(NSString *)keyPath;

@end
