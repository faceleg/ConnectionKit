//
//  LinkListInspectorController.h
//  KTPlugins
//
//  Created by Mike on 09/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class NTBoxView;


@interface LinkListInspectorController : NSObject
{
	IBOutlet NTBoxView	*tableButtonsBox;
	IBOutlet NSButton	*addLinkButton;
	IBOutlet NSButton	*removeLinkButton;
}

@end
