//
//  KTCodeInjectionController.h
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"


@class KTPage, KTDocSiteOutlineController, BWSplitView, KSPlaceholderTextView;


@interface KTCodeInjectionController : KSSingletonWindowController 
{
	IBOutlet NSTextField	*oCodeInjectionDescriptionLabel;
	IBOutlet NSTabView		*oTabView;
	
	IBOutlet KSPlaceholderTextView	*oPreludeTextView;
	
	IBOutlet BWSplitView				*oHeadSplitView;
	IBOutlet KSPlaceholderTextView		*oEarlyHeadTextView;
	IBOutlet KSPlaceholderTextView		*oHeadTextView;
	
	IBOutlet BWSplitView				*oBodySplitView;
	IBOutlet KSPlaceholderTextView		*oBodyStartTextView;
	IBOutlet KSPlaceholderTextView		*oBodyEndTextView;
	IBOutlet NSTextField				*oBodyTagTextField;
	
@private
	KTDocSiteOutlineController	*mySiteOutlineController;	// Weak ref
	BOOL	myIsMaster;
	
	NSTimer	*myTextEditingTimer;
}

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)siteOutline
							 master:(BOOL)isMaster;

- (BOOL)isMaster;

- (IBAction)showHelp:(id)sender;

@end
