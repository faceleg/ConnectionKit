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


@class SVSidebar;


@interface SVSidebarPageletsController : KSSetController
{
  @private
    SVSidebar   *_sidebar;
}

- (id)initWithSidebar:(SVSidebar *)sidebar;    // sets .managedObjectContext too
@property(nonatomic, retain, readonly) SVSidebar *sidebar;

@end
