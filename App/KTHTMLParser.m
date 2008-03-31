//
//  KTHTMLParser.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTHTMLParser+Private.h"
#import "KTHTMLParserMasterCache.h"

#import "Debug.h"
#import "KTDocument.h"	// for constants, methods
#import "KTMaster.h"
#import "KTPage.h"
#import "KTArchivePage.h"

#import "KTMediaManager.h"
#import "KTInDocumentMediaFile.h"
#import "KTExternalMediaFile.h"

#import "KTSummaryWebViewTextBlock.h"

#import "BDAlias+QuickLook.h"
#import "NSBundle+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "NSString+KTExtensions.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "KTMediaContainer.h"

@interface KTHTMLParser ()

- (void)setParentParser:(KTHTMLParser *)parser;

- (NSString *)startHTMLStringByScanning:(NSScanner *)inScanner;
- (NSString *)HTMLStringByScanning:(NSScanner *)inScanner;

- (KTHTMLParserMasterCache *)cache;
- (void)setCache:(KTHTMLParserMasterCache *)cache;

- (BOOL)prepareToParse;
- (void)finishParsing;

- (NSString *)componentLocalizedString:(NSString *)tag;
- (NSString *)componentTargetLocalizedString:(NSString *)tag;
- (NSString *)mainBundleLocalizedString:(NSString *)tag;

- (BOOL)isNotEmpty:(id)aValue;
- (KTDocument *)document;
- (void)setDocument:(KTDocument *)aDocument;

// Support
- (id)parseValue:(NSString *)inString;

@end




@implementation KTHTMLParser

static NSString *kComponentTagStartDelim = @"[[";
static NSString *kComponentTagEndDelim = @"]]";

static NSString *kKeyPathIndicator = @"=";
static NSString *kEscapeHTMLIndicator = @"&";
static NSString *kSpacesToUnderscoreIndicator = @"_";

static NSString *kEncodeURLIndicator = @"%";
static NSString *kTargetStringIndicator = @"\"";			// [[" String to localized in TARGET language Doesn't want a closing delimeter.
static NSString *kTargetMainBundleStringIndicator = @"`";	// [[` String to localized in TARGET language -- but stored in Main Bundle ...  Doesn't want a closing delimeter.
static NSString *kStringIndicator = @"'";					// [[' String to localize in current language. Doesn't want a closing delimeter.

static unsigned sLastParserID;


#pragma mark -
#pragma mark Class Methods

+ (NSCharacterSet *)indicatorCharacters
{
	static NSCharacterSet *sIndicatorCharacterSet = nil;
	
	if (!sIndicatorCharacterSet)
	{
		sIndicatorCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"=&%_"] retain];
	}
	
	return sIndicatorCharacterSet;
}

+ (NSString *)calloutContainerTemplateHTML
{
	static NSString *sCalloutContainerTemplateHTML;
	
	if (!sCalloutContainerTemplateHTML)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTCalloutContainerTemplate" ofType:@"html"];
		sCalloutContainerTemplateHTML = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return sCalloutContainerTemplateHTML;
}


// Usual case, no absolute media paths
+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate component:(id)component
{
	return [self HTMLStringWithTemplate:aTemplate component:component useAbsoluteMediaPaths:NO];
}

/*	A convenience method for simple parsing tasks
 */
+ (NSString *)HTMLStringWithTemplate:(NSString *)aTemplate
						   component:(id <KTWebViewComponent>)component
			   useAbsoluteMediaPaths:(BOOL)useAbsoluteMediaPaths
{
	KTHTMLParser *parser = [[self alloc] initWithTemplate:aTemplate component:component];
	[parser setUseAbsoluteMediaPaths:useAbsoluteMediaPaths];
	
	NSString *result = [parser parseTemplate];
	
	[parser release];
	return result;
}

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithTemplate:(NSString *)HTMLTemplate component:(id <KTWebViewComponent>)parsedComponent
{
	[super init];
	
	if (!HTMLTemplate)
	{
		NSLog(@"-[KTHTMLParser initWithTemplate:component:]  -- Nil template");
		// how can we continue from here?
		[self release];
		return nil;
	}
	
	sLastParserID++;
	myID = [[NSString alloc] initWithFormat:@"%u", sLastParserID];
	
	myTemplate = [HTMLTemplate copy];
	
	myComponent = [parsedComponent retain];
	if ([parsedComponent isKindOfClass:[KTPage class]]) {
		[self setCurrentPage:(KTPage *)parsedComponent];
	}
	
	return self;
}

- (id)initWithPage:(KTAbstractPage *)page
{
	// Archive pages are specially parsed so that the component is the parent page.
	KTPage *component = (KTPage *)page;
	if ([page isKindOfClass:[KTArchivePage class]]) component = [page parent];
	
	
	// Pick the right template to use
	NSString *template;
	if ([component pluginHTMLIsFullPage]) {
		template = [component templateHTML];
	}
	else {
		template = [[component class] pageTemplate];
	}
	
	
	// Create the parser and set up as much of the environment as possible
	[self initWithTemplate:template component:component];
	[self setCurrentPage:page];
	
	
	return self;
}

- (void)dealloc
{
	[myTemplate release];
	[myComponent release];
	[myCache release];
	[myCurrentPage release];
	[myLiveDataFeeds release];
	[myOverriddenKeys release];
	
	[myForEachIndexes release];
	[myForEachCounts release];
	
	[myID release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)parserID { return myID; }

- (NSString *)templateHTML { return myTemplate; }

- (id <KTWebViewComponent>)component { return myComponent; }

- (KTHTMLParserMasterCache *)cache { return myCache; }

- (void)setCache:(KTHTMLParserMasterCache *)cache
{
	[cache retain];
	[myCache release];
	myCache = cache;
}

- (KTDocument *)document
{
    return myDocument; 
}

// Made a weak reference

- (void)setDocument:(KTDocument *)aDocument
{
//    [aDocument retain];
//    [myDocument release];
    myDocument = aDocument;
}

/*	Whenever parsing, it must be within the context of a particular page.
 *	e.g. A single pagelet may be parsed be 50 times, each on a different page.
 *	Use these two methods to specify which the component is being parsed in the context of.
 */
- (KTAbstractPage *)currentPage { return myCurrentPage; }

- (void)setCurrentPage:(KTAbstractPage *)page
{
	[page retain];
	[myCurrentPage release];
	myCurrentPage = page;
}

/*	This accessor pair is a replacement for -[KTDocument publishingmode]
 *	Instead of limiting HTML generating to a single mode at a time, we tell each parser what it is generating the HTML for.
 *	
 */
- (KTHTMLGenerationPurpose)HTMLGenerationPurpose { return myHTMLGenerationPurpose; }

- (void)setHTMLGenerationPurpose:(KTHTMLGenerationPurpose)purpose { myHTMLGenerationPurpose = purpose; }

/*	Used by templates to know if they're allowed external images etc.
 */
- (BOOL)liveDataFeeds
{
	// Publishing always has live feeds turned on
	KTHTMLGenerationPurpose mode = [self HTMLGenerationPurpose];
	if (mode == kGeneratingLocal || mode == kGeneratingRemote || mode == kGeneratingRemoteExport) {
		return YES;
	}
	
	// If a value has been explicitly set, use it.
	if (myLiveDataFeeds)
	{
		return [myLiveDataFeeds boolValue];
	}
	
	// Use the default for the generation mode
	BOOL result = NO;
	if (mode != kGeneratingQuickLookPreview)
	{
		result = [[NSUserDefaults standardUserDefaults] boolForKey:@"LiveDataFeeds"];
	}
	
	return result;
}

- (void)setLiveDataFeeds:(BOOL)flag
{
	[myLiveDataFeeds release];
	myLiveDataFeeds = [[NSNumber alloc] initWithBool:flag];
}

- (BOOL)useAbsoluteMediaPaths { return myUseAbsoluteMediaPaths; }

- (void)setUseAbsoluteMediaPaths:(BOOL)flag { myUseAbsoluteMediaPaths = flag; }

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
	NSAssert(key, @"Attempt to override a nil key");
	NSAssert(override, @"Attempt to override parser key with nil value");
	NSAssert1(([key rangeOfString:@"."].location == NSNotFound), @"\"%@\" is not a valid parser override key", key);
	NSAssert1(![[self _keyOverrides] objectForKey:key], @"The key \"%@\" is already overidden", key);
	
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
- (KTHTMLParser *)newChildParserWithTemplate:(NSString *)templateHTML component:(id <KTWebViewComponent>)component
{
	KTHTMLParser *parser = [[[self class] alloc] initWithTemplate:templateHTML component:component];
	
	[parser setParentParser:self];
	[parser setCurrentPage:[self currentPage]];
	[parser setHTMLGenerationPurpose:[self HTMLGenerationPurpose]];
	if (myLiveDataFeeds) [parser setLiveDataFeeds:[self liveDataFeeds]];
	[parser setDelegate:[self delegate]];
	[parser setUseAbsoluteMediaPaths:[self useAbsoluteMediaPaths]];
	
	return parser;
}

/*	[[parseComponent keypath.to.component keypath.to.templateHTML]]
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
		NSLog(@"parsecomponent: usage [[parseComponent keypath.to.component keypath.to.templateHTML]]");
	}
	else
	{
		id component = [[self cache] valueForKeyPath:[parameters objectAtIndex:0]];
		NSString *template = [[self cache] valueForKeyPath:[parameters objectAtIndex:1]];
		
		if (component)
		{
			KTHTMLParser *parser = [self newChildParserWithTemplate:template component:component];
			result = [parser parseTemplate];
			
			// If possible, wrap the result inside a uniqueID <div> to allow the WebViewController to identify it later.
			if ([component conformsToProtocol:@protocol(KTWebViewComponent)])
			{
				result = [NSString stringWithFormat:@"<div id=\"%@-%@\">\r%@\r</div>",
													[component uniqueWebViewID],
													[parser parserID],
													result];
			}
			
			// Tidy up
			[parser release];
		}
	}
	
	return result;
}

- (KTHTMLParser *)parentParser { return myParentParser; }

- (void)setParentParser:(KTHTMLParser *)parser { myParentParser = parser; }

#pragma mark -
#pragma mark Delegate

- (id)delegate { return myDelegate; }

- (void)setDelegate:(id)delegate { myDelegate = delegate; }		// It's a weak ref

- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didEncounterKeyPath:ofObject:)])
	{
		[delegate HTMLParser:self didEncounterKeyPath:keyPath ofObject:object];
	}
}

- (void)didEncounterMediaFile:(KTAbstractMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didParseMediaFile:upload:)])
	{
		[delegate HTMLParser:self didParseMediaFile:mediaFile upload:upload];
	}
}

- (void)didEncounterResourceFile:(NSString *)resourcePath
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didEncounterResourceFile:)])
	{
		[delegate HTMLParser:self didEncounterResourceFile:resourcePath];
	}
}

- (void)didParseTextBlock:(KTWebViewTextBlock *)textBlock
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didParseTextBlock:)])
	{
		[delegate HTMLParser:self didParseTextBlock:textBlock];
	}
}

#pragma mark -
#pragma mark Parsing

- (NSString *)parseTemplate
{
	NSString *result = nil;
	@try
	{
		BOOL readyToParse = [self prepareToParse];
		if (!readyToParse) {
			return nil;
		}
		
		NSScanner *scanner = [NSScanner scannerWithString:[self templateHTML]];
		[scanner setCharactersToBeSkipped:nil];
		result = [self startHTMLStringByScanning:scanner];
		result = [result removeMultipleNewlines];
	}
	@finally
	{
		[self finishParsing];
	}
	
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
	if ([self currentPage]) [[self cache] overrideKey:@"CurrentPage" withValue:[self currentPage]];
	[cache overrideKey:@"HTMLGenerationPurpose" withValue:[NSNumber numberWithInt:[self HTMLGenerationPurpose]]];
	[cache overrideKey:@"userDefaults" withValue:[NSUserDefaults standardUserDefaults]];
	[cache overrideKey:@"calloutContainerTemplateHTML" withValue:[[self class] calloutContainerTemplateHTML]];
	
	NSEnumerator *overridesEnumerator = [myOverriddenKeys keyEnumerator];
	NSString *aKey;
	while (aKey = [overridesEnumerator nextObject])
	{
		[cache overrideKey:aKey withValue:[[self _keyOverrides] objectForKey:aKey]];
	}

	
	if ([parsedComponent  isKindOfClass:[KTPage class]])
	{
		KTPage *page = (KTPage *)parsedComponent;
		KTDocument *document = [page document];
		[document setUseAbsoluteMediaPaths:[self useAbsoluteMediaPaths]];	// set this value when we set the outer context
	}
	
	/*	This doesn't seem to be actually used.
	// Hack -- don't do this for news controller
	Class contextClass = NSClassFromString([parsedComponent className]);
	
	if (![contextClass isSubclassOfClass:[NSXMLElement class]]) {
		[self setDocument:[parsedComponent valueForKey:@"document"]];
	}*/	
	
	
	
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
                      [inScanner scanString:kComponentTagEndDelim intoString:nil] ) {
                
				// LOG((@"scanner found tag: %@", tag));
                
                if ( [tag hasPrefix:kKeyPathIndicator] )
				{
                    NSScanner *tagScanner = [NSScanner scannerWithString:tag];
					[tagScanner setCharactersToBeSkipped:nil];

                    NSString *keyPath;

					// switch to key path
					NSString *indicatorChars;
                    [tagScanner scanCharactersFromSet:[[self class] indicatorCharacters]
										   intoString:&indicatorChars];
					int htmlEscapeLocation = [indicatorChars rangeOfString:kEscapeHTMLIndicator].location;
					int urlEncodeLocation  = [indicatorChars rangeOfString:kEncodeURLIndicator].location;
					int spacesToUnderscoreLocation  = [indicatorChars rangeOfString:kSpacesToUnderscoreIndicator].location;
					
                    // grab the class name to instantiate
                    // grab the key path
                    keyPath = [[tag substringFromIndex:[tagScanner scanLocation]] condenseWhiteSpace];
                    
//                    LOG((@"keyPath = %@", keyPath));
                    
                    // do we already have an instance in the page's cache?
                    id element = nil;
					
					// Wrap this in an exception handler so we are more forgiving of errors
					@try {
						element = [[self cache] valueForKeyPath:keyPath];

					}
					@catch (NSException *exception) {
						NSLog(@"HTMLStringByScanning:... %@ %@", keyPath, [exception reason]);
					}
                    
                    if ( nil == element ) {
						//LOG((@"%@ [[=%@]] element not found", inContext, keyPath));
						LOG((@"[[=%@]] element not found", keyPath));
						continue;
					}
					else
					{
						NSString *toAppend = [element description];		// convert to a string
						
						// first replace spaces with an underscore
						if (NSNotFound != spacesToUnderscoreLocation)
						{
							toAppend = [toAppend legalizeURLNameWithFallbackID:@"_"];	// doesn't really matter if we lose everything
						}
						
						// now deal with url encoding and/or html escaping
						
						if ((NSNotFound != urlEncodeLocation) && (NSNotFound != htmlEscapeLocation))	// both?
						{
							if (urlEncodeLocation < htmlEscapeLocation)	// URL Encode first
							{
								toAppend = [toAppend urlEncode];
								toAppend = [toAppend escapedEntities];
							}
							else	// HTML escape first
							{
								toAppend = [toAppend escapedEntities];
								toAppend = [toAppend urlEncode];
							}
							
						}
						else
						{
							if (NSNotFound != urlEncodeLocation)
							{
								toAppend = [toAppend urlEncode];
							}
							if (NSNotFound != htmlEscapeLocation)
							{
								toAppend = [toAppend escapedEntities];
							}
						}
						[htmlString appendString:toAppend];
					}
                }
                else if ([tag hasPrefix:kStringIndicator])
                {
					[htmlString appendString:[self componentLocalizedString:tag]];
                }
				else if ([tag hasPrefix:kTargetStringIndicator])
				{
					[htmlString appendString:[self componentTargetLocalizedString:tag]];
                }
				else if ([tag hasPrefix:kTargetMainBundleStringIndicator])
				{
					[htmlString appendString:[self mainBundleLocalizedString:tag]];
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
    return [NSString stringWithString:htmlString];    
}

/*	These 3 methdos are subclassed by KTStalenessHTMLParser, so be sure to update that too if appropriate
 */
- (NSString *)componentLocalizedString:(NSString *)tag
{
	NSString *theString = [tag substringFromIndex:1];			// String to localize in user's language

	NSBundle *theBundle = [[self cache] valueForKeyPath:@"plugin.bundle"];
	NSString *theNewString = [theBundle localizedStringForKey:theString value:@"" table:nil];
	//LOG((@"USER %@ -> %@", theString, theNewString));

	return [theNewString escapedEntities];
}

- (NSString *)componentTargetLocalizedString:(NSString *)tag
{
	NSString *theString = [tag substringFromIndex:1];			// String to localize in TARGET language

	NSBundle *theBundle = [[self cache] valueForKeyPath:@"plugin.bundle"];
	NSString *language = [[self cache] valueForKeyPath:@"CurrentPage.master.language"];
	if (!language) language = @"en";	// fallback just in case
	NSString *theNewString = [theBundle localizedStringForString:theString language:language];
	
	// LOG((@"TARGET %@ -> %@", theString, theNewString));

	return [theNewString escapedEntities];
}

- (NSString *)mainBundleLocalizedString:(NSString *)tag
{
	NSString *theString = [tag substringFromIndex:1];			// String to localize in TARGET language
	
	NSString *language = [[self cache] valueForKeyPath:@"CurrentPage.master.language"];
	NSString *theNewString = [[NSBundle mainBundle] localizedStringForString:theString language:language];
	
	//LOG((@"MAINBUNDLE TARGET %@ -> %@", theString, theNewString));
	
	return [theNewString escapedEntities];
}

#pragma mark -
#pragma mark Functions

- (NSString *)commentWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	return @"";
}

- (NSString *)targetWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"target: usage [[ target otherPage.keyPath ]]");
		return @"";
	}
	
	// If linking to an External Link page set to "open in new window," force the link to open in a new window
	BOOL openInNewWindow = NO;
	id targetPageDelegate = [[[self cache] valueForKeyPath:inRestOfTag] delegate];
	if (targetPageDelegate && [targetPageDelegate respondsToSelector:@selector(openInNewWindow)]) {
		openInNewWindow = [[targetPageDelegate valueForKey:@"openInNewWindow"] boolValue];
	}
	
	if (openInNewWindow)
	{
		return @"target=\"_BLANK\" ";
	}
	else
	{
		return @"";
	}
}

- (NSString *)cssWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	return @"";
}
/*!	ID/Class generator.  The IDs of clickable items are pretty complex, so this builds them and creates
	the id="foo" class="bar" HTML (with leading space), so put this right after the tag type.

	You pass parameters kind of like objC, but in any order.  parameter keyword followed by :
		then either a single word up to the next space, or multiple words in quotes.

	keywords allowed:
		
		entity - like Document, Page, Element, Pagelet.  With optioanl _anything suffix just to keep unique
		property - for editing, what property (key-value) does this ID'd object get loaded from/saved to?
		flags: one or more of:
			block - editable as a block of text, one or more paragraphs
			line - editable as a single line, no newlines allowed
			optional - if empty contents, this div will be taken out
			RootNotOptional -- special; overrides optional if this is the root
			summary - this is a summary of existing content and is not editable (without override?)
		id - the keypath to the uniqueID of this object
		replacement - keypath of flat text to replace when using image replacement
		code - code (h1,h1h,h2,h3,h4s,h4c,m,mc,st) for matching to image replacement.
		class - additional class (or classes separated by space) to apply to this element.
			(dynamic, special classes will be appended to this list for editing purposes)
*/
- (NSString *)idclassWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
//	NSLog(@"[[idclass %@]]", inRestOfTag);

	NSString *pseudoEntity = nil;
	NSString *code = nil;

	NSString *uniqueID = nil;
	NSString *flatProperty = nil;
	NSString *flatPropertyValue = nil;
	NSString *property = nil;
	NSString *propertyValue = nil;
	NSMutableArray *classes = [NSMutableArray array];

	NSScanner *scanner = [NSScanner scannerWithString:inRestOfTag];
	while ( ![scanner isAtEnd] )
	{
		NSString *keyword;
		BOOL foundKeyword = [scanner scanUpToString:@":" intoString:&keyword];
		if (!foundKeyword || ![scanner scanString:@":" intoString:nil])
		{
			[self raiseExceptionWithName:kKTTemplateParserException 
								  reason:@"cannot scan keyword up to ':'"];
		}
		keyword = [keyword lowercaseString];
		
		NSString *value = @"";
		BOOL foundQuote = [scanner scanString:@"\"" intoString:nil];
		if (foundQuote)
		{
			[scanner scanUpToString:@"\"" intoString:&value];
			foundQuote = [scanner scanString:@"\"" intoString:nil];
			if (!foundQuote)
			{
				[self raiseExceptionWithName:kKTTemplateParserException 
									  reason:@"cannot scan to closing \""];
			}
		}
		else	// not quote mark, just scan to next white space
		{
			[scanner scanUpToString:@" " intoString:&value];
		}
		
		// Now we have a key and a value
//		NSLog(@"Have Key: %@ .... value: %@", keyword, value);
		
		if ([keyword isEqualToString:@"entity"])
		{
			pseudoEntity = value;
		}
		else if ([keyword isEqualToString:@"property"])
		{
			property = value;
			propertyValue = [[self cache] valueForKeyPath:value];
		}
		else if ([keyword isEqualToString:@"flags"])
		{
			// Only generate these special classes if we are doing the local preview
			if ([self HTMLGenerationPurpose] == kGeneratingPreview)
			{		
				value = [value lowercaseString];	// convert to lowercase before converting to classes
				NSArray *flags = [value componentsSeparatedByWhitespace];
				BOOL rootNotOptional = [flags containsObject:@"rootnotoptional"];
				
				NSEnumerator *theEnum = [flags objectEnumerator];
				NSString *flag;

				while (nil != (flag = [theEnum nextObject]) )
				{
					if (rootNotOptional && [[[self cache] valueForKey:@"isRoot"] boolValue] && [flag isEqualToString:@"optional"])
					{
						// ignore optional flag
					}
					else
					{
						[classes addObject:
							[NSString stringWithFormat:@"k%@", [flag capitalizedString]]];
					}
				}
			}
		}
		else if ([keyword isEqualToString:@"id"])
		{
			uniqueID = [[self cache] valueForKeyPath:value];
		}
		else if ([keyword isEqualToString:@"replacement"])	// key path to property to replace, flattened version of property
		{
			flatProperty = value;
			flatPropertyValue = [[self cache] valueForKeyPath:value];
			NSAssert1(flatPropertyValue, @"flatPropertyValue for keypath %@ cannot be null", value);

		}
		else if ([keyword isEqualToString:@"code"])
		{
			code = value;
		}
		else if ([keyword isEqualToString:@"class"])
		{
			// Insert explicit classes at the beginning
			[classes replaceObjectsInRange:NSMakeRange(0,0) withObjectsFromArray:
				[value componentsSeparatedByWhitespace]];
		}
		else
		{
			NSLog(@"unknown keyword '%@' in [[idclass %@]]", keyword, inRestOfTag);
		}
	}
	
	NSAssert(pseudoEntity, @"entity cannot be null");
	NSAssert(property, @"property cannot be null");
	NSAssert(uniqueID, @"uniqueID cannot be null");
	NSString *resultingID = [NSString stringWithFormat:@"k-%@-%@-%@", pseudoEntity, property, uniqueID];
	if (nil != code)
	{
		resultingID = [NSString stringWithFormat:@"%@-%@", resultingID, code];
	}
	
	// Mark for image replacement ONLY if QC supported.
	KTAbstractPage *page = [self currentPage];
	if ([page isKindOfClass:[KTArchivePage class]]) page = [page parent];
	OBASSERT([page isKindOfClass:[KTPage class]]);

	//OBASSERT([self document]);

	
	NSString *result;
	// return ID string as an ID declaration for the HTML
	result = [NSString stringWithFormat:@" id=\"%@\"", resultingID];
	
	if ([classes count])
	{
		result = [NSString stringWithFormat:@"%@ class=\"%@\"", result, [classes componentsJoinedByString:@" "]];
	}
	
	return result;
	 
}

- (NSString *)endbodyWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	KTPage *page = (KTPage *)[self component];
	NSMutableString *string = [NSMutableString string];
	
	@try
	{
		[[page managedObjectContext] makeAllPluginsPerformSelector:@selector(addSitewideTextToEndBody:forPage:)
														withObject:string
														  withPage:[page root]];
		

		[page makeComponentsPerformSelector:@selector(addLevelTextToEndBody:forPage:) withObject:string withPage:page recursive:NO];
		
		//[page recursiveComponentPerformSelector:@selector(addPageTextToEndBody:forPage:) withObject:string];
		/// Wasn't actually being used by any plugins and is identical to -addLevelTextToEndBody:
	}
	@finally
	{
	}
	
	return string;
}

- (NSString *)extraheadersWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	KTPage *page = (KTPage *)[self component];
	NSMutableString *string = [NSMutableString string];
	
	@try
	{
		//[[page root] recursiveComponentPerformSelector:@selector(addSitewideTextToHead:forPage:) withObject:string];
		/// Disabled this for 1.2.1 since it currently slows down a lot on a large site.
		
		
		//[page makeComponentsPerformSelector:@selector(addLevelTextToHead:forPage:) withObject:string withPage:page];
		/// Unusued in any plugins so disabled for performance.
		
		[page makeComponentsPerformSelector:@selector(addPageTextToHead:forPage:) withObject:string withPage:page recursive:NO];
	}
	@finally
	{
	}
	
	return string;
}

/*	Support method that returns the path to the resource dependent of our HTML generation purpose.
 */
- (NSString *)resourceFilePathRelativeToCurrentPage:(NSString *)resourceFile
{
	NSString *result;
	switch ([self HTMLGenerationPurpose])
	{
		case kGeneratingPreview:
			result = [[NSURL fileURLWithPath:resourceFile] absoluteString];
			break;
		
		case kGeneratingQuickLookPreview:
			result = [[BDAlias aliasWithPath:resourceFile] quickLookPseudoTag];
			break;
			
		default:
			result = [[self currentPage] publishedPathForResourceFile:resourceFile];
			break;
	}
		
	// Tell the delegate
	[self didEncounterResourceFile:resourceFile];

	return result;
}

#pragma mark if

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
	if ( ![inScanner scanUpToString:endifDelim intoString:&stuffUntilEndIf] ||
		 ![inScanner scanString:endifDelim intoString:nil] )
	{
		NSLog(@"if: missing %@ tag, looking starting at %@", endifDelim, [[inScanner string] substringFromIndex:beforeScanLocation]);
		return @"";
	}
	// Look for the optional else tag; split into the 'true' and 'false' parts.
	NSString *stuffIfTrue = @"";
	NSString *stuffIfFalse = @"";
	
	NSScanner *elseScanner = [NSScanner scannerWithString:stuffUntilEndIf];
	[elseScanner setCharactersToBeSkipped:nil];

	// Try to scan up to the else to get the "true" branch
	[elseScanner scanUpToString:elseDelim intoString:&stuffIfTrue];
	
	// If we find an else, then get the "false" branch
	if ( [elseScanner scanString:elseDelim intoString:nil] )
	{
		// Found an else; put the rest of it into the false part
		stuffIfFalse = [stuffUntilEndIf substringFromIndex:[elseScanner scanLocation]];
	}
	else
	{
		// no else, so it's all the true part; the else is effectively empty.
		stuffIfTrue = stuffUntilEndIf;
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
	id leftValue = [self parseValue:left];
	id rightValue = [self parseValue:right];

	// Now do the comparison.  If greater/less operations, we convert to numbers.
	BOOL compareResult = NO;
	switch (comparisonType)
	{
		case kCompareNotEmptyOrEditing:	// mostly same test; we will "OR" with editing mode
			compareResult = ([self HTMLGenerationPurpose] == kGeneratingPreview)
				|| [self isNotEmpty:leftValue];
			break;
			
		case kCompareNotEmpty:	// return true if item is nil, or collection is empty, or string is empty, or number is non-zero
			compareResult = [self isNotEmpty:leftValue];
			break;
		case kCompareOr:
			compareResult = [self isNotEmpty:leftValue] || [self isNotEmpty:rightValue];
			break;
		case kCompareAnd:
			compareResult = [self isNotEmpty:leftValue] && [self isNotEmpty:rightValue];
			break;
		case kCompareEquals:
			compareResult = [leftValue isEqual:rightValue];
			break;
		case kCompareNotEquals:
			compareResult = ![leftValue isEqual:rightValue];
			break;
		case kCompareLess:
			compareResult = ( [leftValue intValue] < [rightValue intValue] );
			break;
		case kCompareLessEquals:
			compareResult = ( [leftValue intValue] <= [rightValue intValue] );
			break;
		case kCompareMore:
			compareResult = ( [leftValue intValue] > [rightValue intValue] );
			break;
		case kCompareMoreEquals:
			compareResult = ( [leftValue intValue] >= [rightValue intValue] );
			break;
		case kCompareUnknown:
			break;
	}
	
	// Now parse whatever piece we are supposed to use
	NSScanner *ifScanner = [NSScanner scannerWithString:compareResult ? stuffIfTrue : stuffIfFalse];
	[ifScanner setCharactersToBeSkipped:nil];

	NSString *result = [self HTMLStringByScanning:ifScanner];
		
	myIfCount--;
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
	NSLog(@"[[endif...] tag found not balanced with previous [[if...]] tag at scanLocation %d of string:%@", [inScanner scanLocation], [[inScanner string] substringToIndex:[inScanner scanLocation]]);
	return @"";
}

- (NSString *)elseWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSLog(@"[[else...] tag found not balanced with previous [[if...]] tag at scanLocation %d of string:%@", [inScanner scanLocation], [[inScanner string] substringToIndex:[inScanner scanLocation]]);
	return @"";
}

/*!	Claim ownership to the particular representation.  Use like this: [[media image.originalSize uniqueID]]
*/

// 
///  TO FIX someday maybe.  This is possibly obsolete, but I'm leaving it here in case we decide
// to go back and require you to call addRepresentationType on a media representation before using
// it.  In order to get this to work -- it didn't before -- I'd change it from taking 2 args
// to taking 3, the third being the string constant representing the media type.  Then we could
// use representationTypeForKey to convert the string to a KTMediaRepresentation, and then call
// addRepresentationType

/*
- (NSString *)mediaWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
//	NSArray *rawWords = [inRestOfTag componentsSeparatedByWhitespace];
//	NSMutableArray *words = [NSMutableArray arrayWithArray:rawWords];
//	[words removeObject:@""];		// get rid of empty spaces.
//	int count = [words count];
//	if (count != 2)
//	{
//		NSLog(@"Unable to parse [[media %@]]", inRestOfTag);
//		return @"";
//	}
//	KTMediaRepresentation *mediaRepresentation = nil;
//	NSString *ownerID = nil;
//	// Wrap this in an exception handler so we are more forgiving of errors
//	@try {
//		mediaRepresentation = [inContext valueForKeyPath:[words objectAtIndex:0]];
//		ownerID = [inContext valueForKeyPath:[words objectAtIndex:1]];
//	}
//	@catch (NSException *exception) {
//		NSLog(@"mediaWithParameters:... %@", [exception reason]);
//	}
//
//	if ( nil != mediaRepresentation )
//	{
//		[[self mediaManager] retainRepresentation:mediaRepresentation];
//	}
//	else
//	{
//		LOG((@"mediaWithParameters returned nil representation!"));
//	}
	return @"";
}
*/

#pragma mark media & resources

- (NSString *)mediainfoWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)scanner
{
	NSString *result = @"";
	
	// Build the parameters dictionary
	NSDictionary *parameters = [KTHTMLParser parametersDictionaryWithString:inRestOfTag];
	
	
	// Which MediaContainer is requested?
	KTMediaContainer *media = [[self cache] valueForKeyPath:[parameters objectForKey:@"media"]];
	
	if ([parameters objectForKey:@"sizeToFit"])
	{
		NSSize imageSize = [[[self cache] valueForKeyPath:[parameters objectForKey:@"sizeToFit"]] sizeValue];
		media = [media imageToFitSize:imageSize];
	}
	
	
	// What information is desired?
	KTAbstractMediaFile *mediaFile = [media file];
	KTMediaFileUpload *upload = nil;
	
	NSString *infoRequested = [parameters objectForKey:@"info"];
	if ([infoRequested isEqualToString:@"path"])
	{
		switch ([self HTMLGenerationPurpose])
		{
			case kGeneratingPreview:
			{
				NSString *path = [mediaFile currentPath];
				if (path) result = [[NSURL fileURLWithPath:path] absoluteString];
				break;
			}
			
			case kGeneratingQuickLookPreview:
				result = [mediaFile quickLookPseudoTag];
				break;
			
			default:
			{
				upload = [mediaFile defaultUpload];
				result = [upload pathRelativeTo:[self currentPage]];
				break;
			}
		}
	}
	else if ([infoRequested isEqualToString:@"width"])
	{
		result = [[mediaFile valueForKey:@"width"] stringValue];
	}
	else if ([infoRequested isEqualToString:@"height"])
	{
		result = [[mediaFile valueForKey:@"height"] stringValue];
	}
	
	
	// The delegate may want to know
	[self didEncounterMediaFile:mediaFile upload:upload];
	
	
	return result;
}

/*	Produces a link to the specified media file. Handles anything of the KTAbstractMediaFile class.
 *	Does NOT inform the delegate that the keypath was parsed.
 *
 *	Usage:	[[mediafile keypath.to.file]]
 */
- (NSString *)mediafileWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)scanner
{
	NSString *result = @"";
	
	// Check the right parameters were supplied.
	NSArray *parameters = [inRestOfTag componentsSeparatedByWhitespace];
	if ([parameters count] != 1)
	{
		NSLog(@"mediafile: usage [[mediafile keypath.to.file]]");
	}
	else
	{
		KTAbstractMediaFile *mediaFile = [[self cache] valueForKeyPath:[parameters objectAtIndex:0] informDelegate:YES];
		KTMediaFileUpload *upload = nil;
		
		// The link we provide depends on the HTML generation mode
		if ([self HTMLGenerationPurpose] == kGeneratingPreview)
		{
			NSString *path = [mediaFile currentPath];
			if (path) {
				result = [[[NSURL fileURLWithPath:path] absoluteString] escapedEntities];
			}
		}
		else
		{
			upload = [mediaFile defaultUpload];
			result = [upload pathRelativeTo:[self currentPage]];
		}
		
		// The delegate may want to know
		[self didEncounterMediaFile:mediaFile upload:upload];
	}
	
	return result;
}

/*
/// Mike:	The media function above should have replaced this.

// Following parameters:  (1) key-value path to media or mediaImage object  (2) k-v path to page [optional]
// If (2) not specified, it's the page itself... but template better be a page
// Should call mediaPathRelativeTo: on (1) with (2) as the parameter and return the result.

- (NSString *)mediapathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSArray *params = [inRestOfTag componentsSeparatedByWhitespace];
	if ([params count] > 2)
	{
		NSLog(@"mediapath: usage [[ mediapath media.keyPath page.keyPath (OPTIONAL) ]]");
		return @"";
	}
	id media = [[self cache] valueForKeyPath:[params objectAtIndex:0] informDelegate:NO];
	
	id page = nil;
	if ([params count] > 1)
	{
		page = [[self cache] valueForKeyPath:[params objectAtIndex:1]];
	}
	else	// try to get page from context.  Better be there!
	{
		page = [[self cache] valueForKey:@"CurrentPage"];
	}
	return [media mediaPathRelativeTo:page];
}

*/

/*!	Like above, but returns the full URL
*/
- (NSString *)mediaurlWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSArray *params = [inRestOfTag componentsSeparatedByWhitespace];
	if ([params count] > 1)
	{
		NSLog(@"mediaurl: usage [[ mediapath media.keyPath]]");
		return @"";
	}
	id media = [[self cache] valueForKeyPath:[params objectAtIndex:0]];
	
	return [[media publishedURL] absoluteString];
}

// Following parameters:  (1) key-value path to media or mediaImage object  (2) k-v path to page [optional]
// If (2) not specified, it's the page itself... but template better be a page
// Should call resourcePathRelativeTo: on (1) with (2) as the parameter and return the result.

- (NSString *)resourcepathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	// Check suitable parameters were supplied
	NSArray *params = [inRestOfTag componentsSeparatedByWhitespace];
	if ([params count] > 2)
	{
		NSLog(@"resourcepath: usage [[ resourcepath resource.keyPath page.keyPath (OPTIONAL) ]]");
		return @"";
	}
	
	// Figure out the correct page
	KTAbstractPage *page = [self currentPage];
	if ([params count] > 1)
	{
		page = [[self cache] valueForKeyPath:[params objectAtIndex:1]];
	}
    
    // Where is the resource file on disk?
	NSString *resourceFilePath = [[self cache] valueForKeyPath:[params objectAtIndex:0]];
	
	NSString *result = nil;
    if (page && resourceFilePath)
    {
        // The generated link depends on its use
		switch ([self HTMLGenerationPurpose])
		{
			case kGeneratingPreview:
				result = [[NSURL fileURLWithPath:resourceFilePath] absoluteString];
				break;
			
			case kGeneratingQuickLookPreview:
				result = [[BDAlias aliasWithPath:resourceFilePath] quickLookPseudoTag];
				break;
				
			default:
				result = [page publishedPathForResourceFile:resourceFilePath];
				break;
		}
		
		// The delegate may want to know
		[self didEncounterResourceFile:resourceFilePath];
    }
	
	return result;
}

- (NSString *)rsspathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"path: usage [[ rsspath otherPage.keyPath ]]");
		return @"";
	}
	
	id sourcePage = [[self cache] valueForKey:@"CurrentPage"];	
	KTPage *targetPage = [[self cache] valueForKeyPath:inRestOfTag];
	return [targetPage feedURLPathRelativeToPage: sourcePage];
}

// Following parameters:  (1) key-value path to another page

- (NSString *)pathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"path: usage [[ path otherPage.keyPath ]]");
		return @"";
	}
	
	KTPage *targetPage = [[self cache] valueForKeyPath:inRestOfTag];
	NSString *result = [self pathToPage:targetPage];
	return result;
}

- (NSString *)pathToPage:(KTAbstractPage *)page
{
	NSString *result;
	
	switch ([self HTMLGenerationPurpose])
	{
		case kGeneratingPreview:
			result = [page previewPath];
			break;
		case kGeneratingQuickLookPreview:
			result= @"javascript:void(0)";
			break;
		default:
			result = [page pathRelativeTo:[self currentPage]];
			break;
	}
	
	return result;
}

#pragma mark foreach loops

- (unsigned int)currentForeachLoopIndex
{
	unsigned int result = NSNotFound;
	if (myForEachIndexes)
	{
		result = [myForEachIndexes indexAtEndPosition];
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
		result = [myForEachCounts indexAtEndPosition];
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
	if ( [inScanner scanUpToString:endForEachDelim intoString:&stuffToRepeat] && 
			  [inScanner scanString:endForEachDelim intoString:nil] )
	{
		@try
		{	// Wrap this in an exception handler so we are more forgiving of errors
		
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
		@catch (NSException *exception) {
			NSLog(@"foreachWithParameters:... Caught %@: %@", [exception name], [exception reason]);
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
	NSLog(@"[[endforeach...] tag found not balanced with previous [[forEach...]] tag at scanLocation %d of string:%@", [inScanner scanLocation], [[inScanner string] substringToIndex:[inScanner scanLocation]]);
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
	return result;
}

@end
