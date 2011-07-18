//
//  KTDocWindowController+Publishing.m
//  Marvel
//
//  Created by Mike on 23/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//


#import "KTDocWindowController.h"

#import "KTDocument.h"
#import "KTSite.h"
#import "KTExportEngine.h"
#import "KTExportSavePanelController.h"
#import "KTHostProperties.h"
#import "KTMobileMePublishingEngine.h"
#import "KTPublishingWindowController.h"
#import "SVSFTPPublishingEngine.h"
#import "SVSiteOutlineViewController.h"
#import "SVPagesController.h"
#import "KTToolbars.h"
#import "KTPublishingEngine.h"

#import "KSSilencingConfirmSheet.h"

#import "NSObject+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSManagedObjectContext+Karelia.h"
#import "KSURLUtilities.h"
#import "NSWorkspace+Karelia.h"
#import "NSToolbar+Karelia.h"

#import "Registration.h"


@interface KTDocWindowController (PublishingPrivate)
- (BOOL)shouldPublishWithWarningIfNo;
- (Class)publishingEngineClass;
@end


#pragma mark -


@implementation KTDocWindowController (Publishing)

#pragma mark Publishing

- (void)prepareToPublishWithDelegateSelector:(SEL)selector
{
    BOOL result = [[self pagesController] commitEditing];
    if (result) result = [[[[self webContentAreaController] webEditorViewController] graphicsController] commitEditing];
    
	if (!result)
    {
        // Anything more to do?
        return;
    }
    
    if ([[self document] hasUnautosavedChanges])
    {
        [[self document] autosaveDocumentWithDelegate:self
                                  didAutosaveSelector:@selector(document:didAutosave:contextInfo:)
                                          contextInfo:selector];
    }
    else
    {
        [self performSelector:selector];
    }
}

- (void)maybeShowRestrictedPublishingAlertAndContinueWith:(SEL)aSelector;
{
	if (nil == gRegistrationString)	// check registration
	{
		// Further check... see if we have too many pages to publish
		NSArray *pages = [[[self document] managedObjectContext] fetchAllObjectsForEntityForName:@"Page" error:NULL];
		unsigned int pageCount = 0;
		if ( nil != pages )
		{
			pageCount = [pages count]; // according to mmalc, this is the only way to get this kind of count
		}
		
		if (pageCount > kMaxNumberOfFreePublishedPages)
		{
			KSSilencingConfirmSheet *sheet = [[[KSSilencingConfirmSheet alloc]
											   initWithWindow:[self window]
											   silencingKey:@"shutUpDemoUploadWarning"
											   canCancel:YES
											   OKButton:nil
											   silence:nil	// default button
											   title:NSLocalizedString(@"Restricted Publishing", @"title of alert")
											   message:
											   [NSString stringWithFormat:NSLocalizedString(@"You are running the free edition of Sandvox. Only the first %d pages will be exported or uploaded. To publish additional pages, you will need to purchase a license.",@""), kMaxNumberOfFreePublishedPages]
											   ] autorelease];
			
			sheet.invocation = [NSInvocation invocationWithSelector:aSelector target:self];
			sheet.target = self;

			[sheet doAlert];		// may or may not actually alert, but the invocation will happen
		}
		else
		{
			NSInvocation *nextStep = [NSInvocation invocationWithSelector:aSelector target:self];
			[nextStep invoke];
		}
	}
	else
	{
		NSInvocation *nextStep = [NSInvocation invocationWithSelector:aSelector target:self];
        
        [nextStep performSelector:@selector(invoke) withObject:nil afterDelay:0.0f];
	}
}

- (void)document:(NSDocument *)document didAutosave:(BOOL)didAutosave contextInfo:(void *)contextInfo
{
    if (!didAutosave) return;
    
    
    SEL selector = contextInfo;
    if (selector != @selector(_exportSiteAgain))
    {
        if (![self shouldPublishWithWarningIfNo]) return;
        [self maybeShowRestrictedPublishingAlertAndContinueWith:selector];
        return;
    }
    
    [self performSelector:selector];
}

- (IBAction)publishSiteChanges:(id)sender
{
    [self prepareToPublishWithDelegateSelector:@selector(_publishSiteChanges)];
}
- (void)_publishSiteChanges
{
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
	[self prepareToPublishWithDelegateSelector:@selector(_publishSiteAll)];
}
- (void)_publishSiteAll
{
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

/*  Usually acts just like -publishSiteChanges: but calls -publishEntireSite: if the Option key is pressed (when there is no PublishAll)
 */
- (IBAction)publishSiteFromToolbar:(NSToolbarItem *)sender;
{
	NSToolbarItem *publishAllToolbarItem = [[[self window] toolbar] itemWithIdentifier:@"publishAll"];

    if (!publishAllToolbarItem && ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) )
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
- (BOOL)shouldPublishWithWarningIfNo
{
    BOOL result = NO;
    
    // Check host setup
    KTHostProperties *hostProperties = [[[self document] site] hostProperties];
    BOOL localHosting = [[hostProperties valueForKey:@"localHosting"] intValue];    // Taken from
    BOOL remoteHosting = [[hostProperties valueForKey:@"remoteHosting"] intValue];  // KTHostSetupController.m
    
    result = ((localHosting || remoteHosting) && [hostProperties siteURL] != nil);
        
    if (!result)
    {
        // Tell the user why
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:NSLocalizedString(@"This website is not set up to be published on this computer or on another host.", @"Hosting not setup")];
        [alert setInformativeText:NSLocalizedString(@"Please set up the site for publishing, or export it to a folder instead.", @"Hosting not setup")];
        [alert addButtonWithTitle:[TOOLBAR_SETUP_HOST stringByAppendingString:NSLocalizedString(@"\\U2026", @"ellipses appended to command, meaning there will be confirmation alert.  Probably spaces before in French.")]];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "Cancel Button")];
        [alert addButtonWithTitle:NSLocalizedString(@"Export…", @"button title")];
        
        [alert beginSheetModalForWindow:[self window]
                          modalDelegate:self
                         didEndSelector:@selector(setupHostBeforePublishingAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:NULL];
        [alert release];	// will be dealloced when alert is dismissed
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
    else if ([[[[[self document] site] hostProperties] valueForKey:@"protocol"] isEqualToString:@"SFTP"])
    {
        result = [SVSFTPPublishingEngine class];
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
    
    
    NSString *exportDirectoryPath = [[[self document] lastExportDirectory] path];
    
    [savePanel beginSheetForDirectory:[exportDirectoryPath stringByDeletingLastPathComponent]
                                 file:[exportDirectoryPath lastPathComponent]
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(exportSiteSavePanelDidEnd:returnCode:contextInfo:)
                          contextInfo:nil];
    
}

- (IBAction)exportSiteAgain:(id)sender
{
    [self prepareToPublishWithDelegateSelector:@selector(_exportSiteAgain)];
}

- (void)_exportSiteAgain;
{
    NSString *exportDirectoryPath = [[[self document] lastExportDirectory] path];
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
    KTExportSavePanelController *controller = (KTExportSavePanelController *)[savePanel delegate];
    if (controller)
    {
        OBASSERT([controller isKindOfClass:[KTExportSavePanelController class]]);
        
        // Store the new site URL
        if (returnCode == NSOKButton)
        {
            KTHostProperties *hostProperties = [[[self document] site] hostProperties];
            NSString *siteURLString = [[controller siteURL] absoluteString];
            if (![siteURLString isEqualToString:[[hostProperties siteURL] absoluteString]])
            {
                [hostProperties setStemURL:siteURLString];
            
                // host properties has an insane design from the 1.0 days. May need to reset localHosting value for stemURL to take effect. #43405
                if (![hostProperties siteURL])
                {
                    [hostProperties setValue:nil forKey:@"localHosting"];
                }
                
                [[[[self document] site] rootPage] recursivelyInvalidateURL:YES];
            }
        }
        
        [savePanel setDelegate:nil];
        [controller release];
    }
    
    if (returnCode != NSOKButton) return;
    
    
    
    // The old sheet must be ordered out before the new publishing one can appear
    [savePanel orderOut:self];
    
    // Store the path and kick off exporting
    [[self document] setLastExportDirectory:[NSURL fileURLWithPath:[savePanel filename]]];
    [self exportSiteAgain:self];
}

#pragma mark Open in Web Browser

- (IBAction)visitPublishedSite:(id)sender
{
	NSURL *siteURL = [[[[self document] site] rootPage] URL];
	if (siteURL)
	{
		[KSWORKSPACE attemptToOpenWebURL:siteURL];
	}
}

- (IBAction)visitPublishedPage:(id)sender
{
	NSURL *pageURL = [[[[self siteOutlineViewController] content] selection] valueForKey:@"URL"];
	if (pageURL && !NSIsControllerMarker(pageURL))
	{
		[KSWORKSPACE attemptToOpenWebURL:pageURL];
	}
}

- (IBAction)submitSiteToDirectory:(id)sender;
{
	NSURL *siteURL = [[[[self document] site] rootPage] URL];
	NSURL *submissionURL = [[NSURL URLWithString:@"http://www.sandvoxsites.com/submit_from_app.php"]
                            ks_URLWithQueryParameters:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [siteURL absoluteString], @"url",
                                                       gRegistrationString, @"reg",
                                                       nil]];
	
	if (submissionURL)
	{
		[KSWORKSPACE attemptToOpenWebURL:submissionURL];
	}
}

@end
