//
//  APManualListArrayController.h
//  Amazon List
//
//  Created by Mike on 22/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Handles drag and drop operations within the manual list table view.


#import <Cocoa/Cocoa.h>
#import "APProductsArrayController.h"


@class AmazonListInspector;


@interface APManualListArrayController : APProductsArrayController
{
	IBOutlet NSObjectController		*pluginController;
}

// Drag 'n' drop
- (NSArray *)URLDragTypes;
- (id)valueForDropFromPasteboard:(NSPasteboard *)pasteboard;	// Return nil if invalid
@end
