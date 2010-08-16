//
//  CollectionArchiveInspector.m
//  CollectionArchiveElement
//
//  Created by Terrence Talbot on 8/16/10.
//  Copyright 2010 Terrence Talbot. All rights reserved.
//

#import "CollectionArchiveInspector.h"


@implementation CollectionArchiveInspector

- (void)awakeFromNib
{
	// Connect up the target icon if needed
	[collectionLinkSourceView setConnected:([[self propertiesStorage] valueForKey:@"collection"] != nil)];
}



#pragma mark -
#pragma mark Link source dragging

- (void)linkSourceConnectedTo:(KTPage *)aPage;
{
	if (aPage)
	{
		[[self propertiesStorage] setValue:aPage forKey:@"collection"];
	}
}

- (IBAction)clearCollectionLink:(id)sender
{
	[[self propertiesStorage] setValue:nil forKey:@"collection"];
	[collectionLinkSourceView setConnected:NO];
}


@end
