//
//  KTPublishingWindowController.h
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTTransferController.h"


@class KTTransferController, CKTransferRecord;


@interface KTPublishingWindowController : NSWindowController <KTTransferControllerDelegate>
{
    IBOutlet NSTextField            *oMessageLabel;
    IBOutlet NSTextField            *oInformativeTextLabel;
    IBOutlet NSProgressIndicator    *oProgressIndicator;
    IBOutlet NSButton               *oFirstButton;
    IBOutlet NSTableColumn          *oTransferDetailsTableColumn;
    
    
    @private
    KTTransferController    *_transferController;
    CKTransferRecord        *_currentTransfer;
    BOOL                    _didFail;
}

- (IBAction)firstButtonAction:(NSButton *)sender;

- (id)initWithTransferController:(KTTransferController *)transferController;
- (KTTransferController *)transferController;

- (CKTransferRecord *)currentTransfer;
@end
