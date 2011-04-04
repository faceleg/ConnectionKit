//
//  KTCodeInjectionController.m
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "KTCodeInjectionController.h"
#import "KTDocWindowController.h"
#import "SVPagesController.h"

#import "KTApplication.h"
#import "KTPage.h"

#import "KSAppDelegate.h"

#import "Registration.h"
#import "NSTextView+KTExtensions.h"

@interface KTCodeInjectionController ()
@end


@implementation KTCodeInjectionController

- (id)initWithPagesController:(id <KSCollectionController>)controller
                       master:(BOOL)isMaster;
{	
	_pagesController = controller;
	_isMaster = isMaster;
	
	[super initWithWindowNibName:@"CodeInjection"];
	
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Make sure the timer's shut down properly
	[myTextEditingTimer invalidate];
	[myTextEditingTimer release];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	NSDictionary *attr = [oPreludeTextView defaultTextAttributes];
	NSFont *font = [attr objectForKey:NSFontAttributeName];
	NSSize inset = NSMakeSize(0.0, 4.0);
	
	[oPreludeTextView setFont:font];
	[oEarlyHeadTextView setFont:font];
	[oHeadTextView setFont:font];
	[oBodyStartTextView setFont:font];
	[oBodyEndTextView setFont:font];
	[oCSSTextView setFont:font];
	
	[oPreludeTextView setUsesFontPanel:NO];
	[oEarlyHeadTextView setUsesFontPanel:NO];
	[oHeadTextView setUsesFontPanel:NO];
	[oBodyStartTextView setUsesFontPanel:NO];
	[oBodyEndTextView setUsesFontPanel:NO];
	[oCSSTextView setUsesFontPanel:NO];

	[oPreludeTextView setTextContainerInset:inset];
	[oEarlyHeadTextView setTextContainerInset:inset];
	[oHeadTextView setTextContainerInset:inset];
	[oBodyStartTextView setTextContainerInset:inset];
	[oBodyEndTextView setTextContainerInset:inset];
	[oCSSTextView setTextContainerInset:inset];

	
	// Bind our text fields to the right controller.	
	NSString *baseKeyPath = @"selection";
	if ([self isMaster])
	{
		baseKeyPath = [baseKeyPath stringByAppendingString:@".master"];

		// Only CSS for master (whole site)
		[oCSSTextView bind:NSValueBinding
				  toObject:_pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.additionalCSS"]
				   options:nil];
	}
	else
	{
		// Not the master (the document) so take out this tab
		NSInteger cssIndex = [oTabView indexOfTabViewItemWithIdentifier:@"css"];
		if (NSNotFound != cssIndex)
		{
			NSTabViewItem *item = [oTabView tabViewItemAtIndex:cssIndex];
			[oTabView removeTabViewItem:item];
		}
	}
	
	[oPreludeTextView bind:NSValueBinding
				  toObject:_pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.beforeHTML"]
				   options:nil];
	
	[oEarlyHeadTextView bind:NSValueBinding
					toObject:_pagesController
				 withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.earlyHead"]
				     options:nil];
	
	[oHeadTextView bind:NSValueBinding
				  toObject:_pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.headArea"]
				   options:nil];
	
	[oBodyStartTextView bind:NSValueBinding
				    toObject:_pagesController
			     withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.bodyTagStart"]
				     options:nil];
	
	[oBodyEndTextView bind:NSValueBinding
				  toObject:_pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.bodyTagEnd"]
				   options:nil];
	
	[oBodyTagTextField bind:NSValueBinding
				  toObject:_pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjection.bodyTag"]
				   options:nil];
	
	
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	
	// Editing notifications
	NSSet *textViews = [NSSet setWithObjects:oPreludeTextView, oHeadTextView, oEarlyHeadTextView, oBodyStartTextView, oBodyEndTextView, oCSSTextView, nil];
	NSTextView *aTextView;
	for (aTextView in textViews)
	{
		OBASSERT([aTextView isKindOfClass:[NSTextView class]]);
		NSTextStorage *textStorage = [aTextView textStorage];
		OBASSERT([textStorage isKindOfClass:[NSTextStorage class]]);
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(textViewDidProcessEditing:)
													 name:NSTextStorageDidProcessEditingNotification
												   object:textStorage];
	}
	
	
	// Frame autosaving
	[[self window] setFrameAutosaveName:@"CodeInjectionPanel"];
	[[self window] setFrameUsingName:@"CodeInjectionPanel"];
	
	[oHeadSplitView setDelegate:self];
	[oBodySplitView setDelegate:self];	
	
	// Localize the description field
	NSString *description;
	if ([self isMaster])
	{
		description = NSLocalizedString(
			@"Use Code Injection to insert custom code, such as <script> tags or additional HTML, into every page of the site.",
			"Code Injection information");
	}
	else
	{
		description = NSLocalizedString(
			@"Use Code Injection to insert custom code, such as <script> tags or additional HTML, into the selected page(s).",
			"Code Injection information");
	}
	[oCodeInjectionDescriptionLabel setStringValue:description];
	

	[oPreludeTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code at the very beginning of the document, before the opening <html> tag. This is never any HTML or Javascript code; it's only for server-side scripts (such as PHP code) to affect the headers, set cookies, etc.",
		"Code Injection placeholder text")];
	
	[oEarlyHeadTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code after the first <meta> tag. Useful for scripts that must be placed at this location. Otherwise, use the field below to insert code after the main tags.",
		"Code Injection placeholder text")];
	
	[oHeadTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code before the closing </head> tag. Useful for additional <meta> tags, JavaScript <script> tags, stylesheets, etc.",
		"Code Injection placeholder text")];
	
	[[oBodyTagTextField cell] setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code directly (e.g JavaScript 'onload') inside of the <body> tag itself.",
		"Code Injection placeholder text")];
	
	[oBodyStartTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code after the <body> tag. This is generally used by JavaScripts that prepare for the rest of the page contents.",
		"Code Injection placeholder text")];
	
	[oBodyEndTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert code at the end of the page, right before the </body> tag. This is generally used to include JavaScript that processes the preceding page contents.",
		"Code Injection placeholder text")];

	[oCSSTextView setPlaceholderString:NSLocalizedString(
		@"Use this field to insert CSS styles on every page, to override the styles provided by the current design.",
		"Code Injection placeholder text")];
	
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSString *label;
	if ([self isMaster])
	{
		label = NSLocalizedString(@"Site Code Injection", "Window title");
	}
	else
	{
		label = NSLocalizedString(@"Page Code Injection", "Window title");
	}
	
	NSString *result = [displayName stringByAppendingFormat:@" %C %@", 0x2014, label];

	return result;
}

/*	When making the window visible, select the first tab with some content in it.
 */
- (IBAction)showWindow:(id)sender
{
	if (![[self window] isVisible])
	{
		NSString *stringValue = [[oPreludeTextView textStorage] string];
		if (stringValue && ![stringValue isEqualToString:@""])
		{
			[oTabView selectTabViewItemWithIdentifier:@"html"];
		}
		else
		{
			stringValue = [[oEarlyHeadTextView textStorage] string];
			NSString *stringValue2 = [[oHeadTextView textStorage] string];
			
			if ((stringValue && ![stringValue isEqualToString:@""]) ||
				(stringValue2 && ![stringValue2 isEqualToString:@""]))
			{
				[oTabView selectTabViewItemWithIdentifier:@"head"];
			}
			else
			{
				stringValue = [oBodyTagTextField stringValue];
				stringValue2 = [[oBodyStartTextView textStorage] string];
				NSString *stringValue3 = [[oBodyEndTextView textStorage] string];
				
				if ((stringValue && ![stringValue isEqualToString:@""]) ||
					(stringValue2 && ![stringValue2 isEqualToString:@""]) ||
					(stringValue3 && ![stringValue3 isEqualToString:@""]))
				{
					[oTabView selectTabViewItemWithIdentifier:@"body"];
				}
				else
				{
					stringValue = [[oCSSTextView textStorage] string];
					if ([self isMaster] && stringValue && ![stringValue isEqualToString:@""])
					{					
						[oTabView selectTabViewItemWithIdentifier:@"css"];
					}
				}
			}
		}
	}
	
	[super showWindow:sender];
}

- (BOOL)isMaster { return _isMaster; }

- (IBAction)showHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Code_Injection"];		// HELPSTRING
}

#pragma mark -
#pragma mark Editing Timer

/*	The user has made an edit. Reset our internal time so that if this is the last edit they make, the
 *	webview will refresh shortly.
 */
- (void)textViewDidProcessEditing:(NSNotification *)notification
{
	NSDate *fireDate = [[NSDate date] addTimeInterval:0.8];
	
	if (myTextEditingTimer)		// We may have to create & schedule a new timer if none exists
	{
		[myTextEditingTimer setFireDate:fireDate];
	}
	else
	{
		myTextEditingTimer = [[NSTimer alloc] initWithFireDate:fireDate
													  interval:0.0
														target:self
													  selector:@selector(textEditingDidPause:)
													  userInfo:nil
													   repeats:NO];
	
		[[NSRunLoop currentRunLoop] addTimer:myTextEditingTimer forMode:NSDefaultRunLoopMode];
	}
}

/*	Called when there has been a pause in the user's editing. We thus need to commit changes to the model.
 */
- (void)textEditingDidPause:(NSTimer *)timer
{
	// Get rid of the old timer. Next time the user edits something, a fresh timer will be set up.
	[myTextEditingTimer invalidate];
	[myTextEditingTimer release];	myTextEditingTimer = nil;
	
	// Force editing to be committed by messing around with the first responder quickly
	NSResponder *firstResponder = [[self window] firstResponder];
	if (firstResponder && [firstResponder isKindOfClass:[NSTextView class]])
	{
		NSTextView *textView = (NSTextView *)firstResponder;
		//NSArray *selection = [textView selectedRanges];	// Seems restoring selection isn't actually needed
		[[self window] makeFirstResponder:nil];
		[[self window] makeFirstResponder:textView];
		//[textView setSelectedRanges:selection];
	}
}

@end
