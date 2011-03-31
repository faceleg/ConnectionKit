//
//  SVHTMLTemplateParser.m
//  KTComponents
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

#import "SVHTMLTemplateParser+Private.h"
#import "KTHTMLParserMasterCache.h"

#import "KTSite.h"
#import "KTPage+Internal.h"
#import "KTHostProperties.h"
#import "KTImageScalingURLProtocol.h"

#import "KSStringXMLEntityEscaping.h"

#import "CIImage+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "KSURLUtilities.h"
#import "Registration.h"
#import "NSScanner+Karelia.h"

#import "Debug.h"


@implementation SVHTMLTemplateParser

#pragma mark Init & Dealloc

- (id)initWithPage:(KTPage *)page
{
	// Archive pages are specially parsed so that the component is the parent page.
	KTPage *component = page;
	
	
	// Create the parser and set up as much of the environment as possible
	[self initWithTemplate:[[component class] pageTemplate]
                 component:component];
	
	
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

- (void)writeString:(NSString *)string;
{
    [super writeString:string];
    
    // Reset the context to inline writing since we've taken control again
    [[self HTMLContext] startWritingInline];
}

#pragma mark -
#pragma mark Delegate

- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object
{
    [super didEncounterKeyPath:keyPath ofObject:object];
	[[self HTMLContext] addDependencyOnObject:object keyPath:keyPath];
}

- (void)didEncounterMediaFile:(id <SVMedia>)mediaFile upload:(KTMediaFileUpload *)upload
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

- (void)didParseTextBlock:(SVHTMLTextBlock *)textBlock { }

#pragma mark Parsing

- (BOOL)parseWithOutputWriter:(id <KSWriter>)stream;
{
    // Double-check have we got a context?
    if (![self HTMLContext])
    {
        // If not, inherit from parent
        return [self parseIntoHTMLContext:[[[self class] currentTemplateParser] HTMLContext]];
    }
    
    
    // Record us as the current template parser
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLTemplateParserStack"];
    if (!stack)
    {
        stack = [NSMutableArray arrayWithCapacity:1];
        [[[NSThread currentThread] threadDictionary] setObject:stack
                                                        forKey:@"SVHTMLTemplateParserStack"];
    }
    [stack addObject:self];
    
    
    // Do the parsing
    BOOL result = NO;
    @try
    {
        result = [super parseWithOutputWriter:stream];
    }
    @finally
    {
        // Pop. Need to be sure of it, otherwise an exception can screw up all future parsing. #88083
        [stack removeLastObject];
    }
    
    
    return result;
}

- (BOOL)parseIntoHTMLContext:(SVHTMLContext *)context;
{
    OBPRECONDITION(context);
    
    _context = context;
    BOOL result = [self parseWithOutputWriter:context];
    _context = nil;
    
    return result;
}

@synthesize HTMLContext = _context;

/*	We make a couple of extra tweaks for HTML parsing
 */
- (BOOL)prepareToParse
{
	BOOL result = [super prepareToParse];
	
	if (result)
	{
		KTPage *page = [[self HTMLContext] page];
        if (page) [[self cache] overrideKey:@"CurrentPage" withValue:page];
        
		[[self cache] overrideKey:@"HTMLGenerationPurpose" withValue:[self valueForKey:@"HTMLGenerationPurpose"]];
	}
	
	return result;
}

+ (SVHTMLTemplateParser *)currentTemplateParser;
{
    SVHTMLTemplateParser *result = [[[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLTemplateParserStack"] lastObject];
    
    if (!result)
    {
        NSLog(@"+currentTemplateParser returning nil");
    }
    
    return result;
}

@synthesize currentIterationObject = _iterationObject;

/*	We have to implement kCompareNotEmptyOrEditing as superclass (SVTemplateParser) has no concept of editing.
 */
- (BOOL)compareLeft:(NSString *)left
              right:(NSString *)right
     comparisonType:(ComparisonType)comparisonType;
{
	BOOL result;
	
	if (comparisonType == kCompareNotEmptyOrEditing)	// mostly same test; we will "OR" with editing mode
	{
        // When editing, no point doing comparison. In particular, it can register key paths that I'd rather not (#74630)
		result = ([[self HTMLContext] isForEditing] ||
                  [self isNotEmpty:[self parseValue:left]]);
	}
	else
	{
		result = [super compareLeft:left right:right comparisonType:comparisonType];
	}
	
	return result;
}

#pragma mark -
#pragma mark Functions

- (NSString *)targetStringForPage:(id) aDestPage
{
	BOOL openInNewWindow = NO;
	
	/* Logic from 1.x branch:
	 id targetPageDelegate = [aDestPage delegate];
	 if (targetPageDelegate && [targetPageDelegate respondsToSelector:@selector(openInNewWindow)])
	 {
	 openInNewWindow = [[targetPageDelegate valueForKey:@"openInNewWindow"] boolValue];
	 }
	 */
	if (openInNewWindow)
	{
		return @"_BLANK";
	}
	else
	{
		return nil;
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
			if ([[self HTMLContext] isForEditing])
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
	KTPage *page = [[self HTMLContext] page];
#pragma unused (page)
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

#pragma mark foreach loop

/*!	return index of forEach loop (prefixed with "i"), or empty string if out of a loop
 */
- (NSString *)iWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [[self HTMLContext] currentIteration];
	if (index != NSNotFound)
	{
		result = [NSString stringWithFormat:@"i%i", index + 1];
	}
	
	return result;
}

/*!	Return "e" or "o" for index in forEach loop being even or odd ... or empty string if out of a loop
 */
- (NSString *)eoWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [[self HTMLContext] currentIteration];
	if (index != NSNotFound)
	{
		result = (0 == ((index + 1) % 2)) ? @"e" : @"o";
	}
	
	return result;
}

/*!	Return " last-item" if this is the last item in the loop; an empty string otherwise
 */
- (NSString *)lastWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	NSString *result = @"";
	
	unsigned int index = [[self HTMLContext] currentIteration];
	if (index != NSNotFound)
	{
		int count = [[self HTMLContext] currentIterationsCount];
		if (index == (count - 1))
		{
			result = @" last-item";
		}
	}
	
	return result;
}

- (BOOL)evaluateForeachLoopWithArray:(NSArray *)components iterationsCount:(NSUInteger)specifiedNumberIterations keyPath:(NSString *)keyPath scaner:(NSScanner *)inScanner
{
    // Send the loop parameters to the HTML context to keep track of. Iterating will automatically pop it from the stack
    if (specifiedNumberIterations > 0)
    {
        [[self HTMLContext] beginIteratingWithCount:specifiedNumberIterations];
    }
    
    
    return [super evaluateForeachLoopWithArray:components
                               iterationsCount:specifiedNumberIterations
                                       keyPath:keyPath
                                        scaner:inScanner];
}

- (BOOL)doForeachIterationWithObject:(id)object
                                  template:(NSString *)template
                                   keyPath:(NSString *)keyPath;
{
    // Record the object so plug-ins can access it
    id oldObject = _iterationObject;
    _iterationObject = object;
    
    BOOL result = [super doForeachIterationWithObject:object template:template keyPath:keyPath];
    
    _iterationObject = oldObject;
    
    // Increment the iteration after each run
    [[self HTMLContext] nextIteration];
    return result;
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
		NSLog(@"resourcepath: usage [[resourcepath resource.keyPath]] or [[resourcepath \"string]]");
	}
	else
    {
        // Where is the resource file on disk?
		NSString *resourceFilePath = nil;
		if ([inRestOfTag hasPrefix:@"\""])
		{
			inRestOfTag = [inRestOfTag substringFromIndex:1];
			resourceFilePath = [[NSBundle mainBundle] pathForResource:[inRestOfTag stringByDeletingPathExtension] ofType:[inRestOfTag pathExtension]];
			if (!resourceFilePath)
			{
				NSLog(@"resourcePath: not finding resource %@", inRestOfTag);
			}
		}
        else
		{
			resourceFilePath = [[self cache] valueForKeyPath:[params objectAtIndex:0]];
		}
        if (resourceFilePath)
        {
            result = [self resourceFilePath:[NSURL fileURLWithPath:resourceFilePath] relativeToPage:[[self HTMLContext] page]];
        }
    }
    
    return result;
}

/*	Support method that returns the path to the resource dependent of our HTML generation purpose.
 */
- (NSString *)resourceFilePath:(NSURL *)resourceURL relativeToPage:(KTPage *)page
{
    SVHTMLContext *context = [self HTMLContext];
	NSURL *result = [context addResourceAtURL:resourceURL destination:SVDestinationResourcesDirectory options:0];
    
    
	// Tell the delegate
	[self didEncounterResourceFile:resourceURL];
    
	return [context relativeStringFromURL:result];
}

- (NSString *)rsspathWithParameters:(NSString *)inRestOfTag scanner:(NSScanner *)inScanner
{
	if (NSNotFound != [inRestOfTag rangeOfString:@" "].location)
	{
		NSLog(@"path: usage [[ rsspath otherPage.keyPath ]]");
		return @"";
	}
	
	NSURL *sourceURL = [[self HTMLContext] baseURL];
	KTPage *targetPage = [[self cache] valueForKeyPath:inRestOfTag];
	
	NSString *result = [[targetPage feedURL] ks_stringRelativeToURL:sourceURL];
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
	NSString *result = [KSHTMLWriter stringFromAttributeValue:[self pathToObject:target]];
	return result;
}

- (NSString *)pathToObject:(id)anObject
{
	NSString *result = nil;
    
    if ([anObject respondsToSelector:@selector(URL)] && [anObject URL])
    {
        result = [[self HTMLContext] relativeStringFromURL:[anObject URL]];
    }
    else if ([anObject isKindOfClass:[NSURL class]])
    {
        result = [[self HTMLContext] relativeStringFromURL:anObject];
    }
        
	return result;
}

#pragma mark Deprecated

/*  These methods are no longer public in 2.0 as we have moved to the SVHTMLContext concept. But many templates rely on these methods being present in the parser, so they stick around as wrappers around the new functionality
 */

- (KTPage *)currentPage
{
    SVHTMLContext *context = [self HTMLContext];
    OBASSERT(context);
	return [context page];
}

- (KTHTMLGenerationPurpose)HTMLGenerationPurpose
{
    SVHTMLContext *context = [self HTMLContext];
    OBASSERT(context);
	return [context generationPurpose];
}

- (BOOL)isPublishing		// Used by templates
{
    SVHTMLContext *context = [self HTMLContext];
    OBASSERT(context);
	return [context isForPublishing];
}

- (BOOL)includeStyling
{
    SVHTMLContext *context = [self HTMLContext];
    OBASSERT(context);
	return [context includeStyling];
}

/*	Used by templates to know if they're allowed external images etc.
 */
- (BOOL)liveDataFeeds
{
    SVHTMLContext *context = [self HTMLContext];
    OBASSERT(context);
	return [context liveDataFeeds];
}

#pragma mark Plug-in Private API

/*!	Return a code that indicates what license is used.  To help with blacklists or detecting piracy.
 *	Returns a nonsense value.
 */
- (NSString *)referralCode
{
	return (nil != gRegistrationHash) ? gRegistrationHash : @""; 
}

@end
