//
//  KTSiteOutlineDataSource.h
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTPage.h"


extern NSString *KTDisableCustomSiteOutlineIcons;



@class SVSiteItem;


@interface SVSiteOutlineViewController : NSViewController <NSUserInterfaceValidations>
{
  @private
    NSOutlineView       *_outlineView;
    NSArrayController	*_pagesController;
    BOOL                _isChangingSelection;
	    
    // Content
	NSMutableSet    *_pages;
    KTPage          *_rootPage;
    
    // Options
    BOOL    _useSmallIconSize;
	
    // Cache
	NSImage				*_cachedFavicon;
	NSMutableDictionary	*_cachedPluginIcons;
	NSMutableDictionary	*_cachedCustomPageIcons;
	
	NSMutableArray		*_customIconGenerationQueue;
	KTPage				*_generatingCustomIcon;			// Used in KTSiteOutlineDataSource+Icons.m
    
    // Drag & Drop
    NSArray *_draggedItems;
}

@property(nonatomic, retain) IBOutlet NSOutlineView *outlineView;

@property(nonatomic, retain) NSArrayController *content;


@property(nonatomic, retain) KTPage *rootPage;

- (void)resetPageObservation;


#pragma mark Public Functions
- (void)reloadSiteOutline;
- (void)reloadItem:(SVSiteItem *)anItem reloadChildren:(BOOL)aFlag;


#pragma mark Actions
// All act using the selected page(s) as context

- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)rename:(id)sender;  // edits the selected page's title
- (IBAction)duplicate:(id)sender;
- (IBAction)delete:(id)sender;

@property(nonatomic, readonly) BOOL canCopy;  // also used by -cut: as it's effectively doing a copy op
- (BOOL)canRename;
@property(nonatomic, readonly) BOOL canDelete;  // also used by -cut: as it's effectively doing a delete op


#pragma mark Options
@property(nonatomic) BOOL displaySmallPageIcons;


#pragma mark Persistence
- (NSArray *)persistentSelectedItems;
- (void)persistUIProperties;


@end


@interface SVSiteOutlineViewController (Icons)
- (NSImage *)iconForItem:(SVSiteItem *)page;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


@interface KTPage (SVSiteOutline)
@property(nonatomic, copy) NSNumber *isSelectedInSiteOutline;
@end