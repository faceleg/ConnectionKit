//
//  RSSBadgeInspector.h
//  RSSBadgeElement
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


#import "RSSBadgeInspector.h"
#import "RSSBadgePlugIn.h"


@implementation RSSBadgeInspector

- (NSString *)nibName { return @"RSSBadge"; }


#pragma mark -
#pragma mark Init

+ (void)initialize
{
	// Register value trasnsformers
	KSIsEqualValueTransformer *transformer = nil;
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardOrangeLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardOrangeLarge"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:RSSBadgeIconStyleStandardGrayLarge]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"RSSBadgeIconIsNotStandardGrayLarge"];
	[transformer release];
}

- (void)awakeFromNib
{
//	// Connect up the target icon if needed
//	[collectionLinkSourceView setConnected:([[self delegateOwner] valueForKey:@"collection"] != nil)];

	// Connect up the target icon if needed
	NSArray *selectedObjects = [[self inspectedObjectsController] selectedObjects];
	KTPage *collection = (KTPage *)[NSNull null];		// placeholder for not known
	NSCellStateValue state = NSMixedState;
	for (RSSBadgePlugIn *plugin in selectedObjects)
	{
		if (collection == (KTPage *)[NSNull null])
		{
			collection = plugin.collection;	// first pass through
			state = (nil != collection) ? NSOnState : NSOffState;
		}
		else
		{
			if (collection != plugin.collection)
			{
				state = NSMixedState;
				break;		// no point in continuing; it's a mixed state and there's no going back
			}
		}
	}
	[collectionLinkSourceView setConnected:(state == NSOnState)];
}






#pragma mark -
#pragma mark Link source dragging


- (void)linkSourceConnectedTo:(KTPage *)aPage;
{
	if (aPage)
	{
		[[[self inspectedObjectsController] selection] setValue:aPage forKey:@"collection"];
		[collectionLinkSourceView setConnected:YES];
	}
}

//- (IBAction)clearCollectionLink:(id)sender
//{
//	[[self delegateOwner] setValue:nil forKey:@"collection"];
//	[collectionLinkSourceView setConnected:NO];
//}

- (IBAction)clearCollectionLink:(id)sender
{
	[[[self inspectedObjectsController] selection] setValue:nil forKey:@"collection"];
	[collectionLinkSourceView setConnected:NO];
}





@end
