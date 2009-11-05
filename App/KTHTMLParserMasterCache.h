//
//  KTHTMLParserMasterCache.h
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLParserCache.h"


@class KTTemplateParser;


@interface KTHTMLParserMasterCache : KTHTMLParserCache
{
	NSMutableDictionary	*myOverrides;
	KTTemplateParser		*myParser;		// Weak ref
}

// Init
- (id)initWithProxyObject:(NSObject *)proxyObject parser:(KTTemplateParser *)parser;
//- (KTTemplateParser *)parser;

// KVC
- (id)valueForKey:(NSString *)key;
- (id)valueForKeyPath:(NSString *)keyPath;
- (id)valueForKeyPath:(NSString *)keyPath informDelegate:(BOOL)informDelegate;

// KVC Overrides
- (id)overridingValueForKey:(NSString *)key;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

@end
