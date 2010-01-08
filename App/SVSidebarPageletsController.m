//
//  SVSidebarPageletsController.m
//  Sandvox
//
//  Created by Mike on 08/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSidebarPageletsController.h"

#import "KTPage.h"
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

- (void)removePagelet:(SVPagelet *)pagelet fromPageAndDescendants:(KTAbstractPage *)page;
{
    // No point going any further unless the page actually contains the pagelet! This can save recursing enourmous chunks of the site outline
    if ([[[page sidebar] pagelets] containsObject:pagelet])
    {
        // Remove from descendants first
        for (KTPage *aPage in [page childPages])
        {
            [self removePagelet:pagelet fromPageAndDescendants:aPage];
        }
        for (KTAbstractPage *anArchivePage in [page archivePages])
        {
            [self removePagelet:pagelet fromPageAndDescendants:anArchivePage];
        }
        
        // Remove from the receiver
        [[page sidebar] removePageletsObject:pagelet];
    }
}

- (void)willRemoveObject:(id)object
{
    OBPRECONDITION([object isKindOfClass:[SVPagelet class]]);
    SVPagelet *pagelet = object;
                   
    // Recurse down the page tree removing the pagelet from their sidebars.
    [self removePagelet:pagelet fromPageAndDescendants:[[self sidebar] page]];
    
    // Delete the pagelet if it no longer appears on any pages
    if ([[pagelet sidebars] count] == 0 && ![pagelet callout])
    {
        [[self managedObjectContext] deleteObject:pagelet];
    }
}

@end
