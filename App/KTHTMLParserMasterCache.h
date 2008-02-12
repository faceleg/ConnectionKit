//
//  KTHTMLParserMasterCache.h
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLParserCache.h"


@class KTHTMLParser;


@interface KTHTMLParserMasterCache : KTHTMLParserCache
{
	NSMutableDictionary	*myOverrides;
	KTHTMLParser		*myParser;
}

// Init
- (id)initWithProxyObject:(NSObject *)proxyObject parser:(KTHTMLParser *)parser;
- (KTHTMLParser *)parser;

// KVC
- (id)valueForKey:(NSString *)key;
- (id)valueForKeyPath:(NSString *)keyPath;
- (id)valueForKeyPath:(NSString *)keyPath informDelegate:(BOOL)informDelegate;

// KVC Overrides
- (NSSet *)overridenKeys;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

@end
