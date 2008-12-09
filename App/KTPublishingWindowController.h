//
//  KTPublishingWindowController.h
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTTransferController;


@interface KTPublishingWindowController : NSWindowController
{
    IBOutlet NSTextField            *oMessageLabel;
    IBOutlet NSProgressIndicator    *oProgressIndicator;
    IBOutlet NSButton               *oFirstButton;
    IBOutlet NSTableColumn          *oTransferDetailsTableColumn;
    
    
    @private
    KTTransferController    *_transferController;
}

- (id)initWithTransferController:(KTTransferController *)transferController;
- (KTTransferController *)transferController;

@end
