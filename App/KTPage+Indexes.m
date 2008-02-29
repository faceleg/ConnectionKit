//
//  KTPage+Indexes.m
//  Marvel
//
//  Created by Mike on 30/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "KTAbstractIndex.h"
#import "KTAppPlugin.h"
#import "KTIndexPlugin.h"

#import "NSCharacterSet+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSString+KTExtensions.h"
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
		
		Class indexClass = [NSBundle principalClassForBundle:bundle];
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
- (NSArray *)sortedChildrenInIndex
{
	NSArray *allChildren = [self sortedChildren];
	
	unsigned maxPages = [self integerForKey:@"collectionMaxIndexItems"];
	if (maxPages == 0) maxPages = [allChildren count];
	
	NSMutableArray *buffer = [[NSMutableArray alloc] initWithCapacity:maxPages];
	NSEnumerator *childrenEnumerator = [allChildren objectEnumerator];
	KTPage *aPage;
	while (aPage = [childrenEnumerator nextObject])
	{
		if ([aPage includeInIndexAndPublish])
		{
			[buffer addObject:aPage];
			
			if ([buffer count] >= maxPages) break;
		}
	}
	
	NSArray *result = [NSArray arrayWithArray:buffer];
	[buffer release];
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

- (NSString *)feedURLPathRelativeToPage:(KTAbstractPage *)aPage
{
	NSString *result = nil;
	
	if ([self boolForKey:@"collectionSyndicate"] && [self collectionCanSyndicate])
	{
		NSString *feedFileName = [[NSUserDefaults standardUserDefaults] objectForKey:@"RSSFileName"];
		NSString *collectionPath = [self pathRelativeToSiteWithCollectionPathStyle:KTCollectionDirectoryPath];
		NSString *feedPath = [collectionPath stringByAppendingPathComponent:feedFileName];
		
		NSString *comparisonFeedPath = [@"/" stringByAppendingString:feedPath];
		NSString *comparisonPagePath = [@"/" stringByAppendingString:[aPage publishedPathRelativeToSite]];
		
		result = [comparisonFeedPath pathRelativeTo:comparisonPagePath];
	}
	
	return result;
}

- (NSString *)feedURLPath
{
	return [self feedURLPathRelativeToPage:self];
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
	NSString *result = nil;
	
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
	
	return result;
}

#pragma mark -
#pragma mark Custom Summary

/*	Returns nil if there is no custom summary
 */
- (NSString *)customSummaryHTML { return [self wrappedValueForKey:@"customSummaryHTML"]; }

- (void)setCustomSummaryHTML:(NSString *)HTML { [self setWrappedValue:HTML forKey:@"customSummaryHTML"]; }

#pragma mark -
#pragma mark Title List

/*	Constructs the HTML for a title list-style summary using the specified ordering
 */
- (NSString *)titleListHTMLWithSorting:(KTCollectionSortType)sortType;
{
	NSMutableString *result = [NSMutableString stringWithString:@"<ul>\n"];
	
	NSArray *allSortedChildren = [self childrenWithSorting:sortType];
	NSRange childrenRange = NSMakeRange(0, MIN([allSortedChildren count], [self integerForKey:@"collectionSummaryMaxPages"]));
	NSArray *sortedChildren = [allSortedChildren subarrayWithRange:childrenRange];
	
	NSEnumerator *pagesEnumerator = [sortedChildren objectEnumerator];
	KTPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		[result appendFormat:@"\t<li>%@</li>\n", [aPage valueForKey:@"titleHTML"]];
	}
	
	[result appendFormat:@"</ul>"];
	
	return result;
}

#pragma mark -
#pragma mark Other

/*	When creating a new page, load properties from the defaults
 */
- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setValue:[[NSUserDefaults standardUserDefaults] objectForKey:@"MaximumTitlesInCollectionSummary"]
			forKey:@"collectionSummaryMaxPages"];
}

@end
