//
//  KTPublishingWindowController.m
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPublishingWindowController.h"


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
    
    // Start progress indicator
    [oProgressIndicator startAnimation:self];
}

- (KTTransferController *)transferController;
{
    return _transferController;
}

@end
