//
//  KTDocWindowController+Publishing.m
//  Marvel
//
//  Created by Mike on 23/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "KTDocWindowController.h"

#import "KTAbstractPage+Internal.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTExportEngine.h"
#import "KTExportSavePanelController.h"
#import "KTHostProperties.h"
#import "KTMobileMePublishingEngine.h"
#import "KTPublishingWindowController.h"
#import "KTRemotePublishingEngine.h"
#import "SVSiteOutlineViewController.h"
#import "KTDocSiteOutlineController.h"
#import "KTToolbars.h"

#import "KSSilencingConfirmSheet.h"

#import "NSObject+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "Registration.h"


@interface KTDocWindowController (PublishingPrivate)
- (BOOL)shouldPublish;
- (Class)publishingEngineClass;
@end


#pragma mark -


@implementation KTDocWindowController (Publishing)

#pragma mark Publishing

- (IBAction)publishSiteChanges:(id)sender
{
    if (![self shouldPublish]) return;
    
    
    // Start publishing
	Class publishingEngineClass = [self publishingEngineClass];
    KTPublishingEngine *publishingEngine = [[publishingEngineClass alloc] initWithSite:[[self document] site]
																	onlyPublishChanges:YES];
    
    // Bring up UI
    KTPublishingWindowController *windowController = [[KTPublishingWindowController alloc] initWithPublishingEngine:publishingEngine];
    [publishingEngine release];
    
    [windowController beginSheetModalForWindow:[self window]];
    [windowController release];
}

- (IBAction)publishSiteAll:(id)sender
{
    if (![self shouldPublish]) return;
    
    
    // Start publishing
    Class publishingEngineClass = [self publishingEngineClass];
    KTPublishingEngine *publishingEngine = [[publishingEngineClass alloc] initWithSite:[[self document] site]
																	onlyPublishChanges:NO];
    
    // Bring up UI
    KTPublishingWindowController *windowController = [[KTPublishingWindowController alloc] initWithPublishingEngine:publishingEngine];
    [publishingEngine release];
    
    [windowController beginSheetModalForWindow:[self window]];
    [windowController release];
}

/*  Usually acts just like -publishSiteChanges: but calls -publishEntireSite: if the Option key is pressed
 */
- (IBAction)publishSiteFromToolbar:(NSToolbarItem *)sender;
{
    if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
    {
        [self publishSiteAll:sender];
    }
    else
    {
        [self publishSiteChanges:sender];
    }
}

/*  Disallow publishing if the user hasn't been through host setup yet
 */
- (BOOL)shouldPublish
{
    // Check registration
    if (nil == gRegistrationString)
	{
		[KSSilencingConfirmSheet alertWithWindow:[self window]
                                    silencingKey:@"shutUpDemoUploadWarning"
                                           title:NSLocalizedString(@"Sandvox Demo: Restricted Publishing", @"title of alert")
                                          format:NSLocalizedString(@"You are running a demo version of Sandvox. Only the home page (watermarked) will be exported or uploaded. To publish additional pages, you will need to purchase a license.",@"")];
	}
	
    
	// TODO: Commit any pending edits
    BOOL result = [[[self siteOutlineViewController] pagesController] commitEditing];

    
    
    // Check host setup
    result = ([[[[self document] site] hostProperties] siteURL] != nil);
    
    if (result)
    {
        KTHostProperties *hostProperties = [[[self document] site] hostProperties];
        BOOL localHosting = [[hostProperties valueForKey:@"localHosting"] intValue];    // Taken from
        BOOL remoteHosting = [[hostProperties valueForKey:@"remoteHosting"] intValue];  // KTHostSetupController.m
        
        result = ((localHosting || remoteHosting) && [hostProperties siteURL] != nil);
        
        if (!result)
        {
            // Tell the user why
            NSAlert *alert = [[NSAlert alloc] init];    // Will be released when it ends
            [alert setMessageText:NSLocalizedString(@"This website is not set up to be published on this computer or on another host.", @"Hosting not setup")];
            [alert setInformativeText:NSLocalizedString(@"Please set up the site for publishing, or export it to a folder instead.", @"Hosting not setup")];
            [alert addButtonWithTitle:TOOLBAR_SETUP_HOST];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "Cancel Button")];
            [alert addButtonWithTitle:NSLocalizedString(@"Export…", @"button title")];
            
            [alert beginSheetModalForWindow:[self window]
                              modalDelegate:self
                             didEndSelector:@selector(setupHostBeforePublishingAlertDidEnd:returnCode:contextInfo:)
                                contextInfo:NULL];
        }
    }
    
    return result;
}

/*	MobileMe and Local publishing use special subclasses
 */
- (Class)publishingEngineClass
{
	Class result = [KTRemotePublishingEngine class];
	
	if ([[[[self document] site] hostProperties] integerForKey:@"localHosting"])
	{
		result = [KTLocalPublishingEngine class];
	}
	else if ([[[[[self document] site] hostProperties] valueForKey:@"protocol"] isEqualToString:@".Mac"])
	{
		result = [KTMobileMePublishingEngine class];
	}
	
	return result;
}

- (void)setupHostBeforePublishingAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    // Another sheet is probably about to appear, so order out the alert early
    [[alert window] orderOut:self];
    
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [[self document] setupHost:self];
    }
    else if (returnCode == NSAlertThirdButtonReturn)
    {
        [self exportSite:self];
    }
    
    [alert release];
}

- (void)noChangesToPublishAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [alert release];    // It was retained by the publishing window controller
    
    if (returnCode == NSAlertSecondButtonReturn)
    {
        [[alert window] orderOut:self]; // Another sheet's about to appear
        [self publishSiteAll:self];
    }
}

#pragma mark Site Export

/*  Puts up a sheet for the user to pick an export location, then starts up the publishing engine.
 */
- (IBAction)exportSite:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setCanCreateDirectories:YES];
    //[savePanel setMessage:NSLocalizedString(@"Please create a folder to contain your site.", @"prompt for exporting a website to a folder")];
    [savePanel setNameFieldLabel:NSLocalizedString(@"Export To:", @"save panel name field label. You must keep it short!")];
    [savePanel setPrompt:NSLocalizedString(@"Export", @"button title")];
    
    
    // Prompt the user for the site's URL if they haven't been through the HSA.
    KTHostProperties *hostProperties = [[[self document] site] hostProperties];
    //if (![hostProperties siteURL] ||
    //    (![hostProperties boolForKey:@"localHosting"] && ![hostProperties boolForKey:@"remoteHosting"]))
    {
        KTExportSavePanelController *controller = 
		[[KTExportSavePanelController alloc] initWithSiteURL:[hostProperties siteURL]
                                                 documentURL:[[self document] fileURL]];   // we'll release it when the panel closes
        
        [savePanel setDelegate:controller];
        [savePanel setAccessoryView:[controller view]];
    }
    
    
    NSString *exportDirectoryPath = [[[self document] site] lastExportDirectoryPath];
    
    [savePanel beginSheetForDirectory:[exportDirectoryPath stringByDeletingLastPathComponent]
                                 file:[exportDirectoryPath lastPathComponent]
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(exportSiteSavePanelDidEnd:returnCode:contextInfo:)
                          contextInfo:nil];
    
}

- (IBAction)exportSiteAgain:(id)sender
{
    NSString *exportDirectoryPath = [[[self document] site] lastExportDirectoryPath];
    if (exportDirectoryPath)
    {
        // Start publishing
        KTPublishingEngine *publishingEngine = [[KTExportEngine alloc] initWithSite:[[self document] site]
                                                                   documentRootPath:exportDirectoryPath
                                                                      subfolderPath:nil];
        
        // Bring up UI
        KTPublishingWindowController *windowController = [[KTPublishingWindowController alloc] initWithPublishingEngine:publishingEngine];
        [publishingEngine release];
        
        [windowController beginSheetModalForWindow:[self window]];
        [windowController release];
    }
    else
    {
        NSBeep();
    }
}

- (void)exportSiteSavePanelDidEnd:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    // If there was a controller created for the panel, get rid of it
    KTExportSavePanelController *controller = [savePanel delegate];
    if (controller)
    {
        OBASSERT([controller isKindOfClass:[KTExportSavePanelController class]]);
        
        // Store the new site URL
        if (returnCode == NSOKButton)
        {
            KTHostProperties *hostProperties = [[[self document] site] hostProperties];
            [hostProperties setValue:[[controller siteURL] absoluteString] forKey:@"stemURL"];
            
            // host properties has an insane design from the 1.0 days. May need to reset localHosting value for stemURL to take effect. #43405
            if (![hostProperties siteURL])
            {
                [hostProperties setValue:nil forKey:@"localHosting"];
            }
            
            [[[[self document] site] root] recursivelyInvalidateURL:YES];
        }
        
        [savePanel setDelegate:nil];
        [controller release];
    }
    
    if (returnCode != NSOKButton) return;
    
    
    
    // The old sheet must be ordered out before the new publishing one can appear
    [savePanel orderOut:self];
    
    // Store the path and kick off exporting
    [[[self document] site] setLastExportDirectoryPath:[savePanel filename]];
    [self exportSiteAgain:self];
}

#pragma mark Open in Web Browser

- (IBAction)visitPublishedSite:(id)sender
{
	NSURL *siteURL = [[[[self document] site] root] URL];
	if (siteURL)
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:siteURL];
	}
}

- (IBAction)visitPublishedPage:(id)sender
{
	NSURL *pageURL = [[[[self siteOutlineViewController] pagesController] selection] valueForKey:@"URL"];
	if (pageURL && !NSIsControllerMarker(pageURL))
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:pageURL];
	}
}

- (IBAction)submitSiteToDirectory:(id)sender;
{
	NSURL *siteURL = [[[[self document] site] root] URL];
	NSURL *submissionURL = [NSURL URLWithBaseURL:[NSURL URLWithString:@"http://www.sandvoxsites.com/submit_from_app.php"]
                                      parameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [siteURL absoluteString], @"url",
                                                  gRegistrationString, @"reg",
                                                  nil]];
	
	if (submissionURL)
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:submissionURL];
	}
}

@end
