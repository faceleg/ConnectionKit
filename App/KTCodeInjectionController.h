//
//  KTCodeInjectionController.h
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSSingletonWindowController.h"


@class KTPage, KTDocSiteOutlineController, KTCodeInjectionSplitView;


@interface KTCodeInjectionController : KSSingletonWindowController 
{
	IBOutlet NSTabView		*oTabView;
	
	IBOutlet NSTextView		*oPreludeTextView;
	
	IBOutlet KTCodeInjectionSplitView	*oHeadSplitView;
	IBOutlet NSTextView					*oEarlyHeadTextView;
	IBOutlet NSTextView					*oHeadTextView;
	
	IBOutlet KTCodeInjectionSplitView	*oBodySplitView;
	IBOutlet NSTextView					*oBodyStartTextView;
	IBOutlet NSTextView					*oBodyEndTextView;
	IBOutlet NSTextField				*oBodyTagTextField;
	
	KTDocSiteOutlineController	*mySiteOutlineController;	// Weak ref
	BOOL	myIsMaster;
}

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)siteOutline
							 master:(BOOL)isMaster;

- (IBAction)showHelp:(id)sender;

@end
