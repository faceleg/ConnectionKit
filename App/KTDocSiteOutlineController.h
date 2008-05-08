//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage, KTDocument, KTDocWindowController, KTSiteOutlineDataSource;


@interface KTDocSiteOutlineController : NSArrayController
{
	IBOutlet NSOutlineView			*siteOutline;
	
@private
	
	KTDocWindowController	*myWindowController;
	KTSiteOutlineDataSource	*mySiteOutlineDataSource;
}

- (NSOutlineView *)siteOutline;

- (KTDocWindowController *)windowController;
- (void)setWindowController:(KTDocWindowController *)controller;

- (NSString *)childrenKeyPath;	// A hangover from NSTreeController

@end


@interface KTDocSiteOutlineController (Selection)

- (KTPage *)selectedPage;

@end