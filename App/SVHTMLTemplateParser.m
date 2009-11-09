//
//  SVHTMLTemplateParser.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "SVHTMLTemplateParser+Private.h"
#import "KTHTMLParserMasterCache.h"

#import "KTSite.h"
#import "KTPage+Internal.h"
#import "KTArchivePage.h"
#import "KTHostProperties.h"
#import "KTImageScalingURLProtocol.h"

#import "BDAlias+QuickLook.h"
#import "CIImage+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSURL+Karelia.h"
#import "Registration.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@implementation SVHTMLTemplateParser

#pragma mark -
#pragma mark Class Methods

- (NSString *)calloutContainerTemplateHTML
{
	static NSString *sCalloutContainerTemplateHTML;
	
	if (!sCalloutContainerTemplateHTML)
	{
		NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"KTCalloutContainerTemplate" ofType:@"html"];
		OBASSERT(templatePath);
		
		sCalloutContainerTemplateHTML = [[NSString alloc] initWithContentsOfFile:templatePath];
		OBASSERT(sCalloutContainerTemplateHTML);
	}
	
	return sCalloutContainerTemplateHTML;
}

#pragma mark -
#pragma mark Init & Dealloc

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
	
	
	return self;
}

#pragma mark Delegate

@dynamic delegate;

#pragma mark -
#pragma mark Handy Keypaths

/*!	For RSS generation
 */
- (NSString *)RFC822Date
{
	return [[NSDate date] descriptionRFC822];		// NOW in the proper format
}

/*!	Return a code that indicates what license is used.  To help with blacklists or detecting piracy.
 *	Returns a nonsense value.
 
 FIXME: Is this even used anywhere?
 */
- (NSString *)rhash
{
	return (nil != gRegistrationHash) ? gRegistrationHash : @""; 
}

#pragma mark -
#pragma mark Parsing

- (NSString *)parseTemplateWithContext:(SVHTMLContext *)context;
{
    if (context)
    {
        [SVHTMLContext pushContext:context];
        NSString *result = [self parseTemplate];
        [SVHTMLContext popContext];
        return result;
    }
    else
    {
        return [self parseTemplate];
    }
}

#pragma mark -
#pragma mark Delegate

- (void)didEncounterMediaFile:(KTMediaFile *)mediaFile upload:(KTMediaFileUpload *)upload
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didParseMediaFile:upload:)])
	{
		[delegate HTMLParser:self didParseMediaFile:mediaFile upload:upload];
	}
}

- (void)didEncounterResourceFile:(NSURL *)resourceURL
{
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(HTMLParser:didEncounterResourceFile:)])
	{
		[delegate HTMLParser:self didEncounterResourceFile:resourceURL];
	}
}

- (void)didParseTextBlock:(SVHTMLTextBlock *)textBlock
{
	[[SVHTMLContext currentContext] didGenerateTextBlock:textBlock];
}

#pragma mark -
#pragma mark Parsing

/*	We make a couple of extra tweakes for HTML parsing
 */
- (BOOL)prepareToParse
{
	BOOL result = [super prepareToParse];
	
	if (result)
	{
		KTAbstractPage *page = [[SVHTMLContext currentContext] currentPage];
        if (page) [[self cache] overrideKey:@"CurrentPage" withValue:page];
        
		[[self cache] overrideKey:@"HTMLGenerationPurpose" withValue:[self valueForKey:@"HTMLGenerationPurpose"]];
	}
	
	return result;
}

/*	We wrap child parsers in a special <div> so the webview controller can later identify them.
 */
- (NSString *)parseTemplate
{
	NSString *result = [super parseTemplate];
	
    // We only need neat formatting when publishing
    KTHTMLGenerationPurpose purpose = [[SVHTMLContext currentContext] generationPurpose];
    if (purpose != kGeneratingPreview && purpose != kGeneratingQuickLookPreview)
    {
        result = [result stringByRemovingMultipleNewlines];
    }
    
    return result;
}

/*	We have to implement kCompareNotEmptyOrEditing as KTTemplateParser has no concept of editing.
 */
- (BOOL)compareIfStatement:(ComparisonType)comparisonType leftValue:(id)leftValue rightValue:(id)rightValue
{
	BOOL result;
	
	if (comparisonType == kCompareNotEmptyOrEditing)	// mostly same test; we will "OR" with editing mode
	{
		result = (![[SVHTMLContext currentContext] isPublishing] || [self isNotEmpty:leftValue]);
	}
	else
	{
		result = [super compareIfStatement:comparisonType leftValue:leftValue rightValue:rightValue];
	}
	
	return result;
}

#pragma mark -
#pragma mark Functions

- (NSString *)targetStringForPage:(id) aDestPage
{
	BOOL openInNewWindow = NO;
	id targetPageDelegate = [aDestPage delegate];
	if (targetPageDelegate && [targetPageDelegate respondsToSelector:@selector(openInNewWindow)])
	{
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

- (NSString *)targetWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"target: usage [[ target otherPage.keyPath ]]");
		return @"";
	}
	
	// If linking to an External Link page set to "open in new window," force the link to open in a new window
	id targetPage = [[self cache] valueForKeyPath:inRestOfTag];
	return [self targetStringForPage:targetPage];
}

/*!	ID/Class generator.  The IDs of clickable items are pretty complex, so this builds them and creates
	the id="foo" class="bar" HTML (with leading space), so put this right after the tag type.

	You pass parameters kind of like objC, but in any order.  parameter keyword followed by :
		then either a single word up to the next space, or multiple words in quotes.

	keywords allowed:
		
		entity - like Document, Page, Element, Pagelet.  With optional _anything suffix just to keep unique
		property - for editing, what property (key-value) does this ID'd object get loaded from/saved to?
		flags: one or more of:
			block - editable as a block of text, one or more paragraphs
			line - editable as a single line, no newlines allowed
			optional - if empty contents, this div will be taken out
			RootNotOptional -- special; overrides optional if this is the root
			summary - this is a summary of existing content and is not editable (without override?)
		id - the keypath to the uniqueID of this object
		replacement - keypath of flat text to replace when using image replacement
		code - code (h1,h1h,h2,h3,h4s,h4c,m,mc,st) for matching to image replacement. (graphicalTextCode:)
		class - additional class (or classes separated by space) to apply to this element.
			(dynamic, special classes will be appended to this list for editing purposes)
*/
- (NSString *)idclassWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
//	NSLog(@"[[idclass %@]]", inRestOfTag);

	NSString *pseudoEntity = nil;
	NSString *code = nil;

	NSString *uniqueID = nil;
	NSString *flatPropertyValue = nil;
	NSString *property = nil;
	NSMutableArray *classes = [NSMutableArray array];

	NSScanner *scanner = [NSScanner scannerWithString:inRestOfTag];
	while ( ![scanner isAtEnd] )
	{
		NSString *keyword;
		BOOL foundKeyword = [scanner scanUpToString:@":" intoString:&keyword];
		if (!foundKeyword || ![scanner scanString:@":" intoString:nil])
		{
			[NSException raise:kKTTemplateParserException format:@"cannot scan keyword up to ':'"];
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
				[NSException raise:kKTTemplateParserException format:@"cannot scan to closing \""];
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
		}
		else if ([keyword isEqualToString:@"flags"])
		{
			// Only generate these special classes if we are doing the local preview
			if (![[SVHTMLContext currentContext] isPublishing])
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
            if (!uniqueID) uniqueID = @"";
		}
		else if ([keyword isEqualToString:@"replacement"])	// key path to property to replace, flattened version of property
		{
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
	
	OBASSERTSTRING(pseudoEntity, @"entity cannot be null");
	OBASSERTSTRING(property, @"property cannot be null");
	OBASSERTSTRING(uniqueID, @"uniqueID cannot be null");
	NSString *resultingID = [NSString stringWithFormat:@"k-%@-%@-%@", pseudoEntity, property, uniqueID];
	if (nil != code)
	{
		resultingID = [NSString stringWithFormat:@"%@-%@", resultingID, code];
	}
	
	// Mark for image replacement ONLY if QC supported.
	KTAbstractPage *page = [[SVHTMLContext currentContext] currentPage];
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
	
		[[page managedObjectContext] makeAllPluginsPerformSelector:@selector(addSitewideTextToEndBody:forPage:)
														withObject:string
														  withPage:[[page site] root]];
		

		[page makeComponentsPerformSelector:@selector(addLevelTextToEndBody:forPage:) withObject:string withPage:page recursive:NO];
		
		//[page recursiveComponentPerformSelector:@selector(addPageTextToEndBody:forPage:) withObject:string];
		/// Wasn't actually being used by any plugins and is identical to -addLevelTextToEndBody:
	return string;
}

- (NSString *)extraheadersWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	KTPage *page = (KTPage *)[self component];
	NSMutableString *string = [NSMutableString string];
	
		//[[page root] recursiveComponentPerformSelector:@selector(addSitewideTextToHead:forPage:) withObject:string];
		/// Disabled this for 1.2.1 since it currently slows down a lot on a large site.
		
		
		//[page makeComponentsPerformSelector:@selector(addLevelTextToHead:forPage:) withObject:string withPage:page];
		/// Unusued in any plugins so disabled for performance.
		
		[page makeComponentsPerformSelector:@selector(addPageTextToHead:forPage:) withObject:string withPage:page recursive:NO];
	return string;
}

#pragma mark resources

// Following parameters:  (1) key-value path to media or mediaImage object
// Should call resourcePathRelativeTo: and return the result.

- (NSString *)resourcepathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
    
    // Check suitable parameters were supplied
	NSArray *params = [inRestOfTag componentsSeparatedByWhitespace];
	if ([params count] != 1)
	{
		NSLog(@"resourcepath: usage [[resourcepath resource.keyPath]]");
	}
	else
    {
        // Where is the resource file on disk?
        NSString *resourceFilePath = [[self cache] valueForKeyPath:[params objectAtIndex:0]];
        if (resourceFilePath)
        {
            result = [self resourceFilePath:[NSURL fileURLWithPath:resourceFilePath] relativeToPage:[[SVHTMLContext currentContext] currentPage]];
        }
    }
    
    return result;
}

/*	Support method that returns the path to the resource dependent of our HTML generation purpose.
 */
- (NSString *)resourceFilePath:(NSURL *)resourceURL relativeToPage:(KTAbstractPage *)page
{
	NSString *result = [[SVHTMLContext currentContext] URLStringForResourceFile:resourceURL];
    
	// Tell the delegate
	[self didEncounterResourceFile:resourceURL];
    
	return result;
}

- (NSString *)rsspathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"path: usage [[ rsspath otherPage.keyPath ]]");
		return @"";
	}
	
	NSURL *sourceURL = [[SVHTMLContext currentContext] baseURL];
	KTPage *targetPage = [[self cache] valueForKeyPath:inRestOfTag];
	
	NSString *result = [[targetPage feedURL] stringRelativeToURL:sourceURL];
	return result;
}

// Following parameters:  (1) key-value path to another page

- (NSString *)pathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"path: usage [[ path otherPage.keyPath ]]");
		return @"";
	}
	
	id target = [[self cache] valueForKeyPath:inRestOfTag];
	NSString *result = [self pathToObject:target];
	return result;
}

- (NSString *)pathToObject:(id)anObject
{
	NSString *result = nil;
    
    if ([anObject isKindOfClass:[KTAbstractPage class]])
    {
        switch ([[SVHTMLContext currentContext] generationPurpose])
        {
            case kGeneratingPreview:
                result = [(KTAbstractPage *)anObject previewPath];
                break;
            case kGeneratingQuickLookPreview:
                result= @"javascript:void(0)";
                break;
            default:
                result = [[(KTAbstractPage *)anObject URL] stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
                break;
        }
    }
    else if ([anObject isKindOfClass:[NSURL class]])
    {
        switch ([[SVHTMLContext currentContext] generationPurpose])
        {
            case kGeneratingPreview:
            case kGeneratingQuickLookPreview:
                result = [(NSURL *)anObject absoluteString];
                break;
            default:
                result = [(NSURL *)anObject stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
                break;
        }
    }
        
	return [result stringByEscapingHTMLEntities];
}

#pragma mark Deprecated

/*  These methods are no longer public in 2.0 as we have moved to the SVHTMLContext concept. But many templates rely on these methods being present in the parser, so they stick around as wrappers around the new functionality
 */

- (KTAbstractPage *)currentPage
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    OBASSERT(context);
	return [context currentPage];
}

- (KTHTMLGenerationPurpose)HTMLGenerationPurpose
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    OBASSERT(context);
	return [context generationPurpose];
}

- (BOOL)isPublishing
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    OBASSERT(context);
	return [context isPublishing];
}

- (BOOL)includeStyling
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    OBASSERT(context);
	return [context includeStyling];
}

/*	Used by templates to know if they're allowed external images etc.
 */
- (BOOL)liveDataFeeds
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    OBASSERT(context);
	return [context liveDataFeeds];
}

@end
