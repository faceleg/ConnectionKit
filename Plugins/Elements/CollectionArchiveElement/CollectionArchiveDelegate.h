//
//  RSSBadgeDelegate.h
//  RSS Badge
//
//  Created by Mike on 20/11/2006.
//  Copyright 2006 Karelia. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SandvoxPlugin.h>


@interface CollectionArchiveDelegate : KTAbstractPluginDelegate
{
	IBOutlet KTLinkSourceView	*collectionLinkSourceView;
}

// IB Actions
- (IBAction)clearCollectionLink:(id)sender;

@end
