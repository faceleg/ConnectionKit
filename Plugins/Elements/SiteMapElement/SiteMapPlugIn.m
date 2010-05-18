//
//  SiteMapPlugIn.m
//  Sandvox SDK: SiteMapElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
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

//  NOTE: No LocalizedStrings in this plugin, so no genstrings build phase needed


#import "SiteMapPlugIn.h"


@interface NSMutableString (indentation)
- (void)appendIndent:(int)anIndent;
@end


@implementation NSMutableString (indentation)

- (void)appendIndent:(int)anIndent
{
	int i;
	for (i = 0 ; i < anIndent ; i++ )
	{
		[self appendString:@"\t"];
	}
}
@end


@implementation SiteMapPlugIn


#pragma mark -
#pragma mark HTML Generation

///*!	Recursive method
// */
//- (void)appendMapOfPage:(id <SVPage>)aPage
//         relativeToPage:(id <SVPage>)thisPage
//               toBuffer:(NSMutableString *)string
//           wantsCompact:(BOOL)wantsCompact
//           isTopSection:(BOOL)isTopSection
//               indentBy:(int)anIndent
//{	
//    if ( [aPage includeInSiteMaps] )
//	{
//        
//        id <SVPlugInContext>context = [SVPageletPlugIn currentContext];
//        
//		// Fetch all children suitable for inclusion in the sitemap
////        static NSPredicate *includeInSiteMapPredicate;
////        if (!includeInSiteMapPredicate) {
////            includeInSiteMapPredicate = [[NSPredicate predicateWithFormat:@"excludedFromSiteMap == 0"] retain];
////        }
////        
////        NSArray *children = [[aPage sortedChildren] filteredArrayUsingPredicate:includeInSiteMapPredicate];
//        
//		
//        //FIXME: how to get all child pages where includeInSiteMaps returns YES?
//        
//        [string appendIndent:anIndent];
//		if (isTopSection)
//		{
//			[string appendString:@"<h3>"];
//		}
//		else
//		{
//			[string appendString:@"<li>"];
//		}
//		
//		if (aPage == thisPage)	// not likely but maybe possible
//		{
//			NSString *title = [aPage title];	/// HTML was leaving extra formatting; we want it less dramatic
//            if (title)
//            {
//                [string appendString:title];
//            }
//		}
//		else
//		{
//            //			/// special case for LinkPage, add target=_BLANK if LinkPage and newWindowLink
//            //			if ( [[[aPage delegate] class] isEqual:[NSClassFromString(@"LinkPageDelegate") class]]
//            //				 && (1 == [(NSNumber *)[aPage valueForKey:@"linkType"] intValue]) ) // 1 is newWindowLink
//            //			{
//            //				[string appendFormat:@"<a target=\"_blank\" href=\"%@\">%@</a>", [aPage pathRelativeTo:thisPage], [[aPage titleText] stringByEscapingHTMLEntities]];
//            //			}
//            //			else
//            //			{
//			//NSString *href = [[aPage URL] stringRelativeToURL:[thisPage URL]];
//            NSString *href = [context relativeURLStringOfPage:aPage];
//
//            OBASSERT(href);
//            NSString *title = [aPage title];
//            
//			if (title)
//			{
//				[string appendFormat:@"<a href=\"%@\">%@</a>", href, title];
//			}
//		}
//		
//		if (isTopSection)
//		{
//			[string appendString:@"</h3>\n"];
//		}
//		else
//		{
//			// There are children -- so start them on a new line.  Otherwise we'll close <ul> below without a newline
//			if ([children count])
//			{
//				[string appendString:@"\n"];
//			}
//			
//		}
//		
//		if ([children count])
//		{
//			// If we want compact, go through and look to see if any of the children have children --
//			// if so, we can't be compact at this level.
//			BOOL doCompact = NO;
//			
//			if (wantsCompact)
//			{
//				BOOL canBeCompact = NO;
//				NSEnumerator *theEnum = [children objectEnumerator];
//				KTPage *aChildPage;
//                
//				while (aChildPage = [theEnum nextObject])
//				{
//					if (![aChildPage hasChildren])
//					{
//						canBeCompact = YES;
//						break;
//					}
//				}
//                
//                for ( id<SVPage> childPage in childPages )
//                {
//                    if ( 
//                }
//				doCompact = canBeCompact;	// we wanted compact, set whether to do it here
//			}
//			
//			if (doCompact)	// immediately show children inline, without a recursion
//			{
//				NSEnumerator *theEnum = [children objectEnumerator];
//				KTPage *aChildPage;
//				BOOL firstPass = YES;
//				[string appendIndent:anIndent+1];
//				[string appendString:@"<ul><li>\n"];
//				while (aChildPage = [theEnum nextObject])
//				{
//                    [string appendIndent:anIndent+2];
//                    if (firstPass)
//                    {
//                        firstPass = NO;
//                    }
//                    else
//                    {
//                        [string appendString:@"&middot; "];
//                    }
//                    if (aChildPage == thisPage)	// not likely but maybe possible
//                    {
//                        NSString *title = [[aChildPage titleString] stringByEscapingHTMLEntities];
//                        OBASSERT([title lowercaseString]);
//                        [string appendFormat:@"%@\n", title];
//                    }
//                    else
//                    {
//                        NSString *path = [[aChildPage URL] stringRelativeToURL:[thisPage URL]];
//                        NSString *title = [[aChildPage titleString] stringByEscapingHTMLEntities];
//                        if (path && title) [string appendFormat:@"<a href=\"%@\">%@</a>\n", path, title];
//                    }
//                    // need separator?	
//				}
//				[string appendIndent:anIndent+1];
//				[string appendString:@"</li></ul>\n"];
//			}
//			else	// non-compact way -- a list
//			{
//				[string appendIndent:anIndent+1];
//				[string appendString:@"<ul>\n"];
//				NSEnumerator *theEnum = [children objectEnumerator];
//				KTPage *aChildPage;
//				
//				while (nil != (aChildPage = [theEnum nextObject]) )
//				{
//					[self appendMapOfPage:aChildPage relativeToPage:thisPage toBuffer:string wantsCompact:wantsCompact topSection:NO indent:anIndent+2];
//				}
//				[string appendIndent:anIndent+1];
//				[string appendString:@"</ul>\n"];
//			}
//		}
//		
//		// Close list item for this guy
//		if (!isTopSection)
//		{
//			if ([children count])		// if there were children, then we close list on new line
//			{
//				[string appendIndent:anIndent];
//			}
//			[string appendString:@"</li>\n"];
//		}
//	}
//}

- (NSString *)siteMap
{	
	NSMutableString *result = [NSMutableString string];
    
    id <SVPlugInContext>context = [SVPageletPlugIn currentContext];
	
	id <SVPage>thisPage = [context page];
	id <SVPage>rootPage = [thisPage rootPage];
    
    //FIXME: do we need to observe propertied for thisPage?
	
	if ( self.showHome )
	{
		// Note: if site map IS home, it will still be shown regardless of show site map checkbox
		[result appendString:(self.sections ? @"<h3>" : @"<p>")];
		if (rootPage == thisPage)	// not likely but maybe possible
		{
			NSString *title = [rootPage titleHTMLString];
            if ( title )
            {
                [result appendString:title];
            }
		}
		else
		{
            NSString *path = [context relativeURLStringOfPage:rootPage];
            if (!path) path = @"";  // Happens for a site with no -siteURL set yet
            
            NSString *title = [rootPage titleHTMLString];
            
            [result appendFormat:@"<a href=\"%@\">%@</a>", path, title];
		}
		[result appendString:(self.sections ? @"</h3>\n" : @"</p>\n")];
	}

	if (!self.sections)
	{
		[result appendString:@"<ul>\n"];
	}
    
    for ( KTPage *topLevelPage in [rootPage childPages] )
    {
        // recursively add each page
		[self appendMapOfPage:topLevelPage 
               relativeToPage:thisPage 
                     toBuffer:result
                 wantsCompact:self.compact 
                 isTopSection:self.sections 
                     indentBy:1];
        
        // observe each page's title, its children (child site items), and sort key
        [context addDependencyOnObject:thisPage keyPath:@"title"];
        //FIXME: how to observe children?
        //FIXME: hot to observe sort key?
    }

	if (!self.sections)
	{
		[result appendString:@"</ul>\n"];
	}
	
	return result;
}


#pragma mark -
#pragma mark Properties

@synthesize sections = _sections;
@synthesize showHome = _showHome;
@synthesize compact = _compact;
@end
