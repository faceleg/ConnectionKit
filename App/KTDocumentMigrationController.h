//
//  KTDocumentMigrationController.h
//  Marvel
//
//  Created by Mike on 27/03/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTDocumentMigrationController : NSWindowController
{
	IBOutlet NSTextField			*messageTextField;
	IBOutlet NSTextField			*informativeTextField;
	IBOutlet NSProgressIndicator	*progressIndicator;
	IBOutlet NSButton				*cancelButton;
}

@end
