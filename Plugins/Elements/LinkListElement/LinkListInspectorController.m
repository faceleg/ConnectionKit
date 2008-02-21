//
//  LinkListInspectorController.m
//  KTPlugins
//
//  Created by Mike on 09/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "LinkListInspectorController.h"

#import <SandvoxPlugin.h>


@implementation LinkListInspectorController

- (void)awakeFromNib
{
	// Set up the box under the table
	[tableButtonsBox setDrawsFrame:YES];
	[tableButtonsBox setFill:NTBoxBevel];
	[tableButtonsBox setBorderMask:(NTBoxLeft | NTBoxRight | NTBoxBottom)];
	[tableButtonsBox setFrameColor:[NSColor lightGrayColor]];
	
	// Give the buttons their icons
	[addLinkButton setImage:[NSImage addToTableButtonIcon]];
	[removeLinkButton setImage:[NSImage removeFromTableButtonIcon]];
}

@end
