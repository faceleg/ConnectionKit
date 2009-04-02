//
//  KTTemplateParser.m
//  Marvel
//
//  Created by Mike on 19/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTTemplateParser.h"
#import "KTHTMLParserMasterCache.h"

#import "NSBundle+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSScanner+Karelia.h"
#import "NSURL+Karelia.h"

#import "Debug.h"


@interface KTTemplateParser (Private)

// Child parsers
- (void)setParentParser:(KTTemplateParser *)parser;

// Parsing
- (void)finishParsing;
- (NSString *)startHTMLStringByScanning:(NSScanner *)inScanner;
- (NSString *)HTMLStringByScanning:(NSScanner *)inScanner;
+ (NSCharacterSet *)keyPathIndicatorCharacters;

// Support
- (id)parseValue:(NSString *)inString;

@end


#pragma mark -


@implementation KTTemplateParser

static NSString *kComponentTagStartDelim = @"[[";
static NSString *kComponentTagEndDelim = @"]]";

static NSString *kKeyPathIndicator = @"=";
static NSString *kEscapeHTMLIndicator = @"&";
static NSString *kSpacesToUnderscoreIndicator = @"_";

static NSString *kEncodeURLIndicator = @"%";
static NSString *kTargetStringIndicator = @"\"";			// [[" String to localized in TARGET language Doesn't want a closing delimeter.
static NSString *kTargetMainBundleStringIndicator = @"`";	// [[` String to localized in TARGET language -- but stored in Main Bundle ...  Doesn't want a closing delimeter.
static NSString *kStringIndicator = @"'";					// [[' String to localize in current language. Doesn't want a closing delimeter.


#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithTemplate:(NSString *)HTMLTemplate component:(id)parsedComponent
{
	OBPRECONDITION(HTMLTemplate);
	
	[super init];
	
	static unsigned sLastParserID = 0;
	sLastParserID++;
	myID = [[NSString alloc] initWithFormat:@"%u", sLastParserID];
	
	myTemplate = [HTMLTemplate copy];
	
	myComponent = [parsedComponent retain];
	
	return self;
}

- (void)dealloc
{
	[myTemplate release];
	[myComponent release];
	[myCache release];
	[myOverriddenKeys release];
	
	[myForEachIndexes release];
	[myForEachCounts release];
	
	[myID release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)parserID
{
	return myID;
}

- (NSString *)template { return myTemplate; }

- (id)component { return myComponent; }

- (KTHTMLParserMasterCache *)cache { return myCache; }

- (void)setCache:(KTHTMLParserMasterCache *)cache
{
	[cache retain];
	[myCache release];
	myCache = cache;
}

#pragma mark -
#pragma mark KVC Overriding

/*	These methods provide access to the cache's override method. However, these overrides are set in place before any
 *	parsing begins and are retained if several parses are made.
 */

- (NSMutableDictionary *)_keyOverrides
{
	if (!myOverriddenKeys)
	{
		myOverriddenKeys = [[NSMutableDictionary alloc] init];
	}
	
	return myOverriddenKeys;
}

- (NSSet *)overriddenKeys
{
	return [NSSet setWithArray:[[self _keyOverrides] allKeys]];
}

- (void)overrideKey:(NSString *)key withValue:(id)override
{
	OBASSERTSTRING(key, @"Attempt to override a nil key");
	OBASSERTSTRING(override, @"Attempt to override parser key with nil value");
	NSAssert1(([key rangeOfString:@"."].location == NSNotFound), @"“%@” is not a valid parser override key", key);
	NSAssert1(![[self _keyOverrides] objectForKey:key], @"The key “%@” is already overidden", key);
	
	[[self _keyOverrides] setObject:override forKey:key];
}

- (void)removeOverrideForKey:(NSString *)key
{
	[[self _keyOverrides] removeObjectForKey:key];
}

#pragma mark -
#pragma mark Child Parsers

/*	Creates a new parser with the same basic properties as ourself, and the specifed template/componet
 *	IMPORTANT:	Follows the standard "new rule" so, the return object is NOT autoreleased.
 */
- (id)newChildParserWithTemplate:(NSString *)template component:(id)component
{
	OBPRECONDITION(template);
    OBPRECONDITION(component);
    
	
	KTTemplateParser *result = [[[self class] alloc] initWithTemplate:template component:component];
	
	[result setParentParser:self];
	[result setDelegate:[self delegate]];
	
	return result;
}

/*	[[parseComponent keypath.to.component keypath.to.template]]
 *
 *	Branches off a new HTML parser for the specified component.
 *	The new parser has the same basic properties as us.
 */
- (NSString *)parsecomponentWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	
	if (!parameters || [parameters count] != 2)
	{
		NSLog(@"parsecomponent: usage [[parseComponent keypath.to.component keypath.to.template]]");
	}
	else
	{
		id component = [[self cache] valueForKeyPath:[parameters objectAtIndex:0]];
		NSString *template = [[self cache] valueForKeyPath:[parameters objectAtIndex:1]];
		
		if (component && template)
		{
			KTTemplateParser *parser = [self newChildParserWithTemplate:template component:component];
			result = [parser parseTemplate];
			[parser release];
		}
	}
	
	return result;
}

- (id)parentParser { return myParentParser; }

- (void)setParentParser:(KTTemplateParser *)parser { myParentParser = parser; }

#pragma mark -
#pragma mark Delegate

- (id)delegate { return myDelegate; }

- (void)setDelegate:(id)delegate { myDelegate = delegate; }		// It's a weak ref

- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(parser:didEncounterKeyPath:ofObject:)])
	{
		[delegate parser:self didEncounterKeyPath:keyPath ofObject:object];
	}
}

#pragma mark -
#pragma mark Parsing

/*	Convenience method for doing a simple parse
 */
+ (NSString *)parseTemplate:(NSString *)aTemplate component:(id)component
{
	KTTemplateParser *parser = [[self alloc] initWithTemplate:aTemplate component:component];
	NSString *result = [parser parseTemplate];
	[parser release];
	
	return result;
}

- (NSString *)parseTemplate
{
	NSString *result = nil;
	@try
	{
		BOOL readyToParse = [self prepareToParse];
		if (readyToParse)
		{
			NSString *template = [self template];
			if (template)
			{
				// Let the delegate know
				id delegate = [self delegate];
				if (delegate && [delegate respondsToSelector:@selector(parserDidStartTemplate:)])
				{
					[delegate parserDidStartTemplate:self];
				}
				
				
				// Parse!
				NSScanner *scanner = [NSScanner scannerWithString:template];
				[scanner setCharactersToBeSkipped:nil];
				result = [self startHTMLStringByScanning:scanner];
			}
		}
	}
    @catch (NSException *exception)
    {
        NSLog(@"Exception raised during parsing of component:\n%@\nTemplate:\n%@",
              [self component],
              [self template]);
        
        @throw;
    }
	@finally
	{
		[self finishParsing];
	}
	
    
    // Let the delegate know
    id delegate = [self delegate];
    if (delegate && [delegate respondsToSelector:@selector(parser:didEndTemplate:)])
    {
        result = [delegate parser:self didEndTemplate:result];
    }
    
    
    // Finish up
	return result;
}

- (BOOL)prepareToParse
{
	BOOL result = YES;
	
	// parsing page, aka outer context
	id parsedComponent = [self component];
	
	
	// Create a new cache for the parsing
	KTHTMLParserMasterCache *cache = [[KTHTMLParserMasterCache alloc] initWithProxyObject:parsedComponent parser:self];
	[self setCache:cache];
	[cache release];
	
	
	// Cache overrides
	[cache overrideKey:@"parser" withValue:self];
	[cache overrideKey:@"userDefaults" withValue:[NSUserDefaults standardUserDefaults]];
	
	NSEnumerator *overridesEnumerator = [myOverriddenKeys keyEnumerator];
	NSString *aKey;
	while (aKey = [overridesEnumerator nextObject])
	{
		[cache overrideKey:aKey withValue:[[self _keyOverrides] objectForKey:aKey]];
	}
	
	
	return result;
}

- (void)finishParsing
{
	[self setCache:nil];
}

- (NSString *)startHTMLStringByScanning:(NSScanner *)inScanner
{
	[inScanner setScanLocation:0];		// start at the front
	myIfCount = 0;
	return [self HTMLStringByScanning:inScanner];
}

- (NSString *)HTMLStringByScanning:(NSScanner *)inScanner
{
	NSMutableString *htmlString = [NSMutableString string];
	while ( ![inScanner isAtEnd] ) {
        NSString *tag;
        NSString *beforeText;
        
		// find [[ ... keep what was before it.
        if ( [inScanner scanUpToString:kComponentTagStartDelim intoString:&beforeText] ) {
            [htmlString appendString:beforeText];
        }
        
		// Get the [[
        if ( [inScanner scanString:kComponentTagStartDelim intoString:nil] ) {
            if ( [inScanner scanString:kComponentTagEndDelim intoString: nil] ) {
                // empty tag ... [[ immediately followed by ]]
                continue;
            }
            else if ( [inScanner scanUpToString:kComponentTagEndDelim intoString:&tag] && 
					 [inScanner scanString:kComponentTagEndDelim intoString:nil] )
			{
                
				// LOG((@"scanner found tag: %@", tag));
                if (tag)
				{
					if ( [tag hasPrefix:kKeyPathIndicator] )
					{
						NSScanner *tagScanner = [NSScanner scannerWithString:tag];
						[tagScanner setCharactersToBeSkipped:nil];
						
						NSString *keyPath;
						
						// switch to key path
						NSString *indicatorChars;
						[tagScanner scanCharactersFromSet:[[self class] keyPathIndicatorCharacters]
											   intoString:&indicatorChars];
						int htmlEscapeLocation = [indicatorChars rangeOfString:kEscapeHTMLIndicator].location;
						int urlEncodeLocation  = [indicatorChars rangeOfString:kEncodeURLIndicator].location;
						int spacesToUnderscoreLocation  = [indicatorChars rangeOfString:kSpacesToUnderscoreIndicator].location;
						
						// grab the class name to instantiate
						// grab the key path
						keyPath = [[tag substringFromIndex:[tagScanner scanLocation]] condenseWhiteSpace];
						
						//                    LOG((@"keyPath = %@", keyPath));
						
						// do we already have an instance in the page's cache?
						id element = [[self cache] valueForKeyPath:keyPath];
											if ( nil == element ) {
							//LOG((@"%@ [[=%@]] element not found", inContext, keyPath));
							LOG((@"[[=%@]] element not found", keyPath));
							continue;
						}
						else
						{
							NSString *toAppend = [element templateParserStringValue];
							
							// first replace spaces with an underscore
							if (NSNotFound != spacesToUnderscoreLocation)
							{
								toAppend = [toAppend legalizedURLNameWithFallbackID:@"_"];	// doesn't really matter if we lose everything
							}
							
							// now deal with url encoding and/or html escaping
							
							if ((NSNotFound != urlEncodeLocation) && (NSNotFound != htmlEscapeLocation))	// both?
							{
								if (urlEncodeLocation < htmlEscapeLocation)	// URL Encode first
								{
									toAppend = [toAppend stringByAddingPercentEscapesForURLQuery:YES];
									toAppend = [toAppend stringByEscapingHTMLEntities];
								}
								else	// HTML escape first
								{
									toAppend = [toAppend stringByEscapingHTMLEntities];
									toAppend = [toAppend stringByAddingPercentEscapesForURLQuery:YES];
								}
								
							}
							else
							{
								if (NSNotFound != urlEncodeLocation)
								{
									toAppend = [toAppend stringByAddingPercentEscapesForURLQuery:YES];
								}
								if (NSNotFound != htmlEscapeLocation)
								{
									toAppend = [toAppend stringByEscapingHTMLEntities];
								}
							}
							OBASSERT(toAppend);
							[htmlString appendString:toAppend];
						}
					}
					else if ([tag hasPrefix:kStringIndicator])
					{
						NSString *toAppend = [self componentLocalizedString:tag];
						if (toAppend) [htmlString appendString:toAppend];
					}
					else if ([tag hasPrefix:kTargetStringIndicator])
					{
						NSString *toAppend = [self componentTargetLocalizedString:tag];
						OBASSERT(toAppend);
						[htmlString appendString:toAppend];
					}
					else if ([tag hasPrefix:kTargetMainBundleStringIndicator])
					{
						NSString *toAppend = [self mainBundleLocalizedString:tag];
						OBASSERT(toAppend);
						[htmlString appendString:toAppend];
					}
					else	// not for echoing.  Do something.
					{
						NSScanner *tagScanner = [NSScanner scannerWithString:tag];
						[tagScanner setCharactersToBeSkipped:nil];
						
						NSString *keyword;
						// grab the method keyword
						[tagScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:&keyword];
						// throw away whitespace after
						[tagScanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
						
						NSString *inRestOfTag = @"";
						if (![tagScanner isAtEnd])
						{
							inRestOfTag = [tag substringFromIndex:[tagScanner scanLocation]];
						}
						
						/// Now using performSelector: here instead of NSInvocation as it should be quicker
						NSString *methodName = [NSString stringWithFormat:@"%@WithParameters:scanner:", [keyword lowercaseString]];
						SEL firstWordSel = NSSelectorFromString(methodName);
						
						if ([self respondsToSelector:firstWordSel])
						{
							NSString *htmlFragment = [self performSelector:firstWordSel withObject:inRestOfTag withObject:inScanner];
							
							/*
							 NSMethodSignature *sig = [[self class] instanceMethodSignatureForSelector:firstWordSel];
							 NSInvocation *inv = [NSInvocation invocationWithMethodSignature: sig];
							 [inv setSelector: firstWordSel];
							 [inv setTarget: self];
							 [inv setArgument:(void *)&inRestOfTag atIndex: 2];
							 [inv setArgument:(void *)&inScanner atIndex: 3];
							 //[inv setArgument:(void *)&inContext atIndex: 4];
							 
							 [inv invoke];
							 NSString *invokeResultString;
							 [inv getReturnValue:&invokeResultString];
							 */
							if ( nil != htmlFragment )
							{
								[htmlString appendString:htmlFragment];
							}
							else
							{
								LOG((@"[[%@ %@]] Invocation unexpectedly returned nil string!", keyword, inRestOfTag));
							}
						}
						else
						{
							LOG((@"Can't process %@: no method %@", tag, methodName));
						}
						
					}
				}
            }
        }
    }
    return [NSString stringWithString:htmlString];    
}

/*	These 3 methods are subclassed by KTStalenessHTMLParser, so be sure to update that too if appropriate
 */
- (NSString *)componentLocalizedString:(NSString *)tag
{
	NSString *theString = [tag substringFromIndex:1];			// String to localize in user's language
	
	NSBundle *theBundle = [[self cache] valueForKeyPath:@"plugin.bundle"];
	NSString *theNewString = [theBundle localizedStringForKey:theString value:@"" table:nil];
	//LOG((@"USER %@ -> %@", theString, theNewString));
	
	return [theNewString stringByEscapingHTMLEntities];
}

- (NSString *)componentTargetLocalizedString:(NSString *)tag
{
	NSString *theString = [tag substringFromIndex:1];			// String to localize in TARGET language
	
	NSBundle *theBundle = [[self cache] valueForKeyPath:@"plugin.bundle"];
	NSString *language = [[self cache] valueForKeyPath:@"CurrentPage.master.language"];
	if (!language) language = @"en";	// fallback just in case
	NSString *theNewString = [theBundle localizedStringForString:theString language:language];
	
	// LOG((@"TARGET %@ -> %@", theString, theNewString));
	
	return [theNewString stringByEscapingHTMLEntities];
}

- (NSString *)mainBundleLocalizedString:(NSString *)tag
{
	NSString *result = [tag substringFromIndex:1];			// String to localize in TARGET language
	
	NSString *language = [[self cache] valueForKeyPath:@"parser.currentPage.master.language"];
	if (language)
	{
		result = [[NSBundle mainBundle] localizedStringForString:result language:language];
	}
	
	return [result stringByEscapingHTMLEntities];
}

+ (NSCharacterSet *)keyPathIndicatorCharacters
{
	static NSCharacterSet *sIndicatorCharacterSet = nil;
	
	if (!sIndicatorCharacterSet)
	{
		sIndicatorCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"=&%_"] retain];
	}
	
	return sIndicatorCharacterSet;
}

#pragma mark -
#pragma mark Comment Function

- (NSString *)commentWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	return @"";
}

#pragma mark -
#pragma mark If Function

- (NSString *)ifWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	myIfCount++;
	NSString *elseDelim = @"[[else]]";
	NSString *endifDelim = @"[[endif]]";
	if (myIfCount > 1)
	{
		elseDelim = [NSString stringWithFormat:@"[[else%d]]", myIfCount];
		endifDelim = [NSString stringWithFormat:@"[[endif%d]]", myIfCount];
	}
	
	int beforeScanLocation = [inScanner scanLocation];
	NSString *stuffUntilEndIf;
	if ( ![inScanner scanUpToRealString:endifDelim intoString:&stuffUntilEndIf] ||
		![inScanner scanRealString:endifDelim intoString:nil] )
	{
		NSLog(@"if: missing %@ tag, looking starting at %@", endifDelim, [[inScanner string] substringFromIndex:beforeScanLocation]);
		return @"";
	}
	// Look for the optional else tag; split into the 'true' and 'false' parts.
	NSString *stuffIfTrue = @"";
	NSString *stuffIfFalse = @"";
	
	if (stuffUntilEndIf)
	{
		NSScanner *elseScanner = [NSScanner scannerWithString:stuffUntilEndIf];
		[elseScanner setCharactersToBeSkipped:nil];
		
		// Try to scan up to the else to get the "true" branch
		[elseScanner scanUpToRealString:elseDelim intoString:&stuffIfTrue];
		
		// If we find an else, then get the "false" branch
		if ( [elseScanner scanRealString:elseDelim intoString:nil] )
		{
			// Found an else; put the rest of it into the false part
			stuffIfFalse = [stuffUntilEndIf substringFromIndex:[elseScanner scanLocation]];
		}
		else
		{
			// no else, so it's all the true part; the else is effectively empty.
			stuffIfTrue = stuffUntilEndIf;
		}
	}
	// Parse rest of tag, and try to separate into three pieces: LHS, comparator, and RHS
	NSString *left = nil;
	NSString *right = nil;
	ComparisonType comparisonType = [inRestOfTag parseComparisonintoLeft:&left right:&right];
	if (kCompareUnknown == comparisonType || nil == left || (nil == right && (comparisonType != kCompareNotEmpty && comparisonType != kCompareNotEmptyOrEditing)) )
	{
		NSLog(@"if: unable to find valid comparison '%@'", inRestOfTag);
		return @"";
	}
	
	// Now do the comparison.  If greater/less operations, we convert to numbers.
	id leftValue = [self parseValue:left];
	id rightValue = [self parseValue:right];
	BOOL compareResult = [self compareIfStatement:comparisonType leftValue:leftValue rightValue:rightValue];
	
	// Now parse whatever piece we are supposed to use
	NSScanner *ifScanner = [NSScanner scannerWithString:compareResult ? stuffIfTrue : stuffIfFalse];
	[ifScanner setCharactersToBeSkipped:nil];
	
	NSString *result = [self HTMLStringByScanning:ifScanner];
	
	myIfCount--;
	return result;
}

- (BOOL)compareIfStatement:(ComparisonType)comparisonType leftValue:(id)leftValue rightValue:(id)rightValue
{
	BOOL result = NO;
	switch (comparisonType)
	{
		case kCompareNotEmpty:	// return true if item is nil, or collection is empty, or string is empty, or number is non-zero
			result = [self isNotEmpty:leftValue];
			break;
		case kCompareOr:
			result = [self isNotEmpty:leftValue] || [self isNotEmpty:rightValue];
			break;
		case kCompareAnd:
			result = [self isNotEmpty:leftValue] && [self isNotEmpty:rightValue];
			break;
		case kCompareEquals:
			result = [leftValue isEqual:rightValue];
			break;
		case kCompareNotEquals:
			result = ![leftValue isEqual:rightValue];
			break;
		case kCompareLess:
			result = ( [leftValue intValue] < [rightValue intValue] );
			break;
		case kCompareLessEquals:
			result = ( [leftValue intValue] <= [rightValue intValue] );
			break;
		case kCompareMore:
			result = ( [leftValue intValue] > [rightValue intValue] );
			break;
		case kCompareMoreEquals:
			result = ( [leftValue intValue] >= [rightValue intValue] );
			break;
		case kCompareUnknown:
			break;
		default:
			OBASSERT_NOT_REACHED("Unknown comparison type");
			break;
	}
	
	return result;
}

- (BOOL)isNotEmpty:(id)aValue
{
	BOOL result = NO;
	if (nil == aValue) {
		result = NO;		// It's nil, so it's empty.  All done.
	} else if ([aValue respondsToSelector: @selector(count)]) {
		// handles NSArray, NSDictionary, NSIndexSet, NSSet, etc.
		result = (0 !=[((NSArray *)aValue) count]); 
	} else if ([aValue respondsToSelector: @selector(length)]) {
		// handles NSAttributedString, NSString, NSData, etc.
		result = (0 != [((NSString *)aValue) length]); 
	} else if ([aValue respondsToSelector: @selector(intValue)]) {
		// handles NSAttributedString, NSString, NSData, etc.
		result = (0 != [((NSString *)aValue) intValue]); 
	} else {
		// handle everything else -- return true if not nil, like for media
		result = (nil != aValue); 
	}
	return result;
}


- (NSString *)endifWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSLog(@"[[endif...] tag found not balanced with previous [[if...]] tag at %@", [[inScanner string] annotatedAtOffset:[inScanner scanLocation]]);
	[NSException raise: NSInternalInconsistencyException
				format: @"[[endif...] tag found not balanced with previous [[if...]] tag"];
	return @"";
}

- (NSString *)elseWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSLog(@"[[else...] tag found not balanced with previous [[if...]] tag at %@", [[inScanner string] annotatedAtOffset:[inScanner scanLocation]]);
	[NSException raise: NSInternalInconsistencyException
				format: @"[[else...] tag found not balanced with previous [[if...]] tag"];
	return @"";
}

#pragma mark -
#pragma mark ForEach Loops

- (unsigned int)currentForeachLoopIndex
{
	unsigned int result = NSNotFound;
	if (myForEachIndexes)
	{
		result = [myForEachIndexes lastIndex];
	}
	return result;
}

/*	The number of items in the current foreach loop.
 */
- (unsigned int)currentForeachLoopCount
{
	unsigned int result = NSNotFound;
	if (myForEachCounts)
	{
		result = [myForEachCounts lastIndex];
	}
	return result;
}

- (unsigned int)currentForeachLoopDepth
{
	unsigned int result = 0;
	
	if (myForEachIndexes)
	{
		result = [myForEachIndexes length];
	}
	
	return result;
}

- (void)incrementCurrentForeachLoop
{
	NSIndexPath *newIndexPath = [myForEachIndexes indexPathByIncrementingLastIndex];
	[myForEachIndexes release];
	myForEachIndexes = [newIndexPath retain];
}

- (void)enterNewForeachLoopWithCount:(unsigned int)count
{
	if (myForEachIndexes)
	{
		NSIndexPath *newIndexPath = [myForEachIndexes indexPathByAddingIndex:1];
		[myForEachIndexes release];
		myForEachIndexes = [newIndexPath retain];
		
		NSIndexPath *newCountPath = [myForEachCounts indexPathByAddingIndex:count];
		[myForEachCounts release];
		myForEachCounts = [newCountPath retain];
	}
	else
	{
		myForEachIndexes = [[NSIndexPath alloc] initWithIndex:1];
		myForEachCounts = [[NSIndexPath alloc] initWithIndex:count];
	}
}

- (void)exitCurrentForeachLoop
{
	NSIndexPath *newIndexPath = [myForEachIndexes indexPathByRemovingLastIndex];
	[myForEachIndexes release];
	myForEachIndexes = [newIndexPath retain];
	
	NSIndexPath *newCountPath = [myForEachCounts indexPathByRemovingLastIndex];
	[myForEachCounts release];
	myForEachCounts = [newCountPath retain];
}

- (NSString *)foreachWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	// Put together the parameters and complain if they are incorrect
	NSArray *params = [inRestOfTag componentsSeparatedByWhitespace];
	if ([params count] < 2 || [params count] > 3)
	{
		NSLog(@"forEach: usage [[ forEach array.keyPath newElement (max.keyPath) ]]");
		return @"";
	}
	
	
	// Load the array to loop over
	NSArray *arrayToRepeat = [[self cache] valueForKeyPath:[params objectAtIndex:0]];
	
	unsigned int numberIterations = [arrayToRepeat count];
	if ([params count] > 2)
	{
		unsigned int specifiedNumberIterations = [[self parseValue:[params objectAtIndex:2]] unsignedIntValue];
		if (specifiedNumberIterations > 0) {
			numberIterations = specifiedNumberIterations;
		}
	}
	
	
	// Begin the new loop
	[self enterNewForeachLoopWithCount:numberIterations];
	
	
	// Get the HTML within the loop to scan
	NSString *endForEachDelim = @"[[endForEach]]";
	if ([self currentForeachLoopDepth] > 1)
	{
		endForEachDelim = [NSString stringWithFormat:@"[[endForEach%d]]", [self currentForeachLoopDepth]];
	}
	
	
	
	NSMutableString *result = [NSMutableString string];
	NSString *stuffToRepeat;
	if ( [inScanner scanUpToRealString:endForEachDelim intoString:&stuffToRepeat]
		&&
		(nil != stuffToRepeat)
		&&
		[inScanner scanRealString:endForEachDelim intoString:nil] )
	{
		NSString *keyForNewElement = [params objectAtIndex:1];
		NSEnumerator *theEnum = [arrayToRepeat objectEnumerator];
		id object;
		
		while (nil != (object = [theEnum nextObject]) )
		{
			NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
			
			// We override the specified key in the cache so that KVC calls are directed to the right object
			[[self cache] overrideKey:keyForNewElement withValue:object];
			
			// need a scanner up to next endForEach
			NSScanner *eachScanner = [NSScanner scannerWithString:stuffToRepeat];
			[eachScanner setCharactersToBeSkipped:nil];
			
			NSString *eachResult = [self HTMLStringByScanning:eachScanner];
			[result appendString:eachResult];
			
			// And then remove the override
			[[self cache] removeOverrideForKey:keyForNewElement];
			
			[innerPool release];
			
			[self incrementCurrentForeachLoop];
			
			if ([self currentForeachLoopIndex] > [self currentForeachLoopCount])	// break if we've hit the max
			{
				break;
			}
		}
	}
	else
	{
		NSLog(@"forEach: missing %@ tag", endForEachDelim);
		result = @"";
	}
	
	[self exitCurrentForeachLoop];
	
	return [NSString stringWithString:result];
}

/*!	return index of forEach loop (prefixed with "i"), or empty string if out of a loop
 */
- (NSString *)iWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [self currentForeachLoopIndex];
	if (index != NSNotFound)
	{
		result = [NSString stringWithFormat:@"i%i", index];
	}
	
	return result;
}

/*!	Return "e" or "o" for index in forEach loop being even or odd ... or empty string if out of a loop
 */
- (NSString *)eoWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [self currentForeachLoopIndex];
	if (index != NSNotFound)
	{
		result = (0 == (index % 2)) ? @"e" : @"o";
	}
	
	return result;
}

/*!	Return " last-item" if this is the last item in the loop; an empty string otherwise
 */
- (NSString *)lastWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [self currentForeachLoopIndex];
	if (index != NSNotFound)
	{
		int count = [self currentForeachLoopCount];
		if (index == count)
		{
			result = @" last-item";
		}
	}
	
	return result;
}

- (NSString *)endforeachWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSLog(@"[[endforeach...] tag found not balanced with previous [[forEach...]] tag at %@", [[inScanner string] annotatedAtOffset:[inScanner scanLocation]]);
	[NSException raise: NSInternalInconsistencyException
				format: @"[[endforeach...] tag found not balanced with previous [[forEach...]] tag"];
	return @"";
}

#pragma mark -
#pragma mark Support

- (id)parseValue:(NSString *)inString
{
	int parsedInt = 0;
	id result = @"";	// always have at least an empty string.
	
	if (nil != inString && ![inString isEqualToString:@""])
	{
		// Try to parse inString value -- as a constant integer, an literal string, or a key path value.
		if ([[NSScanner scannerWithString:inString] scanInt:&parsedInt])
		{
			result = [NSNumber numberWithInt:parsedInt];
		}
		else if ([inString hasPrefix:@"\""] && [inString hasSuffix:@"\""])
		{
			result = [inString substringWithRange:NSMakeRange(1, [inString length] - 2)];
		}
		else if ([inString hasPrefix:@"'"] && [inString hasSuffix:@"'"])
		{
			result = [inString substringWithRange:NSMakeRange(1, [inString length] - 2)];
		}
		else	// not a literal number or string; interpret as a keypath
		{
			result = [[self cache] valueForKeyPath:inString];
			if (nil == result)
			{
				result = @"";		
			}
		}
	}
	return result;
}


/*	Builds up a dictionary from a string of parameters like this:
 *
 *		key1:object1 key2:object2
 */
+ (NSDictionary *)parametersDictionaryWithString:(NSString *)parametersString
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	if (parametersString)
	{
		NSScanner *scanner = [[NSScanner alloc] initWithString:parametersString];
		while (![scanner isAtEnd])
		{
			// Scan the key
			NSString *aKey = nil;
			[scanner scanUpToString:@":" intoString:&aKey];
			[scanner scanString:@":" intoString:NULL];
			
			// Scan up to the value (the template might leave a space between key & value)
			[scanner scanUpToCharactersFromSet:[NSCharacterSet nonWhitespaceAndNewlineCharacterSet] intoString:NULL];
			
			// Scan the value. Handle quote marks a single long value containing spaces.
			NSString *aValue = nil;
			if ([parametersString characterAtIndex:[scanner scanLocation]] == '"')
			{
				[scanner setScanLocation:([scanner scanLocation] + 1)];
				[scanner scanUpToString:@"\"" intoString:&aValue];
				[scanner scanUpToCharactersFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet] intoString:NULL];
			}
			else
			{
				[scanner scanUpToCharactersFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet] intoString:&aValue];
			}
			
			// Store the key-value pair
			if (aKey && aValue)
			{
				[result setObject:aValue forKey:aKey];
			}
			
			// Scan up to the next key
			[scanner scanCharactersFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet] intoString:NULL];
		}
		
		// Tidy up
		[scanner release];
	}
	return result;
}

@end


#pragma mark -


/*  This little bunch of categories will get us the string value of an object. The default is
 *  to use -description but there's a few special cases.
 */


@implementation NSObject (KTTemplateParserAdditions)

- (NSString *)templateParserStringValue
{
    return [self description];
}

@end


@implementation NSURL (KTTemplateParserAdditions)

- (NSString *)templateParserStringValue
{
    return [self absoluteString];
}

@end

