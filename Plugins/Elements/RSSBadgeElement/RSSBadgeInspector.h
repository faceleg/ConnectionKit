//
//  RSSBadgeInspector.h
//  RSSBadgeElement
//
//  Created by Dan Wood on 2/24/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"


@interface RSSBadgeInspector : SVInspectorViewController {

	IBOutlet KTLinkSourceView	*collectionLinkSourceView;
	IBOutlet MAImagePopUpButton	*iconTypePopupButton;

}

// IB Actions
- (IBAction)clearCollectionLink:(id)sender;

@end
