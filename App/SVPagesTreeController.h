//
//  SVPagesTreeController.h
//  Sandvox
//
//  Created by Mike on 10/01/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KSTreeController.h"
#import "SVPagesController.h"


@interface SVPagesTreeController : KSTreeController
{
@private
    SVPageTemplate  *_template;
    NSURL           *_URL;
    
    NSArray         *_selectionToRestore;
    NSTimeInterval  _selectionRestorationTimestamp;
    NSIndexPath     *_fallbackSelection;
}


#pragma mark Inserting Objects
- (void)addChildObject:(id)object;      // NSTreeController doesn't provide this, so we do. Like -addObject:
- (void)addObjects:(NSArray *)objects;  // like NSArrayController
- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexPath:(NSIndexPath *)startingIndexPath;
- (NSIndexPath *)indexPathForAddingObjects;


#pragma mark Grouping
- (void)groupAsCollection:(id)sender;


#pragma mark Object Creation

// Sets the controller up to produce regular pages. Optional template specifies how to populate the new page
- (void)setEntityNameWithPageTemplate:(SVPageTemplate *)pageTemplate;
@property(nonatomic, retain, readonly) SVPageTemplate *pageTemplate;

// Sets the controller up to produce File Downloads or External Link pages. If URL is nil for an external link, controller will attempt to guess it at insert-time
- (void)setEntityTypeWithURL:(NSURL *)URL external:(BOOL)external;
@property(nonatomic, copy, readonly) NSURL *objectURL;

// Overriden to reset pageTemplate and objectURL
- (void)setEntityName:(NSString *)entityName;


#pragma mark Moving Objects
// If the last component of the index path is greater than the number of children, the controller handles it like a drop *on* the collection
- (void)moveNode:(NSTreeNode *)node toIndexPath:(NSIndexPath *)indexPath;


#pragma mark Selection
- (NSTreeNode *)selectedNode;   // small convenience
- (NSIndexPath *)lastSelectionIndexPath;
- (NSCellStateValue)selectedItemsAreCollections;
- (BOOL)selectedItemsHaveBeenPublished;


#pragma mark Queries
- (KTPage *)parentPageOfObjectAtIndexPath:(NSIndexPath *)indexPath;


#pragma mark Pasteboard Support
- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pasteboard;
- (BOOL)insertObjectsFromPasteboard:(NSPasteboard *)pboard atArrangedObjectIndexPath:(NSIndexPath *)startingIndexPath;


@end



