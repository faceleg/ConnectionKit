//
//  KTCodeInjectionController.m
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTCodeInjectionController.h"

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
	[oPreludeTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[oEarlyHeadTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[oHeadTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[oBodyStartTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[oBodyEndTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[oBodyTagTextField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	
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
	NSString *pageName = @"Code_Injection";
	
	NSTabViewItem *selectedTabViewItem = [oTabView selectedTabViewItem];
	NSString *identifier = [selectedTabViewItem identifier];
	
	// Go to the sub-section of this page....
	
	if ( [identifier isEqualToString:@"<html>"] )
	{
		pageName = [NSString stringWithFormat:@"%@#%@", pageName, @"Before_.3Chtml.3E"];
	}
	else if ( [identifier isEqualToString:@"<head>"] )
	{
		pageName = [NSString stringWithFormat:@"%@#%@", pageName, @".3Chead.3E_area"];
	}
	else if ( [identifier isEqualToString:@"<body>"] )
	{
		pageName = [NSString stringWithFormat:@"%@#%@", pageName, @"Within_.3Cbody.3E_tag"];
	}
	else if ( [identifier isEqualToString:@"</body>"] )
	{
		pageName = [NSString stringWithFormat:@"%@#%@", pageName, @"Before_.3C.2Fbody.3E"];
	}
	
	[(KTApplication *)NSApp showHelpPage:pageName];
}

@end
