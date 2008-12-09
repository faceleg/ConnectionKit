//
//  KTPublishingWindowController.m
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPublishingWindowController.h"

#import <Connection/Connection.h>


@implementation KTPublishingWindowController

- (id)initWithTransferController:(KTTransferController *)transferController
{
    if (self = [self initWithWindowNibName:@"Publishing"])
    {
        _transferController = [transferController retain];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // There's a minimum of localized text in this nib, so we're handling it in entirely in code
    [oMessageLabel setStringValue:NSLocalizedString(@"Publishing…", @"Publishing sheet title")];
    
    // TODO: Ensure the button is wide enough for e.g. German
    [oFirstButton setTitle:NSLocalizedString(@"Stop", @"Stop publishing button title")];
    
    // Outline view uses special cell class
    NSCell *cell = [[CKTransferProgressCell alloc] initTextCell:@""];
    [oTransferDetailsTableColumn setDataCell:cell];
    [cell release];
    
    // Start progress indicator
    [oProgressIndicator startAnimation:self];
}

- (KTTransferController *)transferController;
{
    return _transferController;
}

/*  There's no point allowing the user to select items in the publishing sheet.
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return NO;
}

@end
