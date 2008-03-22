//
//  KTCodeInjectionController.m
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTCodeInjectionController.h"

#import "KTCodeInjectionSplitView.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"

#import "KTApplication.h"
#import "KTPage.h"

#import "Registration.h"

@interface KTPage ( CodeInjectionBindings )
- (void)setInsertEndBody:(NSString *)aString;
@end


@interface KTCodeInjectionController ( Private )
@end


@implementation KTCodeInjectionController

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)siteOutline
							 master:(BOOL)isMaster;
{
	if ( !(gIsPro || (nil == gRegistrationString)) )	// don't allow this to be created if we're not pro
	{
		NSBeep();
		[self release];
		return nil;
	}
	
	mySiteOutlineController = siteOutline;
	myIsMaster = isMaster;
	
	[super initWithWindowNibName:@"CodeInjection"];
	
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)awakeFromNib
{
	NSFont *font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
	[oPreludeTextView setFont:font];
	[oEarlyHeadTextView setFont:font];
	[oHeadTextView setFont:font];
	[oBodyStartTextView setFont:font];
	[oBodyEndTextView setFont:font];
	[oBodyTagTextField setFont:font];
	
	
	// Bind our text fields to the right controller.
	KTDocSiteOutlineController *pagesController = [[mySiteOutlineController docWindowController] siteOutlineController];
	
	NSString *baseKeyPath = @"selection";
	if (myIsMaster)
	{
		baseKeyPath = [baseKeyPath stringByAppendingString:@".master"];
	}
	
	[oPreludeTextView bind:@"value"
				  toObject:pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionBeforeHTML"]
				   options:nil];
	
	[oEarlyHeadTextView bind:@"value"
					toObject:pagesController
				 withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionEarlyHead"]
				     options:nil];
	
	[oHeadTextView bind:@"value"
				  toObject:pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionHeadArea"]
				   options:nil];
	
	[oBodyStartTextView bind:@"value"
				    toObject:pagesController
			     withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionBodyTagStart"]
				     options:nil];
	
	[oBodyEndTextView bind:@"value"
				  toObject:pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionBodyTagEnd"]
				   options:nil];
	
	[oBodyTagTextField bind:@"value"
				  toObject:pagesController
			   withKeyPath:[baseKeyPath stringByAppendingString:@".codeInjectionBodyTag"]
				   options:nil];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	/*
	// insertPrelude
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(processPrelude:)
												 name:NSTextStorageDidProcessEditingNotification
											   object:[oPreludeTextView textStorage]];
	[oPreludeTextView setSelectedRange:NSMakeRange(0,0)];


	// insertHead
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(processHead:)
												 name:NSTextStorageDidProcessEditingNotification
											   object:[oHeadTextView textStorage]];
	[oHeadTextView setSelectedRange:NSMakeRange(0,0)];

	// insertEndBody
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(processEndBody:)
												 name:NSTextStorageDidProcessEditingNotification
											   object:[oBodyEndTextView textStorage]];
	[oBodyEndTextView setSelectedRange:NSMakeRange(0,0)];
	*/
	
	[[self window] setFrameAutosaveName:@"CodeInjectionPanel"];
	[[self window] setFrameUsingName:@"CodeInjectionPanel"];
	
	[oHeadSplitView setDividerDescription:
		NSLocalizedString(@"Sandvox will insert its content between these fields", "Code Injection information")];
	
	[oBodySplitView setDividerDescription:
		NSLocalizedString(@"Sandvox will insert its content between these fields", "Code Injection information")];
	
	[oPreludeTextView setPlaceholderString:NSLocalizedString(
		@"Code here is inserted at the very beginning of the document, before the opening <html> tag. This is never any HTML or Javascript code; it's only for server-side scripts (such as PHP code) to affect the headers, set cookies, etc.",
		"Code Injection placeholder text")];
	
	[oEarlyHeadTextView setPlaceholderString:NSLocalizedString(
		@"Code here is inserted shortly after the <head> tag. Useful for scripts that must be placed at this location. Otherwise, use the field below to insert code after the main tags.",
		"Code Injection placeholder text")];
	
	[oHeadTextView setPlaceholderString:NSLocalizedString(
		@"Code here is inserted right before the </head> tag. Useful for additional <meta> tags, JavaScript <script> tags, stylesheets, etc.",
		"Code Injection placeholder text")];
	
	[[oBodyTagTextField cell] setPlaceholderString:NSLocalizedString(
		@"Inserted directly inside of the <body> tag itself.",
		"Code Injection placeholder text")];
	
	[oBodyStartTextView setPlaceholderString:NSLocalizedString(
		@"Code here is inserted after the <body> tag. This is generally used by JavaScripts that prepare for the rest of the page contents.",
		"Code Injection placeholder text")];
	
	[oBodyEndTextView setPlaceholderString:NSLocalizedString(
		@"Code here is inserted at the end of the page, right before the </body> tag. This is generally used to include JavaScript that processes the preceding page contents.",
		"Code Injection placeholder text")];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	NSString *label;
	if (myIsMaster)
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
			}
		}
	}
	
	[super showWindow:sender];
}

- (IBAction)showHelp:(id)sender
{
	[(KTApplication *)NSApp showHelpPage:@"Code_Injection"];
}

@end
