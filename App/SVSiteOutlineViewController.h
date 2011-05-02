//
//  KTSiteOutlineDataSource.h
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTPage+Paths.h"
#import "SVPagesTreeController.h"
#import "KSViewController.h"

#import <BWToolkitFramework/BWHyperlinkButton.h>

extern NSString *KTDisableCustomSiteOutlineIcons;



@class SVPagesController, SVSiteItem, BWSplitView;


@interface SVSiteOutlineViewController : NSViewController <NSUserInterfaceValidations, SVPageSerializationDelegate>
{
	IBOutlet BWSplitView *oSplitView;
    
    IBOutlet NSView             *oToggleIsCollectionAlertAccessoryView;
    IBOutlet BWHyperlinkButton  *oCurrentPageURLLink;
    IBOutlet NSTextField        *oNewPageURLLabel;
    
    IBOutlet NSView             *oDeletePublishedPageAlertAccessoryView;
    IBOutlet BWHyperlinkButton  *oDeletePublishedPageURLLink;
	
  @private
    NSOutlineView           *_outlineView;
    SVPagesTreeController	*_pagesController;
	    
    // Content
	NSMutableSet    *_pages;
    KTPage          *_rootPage;
    
    // Options
    BOOL    _useSmallIconSize;
	
    // Cache
	NSImage				*_cachedFavicon;
	NSMutableDictionary	*_cachedPluginIcons;
	NSMutableDictionary	*_cachedImagesByRepresentation;
    NSOperationQueue    *_queue;
	    
    // Serialization, Drag & Drop
    NSArray     *_nodesToWriteToPasteboard;
    NSUInteger  _indexOfNextNodeToWriteToPasteboard;
}

@property(nonatomic, retain) IBOutlet NSOutlineView *outlineView;
- (BOOL)isOutlineViewLoaded;

@property(nonatomic, retain) SVPagesTreeController *content;

- (void)resetPageObservation;


#pragma mark Public Functions
- (void)loadPersistentProperties;


#pragma mark Adding a Page
- (IBAction)addPage:(id)sender;             // your basic page
- (IBAction)addCollection:(id)sender;       // a collection. Uses [sender representedObject] for preset info
- (IBAction)addExternalLinkPage:(id)sender; // external link
- (IBAction)addRawTextPage:(id)sender;      // Raw HTML page
- (IBAction)addFilePage:(id)sender;         // uses open panel to select a file, then inserts


#pragma mark Pasteboard Actions
// All act using the selected page(s) as context

- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)rename:(id)sender;  // edits the selected page's title
- (IBAction)duplicate:(id)sender;
- (IBAction)delete:(id)sender;

@property(nonatomic, readonly) BOOL canCopy;  // also used by -cut: as it's effectively doing a copy op
- (BOOL)canRename;
@property(nonatomic, readonly) BOOL canDelete;  // also used by -cut: as it's effectively doing a delete op


#pragma mark Publish as Collection
- (IBAction)toggleIsCollection:(id)sender;
// Follow -siteOutlineController:didToggleIsCollection: signature
- (void)setToCollection:(BOOL)makeCollection withDelegate:(id)delegate didToggleSelector:(SEL)selector;
- (void)toggleIsCollectionWithDelegate:(id)delegate didToggleSelector:(SEL)selector;
- (BOOL)canToggleIsCollection;


#pragma mark Options
@property(nonatomic) BOOL displaySmallPageIcons;


#pragma mark Persistence
- (NSArray *)persistentSelectedObjects;
- (void)persistUIProperties;


@end


@interface SVSiteOutlineViewController (Icons)
- (NSImage *)iconForItem:(SVSiteItem *)item isThumbnail:(BOOL *)isThumbnail;

- (void)invalidateIconCaches;
- (void)setCachedFavicon:(NSImage *)icon;

@end


@interface SVSiteItem (SVSiteOutline)
@property(nonatomic, copy) NSNumber *isSelectedInSiteOutline;
@property(nonatomic, copy) NSNumber *collectionIsExpandedInSiteOutline;
@end