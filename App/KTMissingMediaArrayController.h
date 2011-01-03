//
//  KTMissingMediaArrayController.h
//  Marvel
//
//  Created by Mike on 10/11/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTMissingMediaController;


@interface KTMissingMediaArrayController : NSArrayController
{
	IBOutlet NSTableView				*oTableView;
	IBOutlet KTMissingMediaController	*windowController;
}

@end
