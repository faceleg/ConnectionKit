//
//  KTSiteOutlineDataSource.h
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocSiteOutlineController, KTDocument;
@class KTPage;


@interface KTSiteOutlineDataSource : NSObject
{
	@private
    KTDocSiteOutlineController	*mySiteOutlineController;	// Weak ref
	
	NSMutableSet    *myPages;
    KTPage          *myHomePage;
	
	NSImage				*myCachedFavicon;
	NSMutableDictionary	*myCachedPluginIcons;
	NSMutableDictionary	*myCachedCustomPageIcons;
	
	NSMutableArray		*myCustomIconGenerationQueue;
	KTPage				*myGeneratingCustomIcon;
}

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)controller;

- (KTDocSiteOutlineController *)siteOutlineController;
- (void)setSiteOutlineController:(KTDocSiteOutlineController *)controller;

- (NSOutlineView *)siteOutline;
- (KTDocument *)document;

- (void)resetPageObservation;

- (void)reloadSiteOutline;
- (void)reloadPage:(KTPage *)anItem reloadChildren:(BOOL)aFlag;

@end


@interface KTSiteOutlineDataSource (Icons)
- (NSImage *)iconForPage:(KTPage *)page;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


