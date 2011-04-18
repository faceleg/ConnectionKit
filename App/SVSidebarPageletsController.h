//
//  SVSidebarPageletsController.h
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Correctly sorts the pagelets in a given sidebar. 
//  Removing a pagelet from the controller will remove it from all descendant pages too. If the pagelet is then unused, it will be deleted.


#import "KSOrderedManagedObjectControllers.h"

#import "SVSidebar.h"
#import "SVGraphicFactory.h"


@class KTPage;


@interface SVSidebarPageletsController : KSArrayController
{
  @private
    KTPage  *_page;
}

// Populates the controller with the sidebar pagelets for the given page. Changes are NOT observed though. To turn that on, call -bindContentToPage.
- (id)initWithPageletsInSidebarOfPage:(KTPage *)page;

@property(nonatomic, retain) KTPage *page;


#pragma mark Arranging Objects
- (void)bindContentToPage;  // see -initWithPage: docs above
+ (NSArray *)allSidebarPageletsInManagedObjectContext:(NSManagedObjectContext *)context;
+ (NSArray *)pageletSortDescriptors;


#pragma mark Adding/Inserting/Removing/Objects
- (void)moveObject:(id)object toIndex:(NSUInteger)index;
- (void)moveObject:(id)object beforeObject:(id)pagelet;
- (void)moveObject:(id)object afterObject:(id)pagelet;
- (void)exchangeWithPrevious:(id)sender;
- (void)exchangeWithNext:(id)sender;


#pragma mark Recursion
// When adding or removing a pagelet, generally want to recursively add it to all applicable descendants too.
// -addObject: etc. do this as part of their implementation, but if you're not in a position to call -addObject: (i.e. a controller that lists all pagelets, not just those on a specific page) you can use +addPagelet:toSidebarOfPage: directly instead.
// Similarly, -removePagelet:fromSidebarOfPage: recursively removes the pagelet from all applicable sidebars, but never actually deletes it.

+ (void)addPagelet:(SVGraphic *)pagelet toSidebarOfPage:(KTPage *)page;
- (void)removePagelet:(SVGraphic *)pagelet fromSidebarOfPage:(KTPage *)page;


#pragma mark Pasteboard/Serialization

//- (void)insertPageletsFromPasteboard:(NSPasteboard *)pasteboard;

- (BOOL)insertPageletsFromPasteboard:(NSPasteboard *)pboard
               atArrangedObjectIndex:(NSUInteger)index;

- (SVGraphic *)addObjectFromSerializedPagelet:(id)serializedPagelet;

@end


#pragma mark -


// Tailored to supply the tableview in Inspector
@interface SVInspectorSidebarPageletsController : SVSidebarPageletsController

// Synchronous unlike default implementation. #116944
- (void)fetch:(id)sender;

@end
