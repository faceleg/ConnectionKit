//
//  KTPublishingWindowController.m
//  Marvel
//
//  Created by Mike on 08/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTPublishingWindowController.h"

#import "KTDocumentInfo.h"
#import "KTDocWindowController.h"
#import "KTHostProperties.h"
#import "KTExportEngine.h"

#import "NSApplication+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import <Connection/Connection.h>
#import <Growl/Growl.h>
#import "UKDockProgressIndicator.h"


const float kWindowResizeOffset = 59.0; // "gap" between progress bar and bottom of window when collapsed


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
		
		
		// There's a minimum of localized text in this nib, so we're handling it in entirely in code
		if ([self isExporting])
		{
			[self setMessageText:NSLocalizedString(@"Exporting…", @"Publishing sheet title")];
			[self setInformativeText:NSLocalizedString(@"Preparing to export…", @"Uploading progress info")];
		}
		else
		{
			[self setMessageText:NSLocalizedString(@"Publishing…", @"Publishing sheet title")];
			[self setInformativeText:NSLocalizedString(@"Preparing to upload…", @"Uploading progress info")];
		}
		
		_dockProgress = [[UKDockProgressIndicator alloc] init];
		[_dockProgress setHidden:YES];		// keep hidden for now
		[_dockProgress setMinValue:0.0];
		[_dockProgress setMaxValue:100.0];
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_publishingEngine setDelegate:nil];
    [_publishingEngine release];
	[_dockProgress release];
	
	[_messageText release];
	[_informativeText release];
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	
	// Load text into the message and info text labels
	[oMessageLabel setStringValue:[self messageText]];
	[oInformativeTextLabel setStringValue:[self informativeText]];
	
    
    // TODO: Ensure the button is wide enough for e.g. German
    [oFirstButton setTitle:NSLocalizedString(@"Stop", @"Stop publishing button title")];
    
	
    // Outline view uses special cell class
    NSCell *cell = [[CKTransferProgressCell alloc] initTextCell:@""];
    [oTransferDetailsTableColumn setDataCell:cell];
    [cell release];
    
	
    // Start progress indicator
	[oProgressIndicator setUsesThreadedAnimation:YES];
    [oProgressIndicator startAnimation:self];
	
	
	// Restore window size
	float storedWidth = [[NSUserDefaults standardUserDefaults] floatForKey:@"PublishingWindowWidth"];
    float storedHeight = [[NSUserDefaults standardUserDefaults] floatForKey:@"PublishingWindowExpandedHeight"];
	
	NSRect contentRect = [[self window] contentRectForFrameRect:[[self window] frame]];
	NSSize minSize = [[self window] minSize];
	NSSize maxSize = [[self window] maxSize];
	
	if (storedWidth >= minSize.width && storedWidth <= maxSize.width)
	{
		contentRect.size.width = storedWidth;
	}
	if (storedHeight >= minSize.height && storedHeight <= maxSize.height)
	{
		contentRect.size.height = storedHeight;
	}
	
	[[self window] setFrame:[[self window] frameRectForContentRect:contentRect] display:YES];
	
	
	// show expanded view?
	BOOL shouldExpand = [[NSUserDefaults standardUserDefaults] boolForKey:@"PublishingWindowShowsAccessory"];
	[oExpandButton setState:shouldExpand];
	[self showAccessoryView:shouldExpand animate:NO];
}

#pragma mark -
#pragma mark Actions

- (IBAction)firstButtonAction:(NSButton *)sender
{
    [self endSheet];
}

// we need to implement these pass-through actions here for proper menu validation
- (IBAction)visitPublishedSite:(id)sender
{
	KTDocWindowController *windowController = [_modalWindow windowController];
	OBASSERT(windowController); // This is a slightly hacky way to get to the controller, but it works

	[windowController visitPublishedSite:sender];
}

- (IBAction)visitPublishedPage:(id)sender
{
	KTDocWindowController *windowController = [_modalWindow windowController];
	OBASSERT(windowController); // This is a slightly hacky way to get to the controller, but it works

	[windowController visitPublishedPage:sender];
}

- (IBAction)submitSiteToDirectory:(id)sender;
{
	KTDocWindowController *windowController = [_modalWindow windowController];
	OBASSERT(windowController); // This is a slightly hacky way to get to the controller, but it works
	
	[windowController submitSiteToDirectory:sender];
}

#pragma mark -
#pragma mark Publishing Engine

- (KTPublishingEngine *)publishingEngine;
{
    return _publishingEngine;
}

- (BOOL)isExporting
{
    BOOL result = [[self publishingEngine] isKindOfClass:[KTExportEngine class]];
    return result;
}

- (void)publishingEngine:(KTPublishingEngine *)engine didBeginUploadToPath:(NSString *)remotePath;
{
    NSString *format = ([self isExporting]) ?
						NSLocalizedString(@"Exporting “%@”", @"Upload information") :
						NSLocalizedString(@"Uploading “%@”", @"Upload information");
	
	NSString *text = [[NSString alloc] initWithFormat:format, [remotePath lastPathComponent]];
	[self setInformativeText:text];
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
	double progress = [[engine rootTransferRecord] progress];
	if (![oProgressIndicator isIndeterminate])
	{
		[oProgressIndicator setDoubleValue:progress];
		[_dockProgress setDoubleValue:progress];
	}
}

/*  We're done publishing, close the window.
 */
- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine
{
    // Setup Growl
    [GrowlApplicationBridge setGrowlDelegate:(id)[KTPublishingWindowController class]];
	[_dockProgress setHidden:YES];
   
    
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
        if ([[[[engine connection] request] URL] isFileURL])
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
    
    
    // Keep the sheet open if command-option is held down as a debugging aid. BUGSID:38342
    unsigned eventModifierFlags = [[NSApp currentEvent] modifierFlags];
    if ((eventModifierFlags & NSCommandKeyMask) && (eventModifierFlags & NSAlternateKeyMask))
    {
        [self setMessageText:NSLocalizedString(@"Publishing finished.", @"Upload message text")];
        [self setInformativeText:nil];
        [oFirstButton setTitle:NSLocalizedString(@"Close", @"Button title")];
    }
    else
    {
        [self endSheet];
    }
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
        [self setMessageText:NSLocalizedString(@"Publishing failed.", @"Upload message text")];
        
        [oInformativeTextLabel setTextColor:[NSColor redColor]];
        NSString *errorDescription = [error localizedDescription];
        [self setInformativeText:errorDescription];
        
        [oProgressIndicator stopAnimation:self];
		[_dockProgress setHidden:YES];

        
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
#pragma mark Disclosure Button

- (IBAction)toggleExpanded:(id)sender
{
	BOOL shouldExpand = [sender state];
	
	[[NSUserDefaults standardUserDefaults] setBool:shouldExpand forKey:@"ExpandPublishingWindow"];
	[self showAccessoryView:shouldExpand animate:YES];
}

- (NSView *)accessoryView { return oAccessoryView; }

- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)proposedFrameSize
{
	// if the accessory view is hidden, don't resize vertically
	NSSize result = proposedFrameSize;
	
	if ([[self accessoryView] isHidden])
	{
		NSSize currentFrameSize = [window frame].size;
		result = NSMakeSize(proposedFrameSize.width, currentFrameSize.height);
	}
	
	return result;
}

- (void)windowDidResize:(NSNotification *)notification
{
	// Store in the defaults
	NSSize windowSize = [[self window] contentRectForFrameRect:[[self window] frame]].size;
    
	[[NSUserDefaults standardUserDefaults] setFloat:windowSize.width forKey:@"PublishingWindowWidth"];
	if (![[self accessoryView] isHidden])
	{
		[[NSUserDefaults standardUserDefaults] setFloat:windowSize.height forKey:@"PublishingWindowExpandedHeight"];
	}
}

- (void)showAccessoryView:(BOOL)showFlag animate:(BOOL)animateFlag
{
	NSWindow *window = [self window];
	NSRect windowFrame = [window contentRectForFrameRect:[window frame]];
	
	if (showFlag)
	{
		// expand
		float height = [[NSUserDefaults standardUserDefaults] floatForKey:@"PublishingWindowExpandedHeight"];
		if (height < [window minSize].height) height = 417.0;
		
		NSRect newContentFrame = NSMakeRect(windowFrame.origin.x,
											windowFrame.origin.y + (windowFrame.size.height - height),
											windowFrame.size.width,
											height);
		[window setFrame:[window frameRectForContentRect:newContentFrame] display:YES animate:animateFlag];
		
		[[self accessoryView] setHidden:NO];
		[[self accessoryView] setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	}
	else
	{
		// collapse
		[[self accessoryView] setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];	// Keep it fixed in place
		[[self accessoryView] setHidden:YES];
		
		NSRect newContentFrame = NSMakeRect(windowFrame.origin.x,
											windowFrame.origin.y + (windowFrame.size.height - 139.0),
											windowFrame.size.width,
											139.0);	// Cheating and hardcoding for now
		[window setFrame:[window frameRectForContentRect:newContentFrame] display:YES animate:animateFlag];
	}
	
	
	[[NSUserDefaults standardUserDefaults] setBool:showFlag forKey:@"PublishingWindowShowsAccessory"];
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
    [[self publishingEngine] cancel];
    
    OBASSERT(_modalWindow);
    _modalWindow = nil;
    
    [NSApp endSheet:[self window]];
    [[self window] orderOut:self];
    
    [self release]; // To balance the -retain when beginning the sheet.
}

#pragma mark -
#pragma mark Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	KTDocWindowController *windowController = [_modalWindow windowController];
	OBASSERT(windowController); // This is a slightly hacky way to get to the controller, but it works
	
	return [windowController validateMenuItem:menuItem];
}	

@end


#pragma mark -


@implementation KTPublishingWindowController (KSAlert)

/*	Eventually these methods ought to be split out into a decent KSAlert class.
 */

- (NSString *)messageText { return _messageText; }

- (void)setMessageText:(NSString *)text
{
	text = [text copy];
	[_messageText release];
	_messageText = text;
	
	[oMessageLabel setStringValue:(text ? text : @"")];
}

- (NSString *)informativeText { return _informativeText; }

- (void)setInformativeText:(NSString *)text
{
	text = [text copy];
	[_informativeText release];
	_informativeText = text;
	
	[oInformativeTextLabel setStringValue:(text ? text : @"")];
}

@end

