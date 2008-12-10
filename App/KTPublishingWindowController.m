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

- (id)initWithTransferController:(KTPublishingEngine *)transferController
{
    if (self = [self initWithWindowNibName:@"Publishing"])
    {
        _transferController = [transferController retain];
        [transferController setDelegate:self];
        
        // Get notified when transfers start or end
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(transferDidBegin:)
                                                     name:CKTransferRecordTransferDidBeginNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(transferDidFinish:)
                                                     name:CKTransferRecordTransferDidFinishNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_currentTransfer release];
    [_transferController setDelegate:nil];
    [_transferController release];
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // There's a minimum of localized text in this nib, so we're handling it in entirely in code
    [oMessageLabel setStringValue:NSLocalizedString(@"Publishing…", @"Publishing sheet title")];
    [oInformativeTextLabel setStringValue:NSLocalizedString(@"Preparing to upload…", @"Uploading progress info")];
    
    // TODO: Ensure the button is wide enough for e.g. German
    [oFirstButton setTitle:NSLocalizedString(@"Stop", @"Stop publishing button title")];
    
    // Outline view uses special cell class
    NSCell *cell = [[CKTransferProgressCell alloc] initTextCell:@""];
    [oTransferDetailsTableColumn setDataCell:cell];
    [cell release];
    
    // Start progress indicator
    [oProgressIndicator startAnimation:self];
}

#pragma mark -
#pragma mark Actions

- (IBAction)firstButtonAction:(NSButton *)sender
{
    [self endSheet];
}

#pragma mark -
#pragma mark Transfer Controller

- (KTPublishingEngine *)transferController;
{
    return _transferController;
}

/*  Once we know how much to upload, the progress bar can become determinate
 */
- (void)publishingEngineDidFinishGeneratingContent:(KTPublishingEngine *)engine
{
    [oProgressIndicator setIndeterminate:NO];
}

- (void)publishingEngineDidUpdateProgress:(KTPublishingEngine *)engine
{
    
    [oProgressIndicator setDoubleValue:[[engine rootTransferRecord] progress]];
}

- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error
{
    _didFail = YES;
    
    [oMessageLabel setStringValue:NSLocalizedString(@"Publishing failed.", @"Upload message text")];
    
    [oInformativeTextLabel setTextColor:[NSColor redColor]];
    NSString *errorDescription = [error localizedDescription];
    if (errorDescription) [oInformativeTextLabel setStringValue:errorDescription];
    
    [oProgressIndicator stopAnimation:self];
    
    [oFirstButton setTitle:NSLocalizedString(@"Close", @"Button title")];
}

#pragma mark -
#pragma mark Current Transfer

- (CKTransferRecord *)currentTransfer { return _currentTransfer; }

- (void)setCurrentTransfer:(CKTransferRecord *)transferRecord
{
    [transferRecord retain];
    [_currentTransfer release];
    _currentTransfer = transferRecord;
    
    if (transferRecord && [transferRecord name])
    {
        NSString *text = [[NSString alloc] initWithFormat:
                          NSLocalizedString(@"Uploading “%@”", @"Upload information"),
                          [transferRecord name]];
        [oInformativeTextLabel setStringValue:text];
        [text release];
    }
}

- (void)transferDidBegin:(NSNotification *)notification
{
    [self setCurrentTransfer:[notification object]];
}

- (void)transferDidFinish:(NSNotification *)notification
{
    CKTransferRecord *transferRecord = [notification object];
    if (transferRecord == [self currentTransfer])
    {
        [self setCurrentTransfer:nil];
    }
}

#pragma mark -
#pragma mark Outline View

/*  There's no point allowing the user to select items in the publishing sheet.
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return NO;
}

#pragma mark -
#pragma mark Presentation

- (void)beginSheetModalForWindow:(NSWindow *)window
{
    [self retain];  // Ensures we're not accidentally deallocated during presentation. Will release later
    
    [NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:NULL];
}

/*  Outside code shouldn't need to call this, we should handle it ourselves from clicking
 *  the Close or Stop button.
 */
- (void)endSheet;
{
    [[self transferController] cancel];
    
    [NSApp endSheet:[self window]];
    [[self window] orderOut:self];
    
    [self release]; // To balance the -retain when beginning the sheet.
}

@end
