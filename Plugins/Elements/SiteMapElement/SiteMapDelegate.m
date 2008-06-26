//
//  SiteMapDelegate.m
//  SiteMap
//
//  Copyright (c) 2006, Karelia Software. All rights reserved.
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

#import "SiteMapDelegate.h"


@interface NSMutableString ( indentation )
- (void)appendIndent:(int)anIndent;
@end


@implementation NSMutableString ( indentation )

- (void)appendIndent:(int)anIndent
{
	int i;
	for (i = 0 ; i < anIndent ; i++ )
	{
		[self appendString:@"\t"];
	}
}
@end


#pragma mark -


@implementation SiteMapDelegate

#pragma mark -
#pragma mark Site Structure Notification

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	id site = [[[self delegateOwner] page] valueForKey:@"documentInfo"];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(siteStructureDidChange:)
												 name:KTSiteStructureDidChangeNotification
											   object:site];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/*	Due to the unique nature of the Site Map, we want to be marked as stale whenever a change happens to another page that affects
 *	the overall site structure.
 */
- (void)siteStructureDidChange:(NSNotification *)notification
{
	// If this is during an undo, ignore it as the staleness is managed for us
	NSUndoManager *undoManager = [self undoManager];
	if (![undoManager isUndoing] && ![undoManager isRedoing])
	{
		[[self delegateOwner] setIsStale:YES];
	}
}

#pragma mark -
#pragma mark HTML

/*!	Recursive method
*/
- (void) appendMapOfPage:(KTPage *)aPage
		  relativeToPage:(KTPage *)thisPage
				toBuffer:(NSMutableString *)string
			 wantCompact:(BOOL)aWantCompact
			  topSection:(BOOL)isTopSection
				  indent:(int)anIndent
{
	[[self delegateOwner] lockPSCAndMOC];
	
	if (![aPage excludedFromSiteMap])
	{
		NSArray *children = [aPage sortedChildren];

		[string appendIndent:anIndent];
		if (isTopSection)
		{
			[string appendString:@"<h3>"];
		}
		else
		{
			[string appendString:@"<li>"];
		}
		
		if (aPage == thisPage)	// not likely but maybe possible
		{
			[string appendString:[[aPage titleText] escapedEntities]];	/// HTML was leaving extra formatting; we want it less dramatic
		}
		else
		{
//			/// special case for LinkPage, add target=_BLANK if LinkPage and newWindowLink
//			if ( [[[aPage delegate] class] isEqual:[NSClassFromString(@"LinkPageDelegate") class]]
//				 && (1 == [(NSNumber *)[aPage valueForKey:@"linkType"] intValue]) ) // 1 is newWindowLink
//			{
//				[string appendFormat:@"<a target=\"_blank\" href=\"%@\">%@</a>", [aPage pathRelativeTo:thisPage], [[aPage titleText] escapedEntities]];
//			}
//			else
//			{
			NSString *href = [[aPage URL] stringRelativeToURL:[thisPage URL]];
            OBASSERT([href lowercaseString]);               // The lowercase string will help us track down zombies etc.
            NSString *title = [[aPage titleText] escapedEntities];
            OBASSERT([title lowercaseString]);
            
            [string appendFormat:@"<a href=\"%@\">%@</a>", href, title];
//			}
		}
		
		if (isTopSection)
		{
			[string appendString:@"</h3>\n"];
		}
		else
		{
			// There are children -- so start them on a new line.  Otherwise we'll close <ul> below without a newline
			if ([children count])
			{
				[string appendString:@"\n"];
			}
			
		}
		
		if ([children count])
		{
			// If we want compact, go through and look to see if any of the children have children --
			// if so, we can't be compact at this level.
			BOOL doCompact = NO;
			
			if (aWantCompact)
			{
				BOOL canBeCompact = NO;
				NSEnumerator *theEnum = [children objectEnumerator];
				KTPage *aChildPage;

				while (aChildPage = [theEnum nextObject])
				{
					if (![aChildPage hasChildren] && ![aChildPage excludedFromSiteMap])
					{
						canBeCompact = YES;
						break;
					}
				}
				doCompact = canBeCompact;	// we wanted compact, set whether to do it here
			}
			
			if (doCompact)	// immediately show children inline, without a recursion
			{
				NSEnumerator *theEnum = [children objectEnumerator];
				KTPage *aChildPage;
				BOOL firstPass = YES;
				[string appendIndent:anIndent+1];
				[string appendString:@"<ul><li>\n"];
				while (aChildPage = [theEnum nextObject])
				{
					if (![aChildPage excludedFromSiteMap])
					{
						[string appendIndent:anIndent+2];
						if (firstPass)
						{
							firstPass = NO;
						}
						else
						{
							[string appendString:@"&middot; "];
						}
						if (aChildPage == thisPage)	// not likely but maybe possible
						{
							NSString *title = [[aChildPage titleText] escapedEntities];
                            OBASSERT([title lowercaseString]);
                            [string appendFormat:@"%@\n", title];
						}
						else
						{
							NSString *path = [[aChildPage URL] stringRelativeToURL:[thisPage URL]];
                            OBASSERT([path lowercaseString]);
                            NSString *title = [[aChildPage titleText] escapedEntities];
                            OBASSERT([title lowercaseString]);
                            [string appendFormat:@"<a href=\"%@\">%@</a>\n", path, title];
						}
						// need separator?	
					}
				}
				[string appendIndent:anIndent+1];
				[string appendString:@"</li></ul>\n"];
			}
			else	// non-compact way -- a list
			{
				[string appendIndent:anIndent+1];
				[string appendString:@"<ul>\n"];
				NSEnumerator *theEnum = [children objectEnumerator];
				KTPage *aChildPage;
				
				while (nil != (aChildPage = [theEnum nextObject]) )
				{
					[self appendMapOfPage:aChildPage relativeToPage:thisPage toBuffer:string wantCompact:aWantCompact topSection:NO indent:anIndent+2];
				}
				[string appendIndent:anIndent+1];
				[string appendString:@"</ul>\n"];
			}
		}
		
		// Close list item for this guy
		if (!isTopSection)
		{
			if ([children count])		// if there were children, then we close list on new line
			{
				[string appendIndent:anIndent];
			}
			[string appendString:@"</li>\n"];
		}
	}
	
	[[self delegateOwner] unlockPSCAndMOC];
}



- (NSString *)siteMap
{
	[[self delegateOwner] lockPSCAndMOC];
	
	NSMutableString *string = [NSMutableString string];	
	BOOL sections = [[self pluginProperties] boolForKey:@"sections"];	// top level items as H3
	BOOL showHome = [[self pluginProperties] boolForKey:@"showHome"];
	BOOL compact = [[self pluginProperties] boolForKey:@"compact"];
	
	KTPage *thisPage = [self delegateOwner];
	KTPage *root = [[thisPage documentInfo] root];
	
	if (showHome)
	{
		// Note: if site map IS home, it will still be shown regardless of show site map checkbox
		[string appendString:(sections ? @"<h3>" : @"<p>")];
		if (root == thisPage)	// not likely but maybe possible
		{
			[string appendString:[[root titleText] escapedEntities]];
		}
		else
		{
			NSString *path = [[root URL] stringRelativeToURL:[thisPage URL]];
            OBASSERT([path lowercaseString]);
            NSString *title = [[root titleText] escapedEntities];
            OBASSERT([title lowercaseString]);
            [string appendFormat:@"<a href=\"%@\">%@</a>", path, title];
		}
		[string appendString:(sections ? @"</h3>\n" : @"</p>\n")];
	}
	NSArray *children = [root sortedChildren];
	NSEnumerator *theEnum = [children objectEnumerator];
	KTPage *topLevelPage;

	if (!sections)
	{
		[string appendString:@"<ul>\n"];
	}
	while (nil != (topLevelPage = [theEnum nextObject]) )
	{
		[self appendMapOfPage:topLevelPage relativeToPage:thisPage toBuffer:string wantCompact:compact topSection:sections indent:1];
	}
	if (!sections)
	{
		[string appendString:@"</ul>\n"];
	}
	
	[[self delegateOwner] unlockPSCAndMOC];
	return string;
}

@end
