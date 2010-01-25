//
//  SVSidebarPageletsController.h
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Correctly sorts the pagelets in a given sidebar. 
//  Removing a pagelet from the controller will remove it from all descendant pages too. If the pagelet is then unused, it will be deleted.


#import "KSOrderedManagedObjectControllers.h"


@class SVPagelet, KTPage, SVSidebar;


@interface SVSidebarPageletsController : KSSetController
{
  @private
    SVSidebar   *_sidebar;
}

- (id)initWithSidebar:(SVSidebar *)sidebar;    // sets .managedObjectContext too
@property(nonatomic, retain, readonly) SVSidebar *sidebar;


#pragma mark Recursion
// When adding or removing a pagelet, generally want to recursively add it to all applicable descendants too. This method will do that. -addObject: etc. do this as part of their implementation, but if you're not in a position to call -addObject: (i.e. a controller that lists all pagelets, not just those on a specific page) you can use this method directly instead.

- (void)addPagelet:(SVPagelet *)pagelet toSidebarOfPage:(KTPage *)page;


@end
