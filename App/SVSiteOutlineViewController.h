//
//  KTSiteOutlineDataSource.h
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *KTDisableCustomSiteOutlineIcons;



@class KTDocSiteOutlineController, KTDocWindowController;
@class KTPage;


@interface SVSiteOutlineViewController : NSViewController
{
  @private
    NSOutlineView               *_outlineView;
    KTDocSiteOutlineController	*_pagesController;
	    
    // Content
	NSMutableSet    *_pages;
    KTPage          *_rootPage;
    
    // Options
    BOOL    _useSmallIconSize;
	
    // Cache
	NSImage				*myCachedFavicon;
	NSMutableDictionary	*myCachedPluginIcons;
	NSMutableDictionary	*myCachedCustomPageIcons;
	
	NSMutableArray		*myCustomIconGenerationQueue;
	KTPage				*myGeneratingCustomIcon;			// Used in KTSiteOutlineDataSource+Icons.m
}

@property(nonatomic, retain) IBOutlet NSOutlineView *outlineView;

@property(nonatomic, retain) IBOutlet KTDocSiteOutlineController *pagesController;


@property(nonatomic, retain) KTPage *rootPage;

- (void)resetPageObservation;

- (void)reloadSiteOutline;
- (void)reloadPage:(KTPage *)anItem reloadChildren:(BOOL)aFlag;


#pragma mark Options
@property(nonatomic) BOOL displaySmallPageIcons;

@end


@interface SVSiteOutlineViewController (Icons)
- (NSImage *)iconForPage:(KTPage *)page;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


