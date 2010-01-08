//
//  SVSidebarPageletsController.m
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarPageletsController.h"

#import "SVPagelet.h"
#import "SVSidebar.h"


@implementation SVSidebarPageletsController

- (id)initWithSidebar:(SVSidebar *)sidebar;
{
    self = [self init];
    _sidebar = [sidebar retain];
    
    [self setObjectClass:[SVPagelet class]];
    [self setManagedObjectContext:[sidebar managedObjectContext]];
    [self setEntityName:@"Pagelet"];
    [self setAvoidsEmptySelection:NO];
    [self setSortDescriptors:[SVPagelet pageletSortDescriptors]];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES],
                             NSRaisesForNotApplicableKeysBindingOption,
                             nil];
    [self bind:NSContentSetBinding toObject:sidebar withKeyPath:@"pagelets" options:options];
    
    return self;
}

- (void)dealloc
{
    [_sidebar release];
    
    [super dealloc];
}

@synthesize sidebar = _sidebar;

@end
