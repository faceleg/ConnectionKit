//
//  GeneralIndex.m
//  GeneralIndex
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "GeneralIndexPlugIn.h"

@interface GeneralIndexPlugIn ()
- (void)writeThumbnailImageOfIteratedPage;
- (void)writeTitleOfIteratedPage;
- (BOOL)writeSummaryOfIteratedPage;
- (void)writeArticleInfoWithContinueReadingLink:(BOOL)continueReading;
- (void)writeContinueReadingLink;
- (BOOL) hasArticleInfo;
@end


//FIXME: we really shouldn't rely on private API, if we need it, we should
//discuss and expose the proper level of API from Sandvox
@protocol PagePrivate <SVPage>
- (NSNumber *)allowComments;
- (id) master;
- (void)writeComments:(id<SVPlugInContext>)context;
- (BOOL)writeContent:(id <SVPlugInContext>)context
		  truncation:(NSUInteger)maxCount
			  plugIn:(SVPlugIn *)plugIn
			 options:(SVPageWritingOptions)options;

@end


@interface NSString (KareliaPrivate)
- (NSString*)stringByReplacingOccurrencesOfString:(NSString *)value withString:(NSString *)newValue;
@end

@implementation GeneralIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"hyperlinkTitles",
						   @"indexLayoutType",
						   @"showPermaLinks",
                           @"showComments",
						   @"showTimestamps",
                           @"timestampType",
						   @"maxItemLength",
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}

- (void)awakeFromNew;
{
	[super awakeFromNew];
    
    self.enableMaxItems = YES;
    self.maxItems = 10;
	
	NSNumber *isPagelet = [self valueForKeyPath:@"container.isPagelet"];	// Private. If creating in sidebar, make it more minimal
	if (isPagelet && [isPagelet boolValue])
	{
		self.indexLayoutType			= kLayoutTitlesList;
	}
}

#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
	// add dependencies
	[context addDependencyForKeyPath:@"hyperlinkTitles"		ofObject:self];
	[context addDependencyForKeyPath:@"indexLayoutType"		ofObject:self];
	[context addDependencyForKeyPath:@"showPermaLinks"		ofObject:self];
	[context addDependencyForKeyPath:@"showComments"		ofObject:self];
	[context addDependencyForKeyPath:@"showTimestamps"		ofObject:self];
    [context addDependencyForKeyPath:@"timestampType"       ofObject:self];
	[context addDependencyForKeyPath:@"maxItemLength"		ofObject:self];

	// parse template
    [super writeHTML:context];
    
}

- (void)writeIndexStart
{
	id<SVPlugInContext> context = [self currentContext]; 

	if (self.indexLayoutType & kTableMask)
	{
		[context startElement:@"table" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
												   @"0", @"border", nil]];		// TEMPORARY BORDER
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context startElement:@"ul"];
	}
}

- (void)writeIndexEnd
{
	id<SVPlugInContext> context = [self currentContext]; 

	if (self.indexLayoutType & kTableMask)
	{
		[context endElement];
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context endElement];
	}
}


- (void)writeInnards
{
	BOOL truncated = NO;
    id<SVPlugInContext> context = [self currentContext];
	
	NSString *className = [context currentIterationCSSClassNameIncludingArticle:0 != (self.indexLayoutType & kArticleMask)];
	
	if (self.indexLayoutType & kTableMask)
	{
		[context startElement:@"tr" className:className];
	}
	else if (self.indexLayoutType & kListMask)
	{
		[context startElement:@"li" className:className];
	}
	else
	{
		[context startElement:@"div" className:className];
	}
		
	// Table: We write Thumb, then title....
	if (self.indexLayoutType & kTableMask)
	{
		if (self.indexLayoutType & kThumbMask)
		{
			[context startElement:@"td" className:@"dli1"];
			[self writeThumbnailImageOfIteratedPage];
			[context endElement];
		}
		if (self.indexLayoutType & kTitleMask)
		{
			[context startElement:@"td" className:@"dli2"];
			[context startHeadingWithAttributes:
				[NSDictionary dictionaryWithObject:@"index-title" forKey:@"class"]];
			[self writeTitleOfIteratedPage];
			[context endElement];
			[context endElement];
		}
		
		if (self.indexLayoutType & kArticleMask)
		{
			[context startElement:@"td" className:@"dli3"];
			truncated = [self writeSummaryOfIteratedPage];
			
			if (truncated)	// put the continue reading link directly below the text
			{
				[self writeContinueReadingLink];
			}
			[context endElement];
		}
		
		// Do another column if we want to show some meta info
		
		if ((self.indexLayoutType & kArticleMask) && [self hasArticleInfo])
		{
			[context startElement:@"td" className:@"dli4"];
			[self writeArticleInfoWithContinueReadingLink:NO];
			[context endElement];
		}
	}
	else	// Not a table
	{
		if (self.indexLayoutType & kTitleMask)
		{
			if (self.indexLayoutType & kListMask)
			{
				[self writeTitleOfIteratedPage];		// List: Just the title, no header
			}
			else
			{
				[context startHeadingWithAttributes:
				 [NSDictionary dictionaryWithObject:@"index-title" forKey:@"class"]];
				[self writeTitleOfIteratedPage];
				[context endElement];
			}
		}
		if (self.indexLayoutType & kThumbMask)
		{
			[self writeThumbnailImageOfIteratedPage];
		}
		if (self.indexLayoutType & kArticleMask)
		{
			truncated = [self writeSummaryOfIteratedPage];
			[self writeArticleInfoWithContinueReadingLink:truncated];
		}
	}
	
	/*
	 <div class="article-info">
		 [[if truncateChars>0]]
		 <div class="continue-reading-link">
			[[if parser.HTMLGenerationPurpose]]<a href="[[path iteratedPage]]">[[endif2]]
				[[continueReadingLink iteratedPage]]
			[[if parser.HTMLGenerationPurpose]]</a>[[endif2]]
		 </div>
		 [[endif]]
		 
		 [[if iteratedPage.includeTimestamp]]
			<div class="timestamp">
				[[if showPermaLink]]
					<a [[target iteratedPage]]href="[[path iteratedPage]]">[[=&iteratedPage.timestamp]]</a>
				[[else2]]
					[[=&iteratedPage.timestamp]]
				[[endif2]]
			</div>
		 [[endif]]
		 
		 [[COMMENT parsecomponent iteratedPage iteratedPage.commentsTemplate]]
	 </div> <!-- article-info -->
	 </div> <!-- article -->
	 <div class="clear">
	 
	 
	 NOTE
	 
	 
	 when you see something like this
	 [[if parser.HTMLGenerationPurpose==0]]
	 you need to change it to
	 [[if currentContext.isForEditing]]
	 
	*/

	[context endElement];		// li, tr, or div
}

- (void)writeContinueReadingLink;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage,PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	// Note: Right now we are just writing out the format.  We are not providing a way to edit or customize this.
	
	[context startElement:@"div" className:@"continue-reading-link"];
	[context startAnchorElementWithPage:iteratedPage];
	
	NSString *format = [[iteratedPage master] valueForKey:@"continueReadingLinkFormat"];
	NSString *title = [iteratedPage title];
	if (nil == title)
	{
		title = @"";		// better than nil, which crashes!
	}
	NSString *textToWrite = [format stringByReplacingOccurrencesOfString:@"@@" withString:title];
	[context writeCharacters:textToWrite];
	[context endElement];	// </a>
	[context endElement];	// </div> continue-reading-link
}

- (BOOL) hasArticleInfo;		// Do we have settings to show an article info column or section?
{
	id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage, PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	return (self.showTimestamps)
		|| self.showPermaLinks
		|| (self.showComments 
            && [iteratedPage respondsToSelector:@selector(allowComments)] 
            && [[iteratedPage allowComments] boolValue]);
}

- (void)writeArticleInfoWithContinueReadingLink:(BOOL)continueReading;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage,PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	[context startElement:@"div" className:@"article-info"];
	
	if (continueReading)	// put the continue reading link along with the article info
	{
		[self writeContinueReadingLink];
	}
	
	if ( (self.showTimestamps)
			|| self.showPermaLinks)		// timestamps and/or permanent links need timestamp <div>
	{
		
		[context startElement:@"div" className:@"timestamp"];
		
		if (self.showPermaLinks)		// If we are doing permanent link, start <a>
		{
			[context startAnchorElementWithPage:iteratedPage];
		}
		if (self.showTimestamps)	// Write out either timestamp ....
		{
            NSDate *timestampDate = ([self timestampType] ? [iteratedPage modificationDate] : [iteratedPage creationDate]);
			NSString *timestamp = [iteratedPage timestampDescriptionWithDate:timestampDate];
			if (timestamp)
			{
				[context writeCharacters:timestamp];
			}
		}
		else if (self.showPermaLinks)	// ... or permanent link text ..
		{
			NSBundle *bundle = [NSBundle bundleForClass:[self class]];
			NSString *language = [iteratedPage language];
			NSString *permaLink = [bundle localizedStringForString:@"Permanent Link" language:language fallback:
								   SVLocalizedString(@"Permanent Link", @"Text in website's language to indicate a permanent link to the page")];
			[context writeCharacters:permaLink];
		}
		if ( self.showPermaLinks )
		{
			[context endElement];	// </a>
		}
		[context endElement];	// </div> timestamp
	}
	
	if ( self.showComments 
        && [iteratedPage respondsToSelector:@selector(allowComments)] 
        && [[iteratedPage allowComments] boolValue] )
	{
		[iteratedPage writeComments:context];		// PRIVATE		
	}
	
	[context endElement];	// </div> article-info	
}

- (void)writeTitleOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage, PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];
	
	if ([iteratedPage showsTitle])		// Do not show title if it is hidden!
	{
		if ( self.hyperlinkTitles) { [context startAnchorElementWithPage:iteratedPage]; } // <a>
		
		[context writeElement:@"span"
			  withTitleOfPage:iteratedPage
				  asPlainText:(0 == (kArticleMask & self.indexLayoutType))		// plain text 
				   attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
		
		if ( self.hyperlinkTitles ) { [context endElement]; } // </a> 
	}
}


/*
 [[summary item indexedCollection.collectionTruncateCharacters]]
 */

- (BOOL)writeSummaryOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<PagePrivate> iteratedPage = [context objectForCurrentTemplateIteration];

	// BOOL includeLargeMedia = self.indexLayoutType & kLargeMediaMask;
	BOOL excludeThumbnail = self.indexLayoutType & kThumbMask;
	SVPageWritingOptions truncationOptions = 0;
	if (excludeThumbnail) truncationOptions = SVPageWritingSkipThumbnail;
	
    BOOL truncated = [iteratedPage writeContent:context
									 truncation:self.maxItemLength
										 plugIn:self		// so we can stop recursion
										options:truncationOptions];
	return truncated;
}


/*
<img[[idClass entity:Page property:item.thumbnail flags:"anchor" id:item.uniqueID]]
 src="[[mediainfo info:path media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 alt="[[=&item.titleText]]"
 width="[[mediainfo info:width media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 height="[[mediainfo info:height media:item.thumbnail sizeToFit:thumbnailImageSize]]" />*/

- (void)writeThumbnailImageOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    // Do a dry-run to see if there's actually a thumbnail
    if ([context URLForImageRepresentationOfPage:iteratedPage
                                           width:64
                                          height:64
                                         options:(SVImageScaleAspectFit | SVPageImageRepresentationLink)])
    {
        [context startElement:@"div" className:@"article-thumbnail"];
        
        [context writeImageRepresentationOfPage:iteratedPage
                                width:64
                               height:64
                           attributes:nil
                              options:(SVImageScaleAspectFit | SVPageImageRepresentationLink)];
        
        [context endElement];
    }
}

- (NSString *)inlineGraphicClassName;
{
    return ([self indexLayoutType] == kLayoutTable ? @"Download-index" : @"general-index");
}

#pragma mark Properties

@synthesize hyperlinkTitles = _hyperlinkTitles;
@synthesize indexLayoutType = _indexLayoutType;
@synthesize showPermaLinks	= _showPermaLinks;
@synthesize showEntries = _showEntries;
@synthesize showTitles = _showTitles;
@synthesize showComments	= _showComments;
@synthesize showTimestamps	= _showTimestamps;
@synthesize timestampType = _timestampType;
@synthesize maxItemLength	= _maxItemLength;

- (void) setIndexLayoutType:(IndexLayoutType)aType	// custom setter to also set dependent flags
{
	_indexLayoutType = aType;
	self.showTitles = 0 != (aType & kTitleMask);
	self.showEntries = 0 != (aType & kArticleMask);
}

#pragma mark -
#pragma mark Migration

/* We set the comments and timestamp checkboxes if at least one page has that visibility set.
 */
- (void)awakeFromSourceInstance:(NSManagedObject *)sInstance;
{
	[super awakeFromSourceInstance:sInstance];		// this will get awakeFromSourceProperties called
	
	if ([[[sInstance entity] name] isEqualToString:@"Page"] ||
		[[[sInstance entity] name] isEqualToString:@"Root"])	// make sure it's not an index pagelet
	{
		NSSet *children = [sInstance valueForKey:@"children"];
		
		BOOL foundOneTimestamp = NO;
		BOOL foundOneComment = NO;
		BOOL foundOneThumbnail = NO;
		for (NSManagedObject *child in children)
		{
			NSString *thumbnailMediaIdentifier = [child valueForKey:@"thumbnailMediaIdentifier"];
			if (thumbnailMediaIdentifier)
			{
				foundOneThumbnail = YES;
			}
			
			NSNumber *includeTimestamp = [child valueForKey:@"includeTimestamp"];
			if (includeTimestamp && [includeTimestamp boolValue])
			{
				foundOneTimestamp = YES;
			}
			NSNumber *allowComments = [child valueForKey:@"allowComments"];
			if (allowComments && [allowComments boolValue])
			{
				foundOneComment = YES;
			}
			if (foundOneTimestamp && foundOneComment && foundOneThumbnail)
			{
				break;		// no point in continuing if all are turned on
			}
		}
		if (foundOneTimestamp)
		{
			self.showTimestamps = YES;
		}
		if (foundOneComment)
		{
			self.showComments = YES;
		}
		if (foundOneThumbnail && kLayoutArticlesAndMedia == self.indexLayoutType)
		{
			self.indexLayoutType = kLayoutArticlesAndThumbs;		// we had thumbs before, so use this instead.
		}
	}
}


- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
    NSMutableDictionary *propertiesByRemovingNSNull = [[NSMutableDictionary alloc] initWithCapacity:[properties count]];
    [propertiesByRemovingNSNull setValuesForKeysWithDictionary:properties];
    
    
	//NSLog(@"prop keys to convert: %@", [[[properties allKeys] description] condenseWhiteSpace]);
	NSString *collectionIndexBundleIdentifier = [properties objectForKey:@"collectionIndexBundleIdentifier"];
	if ([collectionIndexBundleIdentifier isEqualToString:@"sandvox.ListingIndex"])
	{
		self.indexLayoutType = kLayoutTitlesList;		// kLayoutTitles ?
	}
	else if ([collectionIndexBundleIdentifier isEqualToString:@"sandvox.GeneralIndex"])
	{
		self.indexLayoutType = kLayoutArticlesAndMedia;	// ? kLayoutArticlesAndThumbs
	}
	else if ([collectionIndexBundleIdentifier isEqualToString:@"sandvox.DownloadIndex"])
	{
		self.indexLayoutType = kLayoutTable;
	}
 	else if ([[properties objectForKey:@"pluginIdentifier"] isEqualToString:@"sandvox.IndexElement"])
	{
		self.indexLayoutType = kLayoutTitlesList;	// A collection index pagelet
	}
	else 
    {
        self.indexLayoutType = kLayoutTitlesList; //FIXME: what should the fallback be?
    }

	if (nil != [properties objectForKey:@"collectionHyperlinkPageTitles"])
	{
        self.hyperlinkTitles = 
		[collectionIndexBundleIdentifier isEqualToString:@"sandvox.ListingIndex"]		// listing index automatically gets hyperlinks
			|| [[propertiesByRemovingNSNull objectForKey:@"collectionHyperlinkPageTitles"] boolValue];
	}
	else
	{
		self.hyperlinkTitles = YES;
	}
	self.showPermaLinks = [[propertiesByRemovingNSNull objectForKey:@"collectionShowPermanentLink"] boolValue];
	self.showTimestamps = [[properties objectForKey:@"includeTimestamp"] boolValue];
	self.showComments = [[properties objectForKey:@"allowComments"] boolValue];			// disableComments ?
	
    self.maxItemLength = [[propertiesByRemovingNSNull objectForKey:@"collectionTruncateCharacters"] intValue];
    if (!self.maxItemLength) self.maxItemLength = 999999;
	
    
    // Finish up
    [propertiesByRemovingNSNull release];
	[super awakeFromSourceProperties:properties];

	
	/*
	POSSIBLE VALUES WE MAY BE GIVEN
	 
	 allowComments
	 callouts
	 childIndex
	 codeInjectionBeforeHTML
	 codeInjectionBodyTag
	 codeInjectionBodyTagEnd
	 codeInjectionBodyTagStart
	 codeInjectionEarlyHead
	 codeInjectionHeadArea
	 collectionGenerateArchives
	 collectionGenerateAtom
	 collectionGenerateRSS
	 collectionHyperlinkPageTitles
	 collectionIndexBundleIdentifier
	 collectionMaxIndexItems
	 collectionRSSEnclosures
	 collectionShowNavigationArrows
	 collectionShowPermanentLink
	 collectionSortOrder
	 collectionSummaryMaxPages
	 collectionSummaryType
	 collectionSyndicate
	 collectionSyndicateWithParent
	 collectionTruncateCharacters
	 creationDate
	 customFileExtension
	 customPathRelativeToSite
	 customSiteOutlineIcon
	 customSiteOutlineIconIdentifier
	 customSummaryHTML
	 disableComments
	 editableTimestamp
	 extensiblePropertiesData
	 fileExtensionIsEditable
	 fileName
	 html
	 htmlType
	 includeInheritedSidebar
	 includeInIndex
	 includeInSiteMap
	 includeInSiteMenu
	 includeSidebar
	 includeTimestamp
	 index
	 insertHead
	 insertPrelude
	 introductionHTML
	 isCollection
	 isDraft
	 isStale
	 keywords
	 keywordsData
	 lastModificationDate
	 menuTitle
	 metaDescription
	 pagesInIndex
	 plugin
	 pluginHTMLIsFullPage
	 pluginIdentifier
	 pluginVersion
	 publishedDataDigest
	 publishedPath
	 richTextHTML
	 RSSFileName
	 setWindowTitle
	 shouldUpdateFileNameWhenTitleChanges
	 sidebarChangeable
	 sidebarPagelets
	 sortedChildren
	 thumbnail
	 thumbnailMediaIdentifier
	 titleHTML
	 uniqueID
	 URL
	 useAbsoluteLinks
	 windowTitle
*/	 
}
@end
