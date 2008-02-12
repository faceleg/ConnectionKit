//
//  ContactElementInspectorController.h
//  ContactElement
//
//  Created by Mike on 11/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class NTBoxView;


@interface ContactElementInspectorController : NSObject
{
	IBOutlet NTBoxView	*oFieldsTableButtonsBox;
	IBOutlet NSButton	*oAddLinkButton;
	IBOutlet NSButton	*oRemoveLinkButton;
}

@end
