//
//  KTTemplateParser.h
//  Marvel
//
//  Created by Mike on 19/05/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NSString+Karelia.h"


@class KTHTMLParserMasterCache;


@interface KTTemplateParser : NSObject
{
	@private
	
	NSString				*myID;
	NSString				*myTemplate;
	id						myComponent;
	KTHTMLParserMasterCache	*myCache;
	id						myDelegate;
	KTTemplateParser		*myParentParser;	// Weak ref
	
	NSMutableDictionary	*myOverriddenKeys;
	
	int myIfCount;
	
	NSIndexPath	*myForEachIndexes;
	NSIndexPath *myForEachCounts;
}

- (id)initWithTemplate:(NSString *)templateString component:(id)parsedComponent;

// Accessors
- (NSString *)parserID;
- (NSString *)template;
- (id)component;

- (id)delegate;
- (void)setDelegate:(id)delegate;

// KVC Overrides
- (NSSet *)overriddenKeys;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

// Child parsers
- (id)parentParser;
- (id)newChildParserWithTemplate:(NSString *)templateString component:(id)component;

// Parsing
+ (NSString *)parseTemplate:(NSString *)aTemplate component:(id)component;
- (NSString *)parseTemplate;
- (BOOL)prepareToParse;

- (NSString *)componentLocalizedString:(NSString *)tag;
- (NSString *)componentTargetLocalizedString:(NSString *)tag;
- (NSString *)mainBundleLocalizedString:(NSString *)tag;

// If function
- (BOOL)compareIfStatement:(ComparisonType)comparisonType leftValue:(id)leftValue rightValue:(id)rightValue;
- (BOOL)isNotEmpty:(id)aValue;

@end


@interface NSObject (Delegate)
- (void)HTMLParser:(KTTemplateParser *)parser didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
- (NSString *)parser:(KTTemplateParser *)parser willEndParsing:(NSString *)result;
@end


@interface NSObject (KTTemplateParserAdditions)
- (NSString *)templateParserStringValue;
@end

