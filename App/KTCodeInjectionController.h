//
//  KTCodeInjectionController.h
//  Marvel
//
//  Created by Terrence Talbot on 4/5/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage, KTDocSiteOutlineController;


@interface KTCodeInjectionController : NSWindowController 
{
	IBOutlet NSTabView			*oTabView;
	IBOutlet NSTextView			*oPreludeTextView;
	IBOutlet NSTextView			*oHeadTextView;
	IBOutlet NSTextView			*oBodyEndTextView;
	IBOutlet NSTextField		*oBodyTagTextField;
	
	KTDocSiteOutlineController	*mySiteOutlineController;	// Weak ref
	BOOL	myIsMaster;
}

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)siteOutline
							 master:(BOOL)isMaster;

- (IBAction)showHelp:(id)sender;

@end
