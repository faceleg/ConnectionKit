//
//  KTPage+Indexes.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "KTAbstractElement+Internal.h"
#import "KTAbstractIndex.h"
#import "KTArchivePage.h"
#import "KTHTMLParser.h"
#import "KTIndexPlugin.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSCharacterSet+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSURL+Karelia.h"
#import "NSXMLElement+Karelia.h"


@interface KTAbstractPage (PathsPrivate)
- (NSString *)pathRelativeToSiteWithCollectionPathStyle:(KTCollectionPathStyle)collectionPathStyle;
@end


#pragma mark -


@implementation KTPage (Indexes)

#pragma mark -
#pragma mark Basic Accessors

- (KTCollectionSummaryType)collectionSummaryType { return [self wrappedIntegerForKey:@"collectionSummaryType"]; }

- (void)setCollectionSummaryType:(KTCollectionSummaryType)type
{
	[self setWrappedInteger:type forKey:@"collectionSummaryType"];
	
	//  This setting affects the thumbnail, so update it
	if ([self isCollection])
	{
		[self generateCollectionThumbnail];
	}
}

- (void)setCollectionMaxIndexItems:(NSNumber *)max
{
	[self setWrappedValue:max forKey:@"collectionMaxIndexItems"];
	
	// Clearly this operation affects the list
	[self invalidatePagesInIndexCache];
}

- (BOOL)includeInIndex { return [self wrappedBoolForKey:@"includeInIndex"]; }

- (void)setIncludeInIndex:(BOOL)flag
{
	// Mark our old archive page (if there is one) stale
	KTArchivePage *oldArchivePage = [[self parent] archivePageForTimestamp:[self editableTimestamp] createIfNotFound:flag];
	
	
	[self setWrappedBool:flag forKey:@"includeInIndex"];
	
	
	// Delete the old archive page if it has nothing on it now
	if (oldArchivePage)
	{
		NSArray *pages = [oldArchivePage sortedPages];
		if (!pages || [pages count] == 0) [[self managedObjectContext] deleteObject:oldArchivePage];
	}
	
	
	// We must update the parent's list of pages
	[[self parent] invalidatePagesInIndexCache];
}

#pragma mark -
#pragma mark Index

- (KTAbstractIndex *)index { return [self wrappedValueForKey:@"index"]; }

- (void)setIndex:(KTAbstractIndex *)anIndex { [self setWrappedValue:anIndex forKey:@"index"]; }

- (void)setIndexFromPlugin:(KTAbstractHTMLPlugin *)plugin
{
	if (plugin)
	{
		NSBundle *bundle = [plugin bundle];
		[self setValue:[bundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
		
		Class indexClass = [bundle principalClassIncludingOtherLoadedBundles:YES];
		KTAbstractIndex *theIndex = [[[indexClass alloc] initWithPage:self plugin:plugin] autorelease];
		[self setIndex:theIndex];
	}
	else
	{
		[self setValue:nil forKey:@"collectionIndexBundleIdentifier"];
		[self setIndex:nil];
	}
}

/*	Takes our -sortedChildren property and filters out:
 *		* Pages excluded from the index
 *		* Unpublished draft pages
 *		* Pages outside the maxPages limit
 */
- (NSArray *)pagesInIndex
{
	NSArray *result = [self wrappedValueForKey:@"pagesInIndex"];
	
	if (!result)
	{
		result = [self navigablePages];
        
        NSNumber *maxPages = [self valueForKey:@"collectionMaxIndexItems"];
        if (maxPages && [maxPages intValue] > 0)
        {
            result = [result subarrayToIndex:[maxPages intValue]];
        }
        
		[self setPrimitiveValue:result forKey:@"pagesInIndex"];
	}
	
	return result;
}

- (void)invalidatePagesInIndexCache
{
	[self setValue:nil forKey:@"pagesInIndex"];
}

- (BOOL)pagesInIndexAllowComments
{
	BOOL result = NO;
	
	if ( [self isCollection] )
	{
		NSArray *pages = [self pagesInIndex];
		int i;
		for ( i=0; i<[pages count]; i++ )
		{
			KTPage *page = [pages objectAtIndex:i];
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
	NSArray *result = [self childrenWithSorting:[self collectionSortOrder] inIndex:YES];
	return result;
}

/*	Both return nil if there isn't a suitable sibling.
 *	-sortedChildren caching takes care of KVO for these properties.
 */
- (KTPage *)previousPage
{
	KTPage *result = nil;
	
	NSArray *siblings = [[self parent] navigablePages];
	unsigned index = [siblings indexOfObjectIdenticalTo:self];
	if (index > 0 && index < [siblings count])
	{
		result = [siblings objectAtIndex:index - 1];
	}
	
	return result;
}

- (KTPage *)nextPage
{
	KTPage *result = nil;
	
	NSArray *siblings = [[self parent] navigablePages];
	unsigned index = [siblings indexOfObjectIdenticalTo:self];
	if (index != NSNotFound && index < ([siblings count] - 1))
	{
		result = [siblings objectAtIndex:index + 1];
	}
	
	return result;
}

#pragma mark -
#pragma mark RSS Feed

/*!	Can the collection syndicate? A few things have to be set....
If this is true, the RSS button is enabled.
If this, and "collectionSyndicate" are true, then feed is referenced and uploaded.
*/
- (BOOL)collectionCanSyndicate
{
	return [self isCollection]
	&& nil != [self wrappedValueForKey:@"collectionIndexBundleIdentifier"]
	;
	// TAKE OUT FOR NOW ... NOT USING THIS SETTING, UNTIL/UNLESS WE HAVE MULTIPLE FORMATS TO CHOOSE FROM
	// (which we would put in the site settings)
	// && ([self boolForKey:@"collectionGenerateAtom"] || [self boolForKey:@"collectionGenerateRSS"]) ;
}

- (BOOL)collectionSyndicate { return [self wrappedBoolForKey:@"collectionSyndicate"]; }

- (void)setCollectionSyndicate:(BOOL)syndicate
{
    [self setWrappedBool:syndicate forKey:@"collectionSyndicate"];
    
    // For Sandvox 1.6 and onwards, once the user makes a definitive decision, finalise the filename
    // Until then, we stick with the default Sandvox 1.5 + earlier name. case 40230.
    if (![self valueForUndefinedKey:@"RSSFileName"])
    {
        [self setRSSFileName:(syndicate ? @"index.rss" : [self RSSFileName])];
    }
}

- (NSString *)RSSFileName
{
    NSString *result = [self valueForUndefinedKey:@"RSSFileName"];
    if (!result)
    {
        // We don't want to upset existing RSS feeds, so stick to default filename for those
        result = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
    }
    
    return result;
}

- (void)setRSSFileName:(NSString *)file
{
    [self setValue:file forUndefinedKey:@"RSSFileName"];
}

- (NSURL *)feedURL
{
	NSURL *result = nil;
	
	if ([self collectionSyndicate] && [self collectionCanSyndicate])
	{
		result = [NSURL URLWithPath:[self RSSFileName] relativeToURL:[self URL] isDirectory:NO];
	}
	
	return result;
}

/*  The pages that will go into the RSS feed. This is just -pagesInIndex, sorted chronologically
 */
- (NSArray *)sortedReverseChronoChildrenInIndex
{
	NSArray *sortDescriptors = [NSSortDescriptor reverseChronologicalSortDescriptors];
    NSArray *result = [[self pagesInIndex] sortedArrayUsingDescriptors:sortDescriptors];
	return result;
}

/*!	Return the HTML.
 */
- (NSString *)RSSFeedWithParserDelegate:(id)parserDelegate
{
	// Find the template
	NSString *template = [[[self plugin] bundle] templateRSSAsString];
	if (!template)
	{
		// No special template for this bundle, so look for the generic one in the app
		template = [[NSBundle mainBundle] templateRSSAsString];
	}
	OBASSERT(template);
	
	
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:template component:self];
	[parser setDelegate:parserDelegate];
	[parser setHTMLGenerationPurpose:kGeneratingRemote];
	
	NSString *result = [parser parseTemplate];
	[parser release];
		
	// We won't do any "stringByEscapingCharactersOutOfEncoding" since we are using UTF8, which means everything is OK, and we
	// don't want to introduce any entities into the XML anyhow.
	
	OBPOSTCONDITION(result);
    return result;
}

- (NSSize)RSSFeedThumbnailsSize { return NSMakeSize(128.0, 128.0); }

- (NSArray *)feedEnclosures
{
	NSArray *result = nil;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(pageWillReturnFeedEnclosures:)])
	{
		result = [delegate pageWillReturnFeedEnclosures:self];
	}
	
	return result;
}

#pragma mark -
#pragma mark Standard Summary

/*!	Here is the main information about how summaryHTML works.

A page is asked for its summaryHTML to populate its parent's general index page, if it exists.
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

- (NSString *)preTruncationSummaryHTML
{
	// TODO: Handle collections
	
	NSString *result = @"";
	
	NSString *summaryHTMLKeyPath = [self summaryHTMLKeyPath];
	if (summaryHTMLKeyPath)
	{
		result = [self valueForKeyPath:summaryHTMLKeyPath];
	}

	return result;
}

- (NSString *)summaryHTMLWithTruncation:(unsigned)truncation
{
	NSString *result = [self preTruncationSummaryHTML];
	
	
	// Truncate to the specified no. characters.
	// This is tricky because we want to truncate to number of visible characters, not HTML characters.
	// Also, this might leave us in the middle of an open tag.  
// TODO: figure out how to truncate gracefully
	if (truncation && [result length] > truncation)
	{
//						result = [NSString stringWithFormat:@"%@%C", 
//							[result substringToIndex:truncateCharacters], 0x2026];
		
		// NOTE: I STILL NEED TO TRUNCATE BY CHARACTERS, NOT BY MARKUP
		// I could do it by making a doc of the whole thing, then scan through the XML doc for text, and 
		// stop when I reach the Nth character.  Then dump the rest of the tree,
		// then output the tree and XSLT remove the HTML, HEAD, BODY tags.
		
		// Now, tidy this HTML
		NSError *theError = NULL;
		NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithXMLString:result options:NSXMLDocumentTidyHTML error:&theError] autorelease];
		NSArray *theNodes = [xmlDoc nodesForXPath:@"/html/body" error:&theError];
		NSXMLNode *node = [theNodes lastObject];
		NSXMLElement *theBody = [theNodes lastObject];
		int accumulator = 0;
		while (nil != node)
		{
			if ([node kind] == NSXMLTextKind)
			{
				NSString *thisString = [node stringValue];	// renders &amp; etc.
				int thisLength = [thisString length];
				unsigned int newAccumulator = accumulator + thisLength;
				if (newAccumulator >= truncation)	// will we need to prune?
				{
					int truncateIndex = truncation - accumulator;
					// Now back up just a few more characters if we can hit whitespace.
					NSRange whereWhitespace = [thisString rangeOfCharacterFromSet:[NSCharacterSet fullWhitespaceAndNewlineCharacterSet]
																		  options:NSBackwardsSearch
																			range:NSMakeRange(0,truncateIndex)];
					
#define REASONABLE_WORD_LENGTH 15
					/*
					 Might be NSNotFound which means we want to truncate the whole thing?
					 Perhaps if it's small.  If we have japanese with no spaces, I don't
					 want to lose anything like that.  Maybe if the length > N and we
					 couldn't truncate, don't trucate at all. 
					 */
					if (NSNotFound == whereWhitespace.location)
					{
						if (truncateIndex < REASONABLE_WORD_LENGTH)		truncateIndex = 0;	// remove this segment entirely
						// else, just truncate at character; this might be no-space text.
					}
					else
					{
						// Would we truncate a whole bunch extra (meaning a long long word or few/no spaces text?
						if (truncateIndex - whereWhitespace.location < REASONABLE_WORD_LENGTH)
						{
							// only reset the truncate index if we won't chop off TOO much.
							truncateIndex = whereWhitespace.location;
						}
					}
					NSString *truncd = [thisString substringToIndex:truncateIndex];
					// Trucate, plus add on an ellipses
					NSString *newString = [NSString stringWithFormat:@"%@%C", 
						truncd, 0x2026];

					[node setStringValue:newString];	// re-escapes &amp; etc.
					
					break;		// we will now remove everything after "node"
				}
				accumulator = newAccumulator;
			}
			node = [node nextNode];
		}
		
		[theBody removeAllNodesAfter:(NSXMLElement *)node];

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
	
	
	return result;
}

/*	The key path to generate a summary from. If the delegate does not implement this we return nil
 */
- (NSString *)summaryHTMLKeyPath
{
	NSString *result = @"captionHTML";
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(summaryHTMLKeyPath)])
	{
		result = [delegate summaryHTMLKeyPath];
	}
	
	return result;
}

/*	Whether the page's summary should be editable. Generally this is true, but in some cases (e.g. Raw HTML page)
 *	we want a non-editable summary.
 *	The default is NO to be on the safe side.
 */
- (BOOL)summaryHTMLIsEditable
{
	BOOL result = NO;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(summaryHTMLIsEditable)])
	{
		result = [delegate summaryHTMLIsEditable];
	}
    else if (!delegate || ![delegate respondsToSelector:@selector(summaryHTMLKeyPath)])
    {
        result = YES;
    }
	
	return result;
}

#pragma mark custom summary

/*	Returns nil if there is no custom summary
 */
- (NSString *)customSummaryHTML { return [self wrappedValueForKey:@"customSummaryHTML"]; }

- (void)setCustomSummaryHTML:(NSString *)HTML { [self setWrappedValue:HTML forKey:@"customSummaryHTML"]; }

#pragma mark title list

/*	Constructs the HTML for a title list-style summary using the specified ordering
 */
- (NSString *)titleListHTMLWithSorting:(KTCollectionSortType)sortType;
{
	NSMutableString *result = [NSMutableString stringWithString:@"<ul>\n"];
	
	NSArray *allSortedChildren = [self childrenWithSorting:sortType inIndex:NO];
	NSRange childrenRange = NSMakeRange(0, MIN([allSortedChildren count], [self integerForKey:@"collectionSummaryMaxPages"]));
	NSArray *sortedChildren = [allSortedChildren subarrayWithRange:childrenRange];
	
	NSEnumerator *pagesEnumerator = [sortedChildren objectEnumerator];
	KTPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		[result appendFormat:@"\t<li>%@</li>\n", [aPage titleHTML]];
	}
	
	[result appendFormat:@"</ul>"];
	
	return result;
}

#pragma mark -
#pragma mark Archives

/*	This is a transient NOT persistent property. When accessed for the first time, we look for any pagelets requesting archive
 *	generation and set the value accordingly.
 */
- (BOOL)collectionGenerateArchives
{
	NSNumber *result = [self wrappedValueForKey:@"collectionGenerateArchives"];
	
	if (!result)
	{
		result = [NSNumber numberWithBool:NO];
		
		NSArray *archivePagelets = [[self managedObjectContext] pageletsWithPluginIdentifier:@"sandvox.CollectionArchiveElement"];
		NSEnumerator *pageletsEnumerator = [archivePagelets objectEnumerator];
		KTPagelet *aPagelet;
		while (aPagelet = [pageletsEnumerator nextObject])
		{
			if ([[aPagelet valueForKey:@"collection"] isEqual:self])
			{
				result = [NSNumber numberWithBool:YES];
				break;
			}
		}
		
		[self setPrimitiveValue:result forKey:@"collectionGenerateArchives"];
	}
	
	return [result boolValue];
}

- (void)setCollectionGenerateArchives:(BOOL)generateArchive
{
	// Ignore requests that will do nothing
	//BOOL noChange = (generateArchive == [self collectionGenerateArchives]);
	[self setWrappedBool:generateArchive forKey:@"collectionGenerateArchives"];
	//if (noChange) return;
	
	
	// Delete or add archive pages as needed
	if (generateArchive)
	{
		NSArray *children = [self navigablePages];
		NSEnumerator *pageEnumerator = [children objectEnumerator];
		KTPage *aPage;
		
		while (aPage = [pageEnumerator nextObject])
		{
			// Create any archives that are required
			[self archivePageForTimestamp:[aPage editableTimestamp] createIfNotFound:YES];
		}
	}
	else
	{
		NSSet *archivePages = [self valueForKey:@"archivePages"];
		[[self managedObjectContext] deleteObjectsInCollection:archivePages];
	}
}

/*	Searches through our archive pages for one containing the specified date.
 *	If archives are disabled, always returns nil.
 */
- (KTArchivePage *)archivePageForTimestamp:(NSDate *)timestamp createIfNotFound:(BOOL)flag
{
	OBPRECONDITION(timestamp);
	
	if (![self collectionGenerateArchives]) return nil;
	
	
	NSArray *archives = [[self valueForKey:@"archivePages"] allObjects];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"archiveStartDate <= %@ AND archiveEndDate > %@", timestamp, timestamp];
	KTArchivePage *result = [[archives filteredArrayUsingPredicate:predicate] firstObjectKS];
	
	if (!result && flag)
	{
		// Figure out the range of the timestamp
		NSCalendar *calendar = [NSCalendar currentCalendar];
		unsigned calendarComponents = (NSEraCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit);
		NSDateComponents *timestampComponents = [calendar components:calendarComponents fromDate:timestamp];
		NSDate *monthStart = [calendar dateFromComponents:timestampComponents];
		
		NSDateComponents *oneMonthDateComponent = [[[NSDateComponents alloc] init] autorelease];
		[oneMonthDateComponent setMonth:1];
		NSDate *monthEnd = [calendar dateByAddingComponents:oneMonthDateComponent toDate:monthStart options:0];
		
		
		// Create the archive.
		result = [KTArchivePage pageWithParent:self entityName:@"ArchivePage"];
		[result setValue:monthStart forKey:@"archiveStartDate"];
		[result setValue:monthEnd forKey:@"archiveEndDate"];
		
		
		// Give the archive a decent title
		[result updateTitle];
	}
	
	return result;
}

- (NSArray *)sortedArchivePages
{
    static NSArray *sortDescriptors;
    if (!sortDescriptors)
    {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"archiveStartDate" ascending:NO];
        sortDescriptors = [[NSArray alloc] initWithObject:sortDescriptor];
        [sortDescriptor release];
    }
    
    
    NSArray *result = [[[self valueForKey:@"archivePages"] allObjects] sortedArrayUsingDescriptors:sortDescriptors];
    return result;
}

@end
