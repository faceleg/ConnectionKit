//
//  KTPublishingWindowController.m
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTPublishingWindowController.h"

#import "KTDocumentInfo.h"
#import "KTDocWindowController.h"
#import "KTHostProperties.h"

#import "NSApplication+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import <Connection/Connection.h>
#import <Growl/Growl.h>


const float kWindowResizeOffset = 20.0; // "gap" between Stop button and accessory view


@implementation KTPublishingWindowController

#pragma mark -
#pragma mark Growl Support

+ (NSDictionary *)registrationDictionaryForGrowl
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	NSArray *strings = [NSArray arrayWithObjects:
                        NSLocalizedString(@"Publishing Complete", @"Growl notification"), 
                        NSLocalizedString(@"Export Complete", @"Growl notification"), nil];
	[dict setObject:strings
			 forKey:GROWL_NOTIFICATIONS_ALL];
	[dict setObject:strings
			 forKey:GROWL_NOTIFICATIONS_DEFAULT];
	return dict;
}

+ (NSString *)applicationNameForGrowl
{
	return [NSApplication applicationName];
}

/*  If the user clicks a notification with a URL, open it.
 */
+ (void)growlNotificationWasClicked:(id)clickContext
{
	if (clickContext && [clickContext isKindOfClass:[NSString class]])
	{
		NSURL *URL = [[NSURL alloc] initWithString:clickContext];
        if (URL)
		{
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
			[URL release];
		}
	}
}

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithPublishingEngine:(KTPublishingEngine *)engine
{
    if (self = [self initWithWindowNibName:@"Publishing"])
    {
        _publishingEngine = [engine retain];
        [engine setDelegate:self];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_publishingEngine setDelegate:nil];
    [_publishingEngine release];
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // There's a minimum of localized text in this nib, so we're handling it in entirely in code
    if ([self isExporting])
    {
        [oMessageLabel setStringValue:NSLocalizedString(@"Exporting…", @"Publishing sheet title")];
        [oInformativeTextLabel setStringValue:NSLocalizedString(@"Preparing to export…", @"Uploading progress info")];
    }
    else
    {
        [oMessageLabel setStringValue:NSLocalizedString(@"Publishing…", @"Publishing sheet title")];
        [oInformativeTextLabel setStringValue:NSLocalizedString(@"Preparing to upload…", @"Uploading progress info")];
    }
    
    // TODO: Ensure the button is wide enough for e.g. German
    [oFirstButton setTitle:NSLocalizedString(@"Stop", @"Stop publishing button title")];
    
    // Outline view uses special cell class
    NSCell *cell = [[CKTransferProgressCell alloc] initTextCell:@""];
    [oTransferDetailsTableColumn setDataCell:cell];
    [cell release];
    
    // Start progress indicator
    [oProgressIndicator startAnimation:self];
	
	// preserve window size
	[self setShouldCascadeWindows:NO];
	[[self window] setFrameAutosaveName:@"KTPublishingWindow"];
	
	// remember our accessory size since setHidden: collapses y to 0
	_accessoryHeight = [oAccessoryView bounds].size.height;
	
	// show expanded view?
	BOOL shouldExpand = [[NSUserDefaults standardUserDefaults] boolForKey:@"ExpandPublishingWindow"];
	[oExpandButton setState:shouldExpand];
	[self showAccessoryView:shouldExpand animate:NO];
}

#pragma mark -
#pragma mark Actions

- (IBAction)firstButtonAction:(NSButton *)sender
{
    [self endSheet];
}

- (IBAction)toggleExpanded:(id)sender
{
	BOOL shouldExpand = [sender state];
	
	[[NSUserDefaults standardUserDefaults] setBool:shouldExpand forKey:@"ExpandPublishingWindow"];
	[self showAccessoryView:shouldExpand animate:YES];
}


#pragma mark -
#pragma mark Publishing Engine

- (KTPublishingEngine *)publishingEngine;
{
    return _publishingEngine;
}

- (BOOL)isExporting
{
    BOOL result = ![[self publishingEngine] isKindOfClass:[KTRemotePublishingEngine class]];
    return result;
}

- (void)publishingEngine:(KTPublishingEngine *)engine didBeginUploadToPath:(NSString *)remotePath;
{
    NSString *format = ([self isExporting]) ?
						NSLocalizedString(@"Exporting “%@”", @"Upload information") :
						NSLocalizedString(@"Uploading “%@”", @"Upload information");
	
	NSString *text = [[NSString alloc] initWithFormat:format, [remotePath lastPathComponent]];
	[oInformativeTextLabel setStringValue:text];
	[text release];
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

/*  We're done publishing, close the window.
 */
- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine
{
    // Setup Growl
    [GrowlApplicationBridge setGrowlDelegate:(id)[KTPublishingWindowController class]];
    
    
    // Post Growl notification
    if ([self isExporting])
    {
        [GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Export Complete", "Growl notification")
                                    description:NSLocalizedString(@"Your site has been exported", "Growl notification")
                               notificationName:NSLocalizedString(@"Export Complete", "Growl notification")
                                       iconData:nil
                                       priority:1
                                       isSticky:NO
                                   clickContext:nil];
    }
    else
    {
        NSURL *siteURL = [[[engine site] hostProperties] siteURL];
        
        NSString *descriptionText;
        if ([[[engine connection] URL] isFileURL])
        {
            descriptionText = NSLocalizedString(@"The site has been published to this computer.", "Transfer Controller");
        }
        else
        {
            descriptionText = [NSString stringWithFormat:
                               NSLocalizedString(@"The site has been published to %@.", "Transfer Controller"),
                               [siteURL absoluteString]];
        }
        
        [GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Publishing Complete", @"Growl notification")
                                    description:descriptionText
                               notificationName:NSLocalizedString(@"Publishing Complete", @"Growl notification")
                                       iconData:nil
                                       priority:1
                                       isSticky:NO
                                   clickContext:[siteURL absoluteString]];
    }
    
    
    
    [self endSheet];
}

- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error
{
    _didFail = YES;
    
    // If publishing changes and there are none, it fails with a fake error message
    if ([[error domain] isEqualToString:KTPublishingEngineErrorDomain] && [error code] == KTPublishingEngineNothingToPublish)
    {
        KTDocWindowController *windowController = [_modalWindow windowController];
        OBASSERT(windowController); // This is a slightly hacky way to get to the controller, but it works
        
        [self endSheet];  // Act like the user cancelled
        
        // Put up an alert explaining why and let the window controller deal with it
        NSAlert *alert = [[NSAlert alloc] init];    // The window controller will release it
        [alert setMessageText:NSLocalizedString(@"No changes need publishing.", @"message for progress window")];
        [alert setInformativeText:NSLocalizedString(@"Sandvox has detected that no content has changed since the site was last published. Publish All will upload all content, regardless of whether it has changed or not.", "alert info text")];
        [alert addButtonWithTitle:NSLocalizedString(@"OK", @"change cancel button to ok")];
        [alert addButtonWithTitle:NSLocalizedString(@"Publish All", @"")];
        
        [alert beginSheetModalForWindow:[windowController window]
                          modalDelegate:windowController
                         didEndSelector:@selector(noChangesToPublishAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:NULL];
    }
    else
    {
        [oMessageLabel setStringValue:NSLocalizedString(@"Publishing failed.", @"Upload message text")];
        
        [oInformativeTextLabel setTextColor:[NSColor redColor]];
        NSString *errorDescription = [error localizedDescription];
        if (errorDescription) [oInformativeTextLabel setStringValue:errorDescription];
        
        [oProgressIndicator stopAnimation:self];
        
        [oFirstButton setTitle:NSLocalizedString(@"Close", @"Button title")];
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
#pragma mark Window

- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)proposedFrameSize
{
	// if the accessory view is hidden, don't resize vertically
	
	if ( ![oAccessoryView isHidden] )
	{
		return proposedFrameSize;
	}
	else
	{
		NSSize currentFrameSize = [window frame].size;
		return NSMakeSize(proposedFrameSize.width, 
						  currentFrameSize.height);
	}
}

- (void)windowDidResize:(NSNotification *)notification
{
	// if the window is resized, track the accessory view's change in height
	// (not called if window is being resized via -setFrame:display:animate:)
	
	if ( ![oAccessoryView isHidden] )
	{
		_accessoryHeight = [oAccessoryView bounds].size.height;
	}
}

- (void)showAccessoryView:(BOOL)showFlag animate:(BOOL)animateFlag
{
	NSRect windowFrame = [[self window] frame];
	
	if ( showFlag && [oAccessoryView isHidden] )
	{
		// expand
		if ( animateFlag )
		{
			[self performSelector:@selector(showAccessoryView) withObject:nil afterDelay:0.0];
		}
		else
		{
			[oAccessoryView setHidden:NO];
		}
		NSRect newFrame = NSMakeRect(windowFrame.origin.x,
									 windowFrame.origin.y - _accessoryHeight - kWindowResizeOffset,
									 windowFrame.size.width,
									 windowFrame.size.height + _accessoryHeight + kWindowResizeOffset);
		[[self window] setFrame:newFrame display:YES animate:animateFlag];
	}
	else if ( !showFlag && ![oAccessoryView isHidden] )
	{
		// collapse
		[oAccessoryView setHidden:YES];
		NSRect newFrame = NSMakeRect(windowFrame.origin.x,
									 windowFrame.origin.y + _accessoryHeight + kWindowResizeOffset,
									 windowFrame.size.width,
									 windowFrame.size.height - _accessoryHeight - kWindowResizeOffset);
		[[self window] setFrame:newFrame display:YES animate:animateFlag];
	}
}

- (void)showAccessoryView
{
	// once the window resizes, we unhide the accessory view and adjust its size
	
	[oAccessoryView setHidden:NO];

	NSRect accessoryFrame = [oAccessoryView frame];
	NSRect newFrame = NSMakeRect(accessoryFrame.origin.x, 
								 accessoryFrame.origin.y, 
								 accessoryFrame.size.width, 
								 accessoryFrame.size.height - kWindowResizeOffset);
	[oAccessoryView setFrame:newFrame];
}

#pragma mark -
#pragma mark Presentation

- (void)beginSheetModalForWindow:(NSWindow *)window
{
    OBASSERT(!_modalWindow);    // You shouldn't be able to make the window modal twice
    
    [self retain];  // Ensures we're not accidentally deallocated during presentation. Will release later
    _modalWindow = window;  // Weak ref
    
    [NSApp beginSheet:[self window]
       modalForWindow:window
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:NULL];
    
    // Ready to start
    [[self publishingEngine] start];
}

/*  Outside code shouldn't need to call this, we should handle it ourselves from clicking
 *  the Close or Stop button.
 */
- (void)endSheet;
{
    if (![[self publishingEngine] hasFinished])
    {
        [[self publishingEngine] cancel];
    }
    
    OBASSERT(_modalWindow);
    _modalWindow = nil;
    
    [NSApp endSheet:[self window]];
    [[self window] orderOut:self];
    
    [self release]; // To balance the -retain when beginning the sheet.
}

@end
