//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage, KTDocument, KTDocWindowController, KTSiteOutlineDataSource;


@interface KTDocSiteOutlineController : NSTreeController
{
	IBOutlet NSOutlineView			*siteOutline;
	
@private
	
	KTDocWindowController	*myWindowController;
	KTSiteOutlineDataSource	*mySiteOutlineDataSource;
	
	NSArray		*mySelectedPages;
}

- (NSOutlineView *)siteOutline;

- (KTDocWindowController *)windowController;
- (void)setWindowController:(KTDocWindowController *)controller;

@end


@interface KTDocSiteOutlineController (Selection)

- (NSArray *)selectedPages;
- (void)setSelectedPages:(NSSet *)selectedPages;
- (KTPage *)selectedPage;	// Always fast!

@end