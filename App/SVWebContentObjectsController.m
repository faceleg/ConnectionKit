//
//  SVWebContentObjectsController.m
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentObjectsController.h"

#import "KTPage.h"
#import "SVPagelet.h"
#import "SVSidebar.h"


@implementation SVWebContentObjectsController

- (void)dealloc
{
    [_page release];
    [super dealloc];
}

@synthesize page = _page;

- (void)willRemoveObject:(id)object;
{
    [super willRemoveObject:object];
    
    // For now I'm assuming all content is a pagelet
    // Remove pagelet from sidebar. Delete if appropriate
    SVPagelet *pagelet = object;
    
    [[[self page] sidebar] removePageletsObject:pagelet];
    
    if ([[pagelet sidebars] count] == 0)
    {
        [[pagelet managedObjectContext] deleteObject:pagelet];
    }
}

@end
