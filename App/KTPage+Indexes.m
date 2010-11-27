//
//  KTPage+Indexes.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>

#import "KTPage+Paths.h"

#import "SVArticle.h"
#import "SVArchivePage.h"
#import "SVHTMLContext.h"
#import "SVHTMLTemplateParser.h"
#import "SVMediaGraphic.h"
#import "SVPagesController.h"
#import "SVTextAttachment.h"

#import "NSString+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSCharacterSet+Karelia.h"
#import "NSError+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+KTExtensions.h"
#import "KSURLUtilities.h"
#import "NSXMLElement+Karelia.h"
#import "SVWebEditorHTMLContext.h"
#import "KSStringHTMLEntityUnescaping.h"

@interface KTPage (IndexesPrivate)
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
- (NSString *)truncateMarkup:(NSString *)markup truncation:(NSUInteger)maxCount truncationType:(SVIndexTruncationType)truncationType;
@end


#pragma mark -


@implementation KTPage (Indexes)

#pragma mark Basic Properties

@dynamic collectionSummaryType;

#pragma mark Index

- (BOOL)pagesInIndexAllowComments
{
	BOOL result = NO;
	
	if ([self isCollection])
	{
		NSArray *pages = [[SVPagesController controllerWithPagesToIndexInCollection:self] arrangedObjects];
		for ( KTPage *page in pages )
		{
			if ( [page wrappedBoolForKey:@"allowComments"] )
			{
				result = YES;
				break;
			}
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Navigation Arrows

/*	All those pages which are suitable for linking to with navigation arrows.
 */
- (NSArray *)navigablePages;
{
	// How to sort the pages? Generally this is the same as usual, but for chronological collections, the arrows need to always be the same. #32341
    SVCollectionSortOrder sorting = [[self collectionSortOrder] integerValue];
    BOOL ascending = [self isSortedChronologically] ? NO : [[self collectionSortAscending] boolValue];
    
    NSArray *result = [self childrenWithSorting:sorting ascending:ascending inIndex:YES];
	return result;
}

- (KTPage *)previousPage
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
	NSArray *siblings = [[self parentPage] childPages];
    [context addDependencyOnObject:self keyPath:@"parentPage.childPages"];
    
	unsigned index = [siblings indexOfObjectIdenticalTo:self];
	while (index > 0)
	{
        index--;
		
        KTPage *result = [siblings objectAtIndex:index];
        [context addDependencyOnObject:result keyPath:@"shouldIncludeInIndexes"];
        
        if ([result shouldIncludeInIndexes]) return result;
	}
	
	return nil;
}
+ (NSSet *) keyPathsForValuesAffectingPreviousPage; { return [NSSet setWithObject:@"parentPage.childPages"]; }

- (KTPage *)nextPage
{
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
	NSArray *siblings = [[self parentPage] childPages];
	[context addDependencyOnObject:self keyPath:@"parentPage.childPages"];
    
	unsigned index = [siblings indexOfObjectIdenticalTo:self] + 1;
	while (index < [siblings count])
	{
		KTPage *result = [siblings objectAtIndex:index];
        [context addDependencyOnObject:result keyPath:@"shouldIncludeInIndexes"];

        if ([result shouldIncludeInIndexes]) return result;
        
        index++;
	}
	
	return nil;
}
+ (NSSet *) keyPathsForValuesAffectingNextPage; { return [NSSet setWithObject:@"parentPage.childPages"]; }

#pragma mark Syndication

@dynamic collectionSyndicationType;
- (void)setCollectionSyndicationType:(NSNumber *)type;
{
    [self willChangeValueForKey:@"collectionSyndicationType"];
    [self setPrimitiveValue:type forKey:@"collectionSyndicationType"];
    [self didChangeValueForKey:@"collectionSyndicationType"];
    
    
    // #93646
    if ([type boolValue])
    {
        if ([[self collectionMaxSyndicatedPagesCount] integerValue] < 1)
        {
            [self setCollectionMaxSyndicatedPagesCount:[NSNumber numberWithUnsignedInteger:20]];
        }
    }
    
    
    [[self childItems] makeObjectsPerformSelector:@selector(guessEnclosures)];
}

@dynamic collectionMaxSyndicatedPagesCount;
- (BOOL)validateCollectionMaxSyndicatedPagesCount:(NSNumber **)max error:(NSError **)outError;
{
    // Mandatory for syndicated collections, optional otherwise
    if ([self isCollection] && [[self collectionSyndicationType] boolValue])
    {
        if (!*max)
        {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSValidationMissingMandatoryPropertyError
                                          localizedDescription:@"collectionMaxSyndicatedPagesCount is non-optional for collections"];
            
            return NO;
        }
    }
    
    return YES;
}

@dynamic collectionTruncateFeedItems;
@dynamic collectionMaxFeedItemLength;

@dynamic RSSFileName;

- (NSURL *)feedURL
{
	NSURL *result = nil;
	
	if ([[self collectionSyndicationType] boolValue])
	{
		result = [NSURL ks_URLWithPath:[self RSSFileName] relativeToURL:[self URL] isDirectory:NO];
	}
	
	return result;
}
+ (NSString *)keyPathsForValuesAffectingFeedURL;
{
    return [NSSet setWithObjects:@"collectionSyndicationType", @"URL", @"RSSFileName", nil];
}

/*  The pages that will go into the RSS feed. Sort chronologically and apply the limit
 */
- (NSArray *)pagesInRSSFeed
{
	NSArray *result = [self childrenWithSorting:SVCollectionSortByDateCreated ascending:NO inIndex:YES];
    
    NSUInteger max = [[self collectionMaxSyndicatedPagesCount] unsignedIntegerValue];
    if ([result count] > max)
    {
        result = [result subarrayToIndex:max];
    }
    
	return result;
}

/*!	Return the HTML.
 */
- (NSString *)RSSFeed;
{
	NSMutableString *result = [NSMutableString string];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:result];
    
    [self writeRSSFeed:context];
	[context release];
		
	// We won't do any "stringByEscapingCharactersOutOfEncoding" since we are using UTF8, which means everything is OK, and we
	// don't want to introduce any entities into the XML anyhow.
	
	OBPOSTCONDITION(result);
    return result;
}

- (void)writeRSSFeed:(SVHTMLContext *)context;
{
    // Find the template
	NSString *template = [[NSBundle mainBundle] templateRSSAsString];
	OBASSERT(template);
	
	
    // Generate XML
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template component:self];
	
    [parser parseIntoHTMLContext:context];
    [parser release];
}

- (NSSize)RSSFeedThumbnailsSize { return NSMakeSize(128.0, 128.0); }

#pragma mark RSS Enclosures

- (NSArray *)feedEnclosures
{
    NSSet *attachments = [[self article] attachments];
    
    NSSet *graphics = [[attachments valueForKey:@"graphic"] filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"includeAsRSSEnclosure == 1"]];
    
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[attachments count]];
    
    for (SVGraphic *anAttachment in graphics)
    {
        id <SVEnclosure> enclosure = [anAttachment enclosure];
        if (enclosure) [result addObject:enclosure];
    }
    
	return result;
}

- (void)guessEnclosures;    // searches for enclosures if feed expects them
{
    if ([[[self parentPage] collectionSyndicationType] intValue] > 1)
    {
        NSArray *enclosures = [self feedEnclosures];
        if ([enclosures count] == 0)
        {
            for (SVTextAttachment *anAttachment in [[self article] attachments])
            {
                SVGraphic *graphic = [anAttachment graphic];
                if ([graphic isKindOfClass:[SVMediaGraphic class]])
                {
                    [graphic setIncludeAsRSSEnclosure:[NSNumber numberWithBool:YES]];
                    break;
                }
            }
        }
    }
}

- (void)writeEnclosures;
{
    NSArray *enclosures = [self feedEnclosures];
    
    for (id <SVEnclosure> anEnclosure in enclosures)
    {
        SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
        [context writeEnclosure:anEnclosure];
    }
}

#pragma mark Standard Summary

- (void)writeSummary:(SVHTMLContext *)context truncation:(NSUInteger)maxCount truncationType:(SVIndexTruncationType)truncationType;
{
	[context willWriteSummaryOfPage:self];
    [context startElement:@"div" className:@"article-summary"];

	// do we have a custom summary? if so just write it
    if ( nil != [self customSummaryHTML] )
    {
        [context writeHTMLString:[self customSummaryHTML]];
    }
    else
	{
		NSAttributedString *html = nil;
		
		if ( maxCount > 0 )
		{
			// take the normally generated HTML for the summary  
			
			// complete page markup would be:
			NSString *markup = [[self article] string];
			
			NSString *truncated = [self truncateMarkup:markup truncation:maxCount truncationType:truncationType];

			html = [[self article] attributedHTMLStringFromMarkup:truncated];
		}
		else
		{
			// no truncation, just process the complete, normal summary
			html = [[self article] attributedHTMLString];
		}
		NSMutableAttributedString *summary = [html mutableCopy];
		
		NSMutableArray *attachments = [[NSMutableArray alloc] initWithCapacity:
									   [[[self article] attachments] count]];
		
		
		// Strip out large attachments .... WHY?
		NSUInteger location = 0;
		
		while (location < summary.length)
		{
			NSRange effectiveRange;
			SVTextAttachment *attachment = [summary attribute:@"SVAttachment"
													  atIndex:location
											   effectiveRange:&effectiveRange];
			
			if (attachment && [[attachment causesWrap] boolValue])
			{
				[attachments addObject:[attachment graphic]];
				[summary deleteCharactersInRange:effectiveRange];
			}
			else
			{
				location = location + effectiveRange.length;
			}
		}
		
		
		// Are we left with only whitespace? If so, fallback to graphic captions
		NSString *text = [[summary string] stringByConvertingHTMLToPlainText];
		if ([text isWhitespace])
		{
			[summary release]; summary = nil;
			
			for (SVGraphic *aGraphic in attachments)
			{
				if ([aGraphic showsCaption])
				{
					summary = [[[aGraphic caption] attributedHTMLString] retain];
					break;
				}
			}
		}
		
		
		// Write it
		[context writeAttributedHTMLString:summary];
		
		[attachments release];
		[summary release];
	}


    [context endElement];
    if ([context respondsToSelector:@selector(endDOMController)]) [((SVWebEditorHTMLContext *)context) endDOMController];
}

/*!	Here is the main information about how summaryHTML works.

A page is asked for ds summaryHTML to populate its parent's general index page, if it exists.
Exactly how that summary is generated is a bit complex.

First off -- if this is a collection (with some children), there is a behavior flag which is
consulted.  Depending on this flag, the summary may be generated to do one of the following:
* Show the summaryHTML of the most recently added item in that collection.  This is useful
in the case of a link to a blog, where the latest article is a teaser.
* Show a small list of titles of recent articles, limited to N articles.  Sort of a mini-index.
* Show an alphabetical list of items.  (Limited to N articles, like Yahoo subcategories?)

If the collection is instead marked "automatic", or the page is not a collection, then the
summaryHTML is generated as follows.

We use valueForUndefinedKey to cause the page to check, in this order:
* its delegate, for a summaryHTML method
* the page's plugin properties
* the element --which will also check first its delegate than its plugin properties

The idea is that you give subclasses a chance to "override" the method to calculate the value,
or look it up if not found.

A few known places where a delegate overrides summaryHTML to provide us with something:
* Image element delegate returns a photo's caption.
* Rich text element delegate returns the entire rich text article (possibly truncated)
if no override value has been set in the properties dictionary.

The general idea is that summaryHTML is automatically derived as much as possible, but the site
creator has the ability to override that and replace it with some other text.

For setting Summary HTML, the idea is that if the page has its own summary HTML value of non-nil,
meaning that the summary has been "split off", then go ahead and set that property.  Otherwise,
ask its original source to set its original value.

QUESTION: WHAT IF SUMMARY IS DERIVED -- WHAT DOES THAT MEAN TO SET?

*/
/*
- (NSString *)summaryHTML
{
	NSString *result = [self summaryHTMLAllowingTruncation:YES];	
	return result;
}

- (NSString *)summaryHTMLAllowingTruncation:(BOOL)inAllowTruncation
{
	USESDEPRECATEDAPI;
	
	NSString *result = @"";
	KTCollectionSummaryType summaryType;
	if ([self hasChildren]
		&&
		KTSummarizeAutomatic != (summaryType = [self integerForKey:@"collectionSummaryType"]))
	{
		NSArray *descriptors;
		if (summaryType == KTSummarizeAlphabeticalList)
		{
			descriptors = gAlphaSort;
		}
		else
		{
			descriptors = (KTTimestampModificationDate == [[self master] integerForKey:@"timestampType"])
			   ? gModNewTop
			   : gCreationNewTop;
		}
		
		[self lockPSCAndMOC];
		NSArray *sortedChildren = [[[self childrenInIndexSet] allObjects] sortedArrayUsingDescriptors:descriptors];
		[self unlockPSCAndMOC];
		
		if (summaryType == KTSummarizeMostRecent)
		{
			if ([sortedChildren count])
			{
				KTPage *topPage = [sortedChildren objectAtIndex:0];
				result = [topPage summaryHTML];
			}
		}
		else if (summaryType == KTSummarizeFirstItem)
		{
			if ([sortedChildren count])
			{
				KTPage *topPage = [sortedChildren lastObject];
				result = [topPage summaryHTML];
			}
		}
		else
		{
			int maxForSummary = [[NSUserDefaults standardUserDefaults] integerForKey:@"MaximumTitlesInCollectionSummary"];
			NSMutableString *s = [NSMutableString stringWithString:@"<ul>\n"];
			NSEnumerator *theEnum = [sortedChildren objectEnumerator];
			KTPage *page;
			int count = 1;

			while (nil != (page = [theEnum nextObject]) )
			{
				[s appendFormat:@"\t<li>%@</li>\n", [page wrappedValueForKey:@"titleHTML"]];
				if (count++ >= maxForSummary)
				{
					break;
				}
			}
			[s appendFormat:@"</ul>"];
			result = s;
		}
	}
	
	return result;
}
*/


- (NSString *)truncateMarkup:(NSString *)markup truncation:(NSUInteger)maxCount truncationType:(SVIndexTruncationType)truncationType;
{
	NSString *result = markup;
		
	if (maxCount)	// only do something if we want to actually truncate something
	{
		// Only want run through this if:
		// 1. We are truncating something other than characters
		// 2. We are truncating characters, and our maximum [character] count is shorter than the actual length we have.
		if (truncationType != kTruncateCharacters || maxCount < [result length])
		{			
			// Turn Markup into a tidied XML document
			NSError *theError = NULL;
			NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:result options:NSXMLDocumentTidyHTML error:&theError] autorelease];
			NSArray *theNodes = [xmlDoc nodesForXPath:@"/html/body" error:&theError];
			NSXMLNode *currentNode = [theNodes lastObject];		// working node we traverse
			NSXMLNode *lastTextNode = nil;
			NSXMLElement *theBody = [theNodes lastObject];	// the body that we we will be truncating
			int accumulator = 0;
			BOOL inlineTag = NO;	// for word scanning; if inline, we may count next text as part of previous
			BOOL endedWithWhitespace = YES;	// for word scanning; if last word ends with whitespace, next token is a word.
			BOOL didSplitWord = NO;	// for character scanning; this lets us know if a word was truncated midway.  Doesn't really work in cases like abso<i>lutely</i>
			while (nil != currentNode)
			{
				if (NSXMLTextKind == [currentNode kind])
				{
					NSString *thisString = [currentNode stringValue];	// renders &amp; etc.
					if (kTruncateCharacters == truncationType)
					{
						lastTextNode = currentNode;		// when we are done, we will add ellipses
						unsigned int newAccumulator = accumulator + [thisString length];
						if (newAccumulator >= maxCount)	// will we need to prune?
						{
							int truncateIndex = maxCount - accumulator;
							NSString *truncd = [thisString smartSubstringWithMaxLength:truncateIndex didSplitWord:&didSplitWord];
							
							[currentNode setStringValue:truncd];	// re-escapes &amp; etc.
							
							break;		// we will now remove everything after "node"
						}
						accumulator = newAccumulator;
					}
					else if (kTruncateWords == truncationType)
					{
						NSUInteger len = [thisString length];
						CFStringTokenizerRef tokenRef
							= CFStringTokenizerCreate (
													   kCFAllocatorDefault,
													   (CFStringRef)thisString,
													   CFRangeMake(0,len),
													   kCFStringTokenizerUnitWord,
													   NULL	// Apparently locale is ignored anyhow when doing words?
													   );
						
						CFStringTokenizerTokenType tokenType = kCFStringTokenizerTokenNone;
						CFIndex lastWord = 0;
						BOOL stopWordScan = NO;	// don't use break, since we want breaking out of outer loop
						BOOL firstWord = YES;
						
						while(!stopWordScan && 
							  (kCFStringTokenizerTokenNone != (tokenType = CFStringTokenizerAdvanceToNextToken(tokenRef))) )
						{
							CFRange tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenRef);
							DJW((@"'%@' found at %d+%d", [thisString substringWithRange:NSMakeRange(tokenRange.location, tokenRange.length)], tokenRange.location, tokenRange.length));
							if (firstWord)
							{
								firstWord = NO;
								// Check for space BEFORE first word - we may need to increment previous counter.
								if (tokenRange.location > 0 && accumulator >= maxCount)
								{
									stopWordScan = YES;
									DJW((@"String starts with whitespace.  Early exit from word count, accumulator = %d", accumulator));
								}
								else if (inlineTag && !endedWithWhitespace && 0 == tokenRange.location)
								{
									DJW((@"#### Not incrementing accumulator (%d) since we are still inline.", accumulator));
								}
								else
								{
									++accumulator;
									DJW((@"First word; ++accumulator = %d", accumulator));
								}
							}
							else	// other words, just increment the accumulator
							{
								++accumulator;
								DJW((@"++accumulator = %d", accumulator));
							}
	
							if (!stopWordScan)	// don't increment if we early-exited above
							{
								lastWord = tokenRange.location + tokenRange.length;
								lastTextNode = currentNode;		// If this is the last node we are scanning, we will add ellipses to this
							}

							if (accumulator >= maxCount)
							{
								stopWordScan = YES;
								DJW((@"early exit from word count, accumulator = %d", accumulator));
							}
						}
						CFRelease(tokenRef);
						DJW((@"in '%@' max=%d len=%d", thisString, lastWord, len));
						endedWithWhitespace = (lastWord < len);
						if (accumulator >= maxCount)
						{
							if (lastWord < len)
							{
								NSString *partialString = [thisString substringToIndex:lastWord];
								DJW((@"accumulator = %d; Truncating to '%@'", accumulator, partialString));
								[currentNode setStringValue:partialString];	// re-escapes &amp; etc.
								DJW((@"... and breaking from loop; we're done, since this is really truncating"));
								break;		// exit outer loop, so we stop scanning
							}
							else
							{
								DJW((@"We are out of words, but not breaking here in case we hit inline to follow"));
							}
						}
					}
				}
				else if ([currentNode kind] == NSXMLElementKind)
				{
					NSXMLElement *theElement = (NSXMLElement *)currentNode;
					if (kTruncateParagraphs == truncationType)
					{
						if ([@"p" isEqualToString:[theElement name]])
						{
							if (++accumulator >= maxCount)
							{
								break;	// we will now remove everything after "node"
							}
						}
					}
					else if (kTruncateWords == truncationType)
					{
						DJW((@"<%@>", [theElement name]));
						static NSSet *sInlineTags = nil;
						if (!sInlineTags)
						{
							// TODO: Unify with -[KSHTMLWriter canWriteElementInline]. Class method?
							sInlineTags = [[NSSet alloc] initWithObjects:
								@"a", @"b", @"i", @"br", @"em", @"img", @"sup", @"sub", @"big", @"span", @"font", @"small", @"strong", nil];
						}
						inlineTag = [sInlineTags containsObject:[theElement name]];
						if (!inlineTag)
						{
							// Not an inline tag; see if we should just stop now.
							DJW((@"Not an inline tag, so consider this a word break"));
							if (accumulator >= maxCount)
							{
								DJW((@"accumulator = %d; at following non-inline tag, time to STOP", accumulator));
								break;
							}
						}
					}
				}
				currentNode = [currentNode nextNode];
			}
			
			[theBody removeAllNodesAfter:(NSXMLElement *)currentNode];
			if (lastTextNode)
			{
				// Trucate, plus add on an ellipses.  (Space before ellipses if we didn't break a word up.)
				NSString *theFormat = (didSplitWord ? @"%@%C" : @"%@ %C");
				NSString *lastNodeString = [lastTextNode stringValue];
				NSString *newString = [NSString stringWithFormat:theFormat,
									   lastNodeString, 0x2026];
				[lastTextNode setStringValue:newString];
			}
			
			result = [theBody XMLStringWithOptions:NSXMLDocumentTidyXML];
			// DON'T use NSXMLNodePreserveAll -- it converted " to ' and ' to &apos;  !!!
			
			NSRange rangeOfBodyStart = [result rangeOfString:@"<body>" options:0];
			NSRange rangeOfBodyEnd   = [result rangeOfString:@"</body>" options:NSBackwardsSearch];
			if (NSNotFound != rangeOfBodyStart.location && NSNotFound != rangeOfBodyEnd.location)
			{
				int sPos = NSMaxRange(rangeOfBodyStart);
				int len  = rangeOfBodyEnd.location - sPos;
				result = [result substringWithRange:NSMakeRange(sPos,len)];
			}
		}	
	}
	
	return result;
}

/*	The key path to generate a summary from. If the delegate does not implement this we return nil
 */
- (NSString *)summaryHTMLKeyPath
{
	NSString *result = @"titleHTMLString";
	
	return result;
}

/*	Whether the page's summary should be editable. Generally this is true, but in some cases (e.g. Raw HTML page)
 *	we want a non-editable summary.
 *	The default is NO to be on the safe side.
 */
- (BOOL)summaryHTMLIsEditable
{
	BOOL result = NO;
	
	return result;
}

#pragma mark Archives

@dynamic collectionGenerateArchives;

- (NSArray *)archivePages;
{
    NSMutableArray *result = [NSMutableArray array];
    NSMutableArray *currentPages = [NSMutableArray array];
    NSDateComponents *currentMonth = nil;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSArray *pages = [self childrenWithSorting:SVCollectionSortByDateCreated ascending:NO inIndex:YES];
    for (SVSiteItem *anItem in pages)
    {
        // If this page is into a different archive period, generate an archive for the pages processed so far
        NSDateComponents *components = [calendar components:(kCFCalendarUnitYear | kCFCalendarUnitMonth)
                                                   fromDate:[anItem creationDate]];
        
        if (![components isEqual:currentMonth] && currentMonth)
        {
            SVArchivePage *archivePage = [[SVArchivePage alloc] initWithPages:currentPages];
            [currentPages removeAllObjects];
            
            [result addObject:archivePage];
            [archivePage release];
        }
        
        [currentPages addObject:anItem];
        currentMonth = components;
    }
    
    
    // Create an archive page for the remaining pages
    if ([currentPages count])
    {
        SVArchivePage *archivePage = [[SVArchivePage alloc] initWithPages:currentPages];
        [currentPages removeAllObjects];
        
        [result addObject:archivePage];
        [archivePage release];
    }
    
    
    return result;
}

@end
