//
//  GeneralIndex.m
//  GeneralIndex
//
//  Copyright 2004-2010 Karelia Software. All rights reserved.
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
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "GeneralIndexPlugIn.h"

@interface GeneralIndexPlugIn ()
- (void)writeThumbnailImageOfIteratedPage;
- (void)writeTitleOfIteratedPage;
- (void)writeSummaryOfIteratedPage;
@end


@implementation GeneralIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"hyperlinkTitles",
						   @"includeLargeMedia",
						   @"layoutType",
						   @"shortTitles",
						   @"showPermaLinks",
						   @"showEntries",
						   @"showTitles",
						   @"showThumbnails",
						   @"showTimestamps",
						   @"truncate",
						   @"truncateCount",
						   @"truncationType",
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // parse template
    [super writeHTML:context];
    
    // add dependencies
	[context addDependencyForKeyPath:@"hyperlinkTitles"		ofObject:self];
	[context addDependencyForKeyPath:@"includeLargeMedia"	ofObject:self];
	[context addDependencyForKeyPath:@"layoutType"			ofObject:self];
	[context addDependencyForKeyPath:@"shortTitles"			ofObject:self];
	[context addDependencyForKeyPath:@"showPermaLinks"		ofObject:self];
	[context addDependencyForKeyPath:@"showEntries"			ofObject:self];
	[context addDependencyForKeyPath:@"showTitles"			ofObject:self];
	[context addDependencyForKeyPath:@"showThumbnails"		ofObject:self];
	[context addDependencyForKeyPath:@"showTimestamps"		ofObject:self];
	[context addDependencyForKeyPath:@"truncateCount"		ofObject:self];
	[context addDependencyForKeyPath:@"truncationType"		ofObject:self];
	[context addDependencyForKeyPath:@"truncate"			ofObject:self];
}

- (void)writeIndexStart
{
	id<SVPlugInContext> context = [self currentContext]; 

	switch(self.layoutType)
	{
		case kLayoutTable:
			[context startElement:@"table" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
													   @"1", @"border", nil]];		// TEMPORARY BORDER
			break;
		case kLayoutList:
			[context startElement:@"ul"];
			break;
		case kLayoutSections:
			break;
	}
}

- (void)writeIndexEnd
{
	id<SVPlugInContext> context = [self currentContext]; 

	switch(self.layoutType)
	{
		case kLayoutTable:
			[context endElement];
			break;
		case kLayoutList:
			[context endElement];
			break;
		case kLayoutSections:
			break;
	}
}


- (void)writeInnards
{
    id<SVPlugInContext> context = [self currentContext];
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
	NSString *className = [context currentIterationCSSClassName];
	
	switch(self.layoutType)
	{
		case kLayoutTable:
			[context startElement:@"tr" className:className];
			break;
		case kLayoutList:
			[context startElement:@"li" className:className];
			break;
		case kLayoutSections:
			[context startElement:@"div" className:className];
			break;
	}
	
	// Table: We write Thumb, then title....
	if (kLayoutTable == self.layoutType)
	{
		if (self.showThumbnails)
		{
			[context startElement:@"td" className:@"dli1"];
			[self writeThumbnailImageOfIteratedPage];
			[context endElement];
		}
		[context startElement:@"td" className:@"dli2"];
		[context startElement:@"h3" className:@"index-title"];
		[self writeTitleOfIteratedPage];
		[context endElement];
		[context endElement];
		
		if (self.showEntries || !self.showTitles)	// make sure we show entries if titles not showing
		{
			[context startElement:@"td" className:@"dli3"];
			[self writeSummaryOfIteratedPage];
			[context endElement];
		}
		
		if (self.showTimestamps)
		{
			[context startElement:@"td" className:@"dli4"];
			[context writeText:iteratedPage.timestampDescription];
			[context endElement];
		}
	}
	else
	{
		[context startElement:@"h3" className:@"index-title"];
		[self writeTitleOfIteratedPage];
		[context endElement];

		if (self.showThumbnails)
		{
			[self writeThumbnailImageOfIteratedPage];
		}
		if (self.showEntries || !self.showTitles)	// make sure we show entries if titles not showing
		{
			[self writeSummaryOfIteratedPage];
		}
		if (self.showTimestamps || self.showPermaLinks)		// timestamps and/or permanent links need timestamp <div>
		{
			
			[context startElement:@"div" className:@"timestamp"];

			if (self.showPermaLinks)		// If we are doing permanent link, start <a>
			{
				[context startAnchorElementWithPage:iteratedPage];
			}
			if (self.showTimestamps)	// Write out either timestamp ....
			{
				[context writeText:iteratedPage.timestampDescription];
			}
			else if (self.showPermaLinks)	// ... or permanent link text ..
			{
				NSBundle *bundle = [NSBundle bundleForClass:[self class]];
				NSString *language = [iteratedPage language];
				NSString *permaLink = [bundle localizedStringForString:@"Permanent Link" language:language fallback:
									   LocalizedStringInThisBundle(@"Permanent Link", @"Text in website's language to indicate a permanent link to the page")];
				[context writeText:permaLink];
			}
			if ( self.showPermaLinks )
			{
				[context endElement];	// </a>
			}
			[context endElement];	// </div>
		}
	}
	
	/*
	 <div class="article-info">
		 [[if truncateCount>0]]
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
	 
	*/

	[context endElement];		// li, tr, or div
}

- (void)writeTitleOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    if ( self.hyperlinkTitles) { [context startAnchorElementWithPage:iteratedPage]; } // <a>
    
    [context writeElement:@"span"
          withTitleOfPage:iteratedPage
              asPlainText:NO
               attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
    
    if ( self.hyperlinkTitles ) { [context endElement]; } // </a> 
}



/*
 [[summary item indexedCollection.collectionTruncateCharacters]]
 */

- (void)writeSummaryOfIteratedPage;
{
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    [iteratedPage writeSummary:context
					truncation:self.truncateCount
				truncationType:(self.truncate ? self.truncationType : kTruncateNone)];
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
    
    // Do a dry-run to see if there's actuall a thumbnail
    if ([iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:YES])
    {
        [context startElement:@"div" className:@"article-thumbnail"];
        
        [iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:NO];
        
        [context endElement];
    }
}


#pragma mark Properties

@synthesize hyperlinkTitles = _hyperlinkTitles;
@synthesize includeLargeMedia = _includeLargeMedia;
@synthesize layoutType = _layoutType;
@synthesize shortTitles = _shortTitles;
@synthesize showPermaLinks = _showPermaLinks;
@synthesize showEntries = _showEntries;
@synthesize showTitles = _showTitles;
@synthesize showThumbnails = _showThumbnails;
@synthesize showTimestamps = _showTimestamps;
@synthesize truncateCount = _truncateCount;
@synthesize truncationType = _truncationType;
@synthesize truncate = _truncate;


@end
