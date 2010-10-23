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


@implementation GeneralIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
                           @"hyperlinkTitles", 
                           @"showPermaLink", 
                           @"truncateChars", 
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // parse template
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"hyperlinkTitles" ofObject:self];
    [context addDependencyForKeyPath:@"showPermaLink" ofObject:self];
    [context addDependencyForKeyPath:@"truncateChars" ofObject:self];
}

- (void)writeIndexStart
{
	id<SVPlugInContext> context = [SVPlugIn currentContext]; 
	switch(self.layoutType)
	{
		case kLayoutTable:
			[context startElement:@"table" attributes:[NSDictionary dictionaryWithObjectsAndKeys:
													   @"1", @"border", nil]];
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
	id<SVPlugInContext> context = [SVPlugIn currentContext]; 
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
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
	unsigned int index = [context currentIteration];
	int count = [context currentIterationsCount];

	NSMutableArray *classes = [NSMutableArray arrayWithObject:@"article"];
	if (index != NSNotFound)
	{
		NSString *indexClass = [NSString stringWithFormat:@"i%i", index + 1];
		[classes appendObject:indexClass];

		NSString *eoClass = (0 == ((index + 1) % 2)) ? @"e" : @"o";
		[classes appendObject:indexClass];

		if (index == (count - 1))
		{
			[classes appendObject:"last-item"];
		}
	}
	NSString *className = [classes componentsJoinedByString:@" "];
	
	
	
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
		[context startElement:@"td" classname:@"dli1"];
		[self writeThumbnailImageOfIteratedPage];
		[context endElement];
		[context startElement:@"td" classname:@"dli2"];
		[self writeTitleOfIteratedPage];
		[context endElement];
		[context startElement:@"td" classname:@"dli3"];
		[self writeSummaryOfIteratedPage];
		[context endElement];
		if (self.showTimestamps)
		{
			[context startElement:@"td" classname:@"dli4"];
			// [context writeText:iteratedPage.timestamp];
			[context endElement];
		}
	}
	else
	{
		
		
		
		
	}
	
	/*
	 <h3>[[=writeTitleOfIteratedPage]]</h3>
	 [[=writeThumbnailImageOfIteratedPage]]
	 [[=writeSummaryOfIteratedPage]]
	 <div class="article-info">
	 [[if truncateChars>0]]
	 <div class="continue-reading-link">
	 [[if parser.HTMLGenerationPurpose]]<a href="[[path iteratedPage]]">[[endif2]][[continueReadingLink iteratedPage]][[if parser.HTMLGenerationPurpose]]</a>[[endif2]]
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
	 
	 

	 <ul>
	 [[foreach indexablePagesOfCollection item]]
	 <li class="[[i]] [[eo]][[last]]">
	 <h3>[[=writeTitleAndLinkOfIteratedPage]]</h3>
	 </li>
	 [[endForEach]]
	 </ul>	 
	 
	 
	*/

	[context endElement];		// li, tr, or div
}

- (void)writeTitleOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    if ( self.hyperlinkTitles) { [[context HTMLWriter] startAnchorElementWithPage:iteratedPage]; } // <a>
    
    [context writeTitleOfPage:iteratedPage
                  asPlainText:NO
             enclosingElement:@"span"
                   attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
    
    if ( self.hyperlinkTitles ) { [[context HTMLWriter] endElement]; } // </a> 
}



/*
 [[summary item indexedCollection.collectionTruncateCharacters]]
 */

- (void)writeSummaryOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    [iteratedPage writeSummary:context truncation:self.truncateChars];
}


/*
<img[[idClass entity:Page property:item.thumbnail flags:"anchor" id:item.uniqueID]]
 src="[[mediainfo info:path media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 alt="[[=&item.titleText]]"
 width="[[mediainfo info:width media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 height="[[mediainfo info:height media:item.thumbnail sizeToFit:thumbnailImageSize]]" />*/

- (void)writeThumbnailImageOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    // Do a dry-run to see if there's actuall a thumbnail
    if ([iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:YES])
    {
        [[context HTMLWriter] startElement:@"div" className:@"article-thumbnail"];
        
        [iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:NO];
        
        [[context HTMLWriter] endElement];
    }
}


#pragma mark Properties

@synthesize hyperlinkTitles = _hyperlinkTitles;
@synthesize shortTitles = _shortTitles;
@synthesize showThumbnails = _showThumbnails;
@synthesize includeLargeMedia = _includeLargeMedia;
@synthesize showPermaLinks = _showPermaLinks;
@synthesize truncateChars = _truncateChars;
@synthesize truncationType = _truncationType;
@synthesize layoutType = _layoutType;
@synthesize showTimestamps = _showTimestamps;


@end
