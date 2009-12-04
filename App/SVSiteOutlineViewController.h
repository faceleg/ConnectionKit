//
//  KTSiteOutlineDataSource.h
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *KTDisableCustomSiteOutlineIcons;



@class SVPagesController, KTDocWindowController;
@class KTPage;


@interface SVSiteOutlineViewController : NSViewController <NSUserInterfaceValidations>
{
  @private
    NSOutlineView               *_outlineView;
    SVPagesController	*_pagesController;
	    
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

@property(nonatomic, retain) IBOutlet SVPagesController *pagesController;


@property(nonatomic, retain) KTPage *rootPage;

- (void)resetPageObservation;


#pragma mark Public Functions
- (void)reloadSiteOutline;
- (void)reloadPage:(KTPage *)anItem reloadChildren:(BOOL)aFlag;


#pragma mark Actions
// All act using the selected page(s) as context

- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)delete:(id)sender;

@property(nonatomic, readonly) BOOL canCopy;  // also used by -cut: as it's effectively doing a copy op
@property(nonatomic, readonly) BOOL canDelete;  // also used by -cut: as it's effectively doing a delete op


#pragma mark Options
@property(nonatomic) BOOL displaySmallPageIcons;

@end


@interface SVSiteOutlineViewController (Icons)
- (NSImage *)iconForPage:(KTPage *)page;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


